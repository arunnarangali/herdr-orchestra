---
title: Driving a run
description: Two ways to run the build loop, the lead or the orch autopilot script, and how to choose.
---

Once the plan is ready, something has to hand out milestones, run checks, send reviews and land the results. You choose who does that for each run. Both follow the same rules and use the same state, so you can switch between them mid-run.

| | Lead drives | Script drives |
|---|---|---|
| Start it | `/orch-run` in the lead's pane, or "use the orch-run skill", or ``Run `orch lead run` and follow it`` | `orch autopilot` in a spare terminal |
| Judgment on failures | Yes: the lead reads panes and reports | No: it applies the round limits and stops for you |
| Cost | AI tokens for every scheduling turn | None for scheduling; agents only spend tokens on coding and review |
| Baseline check already failing | Works (judges "no new failures") | Refuses to start |
| Best for | Short runs, unclear failures | Long runs, overnight runs |

## The lead drives

The lead runs the loop itself: `orch ready`, `orch pick`, `orch prepare`, `orch write-task`, `orch send`, then waits with `orch poll` and handles each event (`DONE`, `REVIEWED`, `BLOCKED`, `IDLE`, `TIMEOUT`, `GONE`). It never edits code and never tells a coder how to fix something. To keep costs down it polls with long waits and suggests a fresh session after each landed milestone; everything needed to resume is on disk.

## The script drives

`orch autopilot` does the same loop as a plain program. It exits 0 when every milestone has landed, or 3 when it needs you, and writes why to `.orchestrate/autopilot.log` with a desktop notification.

When it stops, you can answer and run it again, or ask the lead to act as the exception handler: it reads `orch status` and the log, asks you what it needs, writes your answers into the plan, and tells you to restart the script. See [When a run stops](/docs/when-it-stops/).

## Resuming

Both pick up where the run left off: landed milestones are never redone, and parked milestones keep their work in hidden git refs.
