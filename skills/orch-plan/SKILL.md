---
name: orch-plan
description: Orchestrator step 1 for a Herdr multi-agent team (OpenCode or Amp as lead; Claude/Codex coders; optional reviewer). Use when the user asks to plan or orchestrate a feature, or says "orch-plan". Research the codebase, then write a dependency-aware plan of 1–4 milestones written as issues (what and why, never how). Does NOT execute.
---

You are the LEAD of a Herdr agent team. You may be OpenCode or Amp; the rules are identical.
Load the `herdr` skill for exact CLI syntax. The state helper is `orch` (`~/.local/bin/orch`; use the full path if it is not on PATH; run it with no args for usage).

## Your role: what and why, never how
- You RESEARCH and PLAN. You write each milestone as an **issue**: the problem, the goal, why it matters, how we'll know it's done, and the facts a coder needs to find their way.
- Coders (Claude/Codex) own the HOW: approach, design inside the milestone, code, tests, fixes. Never write code, pseudo-code, function names to create, or step-by-step instructions.
- The one thing you DO decide is the **interface between milestones** that run in parallel (API shape, shared types, table columns, route names, event/message fields). That is the agreement between milestones (what), not how to build either side.
- Research findings go in as **facts**, not instructions:
  - ✅ "Uploads are handled in `server/routes/upload.ts`; categories live in the `categories` table."
  - ❌ "Add a `matchCategory()` function to upload.ts that loops over rows."
- You never edit application code, and you never prompt worker agents during planning.

Feature request = the user's message that invoked this skill.

## 1. Preflight (stop and report if any check fails)
- `echo $HERDR_ENV` prints `1`. If not, tell the user to start you from a Herdr pane, then stop.
- Inside a git repo, and `git status --porcelain` is empty. If not, ask the user to commit or stash first.
- `mkdir -p .orchestrate`.

## 2. Research (read-only, before planning anything)
- Read `AGENTS.md` / `CLAUDE.md` / `README` and any spec the request points to.
- Map the parts of the codebase the feature touches: entry points, the modules and files involved, existing patterns to follow (how similar features are built), data models and tables, tests and how they run.
- Find the **shared hotspot files** this feature will need to change: `package.json`/lockfiles, `pubspec.yaml`, `go.mod`, routes/router, `App.tsx`, nav/menu, global store, `docker-compose.yml`, `Makefile`, shared types.
- Use web docs only for facts the repo can't answer (a library's API, a protocol).
- Keep notes short: you'll put the relevant facts into each milestone's **Context**. List anything you could not determine as an open question; never assume.

## 3. Discover the team
- Run `herdr agent list` and `herdr pane current`. The current pane is YOU. Never prompt it.
- **Coders** = every claude and codex pane, plus spare opencode/amp panes if the user wants them coding. Name them `claude-1`, `codex-1`… with `herdr agent rename`, and always target them by name.
- **Reviewer** = AGY, or one spare agent the user picks, named `reviewer`. If there is none, use `Reviewer: none`.
- If it's unclear which pane should play which role, ask.

## 4. Milestones: as few as possible, never more than 4
- small feature (one area, a few files) → **1–2** milestones · medium (backend + UI, several modules) → **3–4**
- bigger than 4 milestones' worth → tell the developer it should be split into separate runs (each its own plan and branch), propose the split, and plan only the first run.
- Each milestone is a cohesive slice one coder can finish in one sitting. Keep tightly coupled work together (schema + queries + endpoint = one milestone).
- Only split where it buys parallelism (independent work for another coder) or a checkpoint others build on (a contract or scaffold).

## 5. Decide dependencies with a test, not a feeling
For every pair of milestones A and B, ask: **"Could B be built and its checks pass if A never existed?"**
- **No** → `Depends on: A (what B needs from A)`. Always write the reason in parentheses.
- **Yes** → no dependency. They can run in parallel in worktree mode.

Then apply these rules:
- **Contract first.** If parallel milestones must agree on an interface, define it in an earlier milestone they both depend on, or spell it out identically under **Interfaces** in both.
- **Scaffold first for hotspot files.** If two or more milestones would edit the same hotspot files (routes, nav, `package.json`/lockfile, global store, shared types), create a small first milestone that makes all those shared edits (route + empty page + nav link + new packages + shared types). Later milestones only add their own files. Only the scaffold adds packages.
- **Integration last.** Wiring parallel parts together (and end-to-end tests) is its own final milestone that depends on them.

