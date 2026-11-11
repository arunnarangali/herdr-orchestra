---
title: The orchestration run
description: The lead dispatches and decides; the event manager (orch autopilot) does the work in between and wakes the lead.
---

Once you approve the plan, the **orchestration run** starts. Two things run it:

- The **lead** dispatches milestones and makes every decision that needs judgment.
- The **event manager**, `orch autopilot`, is a plain script. It hands each milestone to a coder, runs checks, sends reviews and fixes, lands the results, and wakes the lead when there is something to decide. No AI spends tokens on scheduling or waiting.

## Starting it

Tell the lead to go (`/orch-run`). It runs:

```bash
orch dispatch M1 M2
```

That releases the milestones and starts the event manager in the background if none is running (its log is `.orchestrate/autopilot.log`). The lead then pauses. You can also start the event manager yourself in a spare terminal:

```bash
orch autopilot
```

It exits 0 when every milestone has landed.

## The lead is woken, not polling

The lead does nothing between events. When a milestone lands, a coder asks a question, a milestone fails or is held, or new work is ready, the event manager types one line into the lead's pane, and the lead runs `orch events`, handles what it lists, and pauses again. Every event is stored on disk first, so none is missed while the lead is busy or away. See [The lead and the event manager](/docs/lead/).

## What the event manager handles on its own

| Situation | What it does |
|---|---|
| A dispatched milestone is ready | sends it to a free coder whose model serves its tier; milestones that touch the same files run one after the other |
| A check fails | sends the last 60 lines back to the coder, up to 3 rounds |
| A review finds blockers | queues a fix job for the next free coder, up to 2 rounds |
| A milestone is out of rounds | one fresh round on a coder with a stronger model, with the work so far |
| A merge conflicts | sends a conflict job, then has the resolution reviewed again |
| Passes alone, fails once merged | nothing is committed; a coder gets a fix round |
| A coder hits a usage limit | benches it for 60 minutes; another coder continues with the work so far |
| An agent stops early | nudges it once, then parks the milestone and wakes the lead |
| Attempts keep getting lost | the milestone fails after 4 (`ORCH_MAX_LOST`) instead of looping |
| Lockfiles changed | runs the setup command again in that folder |
| A risky change | holds it until you run `orch approve Mn` |
| The lead does not read its events | wakes it again after 5 minutes, 3 times, then notifies you; starts ready work itself after 15 minutes |

## One driver per run

While the event manager runs it holds the run's lease. A second one is refused, and so is any `orch` command that would change the run from another terminal or agent. Reading still works (`orch status`, `orch report`, `orch events`), and so do the requests the event manager carries out for the lead and for you: `orch dispatch`, `orch answer` and `orch approve`.

If the event manager is killed, the lease is freed and the next start recovers: a prompt that was never confirmed is confirmed or sent again to the same agent, and a half-done merge is finished or undone. The lead's next `orch dispatch` or `orch answer` starts it again.

## Nothing red is committed

Each milestone is squashed onto the feature branch, the check runs on that result, and only a green result is committed. The check must also pass before the run starts; the event manager refuses to start on a failing baseline.

## Held for approval

A milestone that deletes files, touches migrations, CI configuration or secrets files, changes dependency files it did not list, or is very large is held before it lands. The lead shows you why. Look at it, then run `orch approve Mn`. The lead cannot approve it. `Risk hold: off` in the plan header turns this off.

## Running without a lead

With `Lead mode: off` in the plan header, `orch autopilot` dispatches every ready milestone by itself and exits 3 when it needs you, with the reason in the log and a desktop notification. See [When a run needs you](/docs/when-it-stops/).

## Resuming

Run `orch autopilot` again, or have the lead dispatch or answer. Landed milestones are never redone, and parked milestones keep their work in hidden git refs.

## How the run went

`orch report` prints time, rounds, first-pass rate and wasted work for the run, and how each model did (`--json` for a script). The same report is in `.orchestrate/summary.md` at the end, next to a table of the tier planned for each milestone and the model that really did it.
