#!/bin/sh
# Opens the board popup in the folder of the pane you were in (that is where the run's repo is).
dir=$(python3 - <<'PY' 2>/dev/null
import json, os
def find(o, keys):
    if isinstance(o, dict):
        for k in keys:
            if isinstance(o.get(k), str) and os.path.isdir(o[k]):
                return o[k]
        o = list(o.values())
    if isinstance(o, list):
        for v in o:
            r = find(v, keys)
            if r:
                return r
    return None
try:
    print(find(json.loads(os.environ.get("HERDR_PLUGIN_CONTEXT_JSON") or "{}"), ("foreground_cwd", "cwd", "path")) or "")
except ValueError:
    print("")
PY
)
herdr=${HERDR_BIN_PATH:-herdr}
if [ -n "$dir" ]; then
  exec "$herdr" plugin pane open --plugin herdr-orchestra.board --entrypoint board --placement popup --cwd "$dir"
fi
exec "$herdr" plugin pane open --plugin herdr-orchestra.board --entrypoint board --placement popup
