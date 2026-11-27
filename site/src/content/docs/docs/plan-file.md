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
Role: API designer whose types other teams build on: names that match the domain, nothing optional that is always present
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
| `Mode:` | Optional. `full` (default) or `quick`: a [quick run](/docs/quick-runs/) for a small, clear change. A quick plan has one milestone, needs `Quick because:`, defaults to `Isolation: shared`, and may not list migrations, CI, secrets or dependency files |
| `Quick because:` | Needed with `Mode: quick`: what the lead found in the code that makes the change small, e.g. `the column already exists, only the response changes` |
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
| `Risk hold:` | Optional. `off` stops risky changes (and milestones marked `Door: one-way`) being held for `orch approve` |
| `Docs:` | Optional. The folder with your repo's own rules files: `glossary.md`, `adr/` and `coding-standards.md` (default `docs`). See [House rules](/docs/how-to/#how-do-i-give-the-coders-and-the-reviewer-my-projects-rules) |
| `Budget:` | Optional. A time limit for the whole run, e.g. `4h`; the event manager stops when it is used up. Time spent waiting for your answer does not count |
| `Estimate:` | How long the whole feature should take, e.g. `1h30m`. Milestones that run side by side count once. The summary compares it with the real time |
| `Parallel checks:` | Optional. How many check commands may run at once (default `1`). The event manager keeps going while a check runs either way; raise it only if your machine can run two test suites side by side. Shared mode always uses 1 |
| `Early review:` | Optional. `on` (default) sends a `Review: yes` milestone to the reviewer while its check runs; if the check fails, the coder gets one fix job with both the check output and the reviewer's blockers. `off` reviews only after the check passed |
| `Branch check:` | Optional. `auto` (default) skips the check on the feature branch when the merged files are exactly the ones already checked in the coder's folder (nothing else landed meanwhile). `always` runs it on every merge, for checks that depend on more than the files (the branch name, the time, a service) |
| `Auto dispatch:` | Optional. `on` (default): a milestone that a landing unlocked starts at once, and the lead is told (`AUTO-DISPATCHED`). `off`: it waits for the lead's `orch dispatch` |
| `Setup inputs:` | Optional. Extra files that make the setup command run again when they change, besides lockfiles |
| `Check <side>:` | Optional, a monorepo with sides: `Check frontend: cd frontend && npm test`. A milestone with `Side: frontend` is checked with that command only; the whole `Check command` still runs on the finished branch |
| `Repos:` | Only in a workspace (several git repos in one folder): `Repos: frontend, backend` (folders next to `.orchestrate/`) or `Repos: web=apps/web, api=../api`. `orch sync` there writes each repo's own plan; each repo is then its own run (worktrees, branch, check, PR). See [Frontend and backend](#frontend-and-backend) |
| `Check <repo>:`, `Setup <repo>:` | In a workspace: that repo's check and setup commands (else `Check command:` / `Setup command:`) |
| `Workers <repo>:`, `Reviewer <repo>:` | In a workspace, optional: that repo's own coders and reviewer. Without them each repo gets `Workers:` and `Reviewer:`, named after the repo (`frontend-claude-1`) |

## Milestone sections

