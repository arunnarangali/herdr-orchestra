---
title: Autopilot
description: What orch autopilot does on its own, and when it stops for you.
---

`orch autopilot` runs the whole plan with no AI in the loop: dispatch, checks, fix rounds, reviews, conflicts and merges. It stops only when a human is needed, with a desktop notification and a line in `.orchestrate/autopilot.log`.

## What it handles by itself

| Situation | Behaviour |
|---|---|
| Checks fail | sends the last 60 lines back to the coder, up to 3 rounds |
| Reviewer blockers | queued as a problem-only fix job for the next free coder, up to 2 rounds |
| Merge conflict | a coder merges the branch and resolves it, up to 2 rounds |
| A coder hits a usage limit | benches it for 60 min; another coder continues with the work so far |
| Permission prompt | desktop alert; other tasks keep running |
| Agent stops early | nudged once, then parked |
| Worker asks a question | that task and its dependents wait; everything else continues |
| Passes alone, fails once merged | nothing is committed; a coder gets a fix round |
| Attempts keep getting lost | the task fails after 4 (`ORCH_MAX_LOST`) instead of looping |
| Lockfiles changed | the setup command runs again in that folder |
| Risky change | held until `orch approve Mn` |

## Review pipelining (worktree mode)

When a milestone passes its checks it is committed and the coder is **freed immediately**, so it takes the next ready milestone while the reviewer works. Blockers come back as a **fix job** for the next free coder, preferring the one who built it. Fix jobs go before new milestones.

## One driver per run

`orch autopilot` is the only driver. While it runs it holds the run's lease: a second autopilot is refused, and so is any `orch` command that would change the run from another terminal or agent (`orch status`, `orch report` and `orch approve` still work). If autopilot is killed, the lease is freed and the next run recovers: an unconfirmed prompt is confirmed or re-sent to the same agent, and a half-done merge is finished or undone.

The lead no longer drives runs. When autopilot stops, ask the lead to handle it with you: `/orch-run`, "use the orch-run skill", or "Run `orch lead run` and follow it".

## Nothing red is committed

Each milestone is squashed onto the feature branch, the check runs on that result, and only a green result is committed. A milestone that passes alone but fails once merged commits nothing and goes back to a coder as a fix round.

## Held for approval

A milestone that deletes files, touches migrations, CI configuration or secrets files, changes dependency files it did not list, or is very large is **held** before it lands. Look at it, then run `orch approve Mn`. `Risk hold: off` in the plan header turns this off.

## Tunables

| Variable | Default |
|---|---|
| `ORCH_CODER_BUDGET_MIN` | 45 |
| `ORCH_REVIEW_BUDGET_MIN` | 15 |
| `ORCH_CHECK_TIMEOUT_MIN` | 30 |
| `ORCH_COOLDOWN_MIN` | 60 |
| `ORCH_MAX_TASKS` | 4 |
| `ORCH_MAX_LOST` | 4 |
| `ORCH_RISK_MAX_LINES` | 1500 |
