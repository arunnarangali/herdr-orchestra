---
title: Quick start
description: Build your first feature with a lead, two coders and a reviewer.
---

This walks through one feature from request to pull request. It assumes herdr-orchestra is [installed](/docs/installation/) and your repo has a clean working tree.

## 1. Open your team

In Herdr, open one pane per agent in your repo. `orch agents launch <kind>` prints the right command for each kind, with edits auto-approved.

| Pane | Example command | Name |
|---|---|---|
| Lead | any agent, e.g. `claude` or `opencode` | `lead` (the lead names itself) |
| Coder | `claude --permission-mode acceptEdits` | `claude-1` |
| Coder | `codex --approve-for-me` | `codex-1` |
| Reviewer (optional) | `agy --mode accept-edits` or any spare agent | `reviewer` |

One coder is fine too. The lead then plans milestones one after another.

## 2. Ask the lead for a feature

In the lead's pane, start the plan playbook. In Claude Code or OpenCode:

```text
/orch-plan CSV import for transactions. Why: users copy rows by hand.
Must: POST /imports, an import page. Must not: new packages.
Done when: a bank CSV shows up as transactions.
```

Every agent also understands: ``Run `orch lead plan` and follow it. Feature: <feature>``. See [Writing a feature request](/docs/feature-request/).

## 3. Review the plan

The lead writes `.orchestrate/plan.md` and shows you the milestones, which ones run in parallel, and any open questions. Edit the file to change dependencies, the preferred coder, review yes or no, and to answer questions under "Notes from user". See [The plan file](/docs/plan-file/).

## 4. Run it

In a spare terminal:

```bash
orch autopilot
```

Coders get their milestones, checks run, the reviewer reads each diff, and finished milestones land as commits on `feature/<name>`. It needs no AI to schedule. See [Driving a run](/docs/driving/).

If something needs you, you get a desktop notification. `/orch-run` in the lead's pane asks the lead to help with what it stopped on. See [When a run stops](/docs/when-it-stops/).

## 5. Finish

Read `.orchestrate/summary.md` and test the feature. Then:

```bash
orch finish
```

It re-runs the check, removes the worktrees, pushes the feature branch and opens a pull request (with `gh`, or prints the compare link). Review and merge it like any other PR.
