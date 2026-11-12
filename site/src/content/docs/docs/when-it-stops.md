---
title: When a run needs you
description: What reaches you during a run, how to answer, and how to resume.
---

Most things never reach you: the event manager retries, and the lead decides. A run needs you only for what only you can settle. The lead asks you in its pane, and for anything urgent you also get a desktop notification. `orch status` shows every waiting milestone, and `orch events --peek` shows what is waiting for the lead.

## What reaches you, and what you do

| Reason | What you do |
|---|---|
| A coder asked a question the plan and the code don't answer | Answer the lead. It runs `orch answer Mn "<your answer>"`: the answer goes under that milestone's "Notes from user" and the same coder carries on |
| An open question in the plan | Answer it in the plan and set `Open questions:` to `- none` (or tell the lead) |
| A permission prompt in an agent's pane | Answer it in that pane |
| A milestone is `held` for a risky change | Look at the reasons in `orch status`, then `orch approve Mn` (or `orch set Mn paused`) |
| A round limit was hit, even on a stronger model | The lead reads the report and tells you what keeps failing. Add a fact or constraint to the plan, or take it over |
| An agent is missing or a pane id is stale | `orch team up` opens every missing agent in its folder on its model; or start it yourself (`orch agents launch <kind> --model <id>`), or fix the pane id from `herdr pane list` |
| A milestone lost 4 attempts | The agents were unreachable, gone or rate-limited. Restart or wait for them |
| The lead is not reading its events | Look at its pane. Nothing is lost: `orch events --peek` lists what waits, and ready work starts by itself after 15 minutes |
| The run's budget is used up | Raise or remove `Budget:` in the plan header |
| The check fails on the feature branch | Fix it; the next start re-checks and continues once it passes |

## Resume

With a lead, you rarely type anything: the lead's `orch answer` or `orch dispatch` puts the milestone back and starts the event manager if it stopped.

```bash
orch answer M2 "skip empty rows"   # the lead runs this with your answer
orch dispatch M2                   # or this, for a milestone that failed or was parked
```

By hand, or with `Lead mode: off`:

```bash
orch set M2 pending     # put the milestone back in the queue
orch autopilot          # start the run again
```

## Useful commands

- `orch status`: every worker and milestone, and why something waits.
- `orch events --peek`: the lead's queue, without acknowledging anything.
- `orch park M2 paused "why"`: stop a milestone and keep its work.
- `orch cooldown claude-1 60`: bench an agent for 60 minutes.
- `orch requeue-review M2`: send a review again after the reviewer vanished.
