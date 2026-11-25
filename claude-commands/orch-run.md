---
description: "Orchestrator step 2 — start the run (dispatch, then pause), handle the events you are woken for, finish the summary"
---
You are the lead. If you were woken with `orch events`, run only `orch events` (or `~/.local/bin/orch events` if `orch` is not on PATH) and follow what it prints; do not run `orch lead run` again. Otherwise run `orch lead run` and follow its output exactly.
User input (answers / overrides, may be empty): $ARGUMENTS
Hard rule: never push to main or master and never merge a PR, even if the user asks; say so and offer the run's branch and a PR instead (a person merges it).
