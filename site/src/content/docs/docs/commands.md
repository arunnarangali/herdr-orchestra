---
title: Commands
description: Every orch command, grouped by when you use it.
---

Run `orch` with no arguments for the full help.

## Everyday

| Command | What it does |
|---|---|
| `orch status` | Workers with their models, milestones with their tiers, events waiting for the lead; prints `ALL_DONE` or `STUCK` when relevant |
| `orch ready` | Free coder slots, fix jobs, then ready milestones |
| `orch autopilot` | The event manager: runs the plan as a script and wakes the lead; exits 0 when done, 3 when it needs you |
| `orch approve <Mn>` | Let a milestone held for risky changes land |
| `orch report [--json]` | Estimated vs actual time per milestone and for the feature (and, when it took longer, where the time went and who it waited on), rounds, first-pass rate and wasted work, and how each model did |
| `orch finish [--no-push]` | Final check, clean up, push the feature branch, open a PR |
| `orch set <Mn> <status> [reason]` | Manual override; accepts `pending`, `paused`, `failed` and `skipped` |
| `orch park <Mn> paused\|failed\|pending [reason]` | Free the worker and keep its work in a hidden ref |
| `orch cooldown <agent> <min> [reason]` | Bench a worker or the reviewer; reason `gone` ends once Herdr sees it again |
| `orch cleanup` | Remove clean worker worktrees |
| `orch version` | The installed version |

## The lead, during a run

| Command | What it does |
|---|---|
| `orch dispatch <Mn>... [--to <worker>] [--tier <tier>]` | Start or restart milestones. Starts the event manager when none is running |
| `orch events [--peek]` | What the lead was woken for, what is ready, who is free. Reading acknowledges it; `--peek` does not |
| `orch answer <Mn> "<text>"` | The developer's answer: written under the milestone's "Notes from user", and the milestone goes back to the same coder |
| `orch fix <Mn> "<change>" [--to <worker>]` | A change to something Mn already landed: one small follow-up milestone in the plan, sent straight to the coder who built Mn. Check, review and summary still apply. Works after ALL_DONE; you or the lead can run it |

## Models

| Command | What it does |
|---|---|
| `orch models` | The catalog: every allowed model with its tier and ratings, and what the policy denies |
| `orch models show <id>` | One model's ratings and the evidence for them |
| `orch models check <id>` | Is this model allowed, and which tier does it serve? |

## Lead and agents

| Command | What it does |
|---|---|
| `orch lead plan` | Print the plan playbook (any agent can lead: ``Run `orch lead plan` and follow it``) |
| `orch lead run` | Print the run playbook |
| `orch lead check` | Preflight: is this agent in a Herdr pane, can it reach Herdr? |
| `orch lead whoami` | The lead's own pane and how to name it `lead` |
| `orch agents` | The agent registry: kinds, installed or not, roles, launch commands |
| `orch agents launch <kind> [--model <id>]` | The command that starts `<kind>` with edits auto-approved, on a model |
| `orch team <kind> [--coders N] [--models a,b] [--no-reviewer]` | The plan's team built from one tool: coders over its catalog tiers and a reviewer, as `Workers:` / `Reviewer:` lines |
| `orch team up [--dry-run]` | Open a pane for every agent in the plan that herdr can't find, in its folder, on its model, and name it |
| `orch agents sync [kind...]` | Install the skills for every installed agent |
| `orch agents check` | Check the skills are installed |
| `orch doctor [kind]` | Check the installed agents against the real tools |

## Run steps

The event manager uses these to run the work. You rarely need them by hand, and while it runs the ones that change the run are refused from any other terminal.

| Command | What it does |
|---|---|
| `orch sync` | Parse `plan.md` into `state.json`; validates dependencies, cycles, overlaps, tiers and the model policy |
| `orch start` | Create or switch to the feature branch; create worker worktrees |
| `orch pick <Mn>` | The first available worker whose model serves the milestone's tier, or `NONE` |
| `orch escalate <Mn> [reason]` | A milestone out of rounds gets one fresh round on a stronger model; exits 3 when there is none |
| `orch prepare <Mn> <worker>` | Reserve the worker and put its worktree on the milestone's saved work |
| `orch setup-done <worker>` | Mark a worktree as dependency-installed |
| `orch write-task <Mn>` | Build the task file from the plan and the dependency reports |
| `orch send <Mn> <file>` | Prompt the worker to execute a task or fix file |
| `orch poll [secs]` | Wait for the next event: `DONE`, `REVIEWED`, `BLOCKED`, `IDLE`, `TIMEOUT`, `GONE`, `ORPHAN`, `UNCONFIRMED` |
| `orch resend <Mn>` | Send an unconfirmed prompt again to the same agent |
| `orch bump <Mn> fix\|review` | Count a round; exits 3 with `CAP` at the limit |
| `orch handoff <Mn>` | (worktree) Save the milestone for review and free its coder |
| `orch review <Mn>` | Snapshot the diff and send it to the reviewer |
| `orch needs-fix <Mn>` | Queue the review's blockers as a fix job |
| `orch send-job <Mn>` | Send a queued fix or conflict job |
| `orch review-ok <Mn>` | Record that the reviewer approved |
| `orch requeue-review <Mn>` | Queue the same review round again |
| `orch commit <Mn>` | Save the work (shared mode: this lands it) |
| `orch merge <Mn>` | Land the milestone as one commit on the feature branch |
| `orch nudge <Mn>` | Re-send the current prompt once to an agent that stopped early |

## Exit codes

| Code | Meaning |
|---|---|
| 2 | Error |
| 3 | Needs you, busy, or a round limit |
| 4 | Merge conflict |
| 5 | Prompt not delivered (retried later) |
| 6 | The check fails once the milestone is merged; nothing was committed |
| 7 | Held for approval |
| 10 | `poll` is still waiting |