| Field | Meaning |
|---|---|
| `## [x] Mn: title` | Untick `[ ]` to skip the milestone |
| `Depends on:` | `none`, or `M1 (what it needs from M1)`. The reason is required. In a workspace it may name a milestone of another repo: that repo's plan shows it as `backend:M1` |
| `Side:` | Optional, with `Check <side>:` lines: which side's check this milestone gets |
| `Repo:` | In a workspace, needed: the repo this milestone is built in |
| `Why separate:` | Why this is its own milestone: parallel work, a foundation others build on, or too big for one sitting. Needed when the plan has more than one milestone; `orch sync` warns without it |
| `Prefer:` | `any`, a worker kind (`codex`) or a worker name. A preference, not a lock; the tier comes first |
| `Model:` | Written by `orch plan model` when the developer picks a model for this milestone, e.g. `Model: gpt-6.2-sol@low` (after `@`: the thinking level). A lock: only a coder on exactly that model takes it, and orch never moves it to another model (no stronger-model retry, `--to` and `--tier` refused). `orch sync` stops when no coder in `Workers` runs it |
| `Tier:` | `small`, `medium` or `high`: the level of model the milestone needs. Leave it out and any coder may take it |
| `Needs:` | What the work leans on: any of `reasoning`, `coding`, `architecture`, `long-context`, `tool-use`, `planning`, `speed` |
| `Model why:` | One line: what in this milestone makes it that tier |
| `Estimate:` | How long from dispatch to landed if nothing goes wrong, e.g. `40m` or `1h30m`. `orch sync` refuses anything that is not a time and warns when it is missing. See [Estimate vs actual time](/docs/planning/#estimate-vs-actual-time) |
| `Plain:` | One sentence for the developer: what this milestone gives them, in everyday words, e.g. `the screen where you see and add categories`. `orch plan show` puts it on the milestone's card; the coder's task file leaves it out |
| `Role:` | The specialist the coder works as, and what they care about in this milestone. orch puts it at the top of the coder's task file. It sets the standard, never the method |
| `Review:` | `yes` or `no` |
| `Door:` | Optional. `one-way (why)` for a milestone that is hard to undo once it runs (a migration on real data, a public API others call, deleting data, sending emails). It always waits for your `orch approve`, and its coder must show proof. Leave it out for everything else (easy to undo) |
| `Likely files:` | Where the work probably lands; used for the scope check and to run overlapping milestones one after the other |
| `Goal`, `Why` | The outcome and the reason |
| `Acceptance criteria:` | Observable, testable statements |
| `Constraints:` | Your decisions and rules that apply |
| `Interfaces:` | The exact contract with parallel milestones |
| `Context:` | Research facts: where things live, patterns to follow |
| `Out of scope:` | What this milestone must not do |
| `Open questions:` | `- none`, or questions with options. Unanswered questions block the milestone |
| `Notes from user:` | Your answers and extra guidance. Coders see them. `orch answer Mn "..."` adds a line here |

Optional section `## Glossary additions`: one line per new word the feature brings, `- **Discount**: money taken off an order total, in paise`. The milestone that introduces the word writes it into `docs/glossary.md` (it has an acceptance criterion for it and the file in its Likely files); `orch sync` warns when no milestone does, and `orch plan show` lists the words.

Each section must stand alone: the coder receives it as written, plus the global instructions and the reports of the milestones it depends on.

## Frontend and backend

**One repo (a monorepo).** Each coder has its own worktree of the whole repo, and every milestone lands on the one feature branch (one PR). Give each side a quicker check if it has one:

```markdown
Check command: pnpm -r test
Check frontend: cd frontend && pnpm test
Check backend: cd backend && pytest -q

## [x] M2: Orders endpoint
Side: backend
```

**Separate repos (a workspace).** One plan in the folder that holds the repos:

```markdown
# Plan: Discounts
Branch: feature/discounts
Repos: frontend, backend
Check frontend: npm test
Check backend: pytest -q
Workers: claude-1 (claude: sonnet)
Reviewer: none

## [x] M1: Orders endpoint
Repo: backend
Depends on: none

## [x] M2: Orders screen
Repo: frontend
Depends on: M1 (the endpoint it calls)
```

```
shop/.orchestrate/plan.md                  the plan above
shop/backend/                              M1 lands on backend's feature/discounts
shop/backend-wt/backend-claude-1/          the backend coder's worktree
shop/frontend/                             M2 lands on frontend's feature/discounts, after M1 landed
shop/frontend-wt/frontend-claude-1/        the frontend coder's worktree
```

Run orch in `shop/`: `orch sync` writes and syncs each repo's plan (don't edit those), milestone commands such as `orch dispatch M2` go to that milestone's repo, and `orch start`, `status`, `events`, `team up`, `autopilot` and `finish` run in every repo. `orch finish` opens one PR per repo.

**Agent names.** herdr finds agents by name, so two runs on one machine can't share one: `orch sync` refuses a name another going run uses, and `orch team <kind>` names the team after the repo (`frontend-codex-1`) while another run is going (`--prefix <name>` to choose).
