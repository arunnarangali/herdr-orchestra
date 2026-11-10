---
title: The plan file
description: The format of .orchestrate/plan.md, field by field.
---

The lead writes `.orchestrate/plan.md` and you edit it. `orch sync` parses it into `.orchestrate/state.json`; run it after every edit (the lead and autopilot run it for you).

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
Lead: lead (claude)
Workers: claude-1 (claude), codex-1 (codex)
Reviewer: reviewer (agy)

## Global instructions
Must not add packages. Reuse the 10 MB upload limit.

## [x] M1: Shared import types
Depends on: none
Prefer: any
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
| `Lead:` | The lead's pane and kind. It can't also be a worker or the reviewer |
| `Workers:` | Coders as `name (kind)`, or `name (kind @pane:<id>)` for a pane Herdr doesn't list as an agent |
| `Reviewer:` | `name (kind)` or `none` |
| `Scope:` | Optional. `warn` (default) notes files changed outside a milestone's Likely files; `strict` sends them back to the coder |
| `Parallel:` | Optional. `allow` lets milestones with overlapping Likely files run at once |
| `Risk hold:` | Optional. `off` stops risky changes being held for `orch approve` |
| `Budget:` | Optional. A time limit for the whole run, e.g. `4h`; autopilot stops when it is used up |
| `Setup inputs:` | Optional. Extra files that make the setup command run again when they change, besides lockfiles |

## Milestone sections

| Field | Meaning |
|---|---|
| `## [x] Mn: title` | Untick `[ ]` to skip the milestone |
| `Depends on:` | `none`, or `M1 (what it needs from M1)`. The reason is required |
| `Prefer:` | `any`, a worker kind (`codex`) or a worker name. A preference, not a lock |
| `Review:` | `yes` or `no` |
| `Likely files:` | Where the work probably lands; used for the scope check and to run overlapping milestones one after the other |
| `Goal`, `Why` | The outcome and the reason |
| `Acceptance criteria:` | Observable, testable statements |
| `Constraints:` | Your decisions and rules that apply |
| `Interfaces:` | The exact contract with parallel milestones |
| `Context:` | Research facts: where things live, patterns to follow |
| `Out of scope:` | What this milestone must not do |
| `Open questions:` | `- none`, or questions with options. Unanswered questions block the milestone |
| `Notes from user:` | Your answers and extra guidance. Coders see them |

Each section must stand alone: the coder receives it as written, plus the global instructions and the reports of the milestones it depends on.
