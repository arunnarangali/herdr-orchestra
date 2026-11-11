---
title: Introduction
description: What herdr-orchestra is, who does what, and how one run goes from a feature request to a pull request.
---

herdr-orchestra turns the AI coding agents you already use into a small team. You describe a feature. A **lead** agent researches your codebase, writes the **orchestration plan** and picks the level of model each step needs. A pool of **coders** builds it, in parallel when the work allows, each on a model that fits its task. An optional **reviewer** checks every diff. During the **orchestration run** the lead stays in charge: it hands out the work, pauses, and is woken whenever something needs a decision. You review one pull request at the end.

## Who does what

| Role | Does | Never does |
|---|---|---|
| **You** | Describe the feature, approve the plan, answer the questions only you can answer, review the PR | Babysit agents |
| **Lead** (any agent) | Researches the codebase, writes 1 to 4 milestones as issues, gives each a model tier, dispatches the work, and decides when woken: what starts next, a coder's question, a failed or held milestone | Writes code, tells coders how to build it, or polls agents |
| **Coders** (any agents) | Own the how: design, code, tests, fixing failed checks and review findings, resolving conflicts | Change scope or skip acceptance criteria |
| **Reviewer** (optional, any agent) | Reports problems as `BLOCKER: file:line — what — why` | Edits code or prescribes the fix |
| **Event manager** (`orch autopilot`, a script) | Sends work to coders, watches every agent, runs checks, merges, queues events and wakes the lead | Decides anything |

Any installed agent can play any role: Claude Code, Codex, Amp, OpenCode, Hermes, Antigravity, or anything else that can run shell commands. See [Agents and roles](/docs/agents/).

## One run, end to end

1. **Request.** You ask the lead for a feature: what, why, the musts and must-nots, and when it is done.
2. **Orchestration plan.** The lead reads the code and writes `.orchestrate/plan.md`: 1 to 4 milestones, each with a goal, acceptance criteria, the facts a coder needs, dependencies with reasons, and the model tier it needs (small, medium or high) with the reason.
3. **Go.** You read the plan, change what you like, and tell the lead to start.
4. **Orchestration run.** The lead dispatches the milestones and pauses. The event manager sends each one to a free coder on a model of its tier. Independent milestones run at the same time in separate git worktrees. Your check command runs on every result, the reviewer reads every diff, and problems go back as fix jobs. When a milestone lands, a coder asks a question, or something fails, the lead is woken, decides, and pauses again.
5. **Land.** Each finished milestone becomes one commit on the run's `feature/<name>` branch.
6. **Finish.** `orch finish` re-checks the branch, cleans up, pushes it and opens a pull request for you.

The whole flow is explained step by step in [How a run works](/docs/workflow/). The lead's part is in [The lead and the event manager](/docs/lead/), and model choice in [Models and tiers](/docs/models/).

## Where it runs

The team runs in [Herdr](https://herdr.dev), a terminal workspace for coding agents: one pane per agent. `orch`, the command-line tool that ships with herdr-orchestra, uses Herdr to hand each agent its task and to see whether it is working, idle or waiting for you. Everything else (the plan, the state, the reports) is plain files in `.orchestrate/` in your repo.

## Next

- [Install it](/docs/installation/)
- [Run your first feature](/docs/quick-start/)
