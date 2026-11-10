---
title: How a run works
description: Every step of a herdr-orchestra run, and the states a milestone goes through.
---

A **run** builds one feature. It has 1 to 4 milestones, lives on one `feature/<name>` branch, and ends in one pull request.

## The steps

### 1. Request

You describe the feature to the lead: Feature, Why, Must, Must not, Already decided, Done when, and optionally the mode. See [Writing a feature request](/docs/feature-request/).

### 2. Research and plan

The lead checks it is in a Herdr pane and that your tree is clean, then researches: the files involved, the patterns to follow, the data models, how tests run, and the shared hotspot files (routes, `package.json`, shared types). It finds the team (which panes are coders, which is the reviewer) and writes milestones sized for that team. Planning never touches git.

The lead decides the **what** and **why**. The one technical thing it decides is the interface between milestones that run in parallel, such as an API shape or shared types. See [Planning and milestones](/docs/planning/).

### 3. You edit the plan

`.orchestrate/plan.md` is a normal Markdown file. `orch sync` checks it after each edit: dependency cycles, missing reasons, hotspot files in parallel milestones, "how" written into a milestone, more than 4 milestones.

### 4. Build

`orch start` creates the feature branch and, in worktree mode, one git worktree per coder. Then the run loops:

1. **Dispatch.** Each ready milestone (its dependencies have landed) goes to a free coder, preferring the kind the plan asks for. Fix and conflict jobs go first.
2. **Code.** The coder gets a task file built from the plan: the milestone, the global instructions, the check command, the reports of the milestones it depends on, and the rules for coders. It writes a short report ending in a `COMMIT:` line and a done file.
3. **Check.** Your check command runs on the coder's work. A failure goes back with the last 60 lines of output, up to 3 rounds.
4. **Review.** If the milestone has `Review: yes`, the reviewer reads the diff. In worktree mode the coder is freed first and picks up other work meanwhile. Blockers become a fix job for the next free coder, up to 2 rounds.
5. **Land.** The milestone becomes one commit on the feature branch, and the milestones that depended on it unlock.

Who drives this loop is your choice: the lead, or the `orch autopilot` script. See [Driving a run](/docs/driving/).

### 5. Finish

When every milestone has landed, the summary in `.orchestrate/summary.md` lists the commits, files, which agent did what, design notes and a manual test checklist. `orch finish` pushes the branch and opens the PR. See [Git, commits and the PR](/docs/git/).

## Milestone states

| State | Meaning |
|---|---|
| `pending` | Waiting for its dependencies or a free coder |
| `needs-answer` | Has open questions; it and its dependents wait |
| `coding` | A coder is working on it |
| `awaiting-review`, `reviewing` | Checks passed; queued for or with the reviewer |
| `merged` | Landed as a commit on the feature branch |
| `paused` | Waiting for you (a question, a permission prompt, a round limit) |
| `failed` | Gave up after its round limits; the work is kept |

`orch status` shows every milestone's state, and prints `ALL_DONE` or `STUCK` when the run is over or needs you.
