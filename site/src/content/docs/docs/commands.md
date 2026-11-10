---
title: Commands
description: Every orch command and environment variable.
---

Run `orch` with no arguments for the full help.

| Command | What it does |
|---|---|
| `orch status` | Branch, workers and every milestone's state |
| `orch ready` | Milestones and fix jobs that can start now |
| `orch autopilot` | Run the whole plan with no AI in the loop |
| `orch lead plan` | Print the lead's plan playbook |
| `orch lead run` | Print the lead's run playbook |
| `orch lead check` | Confirm the lead is inside a Herdr pane |
| `orch lead whoami` | Show the lead's pane and how to name it |
| `orch agents` | List agent kinds, installed or not |
| `orch agents launch <kind>` | Print an agent's launch command |
| `orch agents sync [kind...]` | Install skills and commands for installed agents |
| `orch agents check` | Confirm the skills are installed |
| `orch handoff Mn` | Commit a milestone and free its coder (worktree mode) |
| `orch needs-fix Mn` | Queue review findings as a fix job |
| `orch set Mn pending` | Put a milestone back in the queue (`set` accepts pending, paused, failed, skipped) |
| `orch approve Mn` | Let a milestone held for risky changes land |
| `orch report [--json]` | Time, rounds, first-pass rate and wasted work for the run |
| `orch doctor [kind]` | Check installed agents against the real tool |
| `orch park Mn paused "why"` | Free the worker and keep the work |
| `orch cooldown claude-1 60` | Bench an agent for 60 minutes |
| `orch cleanup` | Remove finished worktrees |
| `orch version` | Show the active version |

## Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `ORCH_CODER_BUDGET_MIN` | 45 | Minutes a coder gets per milestone |
| `ORCH_REVIEW_BUDGET_MIN` | 15 | Minutes the reviewer gets per review |
| `ORCH_CHECK_TIMEOUT_MIN` | 30 | Timeout for the check command |
| `ORCH_COOLDOWN_MIN` | 60 | How long a rate-limited agent is benched |
| `ORCH_MAX_TASKS` | 4 | Milestone limit per run |
| `ORCH_VERSION` | | Version the installer picks |
