#!/usr/bin/env bash
# Runs tests/run.sh faster by running its sections side by side. Nothing in the tests changes: every section runs
# exactly as written, with the same waits, in its own copy of the test setup (its own temp folder, fake herdr,
# fake agents and orch config), so sections cannot see each other.
#   bash tests/parallel.sh             all sections, side by side (what CI runs)
#   bash tests/parallel.sh -j 2        at most 2 groups at a time (default: twice the CPU count, at most 12)
#   bash tests/parallel.sh --list      the groups and their sections
#   bash tests/parallel.sh 24 45       only the groups that hold sections 24 and 45 (for local work; not a gate)
#   bash tests/run.sh                  the same tests one after another, as before
# It fails if any check fails, if any group stops early, or if a section of run.sh was not run at all.
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC="$ROOT/tests/run.sh"
jobs=$(( $(nproc 2>/dev/null || echo 2) * 2 )); [ "$jobs" -gt 12 ] && jobs=12
list=0; want=()
while [ $# -gt 0 ]; do
  case $1 in
    -j) jobs=$2; shift;;
    -j*) jobs=${1#-j};;
    --list) list=1;;
    -h|--help) sed -n '2,10p' "$0"; exit 0;;
    *) want+=("$1");;
  esac; shift
done

# Sections that use what an earlier section left behind (its repo, its variables) run in the same group, right after
# it. Each entry is the section's number as run.sh prints it; it joins the group of the section before it in run.sh.
# A section added later that needs the one before it goes here too (tests/parallel.sh then runs them together).
JOINS=" 2 8 19 27 25b 26 11b 30 31 32 30b 34 38 41 42 48b 48c 59 "

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
# cut run.sh into: the setup at the top, one file per section, and the final count at the bottom
awk -v T="$T" '
  /^echo "[0-9]+[a-z]?\. / && !tail { n++; f = sprintf("%s/sec-%03d", T, n); }
  /^echo; echo "passed \$pass, failed \$fail"$/ { tail = 1; f = T "/tail" }
  { if (!n && !tail) print > (T "/head"); else print > f }
' "$SRC"
[ -s "$T/head" ] && [ -s "$T/tail" ] || { echo "tests/parallel.sh: could not find the sections in tests/run.sh"; exit 2; }
label(){ sed -n '1s/^echo "\([0-9]*[a-z]*\)\..*/\1/p' "$1"; }

# group the sections
g=0; : > "$T/groups"
for s in "$T"/sec-*; do
  l=$(label "$s")
  if [ "$g" -eq 0 ] || [[ $JOINS != *" $l "* ]]; then g=$((g+1)); fi
  echo "$g $l ${s##*/}" >> "$T/groups"
done
for j in $JOINS; do grep -q " $j sec-" "$T/groups" || { echo "tests/parallel.sh: JOINS names section $j, which run.sh does not have"; exit 2; }; done

if [ $list -eq 1 ]; then
  awk '{a[$1] = a[$1] " " $2; if ($1 > m) m = $1} END {for (i = 1; i <= m; i++) print "group " i ":" a[i]}' "$T/groups"; exit 0
fi

sel=$(cut -d' ' -f1 "$T/groups" | sort -un)
if [ ${#want[@]} -gt 0 ]; then
  sel=$(for w in "${want[@]}"; do awk -v w="$w" '$2 == w {print $1}' "$T/groups"; done | sort -un)
  [ -n "$sel" ] || { echo "no section ${want[*]} in tests/run.sh (see --list)"; exit 2; }
fi

# one script per group: the setup, its sections, the final count. ROOT is the real checkout, not the temp folder.
for i in $sel; do
  { sed "s|^ROOT=.*|ROOT=\"$ROOT\"|" "$T/head"
    awk -v i="$i" '$1 == i {print $3}' "$T/groups" | while read -r f; do cat "$T/$f"; done
    cat "$T/tail"; } > "$T/group-$i.sh"
  grep -q "^ROOT=\"$ROOT\"$" "$T/group-$i.sh" || { echo "tests/parallel.sh: could not set ROOT"; exit 2; }
done

start=$(date +%s)
echo "running $(wc -w <<<"$sel") groups of tests/run.sh, $jobs at a time"
# the slowest groups start first, so the run is not left waiting on one long group at the end
order=$(for i in $sel; do printf '%s %s\n' "$(grep -c 'autopilot\|sleep\|timeout' "$T/group-$i.sh")" "$i"; done | sort -rn | cut -d' ' -f2)
printf '%s\n' $order | xargs -P "$jobs" -I{} bash -c 's=$(date +%s); bash "$1/group-$2.sh" > "$1/out-$2" 2>&1; echo $? > "$1/code-$2"; echo $(( $(date +%s) - s )) > "$1/secs-$2"' _ "$T" {}

pass=0 fail=0 bad=0
for i in $sel; do
  cat "$T/out-$i"
  last=$(grep -E '^passed [0-9]+, failed [0-9]+$' "$T/out-$i" | tail -1)
  if [ -z "$last" ]; then
    echo "  FAIL group $i stopped before its end (exit $(cat "$T/code-$i"))"; bad=$((bad+1)); continue
  fi
  set -- $last; pass=$((pass+${2%,})); fail=$((fail+$4))
  # every section of the group printed its title, so none was skipped
  for l in $(awk -v i="$i" '$1 == i {print $2}' "$T/groups"); do
    grep -q "^$l\. " "$T/out-$i" || { echo "  FAIL section $l did not run"; bad=$((bad+1)); }
  done
done
echo
echo "slowest groups:"; for i in $sel; do echo "$(cat "$T/secs-$i")s group $i:$(awk -v i="$i" '$1 == i {printf " %s", $2}' "$T/groups")"; done | sort -rn | head -5
echo "passed $pass, failed $fail$([ $bad -gt 0 ] && echo ", $bad group problems") in $(( $(date +%s) - start ))s"
[ $fail -eq 0 ] && [ $bad -eq 0 ]
