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
 you ──► lead: ORCHESTRATION PLAN  (as many milestones as needed, dependencies, a model tier for each, and why)
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
| **Lead** (any agent; you pick it by starting the playbook in its pane) | Researches the codebase; writes as many milestones as the feature needs as issues (or a short quick-run plan for a small change) (goal, why, acceptance criteria, constraints, interfaces, context facts, dependencies with reasons); gives each a model tier with the reason and a time estimate; dispatches the work, pauses, and is woken to decide: what to start next, a coder's question (asking you when only you can answer), a failed or held milestone, the final summary | Writes code, tells coders how to implement or fix, prompts or polls agents |
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
| `orch-plan`, `orch-run`, `orch-explain` skills, one copy per agent (an agent never lists them twice) | `~/.agents/skills/` or the agent's own skills folder |
| `/orch-plan`, `/orch-run`, `/orch-explain` OpenCode commands | `~/.config/opencode/commands/` |

Updating replaces the skills, it never adds a second copy: the installer picks one folder per agent and removes orch's older copies from the rest (your own skills are left alone). `orch agents check` says `DUPLICATE` if an agent would still see a skill twice.
| every installed version, side by side | `~/.local/share/herdr-orchestra/` |

Install once — you don't need to run the installer again when you add an agent. After installing Claude, Hermes, Amp or anything else, run:

```bash
orch agents sync
```

It finds every installed agent (binary on `PATH`), copies the `orch-plan` / `orch-run` / `orch-explain` skills and slash commands into that agent's folders, and records them so `--uninstall` still removes exactly what was installed. `orch agents` prints a hint when a new agent is missing its skills.

## Updates

**Already installed (5.7 or older)? Run `npx herdr-orchestra@latest` once.** That install asks the question below, and from then on orch keeps itself up to date.

The installer asks once: `Keep herdr-orchestra up to date automatically? [Y/n]`. Enter means yes. The answer is saved for this machine (`~/.local/share/herdr-orchestra/settings.json`) and is not asked again. With no keyboard (CI, a script) it does not ask and turns it on; `--auto-update` / `--no-auto-update` or `ORCH_AUTO_UPDATE=1|0` answer it for a script.

```bash
orch update                    # install the latest release now and show what is new
orch update --check            # only say whether a new version is out
orch update --version v5.8.0   # install that exact version (this is also how you go back)
orch config                    # auto-update on/off, the installed version, the last check
orch config auto-update off    # or: on
```

- **The check.** At most once a day, at `orch lead plan` or `orch version`, orch asks GitHub for the latest release (3 seconds at most; nothing about you or your project is sent). With no internet it stays silent and asks again the next day. `ORCH_NO_UPDATE_CHECK=1` turns the check off.
- **Auto-update on.** When a new plan starts (`orch lead plan`) and a newer release is out, orch installs it first and the plan runs on the new version: `UPDATED herdr-orchestra 5.8.0 -> 5.8.1`, with what is new.
- **Never during a run.** While an event manager is running anywhere on this machine nothing is installed; it happens at the next plan with no run going. A run that was started on the old version finishes on the new one.
- **Not installed by itself:** a major version (5.x to 6.0: read its changelog, then `orch update`), a repo pinned with `.orch-version`, and a git checkout.
- **A failed update** keeps the version you have, prints one warning, writes the reason to `~/.local/share/herdr-orchestra/update.log` and tries again the next day.
- **Auto-update off.** `orch lead plan`, `orch status` and `orch version` show one line instead: `herdr-orchestra 5.8.1 is out (you have 5.8.0). Run orch update.`

