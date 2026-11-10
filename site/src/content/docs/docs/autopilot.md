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
| Worker writes `QUESTION:` | that task and its dependents wait; everything else continues |

## Review pipelining (worktree mode)

When a milestone passes its checks it is committed and the coder is **freed immediately**, so it takes the next ready milestone while the reviewer works. Blockers come back as a **fix job** for the next free coder, preferring the one who built it. Fix jobs go before new milestones.

## Two ways to drive a run

- `orch autopilot` in a spare terminal: the cheapest, no AI tokens spent on scheduling.
- Ask the lead to drive: `/orch-run`, "use the orch-run skill", or "Run `orch lead run` and follow it". Useful when you want judgment on failures.

## Tunables

| Variable | Default |
|---|---|
| `ORCH_CODER_BUDGET_MIN` | 45 |
| `ORCH_REVIEW_BUDGET_MIN` | 15 |
| `ORCH_CHECK_TIMEOUT_MIN` | 30 |
| `ORCH_COOLDOWN_MIN` | 60 |
| `ORCH_MAX_TASKS` | 4 |
