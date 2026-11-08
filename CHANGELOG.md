# Changelog

All notable changes. Versions follow [semantic versioning](https://semver.org).

## [4.2.0] - 2026-11-07

### Added
- **Review pipelining (worktree mode):** when a milestone passes its checks, it's committed to its branch and the coder is freed straight away (`orch handoff`). The coder takes the next ready milestone while the reviewer works. Review findings become a **fix job** (`orch needs-fix`) for the next free coder, preferring the one who built it. Fix and conflict jobs are dispatched before new milestones.
- **Lead researches; coders own the how.** The planner has a research phase and writes milestones as issues: Goal, Why, Acceptance criteria, Constraints, Interfaces, Context (facts), Out of scope. Reviews report problems only (`BLOCKER: file:line — what — why`). Fix and conflict jobs describe the problem and leave the solution to the coder.
- **Better dependency planning:** the "could B be built if A never existed?" test, a reason required for every dependency (`Depends on: M1 (what it needs)`), scaffold-first for hotspot files, contract-first for parallel milestones, integration last.
- `orch sync` warnings: dependency without a reason; shared hotspot files (`package.json`, lockfiles, routes, `App.tsx`, `pubspec.yaml`, `go.mod`, `docker-compose.yml`…) in parallel milestones; code blocks or step-by-step "how" in a milestone; independent milestones in shared mode.
- Commands: `orch handoff`, `orch needs-fix`, `orch send-job`, `orch review-ok`. `orch ready` lists `FIX` jobs first.

### Changed
- Review diffs are taken against the merge-base, and from the task branch once the coder has moved on.
- Merge conflicts are queued as jobs for any free coder (up to 2 per milestone).
- `orch pick` prefers the coder who last worked on the milestone.

## [4.1.0] - 2026-11-07
First release in this repository.

### Added
- `orch autopilot`: runs the whole plan with no AI in the loop. Handles dispatch, checks, fix rounds, reviews, conflicts and merges, and stops only when a human is needed (desktop notification + `.orchestrate/autopilot.log`).
- `orch write-task`: builds worker task files from the plan, plus the reports of merged dependencies.
- `orch nudge` and `orch version`.
- Milestone budget: the planner targets 1–2 milestones for small features and 3–4 for medium; `orch sync` warns above 4 (`ORCH_MAX_TASKS`).
- Context-budget rules for the AI lead: short reports, long polls, fresh-session checkpoints.
- Curl installer with versions (`--version`, `--list`, `.orch-version` pinning, `--uninstall`).
- End-to-end test suite with fake agents; CI and tag-driven releases.

### Fixed
- Review snapshots no longer reset the git index, which used to cancel an in-progress merge and loop forever on conflicts.
- Re-reading the plan keeps each task's progress data: review approval, reports, conflict count.

## Before this repository (kit zips)
- **v4.0**: autopilot prototype.
- **v3**: pool of coders (Claude + Codex), task dependencies, worktree and shared modes, the `orch` state CLI.
- **v2**: shared skills so Amp or OpenCode can lead.
- **v1**: single coder/reviewer playbook; done files replace herdr wait callbacks.