The skills are thin wrappers that call `orch`, so an updated `orch` is new logic for every agent at once.

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
   | Reviewer (optional) | `claude --permission-mode acceptEdits --disallowedTools Edit,NotebookEdit --model opus`, `agy --mode accept-edits` or a spare agent | `reviewer` |

   `orch agents launch <kind> --model <id>` prints the command with the model (`--role reviewer` gives the reviewer's command: for Claude Code its edit tools are off, it only reads the change and writes its review file); `orch models` lists the models and their tiers. Use whatever your installed agents already reach.

   **Only one tool installed, or just one window open?** Open only the lead and start the plan playbook. The lead sees it is alone and builds the team from its own tool: `orch team codex` picks coders and a reviewer of that tool on the models the catalog allows, spread over its tiers, and the lead writes them into the plan. When you say go, `orch team up` opens their panes next to the lead, each in its own folder and on its model, and names them. You never type either command yourself (you can: `orch team codex --coders 1`, `orch team up --dry-run`). Each pane is a separate session of the same tool, on your existing login.

   ```
   you (1 Codex pane) ──► $orch-plan add a login page
                             lead: only me here → orch team codex
                             Workers: codex-1 (codex: gpt-6-luna@high), codex-2 (codex: gpt-6.2-sol@medium)
                             Reviewer: reviewer (codex: gpt-6.2-sol@medium)
                  you ──► go
                             orch start → orch team up → 3 more Codex panes open → the run as usual
   ```

   **An all-Codex team.** Codex runs every command in its sandbox, which blocks two things orch needs: talking to herdr, and writing the repo's `.git` (branches, worktrees). So orch starts every Codex pane with two settings that open just those (`-c sandbox_workspace_write.network_access=true`, which also allows the internet, and the repo's `.git` as a writable folder). Start your own Codex lead the same way: `orch agents launch codex --role lead --model gpt-6.2-sol@medium` prints the command; `orch lead plan` warns when the pane you run it in is still blocked. A Codex model id can end in a thinking level: `gpt-6.2-sol@low` is Sol on low thinking. The Codex levels are small = `gpt-6-luna@high`, medium = `gpt-6.2-sol@low`, high = `gpt-6.2-sol@medium` (Astra stays blocked), and `orch models` asks Codex itself (`codex debug models`) for its current models, so a newer Sol or Luna is used without anyone editing a file.

