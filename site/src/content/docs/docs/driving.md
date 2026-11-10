---
title: Driving a run
description: orch autopilot drives every run; the lead helps when it stops.
---

Once the plan is ready, something has to hand out milestones, run checks, send reviews and land the results. That is `orch autopilot`: a plain script you start in a spare terminal. No AI spends tokens on scheduling; agents only spend them on coding and review.

```bash
orch autopilot
```

It exits 0 when every milestone has landed, or 3 when it needs you, and writes why to `.orchestrate/autopilot.log` with a desktop notification.

## What it handles on its own

| Situation | What autopilot does |
|---|---|
| Milestones are ready | sends each to a free coder; milestones that touch the same files run one after the other |
| A check fails | sends the last 60 lines back to the coder, up to 3 rounds |
| A review finds blockers | queues a fix job for the next free coder, up to 2 rounds |
| A merge conflicts | sends a conflict job, then has the resolution reviewed again |
| Passes alone, fails once merged | nothing is committed; a coder gets a fix round |
| A coder hits a usage limit | benches it for 60 minutes; another coder continues with the work so far |
| An agent stops early | nudges it once, then parks the milestone |
| Attempts keep getting lost | the milestone fails after 4 (`ORCH_MAX_LOST`) instead of looping |
| Lockfiles changed | runs the setup command again in that folder |
| A risky change | holds it until you run `orch approve Mn` |

## One driver per run

While autopilot runs it holds the run's lease. A second autopilot is refused, and so is any `orch` command that would change the run from another terminal or agent. `orch status`, `orch report` and `orch approve` still work.

If autopilot is killed, the lease is freed and the next run recovers: a prompt that was never confirmed is confirmed or sent again to the same agent, and a half-done merge is finished or undone.

## Nothing red is committed

Each milestone is squashed onto the feature branch, the check runs on that result, and only a green result is committed. The check must also pass before the run starts; autopilot refuses to start on a failing baseline.

## Held for approval

A milestone that deletes files, touches migrations, CI configuration or secrets files, changes dependency files it did not list, or is very large is held before it lands. Look at it, then run `orch approve Mn`. `Risk hold: off` in the plan header turns this off.

## Where the lead fits

The lead plans the feature and handles exceptions. It does not drive runs. When autopilot stops, ask the lead to help: `/orch-run`, "use the orch-run skill", or ``Run `orch lead run` and follow it``. It reads `orch status` and the log, asks you what it needs, writes your answers into the plan, and tells you to start autopilot again. See [When a run stops](/docs/when-it-stops/).

## Resuming

Run `orch autopilot` again. Landed milestones are never redone, and parked milestones keep their work in hidden git refs.

## How the run went

`orch report` prints time, rounds, first-pass rate and wasted work for the run (`--json` for a script). The same report is in `.orchestrate/summary.md` at the end.
