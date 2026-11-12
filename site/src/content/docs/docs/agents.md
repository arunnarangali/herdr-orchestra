---
title: Agents and roles
description: The agent registry, choosing a lead and its model, and adding your own agent.
---

Any installed agent can play any role: Claude Code, Codex, Amp, OpenCode, Hermes, Antigravity (`agy`), or anything else that can run shell commands. See the [Agents page](/agents) for every kind's launch command.

## Choose your lead

The agent whose pane you start the plan playbook in becomes the lead. It names its pane `lead` and writes `Lead: lead (<kind>: <model>)` into the plan. It never codes or reviews in its own run. During the run it dispatches milestones and is woken to decide; see [The lead and the event manager](/docs/lead/).

| Lead | Start it with |
|---|---|
| Claude Code | `/orch-plan <feature>` |
| OpenCode | `/orch-plan <feature>` |
| Codex | `$orch-plan <feature>` or "use the orch-plan skill: &lt;feature&gt;" |
| Amp, Hermes, Antigravity | "use the orch-plan skill: &lt;feature&gt;" |
| any agent | "Run `orch lead plan` and follow it. Feature: &lt;feature&gt;" |

## Pick roles for your team

- **Lead:** the agent you talk to most. It reads a lot of code, plans and coordinates, so give it a high-tier model.
- **Coders:** one or more, each on a model that fits the work you expect: a small fast one for simple milestones, a medium one for normal implementation, a high one when the plan has design work. With two, a backend + frontend feature is split so both work at once.
- **Reviewer:** optional, any spare agent, at least as strong as the work it reviews. A different kind from the coders gives a second opinion; another pane of the same tool works too.

## One tool, whole team

You don't need several tools, or to open every pane yourself. With only Codex (or only Claude Code, or only OpenCode), open one pane, start the plan playbook in it, and the lead builds the team from that same tool.

```text
~/my-app$ codex            (one herdr pane)
> $orch-plan add a login page

lead: only one agent window is open, so the team is 2 more Codex coders and a Codex reviewer;
      orch opens their windows when you say go.
      Workers: codex-1 (codex: gpt-6-luna), codex-2 (codex: gpt-6-sol)
      Reviewer: reviewer (codex: gpt-6-sol)
> go
orch start        → codex-1, codex-2, reviewer: herdr=NOT FOUND
orch team up      → OPENED codex-1 in ../my-app-wt/codex-1, codex-2 in ../my-app-wt/codex-2, reviewer in my-app
orch start        → every agent found; the run goes on as usual
```

Two commands do this, and the lead runs both:

| Command | What it does |
|---|---|
| `orch team <kind>` | Picks the team from one tool: coders spread over the tiers the catalog allows for it (the weakest and the strongest first), and a reviewer on the strongest. Prints the `Workers:` and `Reviewer:` lines for the plan. `--coders N`, `--models a,b`, `--no-reviewer` change the pick. Read-only. |
| `orch team up [--dry-run]` | After `orch start`: opens a pane for every worker and the reviewer that herdr can't find, split from the lead's pane, in the agent's folder (its worktree, or the repo), starts it on its plan model and gives it its plan name. Agents that already run are left alone, so running it twice is safe. |

Good to know:

- Every pane is its own session of the same tool, on your existing login. More panes use more of that tool's limits, so the lead opens only what the plan needs (`--coders 1` for a one-milestone feature).
- Codex has no high-tier model in runs (Astra is denied), so a Codex-only team does high-tier milestones on its strongest allowed model. `orch team codex` and `orch sync` say so.
- If a new pane stops at a first-run question (trust this folder, sign in), `orch team up` reports `WAITING` with the rename command; answer the question in that pane and run `orch team up` again.
- For a kind herdr can't watch, `orch team up` opens and labels the pane and tells you the `name (kind @pane:<id>)` line to put in the plan.

## Models

An agent kind is the tool; the model is what runs inside it. The plan records both: `claude-1 (claude: sonnet)`. `orch agents launch claude --model sonnet` prints the command that starts a pane on a model, for kinds whose registry entry has a `model_flag` (Claude Code, Codex, OpenCode). For the others, pick the model inside the tool and write it in the plan.

Milestones are matched to coders by tier, not by kind. The plan's `Prefer:` line can still steer a milestone to a kind or a named coder when the tool matters; it is a preference, not a lock. See [Models and tiers](/docs/models/).

## The registry

`orch agents` shows every known kind: installed or not, roles, whether Herdr can watch it, and its launch command. Defaults ship in `agents.default.toml`.

- `orch agents launch <kind> [--model <id>]` prints the command.
- `orch team <kind>` and `orch team up` build and open a team from one tool (see [above](#one-tool-whole-team)).
- `orch agents sync` installs the skills for every installed agent. Run it after adding one.
- `orch agents check` confirms the skills are installed.

## Add your own agent

Add or fix kinds in `~/.config/herdr-orchestra/agents.toml`, merged key by key over the defaults:

```toml
[claude]
launch = "claude --permission-mode acceptEdits"
model_flag = "--model"        # what `launch claude --model <id>` appends

[myagent]                     # a new kind
binary = "myagent"
launch = "myagent --auto-approve"
herdr_detect = false          # herdr can't tell its idle/working/blocked state
roles = ["coder"]
skills_dirs = ["~/.myagent/skills"]
```

## Agents Herdr can't watch

For a kind with `herdr_detect = false`, `orch` relies only on the done file and the time budget, and `orch status` marks it `detect:off`. If Herdr doesn't recognise the pane as an agent at all, address it by pane id: `Workers: hermes-1 (hermes @pane:w1:p3)`.