2. **Orchestration plan:** start the plan playbook in the lead's pane (see [Choose your lead](#choose-your-lead)). The lead researches, writes `.orchestrate/plan.md` and shows you the milestones, which coder and model each one goes to, and why. Edit the plan if you like: dependencies, tier, review yes/no, your answers to open questions.
3. **Orchestration run:** tell the lead **go** (`/orch-run`). It dispatches the milestones (`orch dispatch M1 M2`), which starts the event manager, and pauses. From here the run looks after itself:
   - a milestone finishes → the event manager checks and merges it, then wakes the lead, which dispatches what that unlocked;
   - a coder asks a question → the lead is woken; if the plan or the code already answers it, it answers, otherwise it asks you in its pane. `orch answer M2 "<your answer>"` writes the answer into the plan and the **same coder** carries on with its work; if a criterion can't be met (say an outside API is missing) and you agree to ship the rest, the lead runs `orch answer M2 --defer AC2 "<your words>"`: no fix rounds or stronger-model retries for AC2, and the summary lists it as **not done**, with a follow-up;
   - a risky change is **held** → you look and run `orch approve Mn`.

   You can also start the event manager yourself: `orch autopilot` in a spare terminal. It is the only driver of a run: while it runs, other `orch` commands that would change the run are refused (`orch status`, `orch report`, `orch approve` and the lead's `orch events` / `orch dispatch` / `orch answer` still work).
   After each wake-up the lead says in its chat what happened and what it did, one plain line per event; `orch story` keeps the whole run as a diary, and `orch plan show` gives the plan as one short card per milestone.
4. **If the lead is away** (its pane is closed, or it never reads its events): nothing is lost, the events wait in the queue. Ready work starts by itself after 15 minutes, you get a desktop notification, and `orch events --peek` shows what is open. With `Lead mode: off` in the plan header there is no lead in the run at all: `orch autopilot` dispatches by itself and stops (exit 3) when it needs you.
5. **When it's done:** read `.orchestrate/summary.md` and do its manual checklist. It holds only what needs your eyes or hands (how the UI looks and behaves, a real device); whatever a command or a look at the code can settle, the run and the lead have already checked and listed with the evidence. Want a change? Tell the lead (for example "the login button should be blue"). It runs `orch fix M1 "the login button should be blue"`: one small follow-up job goes straight to the coder who built M1, with the check and review as before, and no new plan. You can run `orch fix` yourself too. When you are happy, run `orch finish`. It re-runs the check (or reuses it when it already passed on exactly these files; `--recheck` runs it anyway), removes the coders' worktrees and the `../<repo>-wt` folder (a coder folder with changes no milestone has is kept and named), pushes `feature/<name>` and opens a PR into `main` (with `gh`, or prints the compare link). Last, it prints the manual tests as a numbered list (`orch manual` prints them again), and the lead posts the same list in its chat.

### Git: one branch per run, real commits, one PR
Planning touches no git at all. `orch start` creates the plan's `Branch:` (`feature/<slug>`) and that is the only branch a run makes: coders work on detached worktrees, and a milestone's work in progress (under review, parked, waiting for a fix) lives in hidden refs under `refs/orch/`, which `git branch` doesn't list and `git push` doesn't send. Each milestone lands as **one commit whose message says what changed** (the coder's `COMMIT:` line, e.g. `feat(api): add categories endpoint`, with a `Milestone: M2` trailer). `Commits: single` in the plan header squashes the run into one commit at finish.

### No agent ever pushes to main
This is a hard rule. No agent of a run (the lead, the coders, the reviewer, on any tool: Claude, Codex, Pi, OpenCode, AGY…) pushes to `main`, `master` or the repo's default branch, or merges a PR, **in any situation, even when you ask it to**. Agents work on the run's branch; `orch finish` pushes only that branch and opens a PR; you merge it by hand.

Example: in the middle of a run you type "just push this to main". The lead answers: "I can't push to main, even when asked: that's a hard rule of this setup. The work is on feature/csv-import; `orch finish` pushes that branch and opens a PR, and you merge it yourself."

It is kept in three places:
- **In words:** every skill (`orch-plan`, `orch-run`, `orch-explain`), the lead's playbooks, each coder's task file and the reviewer's prompt say it, and the lead is reminded at every wake-up.
- **In orch:** `orch sync` refuses a plan whose `Branch:` is `main` or `master`, and `orch start` and `orch finish` refuse to work on or push such a branch.
- **In git:** `orch start` installs a **pre-push guard** in the repo (`.git/hooks/pre-push`, shared by every coder's worktree). It refuses any push that would change `main`, `master`, the remote's default branch, or a branch you add with `git config --add orch.protected <branch>`: `git push origin main`, `git push origin HEAD:main`, a force push, `--all`, deleting main. A pre-push hook you already had is kept and still runs after it. `orch guard` installs it by hand, `orch guard status` and `orch doctor` say whether it is on. If your repo keeps its hooks inside the project (husky, via `core.hooksPath`), orch doesn't write there: `orch guard --print` gives the script to add yourself.

A git hook can be skipped (`git push --no-verify`), and a PR can be merged with `gh pr merge`. The agents are told never to do either, but the lock nobody can skip is on GitHub: **Settings > Rules > Rulesets > New branch ruleset**, target `main`, tick "Require a pull request before merging" and "Block force pushes". `orch guard status` checks it when `gh` is installed and tells you when it is off.

A good feature request: Feature · Why · Must · Must not · Already decided · Done when · Mode (`shared` or `worktree`).

### Models and tiers
The lead does not pick a model by its name. It reads the catalog (`orch models`), which rates each model 1–5 on **reasoning, coding, architecture, instruction following, tool use, planning and speed**, records its context window, and says where each rating comes from. Each model serves one tier, and a model needs enough reasoning for its tier: coding skill alone never makes a model `high`.

| Tier | For | Examples from the default catalog |
|---|---|---|
| **small** | classification, renames, docs, config, mechanical edits | `haiku`, `gpt-6-luna@high`, `qwen3.6-35b-a3b` |
| **medium** | normal implementation, tests, debugging inside one module | `sonnet`, `gpt-6.2-sol@low`, `qwen3.8-27b` |
| **high** | the lead itself, contracts and architecture, cross-module refactors, auth / payments / schema, escalations | `opus`, `gpt-6.2-sol@medium`, `deepseek-v4-pro`, `glm-5.3` |

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
The agent whose pane you start the plan playbook in becomes the lead. orch names its pane `lead` by itself (`orch lead plan`, `orch start` and `orch dispatch` run in the lead's own pane and name it), and it writes `Lead: lead (<kind>)` into the plan. If herdr has no agent named `lead`, `orch start` and `orch dispatch` refuse with the exact rename command, so a run never starts with a lead nobody can wake; it never codes or reviews in its own run (`orch sync` rejects that). Give it a high-tier model: planning and coordination are reasoning work. Another pane of the same kind as a coder is fine.

| Lead | Start it with |
|---|---|
| Claude Code | `/orch-plan <feature>` |
| OpenCode | `/orch-plan <feature>` |
| Codex | `$orch-plan <feature>` or "use the orch-plan skill: <feature>" |
| Amp | "use the orch-plan skill: <feature>" |
| Hermes | "use the orch-plan skill: <feature>" |
| Antigravity (`agy`) | "use the orch-plan skill: <feature>" |
| **any agent** | "Run `orch lead plan` and follow it. Feature: <feature>" |

### Explain something simply
`orch-explain` makes any agent explain a concept, a code flow, a bug fix or an architecture change in plain words, in four parts: a short summary with an everyday analogy, a table of the parts involved, an ASCII flowchart under 65 characters wide (it fits a narrow pane), and a 3-row "why it matters" table, with one example used all the way through. It needs no run and no `orch` command.

| Agent | Ask it |
|---|---|
| Claude Code, OpenCode | `/orch-explain how does the event manager wake the lead` |
| Codex | `$orch-explain how does orch fix work` |
| Pi | `/skill:orch-explain <topic>` |
| any other | "use the orch-explain skill: <topic>" (or just "explain X simply") |

The orch-plan and orch-run skills and slash commands are thin wrappers: the playbooks themselves live in `orch` (`orch lead plan`, `orch lead run`), so every agent follows the same, versioned instructions. They are printed in parts so the lead reads only what it needs: `orch lead plan` prints research and the quick-or-full decision, then `orch lead plan quick` (a quick run's rules) or `orch lead plan full` (steps 3 to 10); on a wake-up, `orch events` prints the rules and steps for those events, so the run playbook is read once.

### Agent registry
`orch agents` shows every known kind: installed or not, roles, whether herdr can watch it, and its launch command. Defaults ship in `agents.default.toml`; add or fix kinds in `~/.config/herdr-orchestra/agents.toml` (merged key by key):

```toml
[claude]
launch = "claude --permission-mode acceptEdits"
review_launch = "claude --permission-mode acceptEdits --disallowedTools Edit,NotebookEdit"   # the reviewer pane
model_flag = "--model"        # what `orch agents launch claude --model <id>` appends

[myagent]                     # a new kind
binary = "myagent"
launch = "myagent --auto-approve"
herdr_detect = false          # herdr can't tell its idle/working/blocked state
roles = ["coder"]
skills_dirs = ["~/.myagent/skills"]
```

`orch doctor [kind]` checks an installed agent against the real tool (version, whether the launch flags still exist in its `--help`, skills, herdr detection; the `review_launch` flags too). `orch agents launch <kind>` prints the command · If you set your own `launch` for a kind and no `review_launch`, your `launch` is used for the reviewer too · `orch team <kind>` / `orch team up` build and open a whole team from one tool · `orch agents sync` installs the skills for every installed agent (run it after adding a new one) · `orch agents check` confirms every installed agent sees each skill exactly once (not missing, not twice). Many tools read more than one folder (Codex reads `~/.agents/skills` and `~/.codex/skills` and lists a skill found in both twice), so the installer writes the fewest folders that give each installed agent one copy, e.g. with Claude, Codex and OpenCode: `~/.claude/skills` (Claude) and `~/.agents/skills` (Codex; OpenCode reads both, and its docs say one copy wins). Claude Code gets the skill only (a skill is already the `/orch-plan` command); OpenCode gets slash commands in `~/.config/opencode/commands`.

### Agents herdr can't watch
For a kind with `herdr_detect = false` (or one missing from the registry, which `orch sync` warns about), `orch` relies only on the **done file and the time budget**: it never reports GONE, BLOCKED or IDLE for it, treats it as free whenever it has no task, and `orch status` marks it `detect:off`. If herdr doesn't recognise the pane as an agent at all, address it by pane id: `Workers: hermes-1 (hermes @pane:w1:p3)`. `orch` then types prompts into that pane, and `orch start` reports a `STALE pane` when the id has changed (`herdr pane list` shows the current ids).

### Small changes: quick runs
A button colour, a new field in an API response, a validation rule or a one-function bug fix doesn't need a feature breakdown, roles, worktrees and a reviewer. After reading the code, the lead makes it a **quick run** when all four hold: one coder can do it in one go, nothing about it is unclear, it stays out of risky areas (database schema or migrations, auth, payments, new packages, CI, secrets), and it follows a pattern the code already has. There is no rule about file counts: "add `createdAt` to GET /orders" is quick when the column exists, and "add `discount`" is not when it needs a migration. The plan header says `Mode: quick` and `Quick because: <what the lead found>`, and you still say go.

A quick run is one milestone (one acceptance criterion per change), one coder, no reviewer, your folder as it is (`Isolation: shared`, no setup). The check runs before work and after the coder; the final check and `orch finish` reuse that result when the files are exactly the same. The summary is what changed plus your checklist. Choose yourself with `/orch-plan quick: …`, `/orch-plan quick review: …` (keep a reviewer) or `/orch-plan full: …`. `orch sync` refuses a quick plan that lists migrations, CI, secrets or dependency files, and the risk hold still stops a change that turns out bigger. Details: [Quick runs](https://herdr-orchestra.vercel.app/docs/quick-runs/).

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

### Pi: panes or one window (subagent mode)

herdr-orchestra is also a [Pi](https://pi.dev) package:

```bash
pi install npm:herdr-orchestra
```

You can also install it straight from GitHub (same files, no npm needed): `pi install git:github.com/arunnarangali/herdr-orchestra` (add `@vX.Y.Z` to pin a release). Step-by-step setup: the [Pi page](https://herdr-orchestra.vercel.app/docs/pi/) of the docs.

Pi then has the `orch-plan`, `orch-run` and `orch-explain` skills and two commands. The first time, Pi says the `orch` command is missing (or older than the package): type `/orch-setup` once and it runs this package's installer. Pi may warn once that `orch-plan` / `orch-run` were found twice (the installer also puts them in `~/.agents/skills` for Codex, Amp and OpenCode); it keeps one copy and works.

Runs have two modes. Nothing changes for anyone who never picks the second one.

| Mode | Where the coder and reviewer run | Who drives the run |
|---|---|---|
| `panes` (default) | herdr panes, as described above | the event manager; the lead dispatches and pauses |
| `subagent` | inside one Pi window, as Pi subagents ([pi-subagents](https://www.npmjs.com/package/@tintinweb/pi-subagents)) | the lead, one milestone at a time |

Switch with `/orch-mode subagent` in Pi; `/orch-mode` alone shows the mode, and Pi's footer shows it too (`orch: subagent`). The choice is saved in `~/.config/herdr-orchestra/config.json`, and a run keeps the mode it was planned in.

`/orch-mode subagent` also sets subagent mode up, right there in Pi, with no terminal step: it installs the `orch` command if it is missing or old, writes the coder and reviewer agents, installs pi-subagents, and reloads Pi so the `Agent` tool is ready. It ends with `Done: subagent mode is ready.` `/orch-setup --mode subagent` does the same. From a normal terminal (no Pi open), the same setup is:

```bash
orch setup --mode subagent          # or: npx herdr-orchestra@latest --mode subagent, or orch team up --mode subagent
```

Setup writes `~/.pi/agent/agents/coder.md` and `reviewer.md` (the reviewer cannot edit files) and installs `npm:@tintinweb/pi-subagents`. Pick their models in the config file; with none, they use the lead's model. `max_turns` (optional) stops a subagent that loops after that many turns; the lead then resumes it once or asks you. A model the policy denies is refused, and a file you edited yourself (without orch's line in it) is left alone. Both agents' descriptions say they are only for orch runs, so a normal Pi chat does not hand its own work to them.

```json
{
  "mode": "subagent",
  "subagent": {
    "coder":    { "model": "anthropic/claude-sonnet-4-5", "thinking": "medium", "max_turns": 80 },
    "reviewer": { "model": "openai/gpt-5", "thinking": "high" }
  }
}
```

A subagent run: `/orch-plan` as usual (the plan's team is `Workers: coder (pi)`, `Reviewer: reviewer (pi)`, `Isolation: shared`), say go, and the lead repeats for each milestone: `orch sub next` (the next milestone and its task file) → the `coder` subagent builds it → `orch check Mn` (failures go back to the same coder) → the `reviewer` subagent when the milestone has `Review: yes` → `orch sub done Mn` (orch commits it on the feature branch; risky changes still wait for `orch approve`). At the end you get the summary and run `orch finish`, as always. It is simpler and needs no herdr, but slower than panes mode: no coders in parallel, and the lead spends more tokens.

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
| An agent disappears | coder: its task moves on with the work so far, and the lead gets a `WORKER-LOST` event with the exact fix (`orch resume` or `orch team up`); reviewer: only the review waits. Either is used again as soon as it's back. A pane where the agent quit and only a shell is left counts as gone: nothing is typed into a shell |
| Most agents vanish at once | `HERDR RESTART?` in the log, a desktop alert and a lead event: run `orch resume` |
| A prompt can't be delivered | the task goes back in the queue (its job kept) and that agent is retried after 2 min; 3 in a row bench it for 30 min |
| Attempts keep getting lost (unreachable, gone, rate-limited) | after 4 (`ORCH_MAX_LOST`) the task fails with the history instead of looping |
| Autopilot is killed mid-step | the next run confirms or re-sends an unconfirmed prompt to the same agent, and finishes or undoes a half-done merge |
| The computer was off, herdr was closed, or the event manager died | `orch status` says so in its first lines. `orch resume` carries on: the time orch was down is not counted against any task, the agents' panes get their names back, unsaved work is saved and the tasks in progress are sent again (see [After a restart](#after-a-restart)) |
| A milestone is paused or moved while its coder still works | orch presses the agent's interrupt key (Esc; set per agent kind as `interrupt_keys` in the registry), then types the STOP note. The coder shows as `stopping M7` in `orch status` and gets no new work until herdr shows it idle; the event manager presses the key again if it keeps going. `orch free <worker>` frees it once you have checked its pane |
| A paused coder keeps writing files | whatever it writes anyway is saved into the milestone the next time the milestone or that folder is used. orch never refuses a task because a folder has unsaved files |
| plan.md changed while a coder works on that milestone | its task.md is not rewritten mid-work; `orch sync` warns and says how to send the new text (`orch set Mn paused`, then `orch dispatch Mn`) |
| Lockfiles changed since a folder was set up | the setup command runs again there (and in your main folder before the merge check) |
| Risky change (deleted file, migration, CI config, secrets file, unlisted dependency change, very large diff) | the milestone is **held** until you run `orch approve Mn`; the rest keeps going |
| The wake-up prompt never became a turn for the lead (it sat in the input box, or you were typing there) | sent again after 30s, then 1 min; after 3 tries you get a notification. The event manager does not leave at ALL_DONE before the lead has read the last events |
| A coder changes files outside its `Likely files` | listed in the summary (`Scope: strict` sends it back instead) |
| An orch step fails for one task | that task is paused with the error; the others keep running |
| The final check fails on the branch | stops; the next run re-checks and carries on once it passes |
| Permission prompt | desktop alert, other tasks keep running |
| Agent stops early | nudged once, then parked |
| Worker writes `QUESTION:` | that task and its dependents wait, the lead is woken to answer or ask you; everything else continues |

### After a restart
Nothing on a switched-off computer can restart itself, so after a reboot (or after closing herdr) one command is needed. Open herdr, then run in the repo:

```bash
orch resume
```

It does five things, and says what it did:

1. **The time orch was down is not counted.** Example: M4 was sent at 11:30, the computer went off at 11:42 and came back at 13:31. M4 counts 12 minutes of work, not 2 hours, so it is not paused as "over its time budget", and the time report says `Not counted: 1h49m while orch was not running`. A laptop that only slept, with the event manager still up, is handled without any command: the sleep is taken out the same way.
2. **Agents get their names back.** herdr brings the panes back, but not the agents' names, and orch reaches agents by name. `orch resume` finds each coder's pane by its folder and names it again (`NAMED opencode-1: pane w1:p3`). Where it can't decide (the reviewer and the lead sit in the main folder, next to your own panes), it prints the exact command: `herdr agent rename w1:p5 reviewer`. A pane that came back as a plain shell needs its agent started: `orch team up` does that in the same pane.
3. **Unsaved work is saved** into the milestone it belongs to.
4. **Each task that was in progress is sent to its agent again.** The agent's old conversation is not needed: the task and the code are in files, so a fresh conversation carries on from them. You don't have to type "continue" in each pane.
5. **The event manager is started**, and it wakes the lead if events wait for it.

It is safe to run more than once. If an agent with work in progress is still missing, it stops and says what to do. `orch autopilot` and the lead's `orch dispatch` do steps 1 to 4 by themselves when they start the event manager after a gap.

orch can't bring an agent's old conversation back, and it can't start itself when the computer starts.

### Keep a coder out, swap a coder
- `orch bench claude-1 off "no Claude today"` keeps a coder out of the run until `orch bench claude-1 on`. It holds across restarts, `orch sync`, `orch resume` and `orch team up`; a usage-limit bench, by contrast, ends by itself.
- `orch dispatch Mn --to <worker>` refuses a worker with no agent in herdr and says to run `orch team up`. `orch status` shows each worker as `herdr=ok`, `NO AGENT` or `SHELL ONLY`, and `state=free`, `coding M3`, `benched 42m (rate-limit)` or `OFF`.
- Swap a coder: `orch stop` (the event manager finishes its current step and exits; nothing is lost), change `Workers:` in plan.md, `orch sync`, `orch team up`, then `orch resume`.
- `orch team up` looks again a few seconds after it starts each agent. One that quit at once (a bad flag, a sign-in) is reported as `QUIT`, with its last screen saved.

### Logs and crash notes
Everything is in the repo's own `.orchestrate/` folder, so two projects never share a log:

| File | What is in it |
|---|---|
| `autopilot.log` | the event manager's diary. Over 2 MB it becomes `autopilot.log.1` (one old copy is kept) |
| `manager.out` | raw output of a manager started in the background (1 MB, one old copy) |
| `events.jsonl` | one line per milestone status change (`orch report` reads it) |
| `crash/` | the last screen of an agent that quit or vanished, newest 20 kept |

Every stop of the event manager writes a last line: `STOPPED: orch stop`, `STOPPED: the event manager exited (code 3)`, or `CRASHED: <error>` with the traceback. A manager killed without a word (the memory guard closing the terminal, a reboot) is found by the next `orch status`, `orch resume` or manager start, which looks up why in the computer's own log (`journalctl`, `coredumpctl`, boot time) and writes it, for example `[shop feature/cart] CRASHED: ... Reason: the memory guard (systemd-oomd) closed the terminal`. A kill is blamed on this run only when it names one of this run's own processes (recorded when the manager starts), so another project's crash is never written here. `orch doctor --crash` shows the last notes and saved screens. Sizes: `ORCH_LOG_MAX_MB` (default 2), `ORCH_CRASH_KEEP` (default 20).

The event manager starts in its own systemd scope when it can (`systemd-run --user --scope`), so a closed terminal or herdr pane does not take it down; elsewhere it starts as before (`ORCH_NO_SCOPE=1` turns this off).

### Contracts and reports
`plan.md` stays the file you edit. From it `orch` generates a `task.json` for each milestone (numbered acceptance criteria `AC1…`, allowed files, interfaces, the commits of its dependencies). Coders answer with a `result-N.json` (status, commit message, files changed, the check they ran, each criterion met or not), and the reviewer with a `review-N.json` (a verdict per criterion plus findings). The old line formats (`COMMIT:`, `QUESTION:`, `BLOCKER:`) still work as a fallback. The shapes are in [docs/contracts.md](docs/contracts.md).

Every status change is written to `.orchestrate/events.jsonl`, and `orch report [--json]` shows estimated vs actual time (and why anything took longer), time per milestone, fix/review/conflict rounds, first-pass rate and wasted work, plus how each model did. Tokens and cost appear only when an agent reports `usage` in its result file.

Optional plan header lines: `Lead mode: events | off` (default `events` when the plan has a `Lead:` line) · `Scope: warn | strict` · `Risk hold: on | off` · `Budget: 3h` (autopilot stops when its running time is used up) · `Estimate: 1h30m` (the lead's estimate for the feature) · `Setup inputs: <globs>` (which files mean "run setup again"; default: lockfiles and manifests). Per milestone: `Why separate` (why it is its own milestone; needed when the plan has more than one) · `Tier`, `Needs`, `Model why` (see [Models and tiers](#models-and-tiers)) · `Estimate: 40m` (dispatch to landed if nothing goes wrong) · `Parallel: allow` lets it run next to a milestone that shares its `Likely files`.

### Commands
`orch status` · `orch resume` · `orch report` · `orch approve Mn` · `orch models [show|check <id>]` · `orch events [--peek]` · `orch dispatch Mn... [--to <worker>] [--tier <tier>]` · `orch answer Mn [--defer AC2] "<answer>"` · `orch defer Mn AC2 "<reason>"` · `orch fix Mn "<change>" [--to <worker>]` · `orch doctor [kind]` · `orch guard [status|--print]` · `orch ready` · `orch autopilot` · `orch lead plan|run|check|whoami` · `orch agents [launch <kind> [--model <id>]|sync|check]` · `orch handoff Mn` · `orch needs-fix Mn` · `orch set M3 pending` · `orch park M2 paused "why"` · `orch cooldown claude-1 60` · `orch bench claude-1 off|on` · `orch stop [--now]` · `orch doctor --crash` · `orch cleanup` · `orch finish [--no-push]` · `orch version` · `orch update [--check] [--version vX.Y.Z]` · `orch config [auto-update on|off]` · `orch mode [panes|subagent]` · `orch setup [--mode panes|subagent]` · `orch check [Mn]` · `orch sub next|done Mn` · `orch` (full help)

Tunables: `ORCH_CODER_BUDGET_MIN` (45) · `ORCH_REVIEW_BUDGET_MIN` (15) · `ORCH_CHECK_TIMEOUT_MIN` (30) · `ORCH_COOLDOWN_MIN` (60) · `ORCH_MAX_TASKS` (unset: no limit) · `ORCH_GONE_COOLDOWN_MIN` (10) · `ORCH_SEND_RETRY_S` (120) · `ORCH_HERDR_TIMEOUT_S` (30) · `ORCH_MAX_LOST` (4) · `ORCH_UNREACHABLE_MIN` (30) · `ORCH_CONFIRM_S` (30) · `ORCH_DOWN_MIN_S` (120: an event manager silent for longer was down, and that time is not counted) · `ORCH_RISK_MAX_LINES` (1500) · `ORCH_LEAD_WAIT_MIN` (15: ready work the lead hasn't dispatched starts by itself) · `ORCH_LEAD_CONFIRM_S` (30: a wake-up the lead did not pick up is sent again, doubling) · `ORCH_LEAD_REWAKE_S` (300) · `ORCH_LEAD_MAX_WAKES` (3) · `ORCH_LEAD_IDLE_MAX_MIN` (720: how long the event manager waits for an answer) · `ORCH_NO_AUTOSTART=1` (the lead's commands never start the event manager) · `ORCH_GUARD_GITHUB=0` (`orch guard status` doesn't ask GitHub whether main is protected)

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
