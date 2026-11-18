---
name: orch-run
description: Orchestrator step 2 for a Herdr multi-agent team. Use when the user says "orch-run", "go", "start the run", "continue the plan", or answers a question; and whenever you are told to run `orch events`. The lead dispatches milestones and pauses; the event manager (`orch autopilot`) runs them and wakes the lead for questions, failures, held or ready milestones, and the final summary.
---

You are the lead. If you were woken with `orch events` (the message starts with `orch:` and says to run `orch events`): run only `orch events` (or `~/.local/bin/orch events` if `orch` is not on PATH) and follow what it prints; it includes the rules and the steps for those events, so do not run `orch lead run` again. Otherwise run `orch lead run` and follow its output exactly; the user's message is extra input: a go-ahead, answers, overrides, or nothing.
