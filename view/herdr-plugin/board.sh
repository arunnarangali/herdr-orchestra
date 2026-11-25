#!/bin/sh
# The popup's program: `orch board` in the run's repo. Closes with q.
orch=$(command -v orch || echo "$HOME/.local/bin/orch")
[ -x "$orch" ] || { echo "orch not found on PATH — install herdr-orchestra (npx herdr-orchestra@latest)"; sleep 5; exit 1; }
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "This folder is not a git repo with an orch run. Open the board from a pane inside the repo."; sleep 5; exit 1
fi
exec "$orch" board
