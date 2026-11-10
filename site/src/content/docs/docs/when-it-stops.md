---
title: When a run stops
description: What to do when a run needs you, and how to resume it.
---

A run stops only when it can't continue without you. You get a desktop notification, the reason is in `.orchestrate/autopilot.log`, and `orch status` prints `STUCK` with every waiting milestone.

## Common reasons

| Reason | What you do |
|---|---|
| A coder asked a question (`QUESTION:`) | Answer under that milestone's "Notes from user" |
| An open question in the plan | Answer it and set `Open questions:` to `- none` |
| A permission prompt in an agent's pane | Answer it in that pane |
| A round limit was hit (3 check fixes, 2 reviews, 2 conflicts) | Read the report, add a fact or constraint to the plan, or take it over |
| An agent is missing or a pane id is stale | Start the agent (`orch agents launch <kind>`), or fix the pane id from `herdr pane list` |
| A milestone is `held` for a risky change | Look at the reasons in `orch status`, then `orch approve Mn` (or `orch set Mn paused`) |
| A milestone lost 4 attempts | The agents were unreachable, gone or rate-limited. Restart or wait for them |
| The run's budget is used up | Raise or remove `Budget:` in the plan header |
| The check fails on the feature branch | Fix it; the next run re-checks and continues once it passes |

## Resume

```bash
orch set M2 pending     # put the milestone back in the queue
orch autopilot          # start the run again
```

Or ask the lead to handle it with you: it reads the status and log, asks what it needs, writes your answers into the plan and tells you to start autopilot again (`/orch-run`).

## Useful commands

- `orch status`: every worker and milestone, and why something waits.
- `orch park M2 paused "why"`: stop a milestone and keep its work.
- `orch cooldown claude-1 60`: bench an agent for 60 minutes.
- `orch requeue-review M2`: send a review again after the reviewer vanished.
