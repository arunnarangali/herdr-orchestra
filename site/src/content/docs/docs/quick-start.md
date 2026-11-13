---
title: "Quick start: your first multi-agent coding run"
description: "Build your first feature with a multi-agent workflow: a lead, two coders on different models, and a reviewer."
---

This walks through one feature from request to pull request. It assumes herdr-orchestra is [installed](/docs/installation/) and your repo has a clean working tree.

## 1. Open your team

In Herdr, open one pane per agent in your repo. `orch agents launch <kind> --model <id>` prints the right command for each kind, with edits auto-approved. `orch models` lists the models and their tiers; use the ones your agents already reach.

| Pane | Example command | Name |
|---|---|---|
| Lead | a high-tier model, e.g. `claude --model opus` | `lead` (the lead names itself) |
| Coder | `claude --permission-mode acceptEdits --model sonnet` | `claude-1` |
| Coder | `claude --permission-mode acceptEdits --model haiku` | `claude-2` |
| Reviewer (optional) | `agy --mode accept-edits` or any spare agent | `reviewer` |

One coder is fine too. The lead then plans milestones one after another. Mixing kinds works the same way: a Codex coder next to a Claude one.

**Only one tool, or you don't want to open panes yourself?** Open just the lead's pane and go to step 2. The lead sees it is alone, builds the team from its own tool with `orch team <kind>`, and when you say go, `orch team up` opens the other panes for you. See [One tool, whole team](/docs/agents/#one-tool-whole-team).

## 2. Ask the lead for a feature

In the lead's pane, start the plan playbook. In Claude Code or OpenCode:

```text
/orch-plan CSV import for transactions. Why: users copy rows by hand.
Must: POST /imports, an import page. Must not: new packages.
Done when: a bank CSV shows up as transactions.
```

Every agent also understands: ``Run `orch lead plan` and follow it. Feature: <feature>``. See [Writing a feature request](/docs/feature-request/).

## 3. Review the orchestration plan

The lead writes `.orchestrate/plan.md` and shows you the milestones, which ones run in parallel, which coder and model each one goes to and why, and any open questions. Edit the file to change dependencies, a tier, review yes or no, and to answer questions under "Notes from user". See [The plan file](/docs/plan-file/) and [Models and tiers](/docs/models/).

## 4. Start the orchestration run

Tell the lead to go:

```text
/orch-run
```

The lead dispatches the milestones, which starts the event manager (`orch autopilot`, a plain script), and then pauses. Coders get their milestones, checks run, the reviewer reads each diff, and finished milestones land as commits on `feature/<name>`. Each time one lands the lead is woken and dispatches what it unlocked. See [The orchestration run](/docs/driving/).

If a coder has a question only you can answer, the lead asks you in its pane and passes your answer back to the same coder. If a risky change is held, you get a desktop notification and run `orch approve Mn`. See [When a run needs you](/docs/when-it-stops/).

Prefer to start the script yourself? Run `orch autopilot` in a spare terminal at any point.

## 5. Finish

Read `.orchestrate/summary.md` and do its manual checklist: it lists only what needs your eyes or hands (how the UI looks and behaves, a real device). What a command or a look at the code can settle is already checked, with the evidence. Then:

```bash
orch finish
```

It re-runs the check, removes the worktrees, pushes the feature branch and opens a pull request (with `gh`, or prints the compare link). Review and merge it like any other PR.
