---
title: Introduction
description: What herdr-orchestra is, who does what, and how one run goes from a feature request to a pull request.
---

herdr-orchestra turns the AI coding agents you already use into a small team. You describe a feature. A **lead** agent researches your codebase and writes a short plan. A pool of **coders** builds it, in parallel when the work allows. An optional **reviewer** checks every diff. You review one pull request at the end.

## Who does what

| Role | Does | Never does |
|---|---|---|
| **You** | Describe the feature, edit the plan, answer questions, review the PR | Babysit agents |
| **Lead** (any agent) | Researches the codebase, writes 1 to 4 milestones as issues, decides the interfaces between parallel milestones | Writes code or tells coders how to build it |
| **Coders** (any agents) | Own the how: design, code, tests, fixing failed checks and review findings, resolving conflicts | Change scope or skip acceptance criteria |
| **Reviewer** (optional, any agent) | Reports problems as `BLOCKER: file:line — what — why` | Edits code or prescribes the fix |

Any installed agent can play any role: Claude Code, Codex, Amp, OpenCode, Hermes, Antigravity, or anything else that can run shell commands. See [Agents and roles](/docs/agents/).

## One run, end to end

1. **Request.** You ask the lead for a feature: what, why, the musts and must-nots, and when it is done.
2. **Plan.** The lead reads the code and writes `.orchestrate/plan.md`: 1 to 4 milestones, each with a goal, acceptance criteria, the facts a coder needs, and dependencies with reasons.
3. **Edit.** You adjust the plan: dependencies, which coder you prefer, review yes or no, answers to open questions.
4. **Build.** Each ready milestone goes to a free coder. Independent milestones run at the same time in separate git worktrees. Your check command runs on every result, the reviewer reads every diff, and problems go back as fix jobs.
5. **Land.** Each finished milestone becomes one commit on the run's `feature/<name>` branch.
6. **Finish.** `orch finish` re-checks the branch, cleans up, pushes it and opens a pull request for you.

The whole flow is explained step by step in [How a run works](/docs/workflow/).

## Where it runs

The team runs in [Herdr](https://herdr.dev), a terminal workspace for coding agents: one pane per agent. `orch`, the command-line tool that ships with herdr-orchestra, uses Herdr to hand each agent its task and to see whether it is working, idle or waiting for you. Everything else (the plan, the state, the reports) is plain files in `.orchestrate/` in your repo.

## Next

- [Install it](/docs/installation/)
- [Run your first feature](/docs/quick-start/)
