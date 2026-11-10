#!/usr/bin/env bash
# Opt-in smoke test with REAL agents (see tests/live/README.md). Not run in CI: needs herdr + signed-in agents.
#   bash tests/live/run.sh <coder kind> [reviewer kind]
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
ORCH="$ROOT/bin/orch"; HERDR_BIN=${HERDR:-herdr}
coder=${1:?usage: tests/live/run.sh <coder kind> [reviewer kind]}; reviewer=${2:-}
command -v "$HERDR_BIN" >/dev/null || { echo "herdr is not on PATH (set HERDR=/path/to/herdr)"; exit 2; }
"$ORCH" doctor "$coder" ${reviewer:+"$reviewer"} || { echo "orch doctor found a problem: fix it first"; exit 2; }

APP=$(mktemp -d "${TMPDIR:-/tmp}/orch-live-XXXXXX")/app; mkdir -p "$APP"; cd "$APP" || exit 2
git init -q -b main && git config user.email live@example.com && git config user.name live
cat > calc.py <<'PY'
def add(a, b):
    return a + b
PY
cat > test_calc.py <<'PY'
import unittest
import calc


class CalcTest(unittest.TestCase):
    def test_add(self):
        self.assertEqual(calc.add(2, 3), 5)


if __name__ == "__main__":
    unittest.main()
PY
git add . && git commit -qm "init" && mkdir .orchestrate
rev_line=none; review=no
[ -n "$reviewer" ] && { rev_line="live-reviewer ($reviewer)"; review=yes; }
cat > .orchestrate/plan.md <<PLAN
# Plan: Live smoke test
Branch: feature/live-smoke
Check command: python3 -m unittest -q
Setup command: none
Isolation: shared
Workers: live-coder ($coder)
Reviewer: $rev_line

## Global instructions
none

## [x] M1: Multiply
Depends on: none
Review: $review
Likely files: calc.py, test_calc.py
Goal: calc.py can multiply two numbers.
Why: smoke test of the orchestration with a real agent.
Acceptance criteria:
- calc.mul(a, b) returns the product of a and b
- test_calc.py has a test for mul, and the check command passes
Open questions:
- none
PLAN

echo
echo "Start the agent(s) in Herdr panes whose folder is: $APP"
echo "  coder:    $("$ORCH" agents launch "$coder")      then name it:  herdr agent rename <its pane> live-coder"
[ -n "$reviewer" ] && echo "  reviewer: $("$ORCH" agents launch "$reviewer")      then name it:  herdr agent rename <its pane> live-reviewer"
echo "Waiting up to 10 minutes for herdr to see them…"
for _ in $(seq 120); do
  "$HERDR_BIN" agent get live-coder >/dev/null 2>&1 && { [ -z "$reviewer" ] || "$HERDR_BIN" agent get live-reviewer >/dev/null 2>&1; } && break
  sleep 5
done
"$HERDR_BIN" agent get live-coder >/dev/null 2>&1 || { echo "herdr never saw live-coder — giving up"; exit 2; }

start=$(date +%s)
# shellcheck disable=SC2034  # read by the eval'd checks below
"$ORCH" autopilot; code=$?
secs=$(( $(date +%s) - start ))
fail=0
ok(){ echo "  ok   $*"; }; bad(){ echo "  FAIL $*"; fail=1; }
t(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }
t "autopilot finished the run (exit 0)" '[ $code -eq 0 ]'
t "the milestone merged" '"$ORCH" status | grep -q "M1 .*merged"'
t "the coder wrote a valid result file" 'python3 -c "import json,glob; fs=sorted(glob.glob(\".orch-task/M1/result-*.json\")); assert fs; d=json.load(open(fs[-1])); assert d[\"status\"]==\"done\""'
t "the check passes on the branch" 'python3 -m unittest -q >/dev/null 2>&1'
t "calc.mul exists and works" 'python3 -c "import calc; assert calc.mul(6, 7) == 42"'
t "exactly one commit landed, with a real subject" '[ "$(git rev-list --count main..feature/live-smoke)" -eq 1 ] && ! git log -1 --format=%s | grep -qi "^multiply$"'
[ -z "$reviewer" ] || t "the reviewer's verdict was read" 'ls .orchestrate/review/M1/review-1.json .orchestrate/review/M1/review-1.md 2>/dev/null | grep -q review-1'
"$ORCH" report || true
res=$([ $fail -eq 0 ] && echo PASS || echo FAIL)
printf '| %s | %s | %s | %s | %ss | %s |\n' "$(date +%F)" "$("$ORCH" version | awk '{print $2}')" "$coder" "${reviewer:-none}" "$secs" "$res" >> "$ROOT/tests/live/results.md"
echo; echo "$res in ${secs}s — recorded in tests/live/results.md. The test repo is $APP"
exit $fail
