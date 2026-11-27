#!/bin/sh
# The popup's program: `orch board` in the run's repo. Closes with q.
# Herdr closes a popup the moment its program ends, so anything that ends it early (a missing orch, no repo, an
# error) must stay on screen until a key is pressed, and the reason is saved where a bug report can find it.
log="${ORCH_SHARE:-$HOME/.local/share/herdr-orchestra}/board-error.log"
hold() {  # hold <message...>: show why the board ended, save it, wait for a key
  printf '%s\n' "$@"
  mkdir -p "$(dirname "$log")" 2>/dev/null
  { date '+%Y-%m-%d %H:%M:%S'; echo "folder: $(pwd)"; printf '%s\n' "$@"; } > "$log" 2>/dev/null
  printf '\nSaved in %s. Press any key to close.' "$log"
  if [ -t 0 ]; then
    old=$(stty -g 2>/dev/null); stty -icanon -echo 2>/dev/null
    dd bs=1 count=1 >/dev/null 2>&1
    [ -n "$old" ] && stty "$old" 2>/dev/null
  else
    sleep "${ORCH_BOARD_HOLD_S:-30}"
  fi
  exit 1
}
orch=$(command -v orch || echo "$HOME/.local/bin/orch")
[ -x "$orch" ] || hold "orch not found on PATH — install herdr-orchestra (npx herdr-orchestra@latest)"
git rev-parse --show-toplevel >/dev/null 2>&1 \
  || hold "This folder ($(pwd)) is not a git repo with an orch run. Open the board from a pane inside the repo."
{ [ -t 0 ] && [ -t 1 ]; } || hold "The popup has no terminal to draw in (stdin or stdout is not a terminal)."
err=$(mktemp 2>/dev/null || echo "/tmp/orch-board.$$")
start=$(date +%s)
"$orch" board 2>"$err"; code=$?
took=$(( $(date +%s) - start ))
msg=$(tail -n 25 "$err" 2>/dev/null); rm -f "$err"
[ "$code" -eq 0 ] && exit 0                       # closed with q or Esc
hold "orch board stopped by itself (exit $code, after ${took}s) in $(pwd):" "" "${msg:-no error text}"
