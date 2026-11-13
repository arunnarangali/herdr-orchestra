---
title: The plan file
description: The format of .orchestrate/plan.md, field by field.
---

The lead writes `.orchestrate/plan.md` and you edit it. `orch sync` parses it into `.orchestrate/state.json`; run it after every edit (the lead and the event manager run it for you).

## Format

```markdown
# Plan: <feature title>
Branch: feature/<short-slug>
Base: main
Commits: per-milestone
Check command: npm test
Setup command: npm ci
Isolation: worktree
Max parallel: 2
Estimate: 1h10m
Lead: lead (claude: opus)
Workers: claude-1 (claude: sonnet), claude-2 (claude: haiku)
Reviewer: reviewer (agy)

## Global instructions
Must not add packages. Reuse the 10 MB upload limit.

## Feature breakdown
- Shared ImportRow type in packages/shared, used by the API and the web app
- Import endpoint in the API; preview screen in the web app
- Both sides only meet at ImportRow, so they can be built in parallel once it exists

## [x] M1: Shared import types
Depends on: none
Why separate: both sides code against this type; without it first they would collide in packages/shared.
Prefer: any
Tier: high
Needs: architecture, reasoning
Model why: the contract both sides build on; a wrong shape costs two milestones.
Estimate: 15m
Review: no
Likely files: packages/shared/src/imports.ts
Goal: one ImportRow type both sides use
Why: backend and frontend are built in parallel
Acceptance criteria:
- ImportRow { date, amount, payee } is exported from packages/shared
Constraints:
- none
Interfaces:
- ImportRow { date: string, amount: number, payee: string }
Context:
- shared types live in packages/shared/src
Out of scope:
- parsing
Open questions:
- none
Notes from user:
```

## Header

| Field | Meaning |
|---|---|
| `Branch:` | The run's one branch, `feature/<slug>` (or `fix/<slug>`). Created by `orch start` |
| `Base:` | Optional. The branch the PR goes into; defaults to the branch you start from |
| `Commits:` | Optional. `per-milestone` (default) or `single` to squash the run into one commit at finish |
| `Check command:` | What proves the code works, e.g. `npm test`. Must pass before the run starts |
| `Setup command:` | Run once in each new worktree, e.g. `npm ci`, or `none` |
| `Isolation:` | `worktree` (parallel) or `shared` (one at a time). See [Modes](/docs/modes/) |
| `Max parallel:` | How many milestones may be in progress at once, usually the number of coders |
| `Lead:` | The lead's pane, kind and model: `lead (claude: opus)`. It can't also be a worker or the reviewer |
| `Lead mode:` | Optional. `events` (default when there is a `Lead:` line): the lead dispatches and is woken by events. `off`: `orch autopilot` dispatches by itself and stops when it needs you |
| `Workers:` | Coders as `name (kind: model)`. The model is what the pane really runs; leave it out and the coder has no tier. `name (kind @pane:<id>)` addresses a pane Herdr doesn't list as an agent |
| `Reviewer:` | `name (kind: model)` or `none` |
| `Scope:` | Optional. `warn` (default) notes files changed outside a milestone's Likely files; `strict` sends them back to the coder |
| `Parallel:` | Optional. `allow` lets milestones with overlapping Likely files run at once |
| `Risk hold:` | Optional. `off` stops risky changes being held for `orch approve` |
| `Budget:` | Optional. A time limit for the whole run, e.g. `4h`; the event manager stops when it is used up. Time spent waiting for your answer does not count |
| `Estimate:` | How long the whole feature should take, e.g. `1h30m`. Milestones that run side by side count once. The summary compares it with the real time |
| `Setup inputs:` | Optional. Extra files that make the setup command run again when they change, besides lockfiles |

## Milestone sections

| Field | Meaning |
|---|---|
| `## [x] Mn: title` | Untick `[ ]` to skip the milestone |
| `Depends on:` | `none`, or `M1 (what it needs from M1)`. The reason is required |
| `Why separate:` | Why this is its own milestone: parallel work, a foundation others build on, or too big for one sitting. Needed when the plan has more than one milestone; `orch sync` warns without it |
| `Prefer:` | `any`, a worker kind (`codex`) or a worker name. A preference, not a lock; the tier comes first |
| `Tier:` | `small`, `medium` or `high`: the level of model the milestone needs. Leave it out and any coder may take it |
| `Needs:` | What the work leans on: any of `reasoning`, `coding`, `architecture`, `long-context`, `tool-use`, `planning`, `speed` |
| `Model why:` | One line: what in this milestone makes it that tier |
| `Estimate:` | How long from dispatch to landed if nothing goes wrong, e.g. `40m` or `1h30m`. `orch sync` refuses anything that is not a time and warns when it is missing. See [Estimate vs actual time](/docs/planning/#estimate-vs-actual-time) |
| `Review:` | `yes` or `no` |
| `Likely files:` | Where the work probably lands; used for the scope check and to run overlapping milestones one after the other |
| `Goal`, `Why` | The outcome and the reason |
| `Acceptance criteria:` | Observable, testable statements |
| `Constraints:` | Your decisions and rules that apply |
| `Interfaces:` | The exact contract with parallel milestones |
| `Context:` | Research facts: where things live, patterns to follow |
| `Out of scope:` | What this milestone must not do |
| `Open questions:` | `- none`, or questions with options. Unanswered questions block the milestone |
| `Notes from user:` | Your answers and extra guidance. Coders see them. `orch answer Mn "..."` adds a line here |

Each section must stand alone: the coder receives it as written, plus the global instructions and the reports of the milestones it depends on.
