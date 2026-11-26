#!/bin/sh
# Opens the board popup in the repo of the pane you were in. Herdr starts a popup in the plugin's own folder unless
# told otherwise, so the folder is passed with --cwd: the focused pane's folder, else the space's folder, else its worktree.
dir=$(python3 - <<'PY' 2>/dev/null
import json, os, subprocess
try:
    ctx = json.loads(os.environ.get("HERDR_PLUGIN_CONTEXT_JSON") or "{}")
except ValueError:
    ctx = {}
wt = ctx.get("worktree") if isinstance(ctx.get("worktree"), dict) else {}
cands = [c for c in (ctx.get("focused_pane_cwd"), ctx.get("workspace_cwd"), wt.get("path")) if isinstance(c, str) and os.path.isdir(c)]

def toplevel(d):
    r = subprocess.run(["git", "-C", d, "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None

def has_run(d):
    # a worktree's pane has its own top level; the run lives in the main repo (the git common dir's parent)
    r = subprocess.run(["git", "-C", d, "rev-parse", "--git-common-dir"], capture_output=True, text=True)
    if r.returncode != 0:
        return False
    common = os.path.normpath(os.path.join(d, r.stdout.strip()))
    return os.path.isfile(os.path.join(os.path.dirname(common), ".orchestrate", "state.json"))

pick = next((c for c in cands if has_run(c)), None) or next((c for c in cands if toplevel(c)), None) or (cands[0] if cands else "")
print(pick)
PY
)
herdr=${HERDR_BIN_PATH:-herdr}
if [ -n "$dir" ]; then
  exec "$herdr" plugin pane open --plugin herdr-orchestra.board --entrypoint board --placement popup --cwd "$dir"
fi
exec "$herdr" plugin pane open --plugin herdr-orchestra.board --entrypoint board --placement popup