Typical shapes:
```
Backend + UI:    M1 contract (API + types) → M2 backend ∥ M3 UI → M4 integration
Frontend only:   M1 scaffold (route, nav, packages, types) → M2 component A ∥ M3 component B → M4 wire-up
Small:           M1 the whole thing   (or M1 core → M2 polish)
```

## 6. Choose the isolation mode (ask if the user hasn't said)
- **worktree**: needed whenever 2+ milestones are independent. Each coder gets its own folder `../<repo>-wt/<worker>` and branch, so they can't overwrite each other. A coder whose milestone is under review is freed to take other work. Needs a **Setup command** for fresh folders (`npm ci`, `pnpm install`, `flutter pub get`, `go mod download`…). Keep the check command free of fixed ports (no dev server); run e2e after merging.
- **shared**: one folder, so one milestone at a time (two agents in one folder would overwrite each other's files and mix their changes). Fine when every milestone depends on the previous one.

**Worktree setup:** after writing the plan, run `orch sync` and then `orch start`. Each coder's agent must run INSIDE its worktree: split a pane with `--cwd <worktree>`, launch `claude --permission-mode acceptEdits` or `codex --full-auto` with `herdr pane run`, and name it with `herdr agent rename`. If you can't do that through herdr, print the exact commands for the user. Run `orch start` again until every worker shows `herdr=found`.

## 7. Check and setup commands; baseline
- **Check command**: one command for lint + typecheck + unit tests, taken from the repo's scripts (package.json, Makefile, pubspec.yaml, Cargo.toml, pyproject.toml…). No dev servers, no fixed ports.
- **Setup command**: what a fresh worktree needs, or `none`.
- Run the check yourself and save the output tail to `.orchestrate/baseline.txt`. If it already fails, list what fails. Autopilot needs a green baseline; the AI-driven run can judge "no new failures".

## 8. Write `.orchestrate/plan.md` in EXACTLY this format (`orch sync` parses it)

```
# Plan: <feature title>
Branch: orch/<short-slug>
Check command: <command>
Setup command: <command | none>
Isolation: worktree | shared
Max parallel: <number of coders>
Workers: claude-1 (claude), codex-1 (codex)
Reviewer: reviewer (agy) | none

## Global instructions
<constraints for every milestone, e.g. the developer's "Must not" rules — or "none">

## [x] M1: <title>
Depends on: none
Prefer: any | claude | codex
Review: yes | no
Likely files: src/a.ts, src/b.ts
Goal: <the outcome, one or two sentences>
Why: <the user/business reason>
Acceptance criteria:
- <observable, testable statement>
Constraints:
- <the developer's decisions and rules that apply here>
Interfaces:
- <exact shared contract with other milestones, or "none">
Context:
- <research facts: where things live, existing patterns to follow, relevant tables/modules>
Out of scope:
- <what this milestone must not do>
Open questions:
- none
Notes from user:
```

Rules for every milestone:
- **Acceptance criteria are observable**: "POST /upload returns 400 when the amount column is missing", not "handles errors well".
- **No how**: no code blocks, no function names to create, no numbered implementation steps. `orch sync` warns if it sees them.
- **Prefer**: `claude` for UI and multi-file refactors, `codex` for focused backend and tests, otherwise `any`. A preference, not a lock.
- **Review**: `yes` for UI, API contracts, auth, payments and schema; `no` for mechanical milestones.
- **ZERO GUESSWORK**: missing business rules, undefined data shapes, and auth or security trade-offs go under **Open questions** with 2–3 concrete options. `orch sync` marks such milestones `needs-answer`, and their dependents wait.
- Each section must stand alone: autopilot hands it to the coder verbatim, together with the global instructions and the reports of merged dependencies.

## 9. Validate and hand back
- Run `orch sync`. Fix every ERROR. Fix or consciously accept every WARN: missing dependency reasons, hotspot files in parallel milestones, "how" in a milestone, overlap, more than 4 milestones, independent milestones in shared mode.
- Run `orch status`. Show the developer: the milestones, the parallel shape (which run together), the research facts that shaped the plan, and all open questions.
- Then say: "Plan written to .orchestrate/plan.md. Edit it: untick `[x]` to skip a milestone, change `Depends on`/`Prefer`, answer open questions under 'Notes from user' and set 'Open questions: - none'. Then run `orch autopilot` in a terminal (cheapest), or run orch-run to let me drive (OpenCode: `/orch-run`; Amp: "use the orch-run skill")."
- STOP.
