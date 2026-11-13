---
title: "How a run works: the agent workflow step by step"
description: "Every step of a herdr-orchestra agent workflow run, from plan to pull request, and the states a milestone goes through."
---

A **run** builds one feature. It has 1 to 4 milestones, lives on one `feature/<name>` branch, and ends in one pull request.

## The steps

### 1. Request

You describe the feature to the lead: Feature, Why, Must, Must not, Already decided, Done when, and optionally the mode. See [Writing a feature request](/docs/feature-request/).

### 2. Research and plan

The lead checks it is in a Herdr pane and that your tree is clean, then researches: the files involved, the patterns to follow, the data models, how tests run, and the shared hotspot files (routes, `package.json`, shared types). It finds the team (which panes are coders, which is the reviewer, and which model each one runs) and writes milestones sized for that team. Planning never touches git.

The lead decides the **what** and **why**. It decides two more things: the interface between milestones that run in parallel, such as an API shape or shared types, and the **tier** of model each milestone needs (small, medium or high), with a one-line reason. See [Planning and milestones](/docs/planning/) and [Models and tiers](/docs/models/).

### 3. You approve the plan

`.orchestrate/plan.md` is a normal Markdown file. Change what you like, then tell the lead to go. `orch sync` checks the plan after each edit: dependency cycles, missing reasons, hotspot files in parallel milestones, "how" written into a milestone, a milestone that does not say why it is separate, a tier no coder can serve, a model the policy does not allow.

### 4. The orchestration run

`orch start` creates the feature branch and, in worktree mode, one git worktree per coder. The lead dispatches the first milestones (`orch dispatch M1 M2`) and pauses. Then the event manager loops:

1. **Dispatch.** Each milestone the lead has dispatched, once its dependencies have landed, goes to a free coder whose model serves its tier (a stronger one if none is free). Fix and conflict jobs go first.
2. **Code.** The coder gets a task file built from the plan: the milestone, the global instructions, the check command, the reports of the milestones it depends on, and the rules for coders. It writes a short report ending in a `COMMIT:` line and a done file.
3. **Check.** Your check command runs on the coder's work. A failure goes back with the last 60 lines of output, up to 3 rounds.
4. **Review.** If the milestone has `Review: yes`, the reviewer reads the diff. In worktree mode the coder is freed first and picks up other work meanwhile. Blockers become a fix job for the next free coder, up to 2 rounds.
5. **Land.** The milestone becomes one commit on the feature branch, and the milestones that depended on it unlock.
6. **Wake the lead.** The lead is woken with the news and dispatches what is now ready. It is also woken for a coder's question, a milestone that failed, and a milestone held for approval. Between wake-ups it is paused.

The loop is run by a plain script, `orch autopilot`; the decisions in it are the lead's. See [The orchestration run](/docs/driving/) and [The lead and the event manager](/docs/lead/).

### 5. Finish

When every milestone has landed, the summary in `.orchestrate/summary.md` lists the commits, files, which agent and model did what against the tier that was planned, the lead's time estimates against the real time (and why anything took longer), design notes and a manual test checklist. The lead is woken to write the last two. `orch finish` pushes the branch and opens the PR. See [Git, commits and the PR](/docs/git/).

## Milestone states

| State | Meaning |
|---|---|
| `pending` | Waiting for its dependencies, the lead's dispatch, or a free coder of its tier |
| `needs-answer` | Has open questions; it and its dependents wait |
| `coding` | A coder is working on it |
| `awaiting-review`, `reviewing` | Checks passed; queued for or with the reviewer |
| `held` | A risky change waits for your `orch approve` |
| `merged` | Landed as a commit on the feature branch |
| `paused` | Waiting for an answer (a coder's question, an agent that stopped); the lead is woken |
| `failed` | Gave up after its round limits and one round on a stronger model; the work is kept and the lead is woken |

`orch status` shows every milestone's state and tier, each coder's model, and how many events wait for the lead. It prints `ALL_DONE` when the run is over.
