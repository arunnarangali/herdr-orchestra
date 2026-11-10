---
title: Agents
description: The agent registry, choosing a lead, and adding your own agent.
---

Any installed agent can play any role: Claude Code, Codex, Amp, OpenCode, Hermes, Antigravity (`agy`), or anything else that can run shell commands. See the [Agents page](/agents) for every kind's launch command.

## Choose your lead

The agent whose pane you start the plan playbook in becomes the lead. It names its pane `lead` and writes `Lead: lead (<kind>)` into the plan. It never codes or reviews in its own run.

| Lead | Start it with |
|---|---|
| Claude Code | `/orch-plan <feature>` |
| OpenCode | `/orch-plan <feature>` |
| Codex | `$orch-plan <feature>` or "use the orch-plan skill: &lt;feature&gt;" |
| Amp, Hermes, Antigravity | "use the orch-plan skill: &lt;feature&gt;" |
| any agent | "Run `orch lead plan` and follow it. Feature: &lt;feature&gt;" |

## The registry

`orch agents` shows every known kind: installed or not, roles, whether Herdr can watch it, and its launch command. Defaults ship in `agents.default.toml`.

- `orch agents launch <kind>` prints the command.
- `orch agents sync` installs the skills for every installed agent. Run it after adding one.
- `orch agents check` confirms the skills are installed.

## Add your own agent

Add or fix kinds in `~/.config/herdr-orchestra/agents.toml`, merged key by key over the defaults:

```toml
[claude]
launch = "claude --permission-mode acceptEdits --model opus"

[myagent]                     # a new kind
binary = "myagent"
launch = "myagent --auto-approve"
herdr_detect = false          # herdr can't tell its idle/working/blocked state
roles = ["coder"]
skills_dirs = ["~/.myagent/skills"]
```

## Agents Herdr can't watch

For a kind with `herdr_detect = false`, `orch` relies only on the done file and the time budget, and `orch status` marks it `detect:off`. If Herdr doesn't recognise the pane as an agent at all, address it by pane id: `Workers: hermes-1 (hermes @pane:w1:p3)`.
