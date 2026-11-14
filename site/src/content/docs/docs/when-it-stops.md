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
| The computer was restarted, herdr was closed, or the event manager died | `orch status` starts with `!! EVENT MANAGER NOT RUNNING`. Open herdr and run `orch resume` (see below) |
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

## After a restart

Nothing on a switched-off computer can restart itself, so after a reboot, or after closing herdr, run one command in the repo:

```bash
orch resume
```

It says what it did:

1. **The time orch was down is not counted.** Example: M4 was sent at 11:30, the computer went off at 11:42 and came back at 13:31. M4 counts 12 minutes of work, not 2 hours, so it is not paused as "over its time budget". The time report says `Not counted: 1h49m while orch was not running`. A laptop that only slept, with the event manager still up, needs no command: the sleep is taken out the same way.
2. **Agents get their names back.** herdr brings the panes back without the agents' names. `orch resume` finds each coder's pane by its folder and names it again. Where it can't decide, it prints the exact command, such as `herdr agent rename w1:p5 reviewer`. A pane that came back as a plain shell gets its agent started again by `orch team up`, in the same pane.
3. **Unsaved work is saved** into the milestone it belongs to.
4. **Each task that was in progress is sent to its agent again.** A fresh conversation carries on from the task file and the code, so you don't type "continue" in each pane.
5. **The event manager is started**, and it wakes the lead if events wait for it.

It is safe to run more than once. `orch autopilot` and the lead's `orch dispatch` do steps 1 to 4 by themselves when they start the event manager after a gap.

orch never refuses a task because a coder's folder has unsaved files. It saves them into the milestone they belong to first. If it can't tell whose they are, it keeps them in a rescue ref and prints its name, for example `refs/orch/feature-x/rescue-opencode-1-20261114-133100`. `orch finish` keeps rescue refs and lists them.

## Useful commands

- `orch status`: every worker and milestone, and why something waits.
- `orch resume`: carry on after a restart.
- `orch events --peek`: the lead's queue, without acknowledging anything.
- `orch park M2 paused "why"`: stop a milestone and keep its work. A coder that is still working on it is told to stop.
- `orch cooldown claude-1 60`: bench an agent for 60 minutes.
- `orch requeue-review M2`: send a review again after the reviewer vanished.
