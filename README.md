# herdr-orchestra

**Orchestrate AI coding agents as one team in [Herdr](https://herdr.dev).** A lead agent plans, coders build in parallel, a reviewer checks every diff, and you get one pull request. Works with Claude Code, Codex, OpenCode, Amp, Hermes and Antigravity.

```bash
npx herdr-orchestra@latest
```

[![npm](https://img.shields.io/npm/v/herdr-orchestra)](https://www.npmjs.com/package/herdr-orchestra) [![Website](https://img.shields.io/badge/website-herdr--orchestra.vercel.app-f5a524)](https://herdr-orchestra.vercel.app/)

**Website and docs: [herdr-orchestra.vercel.app](https://herdr-orchestra.vercel.app/)** · [Install](#install) · [Quick start](https://herdr-orchestra.vercel.app/docs/quick-start/)

## What is herdr-orchestra?

Run a small team of AI coding agents inside [Herdr](https://herdr.dev). An AI **lead** writes the **orchestration plan**, picks the level of model each step needs, hands out the work and then pauses. A **pool of coders** builds it, in parallel git worktrees when tasks are independent, each on a model that fits its task: a small fast one for simple work, a stronger one where reasoning is the hard part. An optional **reviewer** checks every diff. A plain script, the **event manager** (`orch autopilot`), runs the **orchestration run**: it watches the agents, runs checks, merges, and wakes the lead only when something needs a decision. **Any installed agent can play any role**: Claude Code, Codex, Amp, OpenCode, Hermes, Antigravity (`agy`), or anything else that can run shell commands.

```
 you ──► lead: ORCHESTRATION PLAN  (1–4 milestones, dependencies, a model tier for each, and why)
                    │  you read it, edit it, say go
                    ▼
         lead: orch dispatch M1 M2 ──► lead pauses (no AI running, nothing to pay for)
                    │
                    ▼        ORCHESTRATION RUN — the event manager (orch autopilot, a plain script)
        ┌─────────── sends each milestone to a free coder on a model of its tier
        │          code ──► checks ──► review ──► one commit on feature/<name>
        │            ▲   fail ┘   blocker ┘   conflict ┘      (out of rounds: one go on a stronger model)
        │
        └── event queue ──► wakes the lead:  finished · question · failed · held · ready
                                 │
                 lead decides ◄──┘  dispatches what is ready, asks you when only you can answer,
                 then pauses again  `orch answer` sends your answer back to the same coder
                                                               ▼
                         ALL_DONE ──► lead writes the summary ──► orch finish: push, open a PR into main
```

## Who does what

| Agent | Does | Never does |
|---|---|---|
| **Lead** (any agent; you pick it by starting the playbook in its pane) | Researches the codebase; writes 1–4 milestones as issues (goal, why, acceptance criteria, constraints, interfaces, context facts, dependencies with reasons); gives each a model tier with the reason and a time estimate; dispatches the work, pauses, and is woken to decide: what to start next, a coder's question (asking you when only you can answer), a failed or held milestone, the final summary | Writes code, tells coders how to implement or fix, prompts or polls agents |
| **Coders** (any agents: Claude, Codex, Amp, OpenCode, Hermes, AGY…) | Own the how: design, code, tests, fixing failed checks, fixing review findings, resolving conflicts | Change scope or skip acceptance criteria |
| **Reviewer** (any spare agent, or another pane of the same tool) | Reports problems: `BLOCKER: file:line — what — why` | Edits code or prescribes fixes |
| **Event manager** (`orch autopilot`, a script) | Sends work to coders of the right tier, watches every agent, runs checks, sends fixes and reviews, merges; queues every event and wakes the lead when it is idle | Thinks, or decides anything the lead or you should |

The lead decides one technical thing: the **interfaces between milestones that run in parallel** (API shape, shared types, table columns), so two coders don't invent different versions.

## Install

```bash
npx herdr-orchestra@latest
```

Requirements: [herdr](https://herdr.dev), Node (for npx), git, python3 (3.11+ for the agent registry). Node is also what installs the official herdr skill.

The package is published from every GitHub Release, so `@latest` is the newest release (not the `main` branch). No Node? Use the script from the release instead: `curl -fsSL https://github.com/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash`. Prefer git? `git clone https://github.com/arunnarangali/herdr-orchestra.git && cd herdr-orchestra && git checkout v4.11.1 && bash install.sh`

It installs:

| What | Where |
|---|---|
| `orch` CLI (scheduler + autopilot) | `~/.local/bin/orch` |
| `orch-plan`, `orch-run` skills, one copy per agent (an agent never lists them twice) | `~/.agents/skills/` or the agent's own skills folder |
| `/orch-plan`, `/orch-run` OpenCode commands | `~/.config/opencode/commands/` |

Updating replaces the skills, it never adds a second copy: the installer picks one folder per agent and removes orch's older copies from the rest (your own skills are left alone). `orch agents check` says `DUPLICATE` if an agent would still see a skill twice.
| every installed version, side by side | `~/.local/share/herdr-orchestra/` |

Install once — you don't need to run the installer again when you add an agent. After installing Claude, Hermes, Amp or anything else, run:

```bash
orch agents sync
```

It finds every installed agent (binary on `PATH`), copies the `orch-plan` / `orch-run` skills and slash commands into that agent's folders, and records them so `--uninstall` still removes exactly what was installed. `orch agents` prints a hint when a new agent is missing its skills.

## Versions

Every release is a git tag (`v4.2.0`) with a GitHub Release that carries its own `install.sh`. Every installed version is kept side by side, so switching back is instant.

```bash
# install a specific version
npx herdr-orchestra@4.2.0            # that npm release
npx herdr-orchestra@latest --version v4.2.0   # or download any tag from GitHub

# list versions
npx herdr-orchestra@latest --list

# pin a version for one project: commit this file, then run the installer from that folder
echo v4.2.0 > .orch-version

orch version                         # what's active now
npx herdr-orchestra@latest --uninstall
```

Without Node, the same options work through the release script: `curl -fsSL https://github.com/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash -s -- --list` (or `--version v4.2.0`, `--uninstall`).

Version choice, first match wins: `--version` flag › `ORCH_VERSION` env › `./.orch-version` › the release the script (or npm package) came from.

## Use

1. **Start the team** in herdr, one pane each. `orch agents launch <kind>` prints each agent's command:

   | Pane | Example command | Rename to |
   |---|---|---|
   | Lead | any agent, e.g. `claude` or `opencode` | `lead` (the playbook does it) |
   | Coder (medium work) | `claude --permission-mode acceptEdits --model sonnet` | `claude-1` |
   | Coder (small work) | `claude --permission-mode acceptEdits --model haiku` | `claude-2` |
   | Reviewer (optional) | `claude --model opus`, `agy --mode accept-edits` or a spare agent | `reviewer` |

   `orch agents launch <kind> --model <id>` prints the command with the model; `orch models` lists the models and their tiers. Use whatever your installed agents already reach.

   **Only one tool installed, or just one window open?** Open only the lead and start the plan playbook. The lead sees it is alone and builds the team from its own tool: `orch team codex` picks coders and a reviewer of that tool on the models the catalog allows, spread over its tiers, and the lead writes them into the plan. When you say go, `orch team up` opens their panes next to the lead, each in its own folder and on its model, and names them. You never type either command yourself (you can: `orch team codex --coders 1`, `orch team up --dry-run`). Each pane is a separate session of the same tool, on your existing login.

   ```
   you (1 Codex pane) ──► $orch-plan add a login page
                             lead: only me here → orch team codex
                             Workers: codex-1 (codex: gpt-6-luna), codex-2 (codex: gpt-6-sol)
                             Reviewer: reviewer (codex: gpt-6-sol)
                  you ──► go
                             orch start → orch team up → 3 more Codex panes open → the run as usual
   ```

2. **Orchestration plan:** start the plan playbook in the lead's pane (see [Choose your lead](#choose-your-lead)). The lead researches, writes `.orchestrate/plan.md` and shows you the milestones, which coder and model each one goes to, and why. Edit the plan if you like: dependencies, tier, review yes/no, your answers to open questions.
3. **Orchestration run:** tell the lead **go** (`/orch-run`). It dispatches the milestones (`orch dispatch M1 M2`), which starts the event manager, and pauses. From here the run looks after itself:
   - a milestone finishes → the event manager checks and merges it, then wakes the lead, which dispatches what that unlocked;
   - a coder asks a question → the lead is woken; if the plan or the code already answers it, it answers, otherwise it asks you in its pane. `orch answer M2 "<your answer>"` writes the answer into the plan and the **same coder** carries on with its work;
   - a risky change is **held** → you look and run `orch approve Mn`.

   You can also start the event manager yourself: `orch autopilot` in a spare terminal. It is the only driver of a run: while it runs, other `orch` commands that would change the run are refused (`orch status`, `orch report`, `orch approve` and the lead's `orch events` / `orch dispatch` / `orch answer` still work).
4. **If the lead is away** (its pane is closed, or it never reads its events): nothing is lost, the events wait in the queue. Ready work starts by itself after 15 minutes, you get a desktop notification, and `orch events --peek` shows what is open. With `Lead mode: off` in the plan header there is no lead in the run at all: `orch autopilot` dispatches by itself and stops (exit 3) when it needs you.
5. **When it's done:** read `.orchestrate/summary.md` and do its manual checklist. It holds only what needs your eyes or hands (how the UI looks and behaves, a real device); whatever a command or a look at the code can settle, the run and the lead have already checked and listed with the evidence. Want a change? Tell the lead (for example "the login button should be blue"). It runs `orch fix M1 "the login button should be blue"`: one small follow-up job goes straight to the coder who built M1, with the check and review as before, and no new plan. You can run `orch fix` yourself too. When you are happy, run `orch finish`. It re-runs the check, removes the worktrees, pushes `feature/<name>` and opens a PR into `main` (with `gh`, or prints the compare link).

### Git: one branch per run, real commits, one PR
Planning touches no git at all. `orch start` creates the plan's `Branch:` (`feature/<slug>`) and that is the only branch a run makes: coders work on detached worktrees, and a milestone's work in progress (under review, parked, waiting for a fix) lives in hidden refs under `refs/orch/`, which `git branch` doesn't list and `git push` doesn't send. Each milestone lands as **one commit whose message says what changed** (the coder's `COMMIT:` line, e.g. `feat(api): add categories endpoint`, with a `Milestone: M2` trailer). `Commits: single` in the plan header squashes the run into one commit at finish.

A good feature request: Feature · Why · Must · Must not · Already decided · Done when · Mode (`shared` or `worktree`).

### Models and tiers
The lead does not pick a model by its name. It reads the catalog (`orch models`), which rates each model 1–5 on **reasoning, coding, architecture, instruction following, tool use, planning and speed**, records its context window, and says where each rating comes from. Each model serves one tier, and a model needs enough reasoning for its tier: coding skill alone never makes a model `high`.

| Tier | For | Examples from the default catalog |
|---|---|---|
| **small** | classification, renames, docs, config, mechanical edits | `haiku`, `gpt-6-luna`, `qwen3.6-35b-a3b` |
| **medium** | normal implementation, tests, debugging inside one module | `sonnet`, `gpt-6-sol`, `qwen3.8-27b` |
| **high** | the lead itself, contracts and architecture, cross-module refactors, auth / payments / schema, escalations | `opus`, `deepseek-v4-pro`, `glm-5.3` |

In the plan, each coder carries the model its pane runs, and each milestone says what it needs:

```
Workers: claude-1 (claude: sonnet), claude-2 (claude: haiku)

## [x] M2: Import endpoint
Tier: medium
Needs: coding, tool-use
Model why: one module, a clear contract, an existing endpoint to copy; no design decisions.
```

- **Dispatch follows the tier.** A milestone goes to a free coder of its tier, or a stronger one when none is free; never to a weaker one while a suitable coder exists.
- **One escalation.** A milestone that runs out of fix or review rounds gets one fresh round on a stronger model, with the work so far, before it fails.
- **Policy.** Ultra-premium models (`*fable*`, `*astra*`) are kept out of runs: `orch sync` refuses a plan that names one. Everything else your agents reach is allowed, open-weight models included. Edit `[policy] deny` to change the list.
- **Checked against reality.** `summary.md` has a table of planned tier against the model that really did each milestone, and `orch report` shows first-pass rate and escalations per model. When a model does worse than its rating, lower the rating.
- **A role for every coder.** The lead writes `Role:` on each milestone (for UI work, for example, "senior frontend engineer with a designer's eye: matches the existing components, works on a small screen, has loading, empty and error states"). The coder's task file starts with it, so the coder works to that standard.
- **Estimate vs actual time.** The lead writes `Estimate:` for each milestone and for the whole feature. orch measures the real time, and the summary shows both. When something took longer, it lists where the time went and who it waited on (for example "10m claude-1 (sonnet): fix rounds: the check command failed" or "20m developer / lead: paused, waiting for an answer"), only from what orch recorded.
- **Yours to change.** Add or re-rate models in `~/.config/herdr-orchestra/models.toml` (merged over `models.default.toml`). The default ratings are starting points with their sources, not benchmarks run by this project. A model that is not in the catalog still works; it just has no tier.

### Choose your lead
The agent whose pane you start the plan playbook in becomes the lead. It names its pane `lead` and writes `Lead: lead (<kind>)` into the plan; it never codes or reviews in its own run (`orch sync` rejects that). Give it a high-tier model: planning and coordination are reasoning work. Another pane of the same kind as a coder is fine.

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
launch = "claude --permission-mode acceptEdits"
model_flag = "--model"        # what `orch agents launch claude --model <id>` appends

[myagent]                     # a new kind
binary = "myagent"
launch = "myagent --auto-approve"
herdr_detect = false          # herdr can't tell its idle/working/blocked state
roles = ["coder"]
skills_dirs = ["~/.myagent/skills"]
```

`orch doctor [kind]` checks an installed agent against the real tool (version, whether the launch flags still exist in its `--help`, skills, herdr detection). `orch agents launch <kind>` prints the command · `orch team <kind>` / `orch team up` build and open a whole team from one tool · `orch agents sync` installs the skills for every installed agent (run it after adding a new one) · `orch agents check` confirms every installed agent sees each skill exactly once (not missing, not twice). Many tools read more than one folder (Codex reads `~/.codex/skills` and `~/.agents/skills`; OpenCode reads `~/.agents/skills` and `~/.claude/skills`), so the installer writes the fewest folders that give each installed agent one copy, e.g. with Claude, Codex and OpenCode: `~/.claude/skills` (Claude and OpenCode) and `~/.codex/skills` (Codex). Claude Code gets the skill only (a skill is already the `/orch-plan` command); OpenCode gets slash commands in `~/.config/opencode/commands`.

### Agents herdr can't watch
For a kind with `herdr_detect = false` (or one missing from the registry, which `orch sync` warns about), `orch` relies only on the **done file and the time budget**: it never reports GONE, BLOCKED or IDLE for it, treats it as free whenever it has no task, and `orch status` marks it `detect:off`. If herdr doesn't recognise the pane as an agent at all, address it by pane id: `Workers: hermes-1 (hermes @pane:w1:p3)`. `orch` then types prompts into that pane, and `orch start` reports a `STALE pane` when the id has changed (`herdr pane list` shows the current ids).

### Milestones fit the feature
There is no target number. The lead first writes a `## Feature breakdown` (the real pieces of work and how they connect), starts from **one** milestone, and splits a piece off only when that buys something: another coder can build it in parallel, other work has to build on it first, or the whole is too big for one sitting. More coders never means more milestones: a one-field change that touches API and UI is one milestone, even with five coders. In a plan with two or more milestones, each one carries `Why separate: <reason>`, and `orch sync` warns when it is missing. A feature made of several loosely connected parts is better as separate runs. Set `ORCH_MAX_TASKS` if you want a hard warning above a number of your own.

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
When a milestone passes its checks it's saved to its hidden ref and the coder is **freed immediately**, so it takes the next ready milestone while the reviewer works. Blockers come back as a **fix job** for the next free coder (preferring the one who built it); fix jobs go before new milestones.

### Modes
- **worktree**: each coder works in `../<repo>-wt/<name>`, independent tasks run in parallel, and each task is squash-merged when it passes checks and review. Start each coder inside its own worktree.
- **shared**: everyone works in your folder, one milestone at a time. Two agents in one folder would overwrite each other's files and mix their changes, so this is only safe sequentially. Use it when every milestone depends on the previous one.

### What the event manager handles by itself
| Situation | Behaviour |
|---|---|
| Checks fail | sends the last 60 lines back to the coder, up to 3 rounds |
| Out of fix or review rounds | one fresh round on a coder with a stronger model, if the team has one; then failed, and the lead is woken |
| The lead is busy, gone, or not reading | events wait in the queue; it is woken once per batch when idle, again after 5 min (3 times), then you are told; ready work starts by itself after 15 min |
| Reviewer blockers | queued as a problem-only fix job for the next free coder, up to 2 rounds |
| Merge conflict | the same coder merges the feature branch and resolves it, up to 2 rounds; if the milestone was already approved, the reviewer sees the resolution before it lands |
| Passes alone, fails once merged | the check runs on the merged result **before** the commit; a failure commits nothing and goes back to a coder as a fix round |
| A coder hits a usage limit | benches it for 60 min; the other coder continues, with the work so far (also in shared mode) |
| An agent disappears | coder: its task moves on with the work so far; reviewer: only the review waits. Either is used again as soon as it's back |
| A prompt can't be delivered | the task goes back in the queue (its job kept) and that agent is retried after 2 min; 3 in a row bench it for 30 min |
| Attempts keep getting lost (unreachable, gone, rate-limited) | after 4 (`ORCH_MAX_LOST`) the task fails with the history instead of looping |
| Autopilot is killed mid-step | the next run confirms or re-sends an unconfirmed prompt to the same agent, and finishes or undoes a half-done merge |
| Lockfiles changed since a folder was set up | the setup command runs again there (and in your main folder before the merge check) |
| Risky change (deleted file, migration, CI config, secrets file, unlisted dependency change, very large diff) | the milestone is **held** until you run `orch approve Mn`; the rest keeps going |
| The wake-up prompt never became a turn for the lead (it sat in the input box, or you were typing there) | sent again after 30s, then 1 min; after 3 tries you get a notification. The event manager does not leave at ALL_DONE before the lead has read the last events |
| A coder changes files outside its `Likely files` | listed in the summary (`Scope: strict` sends it back instead) |
| An orch step fails for one task | that task is paused with the error; the others keep running |
| The final check fails on the branch | stops; the next run re-checks and carries on once it passes |
| Permission prompt | desktop alert, other tasks keep running |
| Agent stops early | nudged once, then parked |
| Worker writes `QUESTION:` | that task and its dependents wait, the lead is woken to answer or ask you; everything else continues |

### Contracts and reports
`plan.md` stays the file you edit. From it `orch` generates a `task.json` for each milestone (numbered acceptance criteria `AC1…`, allowed files, interfaces, the commits of its dependencies). Coders answer with a `result-N.json` (status, commit message, files changed, the check they ran, each criterion met or not), and the reviewer with a `review-N.json` (a verdict per criterion plus findings). The old line formats (`COMMIT:`, `QUESTION:`, `BLOCKER:`) still work as a fallback. The shapes are in [docs/contracts.md](docs/contracts.md).

Every status change is written to `.orchestrate/events.jsonl`, and `orch report [--json]` shows estimated vs actual time (and why anything took longer), time per milestone, fix/review/conflict rounds, first-pass rate and wasted work, plus how each model did. Tokens and cost appear only when an agent reports `usage` in its result file.

Optional plan header lines: `Lead mode: events | off` (default `events` when the plan has a `Lead:` line) · `Scope: warn | strict` · `Risk hold: on | off` · `Budget: 3h` (autopilot stops when its running time is used up) · `Estimate: 1h30m` (the lead's estimate for the feature) · `Setup inputs: <globs>` (which files mean "run setup again"; default: lockfiles and manifests). Per milestone: `Why separate` (why it is its own milestone; needed when the plan has more than one) · `Tier`, `Needs`, `Model why` (see [Models and tiers](#models-and-tiers)) · `Estimate: 40m` (dispatch to landed if nothing goes wrong) · `Parallel: allow` lets it run next to a milestone that shares its `Likely files`.

### Commands
`orch status` · `orch report` · `orch approve Mn` · `orch models [show|check <id>]` · `orch events [--peek]` · `orch dispatch Mn... [--to <worker>] [--tier <tier>]` · `orch answer Mn "<answer>"` · `orch fix Mn "<change>" [--to <worker>]` · `orch doctor [kind]` · `orch ready` · `orch autopilot` · `orch lead plan|run|check|whoami` · `orch agents [launch <kind> [--model <id>]|sync|check]` · `orch handoff Mn` · `orch needs-fix Mn` · `orch set M3 pending` · `orch park M2 paused "why"` · `orch cooldown claude-1 60` · `orch cleanup` · `orch finish [--no-push]` · `orch version` · `orch` (full help)

Tunables: `ORCH_CODER_BUDGET_MIN` (45) · `ORCH_REVIEW_BUDGET_MIN` (15) · `ORCH_CHECK_TIMEOUT_MIN` (30) · `ORCH_COOLDOWN_MIN` (60) · `ORCH_MAX_TASKS` (unset: no limit) · `ORCH_GONE_COOLDOWN_MIN` (10) · `ORCH_SEND_RETRY_S` (120) · `ORCH_HERDR_TIMEOUT_S` (30) · `ORCH_MAX_LOST` (4) · `ORCH_UNREACHABLE_MIN` (30) · `ORCH_CONFIRM_S` (30) · `ORCH_RISK_MAX_LINES` (1500) · `ORCH_LEAD_WAIT_MIN` (15: ready work the lead hasn't dispatched starts by itself) · `ORCH_LEAD_CONFIRM_S` (30: a wake-up the lead did not pick up is sent again, doubling) · `ORCH_LEAD_REWAKE_S` (300) · `ORCH_LEAD_MAX_WAKES` (3) · `ORCH_LEAD_IDLE_MAX_MIN` (720: how long the event manager waits for an answer) · `ORCH_NO_AUTOSTART=1` (the lead's commands never start the event manager)

## Develop and release

```bash
bash tests/run.sh          # end-to-end tests with fake agents (no AI, no network)
bash tests/live/run.sh claude codex   # opt-in: one tiny real run per agent kind (needs herdr and the agents; uses their credits)
bash install.sh            # install your checkout (vX.Y.Z at a tag, vX.Y.Z-dev otherwise)
```

Releases are made by themselves. A PR that bumps `VERSION` and adds its `## [X.Y.Z]` section to `CHANGELOG.md` is released when it is merged: the Release workflow runs the tests, tags `vX.Y.Z` on main and publishes the GitHub Release with its own `install.sh`. Nobody pushes a tag. The same workflow publishes to npm with the `NPM_TOKEN` secret, which must be a Granular Access Token with Read and write on packages and "Bypass two-factor authentication" ticked (or a Classic Automation token); a token that asks for two-factor codes fails with EOTP. After fixing the secret, run the Release workflow again by hand: it skips the existing GitHub Release and only publishes to npm. (`bash scripts/release.sh X.Y.Z` still bumps VERSION and checks the CHANGELOG for you; a tag pushed by hand still works, and must match VERSION.)

Semantic versioning: **major** for breaking changes to the plan format or commands, **minor** for new features, **patch** for fixes.

## License
MIT
