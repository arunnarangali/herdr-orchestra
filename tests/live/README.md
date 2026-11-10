# Live smoke suite (opt-in)

`tests/run.sh` proves the orchestration with fake agents. This suite proves the same pipeline with the REAL agent
tools: prompt delivery, the result file, the check, review and the merge. It is not part of CI: it needs Herdr,
the agents signed in, and it spends their credits (one tiny milestone per run).

    bash tests/live/run.sh claude            # claude codes, no reviewer
    bash tests/live/run.sh codex claude      # codex codes, claude reviews

What it does:

1. Runs `orch doctor` for the kinds you named and stops if one is broken.
2. Creates a throwaway repo (a tiny Python module with one test) under `$TMPDIR`.
3. Asks you to start the agents in Herdr panes in that folder and name them `live-coder` (and `live-reviewer`).
   It prints the launch commands and waits until herdr sees them.
4. Runs `orch autopilot` on a one-milestone plan ("add a `mul` function and its test").
5. Asserts: the run finished, the result file was valid JSON, the check passed, exactly one commit landed with a
   real subject, and (with a reviewer) a review file was read. It appends one line to `tests/live/results.md`.

Run it before a release for each agent kind you support, and commit `results.md`.
