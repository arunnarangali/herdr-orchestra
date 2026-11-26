---
title: Commands
description: Every orch command, grouped by when you use it.
---

Run `orch` with no arguments for the full help.

## Everyday

| Command | What it does |
|---|---|
| `orch status` | Workers with their models, milestones with their tiers, events waiting for the lead; prints `ALL_DONE` or `STUCK` when relevant |
| `orch status --json` | The run summary as JSON (`"view": 1`): milestones with their descriptions, agents, counts, time and cost. See [Watch a run](/docs/watching/) |
| `orch view [--lan] [--bg] [--port N] [--no-open]` | The run as a live picture in your browser (view only): milestone graph, agents, details, "needs you" alerts, time and cost, replay. `--lan`: also from your phone with a secret link. `orch view stop`, `orch view status` |
| `orch view herdr-config` / `orch view plugin link\|unlink` | Lines for Herdr's config (sidebar rows, popup key) / the optional Herdr plugin that opens `orch board` as a popup |
| `orch board [--once]` | The run as text, redrawn when it changes: for a Herdr pane or popup |
| `orch ready` | Free coder slots, fix jobs, then ready milestones |
| `orch resume` | After a restart (computer off, herdr closed): leaves the downtime out of every time budget, names the agents' panes again, saves unsaved work, sends the tasks in progress again and starts the event manager |
| `orch autopilot` | The event manager: runs the plan as a script and wakes the lead; exits 0 when done, 3 when it needs you |
| `orch approve <Mn>` | Let a milestone held for risky changes land |
| `orch report [--json]` | Estimated vs actual time per milestone and for the feature (and, when it took longer, where the time went and who it waited on), rounds, first-pass rate and wasted work, and how each model did |
| `orch finish [--no-push] [--recheck]` | Final check, clean up, push the feature branch, open a PR. The check is reused when it already passed on exactly these files; `--recheck` runs it anyway. Ends with the manual tests as a numbered list, and tells the lead, which posts them in its chat |
| `orch set <Mn> <status> [reason]` | Manual override; accepts `pending`, `paused`, `failed` and `skipped`. A coder still working on a paused or failed milestone gets its interrupt key (Esc) and a STOP note, and shows as `stopping` until herdr sees it idle |
| `orch free <worker>` | You looked at its pane and the coder that was told to stop has stopped: it takes work again at once |
| `orch park <Mn> paused\|failed\|pending [reason]` | Free the worker and keep its work in a hidden ref (also what its coder wrote after an earlier park). A coder still working on a paused or failed milestone is told to stop |
| `orch cooldown <agent> <min> [reason]` | Bench a worker or the reviewer; reason `gone` ends once Herdr sees it again |
| `orch bench <worker> off [reason]` / `on` | Keep a coder out of the run until you turn it back on. Holds across restarts, `orch sync` and `orch resume` |
| `orch stop [--now]` | Stop the event manager cleanly: it finishes its current step and exits, nothing is lost. Then change the plan (`orch sync`, `orch team up`) and `orch resume` |
| `orch doctor --crash` | Why the event manager last stopped (the reason found in the computer's own log), the last crash and lost notes, and saved agent screens |
| `orch cleanup` | Remove clean worker worktrees |
| `orch version` | The installed version |
| `orch update [--check] [--version vX.Y.Z]` | Install the latest release (or that one) and show what is new; `--check` only looks |
| `orch config [auto-update on\|off]` | This machine's settings: update by itself when a new plan starts, or only be told |
| `orch config compact on\|off` | Coders and the reviewer get `/compact` between milestones (on by default for Claude Code, Codex and AGY 1.2.15+; never the lead). See [Compact between milestones](/docs/agents/#compact-between-milestones) |

## The lead, during a run

| Command | What it does |
|---|---|
| `orch dispatch <Mn>... [--to <worker>] [--tier <tier>]` | Start or restart milestones. Starts the event manager when none is running. `--to` refuses a worker with no agent in herdr or one that is benched off |
| `orch events [--peek]` | What the lead was woken for, what is ready, who is free. Each event has a `SAY:` line in plain words, which the lead repeats in its chat with what it did. Reading acknowledges it; `--peek` does not |
| `orch plan show` | The plan for a person: one card per milestone in plain words (its `Plain:` line), what it waits for and why, who builds it on which model, how long, and the order |
| `orch manual` | The manual tests: what to try by hand, numbered, from the summary's Manual verification checklist. `orch finish` prints them too, and the lead posts them in its chat |
| `orch story` | The run diary: every event in plain words and what the lead did about it, in time order. Also saved as `.orchestrate/story.md` |
| `orch answer <Mn> [--defer AC2] "<text>"` | The developer's answer: written under the milestone's "Notes from user", and the milestone goes back to the same coder. `--defer AC2` records that the developer agreed to leave AC2 undone |
| `orch defer <Mn> <AC2,AC3> "<reason>"` | Only with the developer's yes: these criteria stay undone in Mn. No fix rounds or stronger-model retries for them, the reviewer does not block on them, and the summary lists them as **not done**, with a follow-up |
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
| `orch lead plan` | Print the start of the plan playbook: research and the quick-or-full decision (any agent can lead: ``Run `orch lead plan` and follow it``) |
| `orch lead plan quick` | The rules a quick plan uses (tiers, estimate, check command, criteria, Likely files) |
| `orch lead plan full` | Steps 3 to 10 of the full planning process |
| `orch lead run` | Print the run playbook |
| `orch lead run --section <EVENT\|ALL_DONE\|rules>` | One part of the run playbook; `orch events` prints these for the lead |
| `orch lead check` | Preflight: is this agent in a Herdr pane, can it reach Herdr? |
| `orch lead whoami` | The lead's own pane; names it `lead` (or prints the rename command when it can't tell which pane is yours) |
| `orch agents` | The agent registry: kinds, installed or not, roles, launch commands |
| `orch agents launch <kind> [--model <id>]` | The command that starts `<kind>` with edits auto-approved, on a model |
| `orch team <kind> [--coders N] [--models a,b] [--no-reviewer]` | The plan's team built from one tool: coders over its catalog tiers and a reviewer, as `Workers:` / `Reviewer:` lines |
| `orch team up [--dry-run]` | Open a pane for every agent in the plan that herdr can't find, in its folder, on its model, and name it |
| `orch agents sync [kind...]` | Install the skills for every installed agent |
| `orch agents check` | Check the skills are installed |
| `orch doctor [kind]` | Check the installed agents against the real tools (plain `orch doctor` also checks the main guard) |
| `orch guard [status\|--print]` | Install the pre-push guard that refuses any push to `main`, `master` or the default branch (`orch start` does it too); `status` reports it and whether GitHub protects `main` |

## Pi

These are for [Pi](/docs/pi/). In Pi you can type `/orch-mode` and `/orch-setup` instead of the first two.

| Command | What it does |
|---|---|
| `orch mode [panes\|subagent] [--agent <kind>]` | Show or switch where the coder and reviewer run: Herdr panes, or Pi subagents in one window. Saved per agent; subagent is for Pi only, every other agent uses panes |
| `orch setup [--mode panes\|subagent]` | Set a mode up; `subagent` writes Pi's `coder` and `reviewer` agents and installs pi-subagents |
| `orch sub next` | Subagent mode: the next milestone and its task file (`NEXT`, `TASK`, `REVIEW`) |
| `orch sub done <Mn>` | Subagent mode: save the milestone on the feature branch (`MERGED`, or `HELD` for risky changes) |

## Run steps

The event manager uses these to run the work. You rarely need them by hand, and while it runs the ones that change the run are refused from any other terminal.

| Command | What it does |
|---|---|
| `orch sync` | Parse `plan.md` into `state.json`; validates dependencies, cycles, overlaps, tiers and the model policy |
| `orch start` | Create or switch to the feature branch; create worker worktrees |
| `orch pick <Mn>` | The first available worker whose model serves the milestone's tier, or `NONE` |
| `orch escalate <Mn> [reason]` | A milestone out of rounds gets one fresh round on a stronger model; exits 3 when there is none |
| `orch prepare <Mn> <worker>` | Reserve the worker and put its worktree on the milestone's saved work. Unsaved files in the folder are saved first, never refused |
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
