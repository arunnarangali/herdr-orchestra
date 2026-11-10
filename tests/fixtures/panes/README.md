# Pane fixtures

Text captured from agent panes, used by `tests/run.sh` to test how `orch` reads them.

- `*ratelimit*.txt` must match `RATE_RE` in `bin/orch` (the agent hit a usage or rate limit).
- every other `.txt` must NOT match it (idle, permission prompt, normal output).

Files named `synthetic-*` were written by hand from the messages the test suite already used. They are not
captures. Replace or add to them with real ones when you see them:

    herdr agent read <agent> --source recent-unwrapped --lines 40 > tests/fixtures/panes/<kind>-ratelimit-<date>.txt

Remove anything private (paths, prompts, keys) before committing a capture.
