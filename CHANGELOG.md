# Changelog

All notable changes. Versions follow [semantic versioning](https://semver.org).

## [6.28.0] - 2026-11-27

### Changed
- **The README and the website say herdr-orchestra is in beta.** A "status: beta" badge and a short note at the top of the README, a BETA line in the homepage hero and a note at the top of the docs introduction say the project is in active development and that commands, plan format and behaviour may still change. Versions stay on 6.x: going back to 0.x would make `npx herdr-orchestra@latest` and installed copies treat new releases as older.

## [6.27.0] - 2026-11-27

`/orch-board` in Pi: open the run board without leaving Pi.

Example: you lead a run from Pi, inside herdr. Type `/orch-board` and the board opens as a popup in the repo you are in, the same popup the board key (`prefix+a`) opens. Close it with `q`. In a plain terminal (no herdr), `/orch-board` starts `orch view` in the background and shows its address, `http://127.0.0.1:...`.

### Added
- **`/orch-board`** (Pi). Inside herdr it opens the board popup with `--cwd` set to your repo. If herdr refuses (for example the plugin is not linked) it says why, points to `orch view plugin link`, and opens the browser page instead. Without herdr, or without the `orch` command, it says what to do (`/orch-setup`).
- Subagent mode needed no change: `orch sub` already records each milestone's start and finish in `state.json`, so the board and `orch view` show them as in panes mode.

### Not yet tried
- With a real Pi window and real herdr: tested with a stand-in for Pi's API and a fake `herdr` command.
## [6.25.0] - 2026-11-27

You choose the model and thinking level of each milestone and of the reviewer, right after the plan. Before, a milestone only had a level (small, medium, high) and went to any coder of that level; to change a model you edited `Workers:` in plan.md by hand, and nothing stopped orch from moving the milestone to another model later.

Example: after `/orch-plan` shows the plan, the lead shows the team table (M1 codex-2 gpt-6.2-sol medium, M2 codex-1 gpt-6-luna high, Reviewer gpt-6.2-sol medium) and asks "Keep this team?". You pick "Change a step", then M2, gpt-6.2-sol, low. The lead runs `orch plan model M2 gpt-6.2-sol@low`: M2 is locked to Sol on low thinking, no coder ran that, so `codex-3 (codex: gpt-6.2-sol@low)` joins the team and `orch team up` opens its panel when you say go. Later, "M2 use luna high" in the lead's chat changes it again.

### Added
- `orch plan team`: one row per milestone and one for the reviewer, with its coder, model, thinking level and whether you chose it; then the models and thinking levels you can pick (your tool's own list, from `codex debug models` for Codex) and the ones never allowed.
- `orch plan model <Mn|reviewer> <model>@<thinking>` (also `M3 gpt-6.2-sol low`): writes `Model:` on the milestone, or the model on the `Reviewer:` line. A new coder joins `Workers` when none runs that model. `auto` takes a milestone's lock off. It refuses a model the policy blocks (Astra) and a thinking level the tool doesn't have, and says what to do when the milestone is already being built or has landed, or the reviewer's panel is open on the old model.
- The plan playbook: only after the plan is shown (full and quick runs), the lead shows the table and asks "Keep this team?" in its question picker, then one question at a time: which step, which model, which thinking. Without a picker the developer types `ok` or `M3 sol low`.
- Registry key `efforts`: the thinking levels a tool accepts (Codex: low, medium, high, xhigh, max).

### Changed
- A milestone with `Model:` is a lock: only coders on exactly that model take it. orch never moves it to another model by itself: `orch escalate` says NO_ESCALATION, and `orch dispatch --to` a coder on another model or `--tier` is refused. The run playbook has a hard rule for the lead: the developer's model choices stay until the developer changes them.
- `orch sync` stops when a `Model:` line names a model no coder in `Workers` runs (and names the command that adds one), or a blocked model.
- `orch plan show` says "locked by you to <model>" on a locked milestone's card.

### Not yet tried
- With a real lead's question picker and real Codex panels: tested with orch's simulated agents.

## [6.24.0] - 2026-11-27

Frontend and backend, in one repo or in two. Before, a run belonged to the one git repo you started it in: frontend and backend in separate repos could not be one run, two runs side by side both called their agents `codex-1`, and in a monorepo every milestone waited for the whole repo's tests.

Example: `~/work/shop/` holds two git repos, `frontend/` and `backend/`. The lead writes one plan in `~/work/shop/.orchestrate/plan.md` with `Repos: frontend, backend`, M1 (`Repo: backend`, the endpoint) and M2 (`Repo: frontend`, the screen, `Depends on: M1`). The backend coder builds M1 in `backend-wt/backend-claude-1`, it lands on backend's `feature/discounts` after backend's check; then the frontend coder builds M2 in `frontend-wt/frontend-claude-1`, and it lands on frontend's own `feature/discounts`. `orch finish` opens one PR in each repo.

### Added
- **A workspace of several repos.** A plan whose header says `Repos: frontend, backend` (folders next to `.orchestrate/`, or `web=apps/web`) gives every milestone a `Repo:`. `orch sync` there writes each repo's own plan and syncs it, so each repo is an ordinary run: its own coders and reviewer (named after the repo: `frontend-claude-1`), worktrees, feature branch, check and PR. Per repo, optionally: `Check <repo>:`, `Setup <repo>:`, `Workers <repo>:`, `Reviewer <repo>:`.
- **Dependencies across repos.** `Depends on: M1` works when M1 is in another repo (the repo's plan shows `backend:M1`). The waiting repo's event manager stays up and says `waiting for another repo: M2 waits for backend M1`; `orch ready` and `orch status` say it too. It gives up after the usual idle time only when the other repo's event manager is not running.
- **One lead for every repo.** In the workspace folder, milestone commands (`orch dispatch M2`, `orch answer`, `orch set`, `orch approve`, `orch check M1`) go to that milestone's repo, and the others (`orch start`, `status`, `events`, `team up`, `autopilot`, `finish`, `resume`, `stop`) run in every repo. `orch autopilot` there runs every repo's event manager side by side. Inside one repo, orch works on that repo's run only.
- **A check per side in a monorepo.** `Check frontend: cd frontend && npm test` in the header and `Side: frontend` on a milestone: that milestone is checked in its coder's folder and when it lands with its side's command only. The plan's whole `Check command` still runs on the finished branch (a side's pass is never reused for it).
- `orch team <kind> --prefix <name>` starts every name of the team with `<name>-`.

### Fixed
- **Two runs on one machine could send work to the same pane.** herdr finds agents by name, and every run called them `codex-1`, `reviewer`, `lead`. `orch sync` now refuses a name another going run uses (it names that run's folder and suggests `<repo>-codex-1`), and `orch team <kind>` names the team after the repo while another run is going. One lead shared by the repos of a workspace is fine.

### Changed
- A plan header key may now end in a word with digits, dots or dashes (`Check web-app:`, `Workers api2:`).

### Not yet tried
- With real agents and real repos: tested with orch's simulated agents (two repos, a dependency across them, both branches and worktrees, the checks per side). Subagent mode (Pi) stays one folder: plan and run it inside one repo.

## [6.23.0] - 2026-11-27

Subagent mode now belongs to Pi only. Before, `orch setup --mode subagent` saved one machine-wide `"mode": "subagent"`, so every lead got Pi's subagent steps, even Antigravity, Claude Code or Codex.

Example: you turn on subagent mode in Pi, then plan a feature with Antigravity. Before, `orch lead plan` in Antigravity printed `SUBAGENT MODE (Pi, one window)` and told it to skip herdr and use Pi subagents. Now Antigravity gets the normal panes playbook, and Pi still gets subagent mode.

### Fixed
- **The mode is saved per agent**: `~/.config/herdr-orchestra/config.json` holds `"modes": {"pi": "subagent"}`. Any agent not listed uses panes mode.
- **Subagent mode is refused for agents that have none.** Only Pi has it today (through pi-subagents), so orch never gives another agent subagent instructions. `orch mode subagent --agent claude` says no. `orch setup --mode subagent` from a plain terminal saves it for Pi.
- **orch knows which agent is asking**: from `AI_AGENT` (Pi sets `pi`, Claude Code sets `claude-code_...`), then `PI_CODING_AGENT`, `CLAUDECODE`, `CODEX_*` or `OPENCODE`. When it can't tell (for example Antigravity), the agent gets panes. `--agent <kind>` or `ORCH_AGENT=<kind>` says it by hand.
- **An old Pi run no longer leaks into the next plan.** If the repo's last run was a Pi subagent run, another agent's `orch lead plan` / `orch lead run` still gets panes. `orch sync` gives a new plan subagent mode only when its `Lead:` is Pi and Pi's saved mode is subagent.
- `orch mode` shows this agent's mode, and the modes saved for other agents (`saved per agent: pi=subagent`).
- **herdr's sidebar could miss a short review.** The sidebar name (`reviewer · reviewing M2`) was only sent once per event-manager round, so a review that finished quickly never showed up there. Now it is sent as soon as a coder's job or a review starts. This also fixes a test that failed now and then in CI.

### Added
- `ORCH_MODE=panes|subagent` changes the mode for one command, for example `ORCH_MODE=panes orch lead plan` in Pi. `subagent` works only in Pi.
- `--agent <kind>` on `orch mode`, `orch setup` and `orch lead plan|run`.

### Changed
- An old config with `"mode": "subagent"` keeps working: orch reads it as Pi's only. The next `orch mode` or `orch setup --mode` saves it as `"modes": {"pi": "subagent"}` and prints `MOVED`. The Pi extension (`/orch-mode`) reads and writes the new format too.

### Not yet tried
- With real Pi and Antigravity windows. Tested with orch's simulated agents and the Pi extension test harness. Pi sets `AI_AGENT=pi` and `PI_CODING_AGENT=true` (checked in `@earendil-works/pi-coding-agent`); Antigravity sets no known mark, so it is treated as "not Pi" (panes).

## [6.22.0] - 2026-11-26

The board popup (`prefix+a`) now opens in the repo of the pane you were in. Before, it could answer "This folder is not a git repo with an orch run" even while a run was going.

Example: you are in the `rupee-flow` space with a run going and press `ctrl+b`, then `a`. The popup used to start in a folder that was not your repo. Now it starts in your pane's folder and shows the run.

### Fixed
- **The popup started in the wrong folder.** Herdr starts a popup in the plugin's own folder unless it is told otherwise. orch looked for the pane's folder under field names Herdr does not use, found none, and told Herdr nothing. It now reads Herdr's real fields: the focused pane's folder, else the space's folder, else its worktree. It prefers the folder whose repo has an orch run (also from a coder's worktree pane), and always passes the folder to Herdr with `--cwd`.
- When the popup still is not in a repo, it now says which folder it is in.
## [6.20.0] - 2026-11-26

The tests run in about 5 minutes instead of about 21. Nothing in orch changed, and no check was removed, skipped or made easier.

Example: `bash tests/parallel.sh` runs the 66 sections of `tests/run.sh` side by side, about 8 at a time, each in its own temp folder with its own fake herdr and fake agents. It finished in 300s with 764 checks passed, the same 764 checks by name as `bash tests/run.sh` gives one after another (1265s on the same machine).

### Changed
- **`tests/parallel.sh`** runs the sections of `tests/run.sh` side by side. Every section runs as written, with the same waits and timeouts, so a timing bug that shows only with slow agents is still caught. Sections that use what the section before them left behind run together in one group (the `JOINS` list). Three sections whose checks compare how long things take (7, 45, 58) run after the others, one at a time, on a quiet machine as in `tests/run.sh` (the `SOLO` list), so the load of the others cannot fail them. The run fails if a check fails, if a group stops early, or if any section did not print its title. `-j N` sets how many groups run at once, `--list` shows the groups, and `bash tests/parallel.sh 45` runs only the group of section 45, for quick runs while you work.
- **CI and the Release workflow** run `tests/parallel.sh`. `bash tests/run.sh` still runs everything one after another, as before.

### Fixed (tests only)
- **A check could fail for nothing on a busy machine.** `cmd | grep -q text` stops reading at the first match, so `orch` could hit "Broken pipe" while still printing its help, and `pipefail` then failed the check. All 127 such checks now use `qgrep`, a grep that reads everything. What each check tests is unchanged.
- Five things several sections use (`P1`, `MPLAN`, `PRS`, `stpy` and the fake agent programs in `$FAKEBIN`) are defined once at the top of `tests/run.sh` instead of inside the first section that used them, so any section can run on its own.

## [6.17.0] - 2026-11-26

A compact that ended quickly always gets its line in `orch story` now. Nothing else about compacting changed.

Example: `claude-1` finishes M1, gets `/compact`, and is idle again before the event manager looks at it. The next job (M5) was sent at once, and the line `claude-1's chat after M1 is now a short summary (/compact)` was never written (about 1 run in 10 in the tests). Now whichever step sees the compact end first writes that line, exactly once.

### Fixed
- **The "compact is over" line could go missing.** When the next job reached the agent before the event manager noticed the compact had ended, `orch send` / `orch review` dropped the compact silently. Both now write the story line (`<agent>'s chat after Mn is now a short summary`), and the event manager writes it only when it is the one that ends the compact. The work itself was never affected: the agent was idle and got its job.
- The test for it no longer depends on timing: section 60 checks the story lines, and a new check sends the next job before the event manager looks (it failed on 6.14.0).

## [6.15.0] - 2026-11-26

The lead's questions before planning now open in your agent's own question picker, so you click your answers instead of typing `1 a, 2 both, 3 no`. This works in every agent that has a picker, and chat stays the fallback.

Example: `/orch-plan add discounts` in Pi shows `Discount on the whole order or on each item?` with `(a) Whole order [Recommended]`, `(b) Each item` and `Custom answer...`. You pick, the answers are saved to `.orchestrate/questions.md`, and the plan follows straight away.

### Added
- **Native question rule** in the plan playbook (step 2a), for every lead: use your question picker when you have one (Claude Code `AskUserQuestion`, OpenCode `question`, Codex `request_user_input`, Pi `orch_ask`, Antigravity's picker), save questions and answers to `.orchestrate/questions.md`, and go straight on to the plan. If you close the picker, planning pauses and the lead never guesses. With no picker, the lead asks in chat as before. `grill:` is still one question at a time.
- **Pi: `orch_ask` tool** in orch's Pi package (Pi has no question tool of its own). It shows one picker per question, marks the suggestion `[Recommended]`, offers a custom answer, and saves the file in the main checkout's `.orchestrate/`, also from a worktree. Escape returns `cancelled`, and a Pi with no screen returns `no_ui`. A second round in the same planning is added to the file, and questions from an earlier plan are replaced.
- **Codex lead with its picker on.** New registry key `lead_flags`, added only to the lead's start command. For Codex it is `-c features.default_mode_request_user_input=true`, which codex-cli 0.172 lists as an "under development" feature. `orch team codex` and `orch agents launch codex --role lead` include it. Coders and the reviewer never get it, because a picker in an unattended pane would wait for nobody.

### Notes
- The real pickers were not tried by hand in Claude Code, Codex, OpenCode, Antigravity or Pi. The tests drive `orch_ask` with a stand-in for Pi's screen, and the extension type-checks against `@earendil-works/pi-coding-agent` 1.6.1. Antigravity's picker tool name is not documented, so the rule describes the tool instead of naming it.
- A Codex lead that is already open keeps working as before: it asks in chat. Start it again with `orch agents launch codex --role lead` to get the picker.
- `.orchestrate/questions.md` is no longer listed as "a plan file orch does not read" in the views and `orch sync` (orch reads it to tell planning from a run).

## [6.14.0] - 2026-11-26

A coder's and the reviewer's chat no longer keeps growing from milestone to milestone. When one is done with a milestone, orch types its tool's `/compact` into its pane while it is idle, so the tool swaps the long chat for a short summary. Every job orch gives an agent is already written down in files (`task.md`, `task.json`, fix and review files), so the next milestone loses nothing it needs.

Example: `claude-1` builds M2 and M2 lands. `claude-1` is idle, so orch sends `/compact`. When herdr shows it idle again, it gets `Read .orch-task/M4/task.md ...`. `orch story` reads `the event manager did: claude-1 finished M2: orch sent /compact so its chat does not keep growing`.

### Added
- **`/compact` between milestones**, on by default for Claude Code, Codex and AGY. orch sends it only while herdr shows the agent idle and it holds no job: as soon as its milestone lands, or just before it starts a different milestone (then that milestone waits until the compact is done). Never in the middle of work, never for a fix or review round of the same milestone, and never for the lead.
- While it compacts, the agent shows as `compacting` in `orch status`, `orch status --json`, `orch view` and `orch board`, and gets no new work. It is free again once herdr shows it idle for `ORCH_COMPACT_SETTLE_S` (10 s). Still working after `ORCH_COMPACT_MAX_S` (5 min): orch stops waiting and says so.
- **`orch config compact on|off`** (and `ORCH_COMPACT=0|1`) turns it on or off for this machine. `orch config` shows it.
- Registry keys **`compact`** (the command, `/compact`) and **`compact_min_version`**. AGY added `/compact` in 1.2.15: an older or unreadable `agy --version` means no compacting, said once in `orch story`, and `orch doctor agy` shows it. OpenCode, amp, Pi and Hermes stay off until their command is checked; `compact = "/compact"` in your `agents.toml` turns it on for a kind, `compact = ""` turns it off.
- Restart recovery: what each agent's chat holds and a compact in progress are kept across `orch sync` and `orch resume`. A compact that was cut short by a restart does no harm: the agent just gets its next job.
- Docs: [Compact between milestones](https://herdr-orchestra.vercel.app/docs/agents/#compact-between-milestones), the new keys and variables in Configuration, the command in Commands.

### Not yet tried
- With real Claude Code, Codex and AGY windows. It was tested with orch's simulated agents and herdr. The command name was checked in each tool's docs (AGY: from 1.2.15).

## [6.13.0] - 2026-11-26

The views no longer pass an old run off as the current one, and orch says when a plan file has a name it does not read.

Example: a developer saves the new plan as `.orchestrate/csv-import.md` and opens `orch view`. Before, the page still showed last week's `plan.md` milestones as if they were live. Now a note at the top reads "This is the last run (Categories): all its milestones landed 2 d ago. No run is going now" and "`.orchestrate/csv-import.md` is not used: orch only reads `.orchestrate/plan.md`. Rename or copy it to plan.md, then run `orch sync`."

### Added
- **Notes about old runs and unread plans** in `orch view` (a bar at the top), `orch board`, `orch status` (a `note:` line) and `orch status --json` (a `notices` list). They appear only when no run is going: the last run landed everything (`old_run`), `plan.md` changed after the last run (`plan_unsynced`), or a `.orchestrate/*.md` file that orch does not read is newer than the run (`other_plan`). Files orch writes itself (summary, story, pr-body, manual-tests) are never counted. While a milestone is being worked on there are no notes.
- **`orch sync` points out a plan it does not read.** With no `plan.md` it names the other `.md` file and says to rename it; with a newer file beside `plan.md` it warns and still loads `plan.md` as before.

### Not changed
- orch still reads only `.orchestrate/plan.md`, and one repo still has one run at a time.

## [6.12.1] - 2026-11-26

### Fixed
- **The run board key is now `prefix+a`, not `prefix+o`.** `prefix+o` is Herdr's own "open notification target" key, so Herdr kept its key and ignored ours. `orch view plugin link`, `orch view herdr-config` and the docs now give `prefix+a`, which no Herdr default key uses. If you added the old lines to Herdr's config, change `prefix+o` to `prefix+a` and restart Herdr.

## [6.12.0] - 2026-11-26

The website's run diagrams are now interactive. Nothing in `orch` changed.

Example: on the home page, pick the `orch resume` tab in the Herdr window and press step. The computer goes off for 1h49m in the middle of M2; the timers stop at 0:18:04, the coders' worktrees keep their files, and `orch resume` names the panes again and re-sends the work. Without that, M2 would read 2:07:04 against a 40-minute budget.

### Added
- **Herdr window, two modes.** `orch autopilot` plays one run: the lead plans and dispatches M1 and M2, two coders build in their own worktrees, the reviewer reads each diff without editing, and the event manager merges. `orch resume` plays a restart mid-milestone. Play/Pause, Step and Replay; nothing loops.
- **Stage inspector** under the run loop and the event loop diagram: `PLAN_READY`, `DISPATCHED`, `CODING`, `REVIEW_AUDIT`, `GATE_HOLD`, `MERGED`. Click or tab to a state, or to a node in the diagram, to see the command (`orch plan show`, `orch dispatch`, `orch answer`, `--defer`, `orch approve`), the role it wakes, the exact text that role gets, and the line it adds to `orch story`.
- **Role mapper** on the Agents page: pick the lead, the coders and the reviewer from the kinds in `agents.default.toml`, and copy the matching `agents.toml` roles and `plan.md` team lines (models from `models.default.toml`).
- **Timeline scrubber** in "How it works": drag it or use ← → to step through the run log. The pane states, the active and not-counted time, and the milestones on the branch diagram follow it. The example run now has a laptop sleep in the middle (14:22 to 16:11), logged as orch logs it.

### Changed
- Site motion: state changes take 150 ms or less, no blinking cursors or endlessly moving lines.
- `astro check` passes with no errors (the run loop diagram had 23 type errors).

## [6.11.0] - 2026-11-25

You can now watch a run as a picture: in your browser, in a Herdr pane, and in Herdr's own sidebar. Every view shows each milestone with a one-line description of what it is for, not only its id.

Example: run `orch view` and your browser shows the milestones as a graph. `M6 Docs page · Help page that explains the CSV import` is red, and clicking it shows the coder's question and the command `orch answer M6 "..."`. Herdr's sidebar meanwhile reads `codex-1 · M2 building` instead of just `codex-1`.

### Added
- **`orch view`: the run in your browser, live and view only.** The run ring (how many milestones are with the lead, coders, checks, reviewer, or waiting for you), a milestone graph with arrows for "needs this first", coloured by where each milestone is, with its plain description under it. Click a milestone for its question, the exact command to answer it, its steps and files. Also the agents (model, tier, what they hold), time and cost (against the lead's estimates, why a milestone took longer, tokens and cost per model), a replay slider that plays the run back from `events.jsonl`, and an optional browser alert when a milestone starts to need you. It updates by itself (Server-Sent Events) and never writes or locks the run. Listens on 127.0.0.1 only. `orch view --bg`, `stop`, `status`, `--port`, `--no-open`.
- **Phone view.** On a narrow screen the graph becomes a list and the milestone that needs you sits at the top. `orch view --lan` opens it to your phone on the same Wi-Fi, with a secret token in the link; without the token the page refuses. Off unless you ask.
- **`orch board`: the same run as text** for a Herdr pane, split or popup: the milestones as a tree with their descriptions, the agents, the last events. Arrow keys pick an agent, Enter jumps to its pane, `w` starts the browser view. `--once` prints it once.
- **Agent names in Herdr's sidebar.** The event manager tells Herdr what each agent does (`codex-1 · M2 building`, `reviewer · reviewing M7 (round 1)`, `codex-3 · free`) and puts a run line on the Space (`orch: 3/7 landed · 1 needs you`). Display only: Herdr still finds agents by their real name. Sent on a separate thread, only on changes, so it never slows the run (tested with a Herdr that takes 4 seconds per call). Names fade an hour after the last change; `orch finish` gives every agent its own name back. Needs Herdr 0.6.3+ (the extra rows 0.7.4+). `ORCH_SIDEBAR=0` turns it off.
- **`orch view herdr-config`** prints the sidebar rows (each agent's milestone description, the run line) and a popup key for Herdr's config. **`orch view plugin link|unlink`** links a small Herdr plugin shipped with orch that opens `orch board` as a popup (Herdr 0.7.4+). `orch view plugin link` now prints the key lines to paste into Herdr's config (`prefix+o`, which is unused in Herdr's default keys; Herdr keeps its own key if yours clashes).
- **`orch status --json`**: one stable run summary (`"view": 1`) that both views read, documented in `docs/contracts.md`.
- `orch status` prints the browser view's link (or how to start it), and the lead's "needs you" events carry a `SEE:` link straight to that milestone while the view runs.
- `orch doctor` says which views your Herdr supports.
- Docs: [Watch a run](https://herdr-orchestra.vercel.app/docs/watching/), and the new commands in Commands.

### Not yet tried
- The sidebar names, the plugin popup and the Enter-to-jump key with a real Herdr. They follow Herdr 0.9.5's documented commands (`pane report-metadata`, `workspace report-metadata`, `plugin link`, `agent focus`) and were tested with the simulated Herdr. The browser page was checked in Chromium (desktop and phone size).

## [6.10.0] - 2026-11-25

No agent ever pushes to main. This is now a hard rule, in words and in code: the lead, the coders and the reviewer (on any tool: Claude, Codex, Pi, OpenCode, AGY…) never push to `main`, `master` or the repo's default branch, and never merge a PR, in any situation, even when the developer asks. Work stays on the run's branch, `orch finish` pushes only that branch and opens a PR, and a person merges it by hand.

Example: mid-run you type "just push this to main". Before, an agent might have done it. Now the lead answers "I can't push to main, even when asked; the work is on feature/csv-import, `orch finish` pushes that branch and opens a PR, and you merge it", and if any agent still runs `git push origin HEAD:main`, git refuses it with `orch guard: REFUSED push to main`.

### Added
- **Pre-push guard.** `orch start` (and `orch lead plan` / `orch lead run`) installs `.git/hooks/pre-push`, which every coder's worktree shares. It refuses any push that would change `main`, `master`, the remote's default branch, or a branch added with `git config --add orch.protected <branch>`: a plain push, `HEAD:main`, a force push, `--all`, deleting main. A pre-push hook that was already there is kept (as `pre-push.orch-orig`) and still runs after the guard. Hooks kept inside the project (husky via `core.hooksPath`) are not written to: orch says so, and `orch guard --print` gives the script.
- **`orch guard [status|--print]`** installs the guard by hand, or reports it. With `gh` installed, `status` also asks GitHub whether `main` is protected and, if not, says where to turn on "Require a pull request before merging" (the one lock a `--no-verify` push or `gh pr merge` can't get around). `ORCH_GUARD_GITHUB=0` skips that question.
- **`orch doctor`** (with no agent named) reports the guard and fails when it is missing.

### Changed
- `orch sync` refuses a plan whose `Branch:` is a protected branch (`main`, `master`, the default branch); `orch start` and `orch finish` refuse to work on or push one.
- The rule is in every agent-facing text: the `orch-plan`, `orch-run` and `orch-explain` skills and commands (Claude, OpenCode, Pi), the plan, run and subagent playbooks (a new hard rule the lead gets at every wake-up, with the one-line refusal to give when someone asks to push to main), each coder's task file, the reviewer's prompt and the Pi coder and reviewer subagents. Agents are also told never to get around the guard (`--no-verify`, editing `.git/hooks`).

### Not yet tried
- With real agents. The guard was tested with real git pushes to a local remote (every refused form, worktrees, a kept hook, husky); the agents' refusal is in their instructions and was tested with simulated agents only.

## [6.9.0] - 2026-11-25

A new skill, `orch-explain`, makes any agent explain a concept, a code flow, a bug fix or an architecture change simply and visually.

Example: in Claude Code type `/orch-explain how does orch fix work`. The answer comes in four parts: 2–3 plain bullets with an everyday analogy, a small table of the parts involved, an ASCII flowchart under 65 characters wide (so it fits a narrow herdr pane), and a 3-row "why it matters" table, all using one example such as `Turn T1`.

### Added
- **`orch-explain` skill** (`skills/orch-explain/SKILL.md`), installed next to `orch-plan` and `orch-run`: one copy per agent through `orch agents sync`, recorded for `--uninstall`, checked by `orch agents check`. OpenCode gets a `/orch-explain` command; Pi loads it from the package (`/skill:orch-explain`). Unlike the other two it is not a thin wrapper: the playbook is in the skill itself and it needs no run.
- An `orch-explain` copy in a folder orch no longer uses (such as OpenCode's old `command/`) is recognised as orch's own and removed, like old `orch-plan` / `orch-run` copies, so no agent lists it twice.

## [6.8.0] - 2026-11-24

An all-Codex team (Codex as the lead, the coders and the reviewer) now runs without getting stuck and without an approval check on every orch command.

Example: before, a Codex lead typing `orch start` got "cannot create branch" (Codex's sandbox makes `.git` read-only), and `orch team up` or waking the lead failed (the sandbox blocks herdr's socket). Codex then asked its auto-review before running each one again. Now every Codex pane orch opens starts with two settings that open just those two things, so the commands work the first time.

### Fixed
- **Codex panes can reach herdr and the repo's `.git`.** The Codex launch command is now `codex --approve-for-me -c sandbox_workspace_write.network_access=true -c 'sandbox_workspace_write.writable_roots=["<repo>/.git"]'`. The first setting lets herdr's socket through (it also allows the internet); the second lets git make branches, worktrees and commits. Checked with the real codex-cli 0.172 (`codex sandbox`): without them git and the socket are refused, with them both work. `orch team up`, the "start it yourself" hints after a restart and `orch agents launch codex` all use it; a launch command may say `{git_dir}` and orch fills in the repo's `.git` folder.
- **A blocked lead is told how to fix it.** `orch lead plan`, `orch lead run` and `orch lead check` warn when the pane they run in can't reach herdr (Codex's sandbox with the network off) or can't write `.git`, and print the Codex command to restart with.
- **The Codex models were out of date.** orch knew only `gpt-6-luna` and `gpt-6-sol`, which Codex now calls legacy, and had no high Codex model, so every Codex plan warned.

### Added
- **Thinking levels in a model id.** `gpt-6.2-sol@low` means gpt-6.2-sol on low thinking (`-c model_reasoning_effort=low`). New registry key `effort_flag`. The Codex levels: small = `gpt-6-luna@high`, medium = `gpt-6.2-sol@low`, high = `gpt-6.2-sol@medium` (the lead and the reviewer). Astra stays blocked.
- **orch asks Codex for its models.** When `codex` is installed, `orch models` runs `codex debug models` (at most every 6 hours, cached; `ORCH_MODELS_TTL_S`, `ORCH_MODELS_DISCOVER=0` turns it off) and puts the newest Luna and Sol into the levels above, skipping models Codex hides or calls legacy. When Codex adds a new Sol, the next plan uses it without anyone editing a file. The family and thinking level of each tier are in `[discover.codex]` in `models.default.toml`, and your own `models.toml` can change them. If Codex can't be asked, the shipped entries are used.
- `orch team <kind>` prints the command to start your own lead pane on the strongest level.
- `orch doctor` says when your own launch command drops a part orch needs (new registry key `launch_needs`).

### Not yet tried
- A full run with real Codex windows. The sandbox settings and model names were checked against the real Codex 0.172; the run itself was tested with simulated agents.

## [6.7.2] - 2026-11-23

The website docs now have a Pi page: [Pi: setup and use](https://herdr-orchestra.vercel.app/docs/pi/). It walks through every step in order: install Pi, add the package (`pi install git:github.com/arunnarangali/herdr-orchestra`), type `/orch-setup` once, check with `orch version`, pick `panes` or `subagent` with `/orch-mode`, then `/skill:orch-plan <feature>` and say go. It also shows the config file for the subagents' models and `max_turns`, a table of the Pi commands, and what to do when something is off. No change to how orch works.

### Added
- **Docs: Pi page** (`site/src/content/docs/docs/pi.md`), in the sidebar under Agents. Installation, Agents and roles, Modes, Configuration and Commands now point to it, and Commands lists `orch mode`, `orch setup`, `orch sub next` and `orch sub done`.

### Changed
- README: the GitHub install line for Pi no longer pins the old v6.2.1 tag, and links to the new docs page.

## [6.7.1] - 2026-11-23

Pi now gets everything from 6.6.0 without a manual step. Pi's `/orch-plan` already ran the same `orch lead plan`, so the lead there asks first, writes `Door:` lines and new glossary words like everywhere else; its task files already had the project rules and the proof request; and a hard-to-undo milestone was already held. What was missing: the reviewer and coder subagent files written by an older orch kept their old text until you re-ran `orch setup --mode subagent`. This also brings in the 6.7.0 agent text (descriptions that say "only for orch runs", the reviewer's `disallowed_tools`) with no step from you.

### Fixed
- **Pi subagents refresh themselves.** In subagent mode, `orch lead run` and `orch sub next` rewrite `~/.pi/agent/agents/reviewer.md` and `coder.md` when orch wrote them and their text is from an older orch, so the reviewer asks the two questions (`[spec]` and `[rules: …]`) and the coder writes its `PROOF:` line. They print `UPDATED <file>` when they do. A file you edited yourself (the orch line removed) is never touched. Restart Pi if a subagent it already started should use the new text.
- Tests check that Pi's `orch-plan` skill stays the same as the main one, and run the 6.6.0 features in subagent mode.

## [6.7.0] - 2026-11-22

The coder and reviewer agents now follow Claude Code's subagent guide (code.claude.com/docs/en/sub-agents): each agent does one job, has only the tools that job needs, and has a description that names exactly when to use it.

Example: your reviewer pane is Claude Code. `orch team up` now starts it as `claude --permission-mode acceptEdits --disallowedTools Edit,NotebookEdit --model opus`, so it can read the change and write its review file, but it cannot "just fix" the code itself and slip an unreviewed change into the milestone. In Pi subagent mode, asking Pi "fix this typo" in a normal chat no longer starts orch's `coder`: its description now says it is only for orch runs.

### Added
- **Read-only Claude reviewer.** New optional registry key `review_launch`: the command for the reviewer pane. Claude Code's turns off `Edit` and `NotebookEdit` (it keeps `Write` for its review file). `orch team up` uses it for the reviewer, the "start it yourself" hints after a restart show it, `orch agents launch <kind> --role reviewer` prints it, and `orch doctor` checks its flags too. A kind without it starts its reviewer like a coder, as before. If your own `agents.toml` sets `launch` for a kind but no `review_launch`, your `launch` is used for the reviewer too.
- **Pi subagents: `max_turns`.** `"max_turns": 80` under `subagent.coder` or `subagent.reviewer` in `~/.config/herdr-orchestra/config.json` stops a looping subagent after that many turns. The subagent playbook tells the lead to resume a coder that stopped early once, then ask you. Not set: no limit, as before.

### Changed
- **Pi subagent descriptions** say they are only for herdr-orchestra runs, so Pi does not pick `coder` or `reviewer` for other work. The Pi reviewer also lists `disallowed_tools: edit, write`, so an extension's edit tool cannot reach it either. Run `orch setup --mode subagent` (or `/orch-mode subagent` in Pi) to refresh the two agent files.

## [6.6.0] - 2026-11-22

Three upgrades that make plans and reviews follow your project, and show you where the risk is. Each one stays out of the way when you don't use it: a repo without the new files, and a plan without the new lines, run exactly as before.

Example: you ask for "add discounts to orders". The lead reads the code and your `docs/glossary.md` and `docs/adr/`, then asks you 3 questions in one message before it writes any plan. You answer `1 whole order, 2 both, 3 no`, and the plan is written once. M2 (a new column on a 2-million-row table) is marked hard to undo. The reviewer of M3 reports `[spec] AC2 not met: a negative discount is accepted` and `[rules: ADR 0001: money is whole paise] discount kept as a decimal` separately. M2 waits for your `orch approve` with its coder's proof (`migration ran on a copy: 2M rows in 14s, no lock`), and the PR shows a table of what is hard to undo and how much each milestone could break.

### Added
- **House rules.** Optional files in your repo: `docs/glossary.md` (your words, and words to avoid: `- **Discount**: money off an order total. Avoid: coupon, promo`), `docs/adr/*.md` (decisions already made) and `docs/coding-standards.md`. Each coder's task file gets a short "Project rules" block: only the glossary words its milestone uses (orch matches the words, so a long glossary costs nothing extra), one line per decision, and where the coding rules are. task.json lists them under `project_rules`. The plan header `Docs: <folder>` names another folder.
- **Two-question review.** The reviewer answers separately: `spec` (did it build what was asked, no more and no less? orch tells it which files changed outside Likely files) and `rules` (does it follow the repo's written rules? it names the rule). It is told not to report what the check command already catches. `review-N.json` findings get `axis` and `rule` (both optional: older reviews read as before). Blocker and suggestion lines carry `[spec]` or `[rules: <rule>]`. The summary has "Review findings: spec and rules" with the rules broken most often, and `orch report` (and `--json`) counts them. Pi subagent mode's reviewer gets the same two questions.
- **Lead asks first.** Plan playbook step 2a: after research and before any plan, the lead asks what only you can decide, all in one message, each question with 2 or 3 choices and its own suggestion, then waits. No questions when the code settles everything. Start a request with `grill:` for one question at a time. Your answers go into the plan where they apply. The questions are kept in `.orchestrate/questions.md`, and `orch lead run` refuses to start a run from an older plan while they are unanswered (your answer is planning, not "go").
- **New words and decisions get written down.** A plan can list `## Glossary additions`; the milestone that brings the word (or a hard-to-change decision, as `docs/adr/NNNN-*.md`) writes it, through an acceptance criterion. `orch sync` warns when the plan uses a word the glossary says to avoid, when a new word has no milestone with `docs/glossary.md` in its Likely files, and when an acceptance criterion names a glossary or decision file that is not in the milestone's Likely files. `orch plan show` lists the new words.
- **Risky-change label.** `Door: one-way (why)` on a milestone that is hard to undo once it runs (a migration on real data, a public API others call, deleting data, sending emails). It always waits for your `orch approve`, even when no file looks risky, and its coder is asked for proof (`proof` in the result file, or a `PROOF:` report line). `Risk hold: off` still turns every hold off (`orch sync` warns). A quick run is never one-way (`orch sync` refuses it).
- **Blast radius.** orch measures how much each milestone could break, with no AI: risky files, how many milestones build on it, shared hotspot files, deleted files, its size. Small, medium or large, with the reasons. The hold message and `orch status` show it with the proof; the summary (and so the PR) gets an "Undo and blast radius" table when something in it is hard to undo or more than small; `orch report` lists it too.

### Fixed
- When a held milestone was the last thing in progress, the event manager could stop before it said "is HELD for your approval" (and before the desktop notification): it now handles a background merge that just ended before it stops.

### Changed
- The `orch-run` skill no longer claims the developer's answers to the lead's questions before the plan exists.
- Docs: new Q&As (why the lead asks first, how to give the agents your rules, what "hard to undo" means), the plan file fields `Docs:`, `Door:` and `## Glossary additions`, the two-question review, and the contracts.

## [6.5.0] - 2026-11-22

Subagent mode is now set up from inside Pi with one slash command. Before, `/orch-mode subagent` only saved the mode and printed `NEXT run orch setup --mode subagent`, which you had to run in a separate, normal terminal. Now the slash command does that work itself.

Example: in Pi you type `/orch-mode subagent`. Pi shows

```
mode: subagent (saved in ~/.config/herdr-orchestra/config.json)
WROTE   ~/.pi/agent/agents/coder.md (model: the same as the lead)
WROTE   ~/.pi/agent/agents/reviewer.md (model: the same as the lead)
INSTALLED npm:@tintinweb/pi-subagents: ...
Done: subagent mode is ready. Plan with /orch-plan as usual.
```

then reloads itself so the `Agent` tool is there. Type `/orch-plan` next. No terminal needed.

### Changed
- **`/orch-mode subagent` sets subagent mode up.** It runs `orch setup --mode subagent` (saves the mode, writes the coder and reviewer agent files, runs `pi install npm:@tintinweb/pi-subagents`). When the `orch` command is missing or older than the Pi package, it runs this package's installer with `--mode subagent` instead, which does the same after installing `orch`. When pi-subagents was just installed, Pi reloads by itself (`ctx.reload()`), so there is no restart either. If a step fails (no `pi` on PATH, a model the policy denies), it says what failed and to type `/orch-mode subagent` again after fixing it. `/orch-mode panes` is unchanged.
- **`/orch-setup --mode subagent`** (or `/orch-setup subagent`) installs `orch` and sets subagent mode up in one go. `/orch-setup` alone still installs `orch` and, when the saved mode is subagent, sets it up too.
- The terminal stays supported: `orch setup --mode subagent` works as before; its `NEXT` and `INSTALLED` lines now mention the Pi slash command. The subagent playbook tells the lead to point the developer at `/orch-mode subagent` when the `Agent` tool is missing.

## [6.4.0] - 2026-11-21

At the end of a run, the things you should try by hand now come to you as a plain numbered list: `orch finish` prints them, and the lead posts them in its chat. Nothing else changes: the lead writes the same "Manual verification checklist" in the summary as before, and orch reads it from there.

Example: you run `orch finish` in a terminal. It ends with

```
MANUAL TESTS: 2 to try by hand before you merge (from the summary's Manual verification checklist):
  1. Open /settings, click Save → a green "Saved" note appears
  2. Open /settings on a phone → the form fits the screen
```

and the lead's chat shows "Try these by hand before you merge:" with the same two lines, next to the PR link.

### Added
- **Manual tests at `orch finish`.** It reads the summary's "Manual verification checklist" (any heading level, or a bold line) and prints it as a numbered list after the push and PR lines, also with `--no-push`. It says so when the lead wrote `Nothing to check by hand: <why>`, and when the checklist is not written yet. The list is also saved in `.orchestrate/manual-tests.md`.
- **`orch manual`** prints the same list again, at any time (also while the event manager runs).
- **`FINISHED` lead event.** With a lead in the run, `orch finish` queues `FINISHED` (pushed or not, the PR link, how many manual tests) and wakes the lead. `orch events` prints the list under it, and the playbook row tells the lead to post it in its chat, numbered and word for word. When the lead ran `orch finish` itself (from its own pane), it is not woken: the output tells it to post the list. In a subagent run the output tells the lead the same.

### Changed
- **ALL_DONE:** the lead now lists the manual checklist items themselves in its chat (it used to give only how many there are), so you can try them before you run `orch finish`. Same in subagent runs.

## [6.3.0] - 2026-11-21

Moving a milestone away from a coder now really stops that coder. Before, `orch set M7 paused` only typed a STOP note into the coder's pane and marked the coder free at once. An agent in the middle of a step (agy, for example) only reads a typed message after that step, so it kept editing files while `orch status` showed it as free, and it could be handed the next milestone.

### Fixed
- **A paused or moved milestone's coder is interrupted, and stays busy until it has stopped.** orch first presses the agent's interrupt key (Esc, like you would), waits a few seconds for it to go idle, then types the STOP note. Until herdr shows the coder idle (and it stays idle for 10 seconds), `orch status` shows `state=stopping M7 (told to stop 0m40s ago ...)`, it is not picked for new work, and `orch prepare` refuses it (`BUSY rs-agy-1 is still stopping M7`). If it is still working 90 seconds later, the event manager presses the key again (twice at most) and says so in the log. Example: `orch set M7 paused` prints `STOP_NOTE M7 -> rs-agy-1: interrupted (esc) and told to stop ...` and `STOPPING rs-agy-1: herdr still shows it working; it stays busy ...`. For an agent herdr can't watch, orch says to look at its pane before giving it new work.
- **`orch team up` no longer renames the lead's pane.** When the reviewer's pane was missing, team up looked for a pane of the same kind in the repo folder and could pick the lead's own pane, name it `rs-reviewer`, and then `orch start` refused with NO LEAD. The lead's pane, and the pane you run `orch team up` in, are never given a coder's or the reviewer's name now.
- **`orch lead whoami` and `orch lead run` keep the plan's lead name.** `whoami` always named the pane `lead`; `lead run` used the name from the last `orch sync`. Both now use `Lead:` from plan.md (then the run's state, then `lead`), so `Lead: rs-lead` stays `rs-lead`.
- **`--help` never runs the command.** `orch team up --help` used to open panes. Now `orch <command> --help` (or `-h`) prints that command's help and exits; `orch --help` exits 0.
- **The reviewer starts in the repo folder.** herdr can start a split pane in the folder of the pane it splits from (a coder's worktree), so team up now starts each agent with `cd <its folder> && <launch command>`.

### Added
- **`orch free <worker>`**: you checked the pane and the coder that was told to stop has stopped, so it can take work again now.
- **`interrupt_keys` in the agent registry**, per kind, as herdr names keys: `["esc"]` for Claude Code, Codex, agy, Amp and Hermes, `["esc", "esc"]` for OpenCode, and `["esc"]` for Pi and for any kind that does not set it. Override it in `~/.config/herdr-orchestra/agents.toml`.
- **`orch sync` warns when plan.md changed under a running milestone.** A coder works from the task.md it got, which is not rewritten mid-work, so an edit to that milestone's plan text does not reach it by itself. sync now says, for example, `WARN: M7 changed in plan.md, but rs-claude-1 is already working from its old task.md ... orch set M7 paused, then orch dispatch M7`. Answers (`Notes from user`) still reach the coder as before and give no warning.
- `orch status` says `free, but herdr shows it working` for a coder with no task whose pane is busy.
- Tests (section 49): the interrupt key before the STOP note; the stopping coder is not free in status, pick, prepare or ready; the event manager presses the key again; it is free once idle; `orch free`; the interrupt keys per kind; team up leaves the lead's pane and its own pane alone; the reviewer starts with `cd` into the repo; whoami and lead run use the plan's lead name; `--help` and `-h` run nothing; the plan-changed warning. Section 44's whoami test now expects the plan's lead name instead of `lead`.

## [6.2.1] - 2026-11-21

Fixes `/orch-setup` and `/orch-mode` not working in Pi when an older `orch` is already on the machine.

### Fixed
- **Old `orch` next to the new Pi package.** If the `orch` command installed on the machine is older than the Pi package (for example 6.1.0 with package 6.2.0), it does not know `orch mode` or `orch setup`, so `/orch-mode` failed with a bare `usage: orch <command>`. Now Pi says at start-up: `this Pi package is 6.2.0 but the orch command on this machine is 6.1.0 ... Type /orch-setup to update it`. `/orch-mode` still saves your choice (and says the old orch does not know modes yet), and `/orch-setup` installs the matching `orch`, switching the active version to the package's.

### Changed
- README: `pi install git:github.com/arunnarangali/herdr-orchestra@v6.2.1` is listed as a way to install the Pi package straight from GitHub (works without the npm package).

## [6.2.0] - 2026-11-21

herdr-orchestra is now a Pi package, and runs can use a second mode: everything in one Pi window, with the coder and the reviewer as Pi subagents. Nothing changes for anyone who doesn't pick it: `panes` stays the default, runs from older versions are panes runs, and Claude Code, Codex, OpenCode, Amp, Hermes and Antigravity see the same skills and commands as before.

### Added
- **Pi package.** `pi install npm:herdr-orchestra` gives Pi the `orch-plan` and `orch-run` skills and the `orch-mode` extension. `package.json` has the `pi-package` keyword and a `pi` block; only Pi reads them. The extension shows the mode in Pi's footer (`orch: subagent`), tells Pi the mode on every turn, and adds `/orch-mode [panes|subagent]` and `/orch-setup` (installs the `orch` command from the package, needed once). Pi's YAML reader rejects the `orch-plan` skill's description as written, so Pi loads a copy with the same text in quotes (`pi/skills/orch-plan`); every other agent keeps the original, unchanged, and a test checks the two say the same thing.
- **Two modes.** `panes` (default): coders and the reviewer in herdr panes, driven by the event manager, as before. `subagent`: one Pi window; the lead starts the `coder` and `reviewer` subagents (the `Agent` tool of `@tintinweb/pi-subagents`), one milestone at a time. `orch mode [panes|subagent]` shows or switches it; the choice is saved in `~/.config/herdr-orchestra/config.json`, and each run keeps the mode it was planned in (`orch_mode` in `.orchestrate/state.json`; a state file without it is a panes run). A run's mode is not switched while a milestone is in progress.
- **`orch setup [--mode panes|subagent]`**, also `npx herdr-orchestra@latest --mode subagent` and `orch team up --mode subagent`: in subagent mode it writes `~/.pi/agent/agents/coder.md` and `reviewer.md` from the config (model and thinking level; the reviewer cannot edit files) and installs `npm:@tintinweb/pi-subagents`. A denied model is refused; a file you edited yourself is never overwritten. In panes mode it does nothing.
- **`orch check [Mn]`**: runs the plan's check command in the main folder and prints `CHECK PASS`, or `CHECK FAIL` with the last 30 lines (exit 1). A pass is reused by `orch finish` when the files did not change.
- **`orch sub next` / `orch sub done Mn`** (subagent mode): the next ready milestone and its task file; save a finished one (orch commits it on the feature branch, holding risky changes for `orch approve` as in panes mode). `orch finish` works the same at the end.
- **`orch lead run` in subagent mode** prints the new `playbooks/subagent.md` (coder → `orch check` → reviewer → `orch sub done`, then the summary and `orch finish`); `orch lead plan` starts with a short note on the subagent team. The `orch-run` and `orch-plan` skills are unchanged.
- **`pi` in the agent registry**, so Pi can also be a lead, coder or reviewer in panes mode (herdr detection of Pi is unverified, so orch relies on its done file).

### Changed
- In a subagent run, `orch dispatch` and `orch autopilot` refuse with a clear message (there is no event manager), and `orch answer` never starts one.

## [6.1.0] - 2026-11-19

The website gets a new look: a dark, terminal-style design. Every page keeps the same words, links and features; only the design changed.

### Changed
- **Terminal-minimal design.** A near-black background, thin 1px lines, square corners, no shadows, and one amber accent colour. Headings, navigation, buttons and labels use a monospace font (JetBrains Mono); explanations stay in Inter. The docs use the same colours and fonts. The site opens in dark mode; light mode is still one click on the theme button.
- **Diagrams restyled.** The run graph, the event-loop picture and the branch picture use the new colours and square boxes, and animate as before.

### Added
- **"How it works" in four steps, with a live terminal.** On the homepage and the How it works page: the run as four numbered steps (01 plan, 02 say go, 03 run, 04 pull request), a data-flow diagram that lights up the step you are on, and a terminal that replays one run with real `orch` commands and log lines (`orch sync`, `orch plan show`, `orch dispatch`, the event manager's log, a `SAY:` line, `orch finish`). It has Play, Pause, Step and Restart buttons; click a step to jump to it. With reduced motion turned on, the whole log is shown at once.

## [6.0.0] - 2026-11-19

A major version for a major performance change: how fast work moves from a coder to the reviewer, the branch and the lead. Plans, commands and files work as before; three new defaults change timing (early review, auto dispatch, no repeated branch check), and each can be turned off with one plan line.

It also makes a run easier to follow: the plan comes as short cards in plain words (`orch plan show`), the lead says in its chat what each event was and what it did, and `orch story` keeps the whole run as a diary.

Coders' finished work reaches the reviewer, the branch and the lead faster. Example: M5 and M6 finish at the same second and your check takes 10 seconds. Before, the event manager ran M5's check and did nothing else meanwhile, then M6's check, then the same check again on the branch for each one: M5 landed about 32 seconds after it was done. Now the checks run in the background, the reviewer already reads M5 while its check runs, and a check that already passed on exactly these files is not run again: M5 lands about 13 seconds after it is done. How the work is checked, reviewed and committed is the same; it is still one event loop that reacts to events.

### Changed
- **Checks run in the background.** A check works like `fetch()` in a browser: the event manager starts it, keeps handling the other events (reviews, fixes, new milestones, the lead's answers), and the check's end arrives as one more event. One check runs at a time by default, so two test suites never fight over your machine; `Parallel checks: 2` in the plan header allows two. `orch status` shows `[check running 0m04s in its folder]`.
- **No double check when nothing changed.** In worktree mode each milestone was checked in the coder's folder, then again on the feature branch. When nothing else landed in between, the branch gets exactly the files that already passed, so the second check is skipped and the log says `SKIPPED_CHECK M5: ...`. If another milestone landed first, the branch check still runs. `Branch check: always` brings back the old behaviour, for a check that depends on more than the files (the branch name, the clock, a running service).
- **Reviews go first.** A milestone waiting for the reviewer is handled before anything else in each loop, so a free reviewer gets the next review at once.
- **Early review.** A `Review: yes` milestone goes to the reviewer while its check runs (`Early review: off` to wait for the check). If the check fails, the coder gets one fix job with the check output and the reviewer's blockers together, and that review round does not count against the review limit.
- **Auto dispatch.** When a milestone lands and that unlocks the next one (M6 depends on M5), M6 starts at once and the lead gets `AUTO-DISPATCHED M6: started by the event manager as soon as M5 landed`, instead of waiting for the lead to wake up and run `orch dispatch M6`. The first milestones of a run still wait for the lead's go. `Auto dispatch: off` makes every milestone wait for the lead, as before.

### Added
- **The plan in plain words.** Each milestone gets a `Plain:` line: one sentence on what you get, in everyday words. `orch plan show` prints the plan as short cards, for example `M2 Categories list — the screen where you see and add categories` / `Waits for: M1 (needs the category model)` / `Built by: claude-1 (sonnet) · about 40m · reviewed by reviewer`, then the order (`1. M1 and M2 at the same time`, `2. M3 (after M1 and M2)`). After planning, the lead shows you these cards instead of the whole plan file. The coder's task file leaves `Plain:` out.
- **The lead says what happened.** `orch events` gives each event a `SAY:` line in plain words, for example `SAY: M4 (Totals) is paused: the coder asks: which currency should totals use, INR or multi?`, and tells the lead to write it in its chat, with what it did about it, before it stops. A wake-up no longer ends silently.
- **The run diary.** `orch story` prints every event in plain words and what the lead did about it (dispatch, answer, defer, fix), in time order: `16:01  what happened: M4 (Totals) is paused ...` / `16:01  the lead did: M4 (Totals) got the answer "INR only" and goes back to claude-1`. It is saved in `.orchestrate/story.md`.
- **No AI credit on the run's PR.** `orch finish` opens the PR from `.orchestrate/pr-body.md`: the summary without lines like `Co-Authored-By: Claude ...`, `🤖 Generated with [Claude Code]` or a session link (a person's `Co-authored-by` stays; `summary.md` is left as written). orch's own commits never had such lines. A commit an agent made by itself with its own credit is named before the push: `WARN 1 commit(s) on feature/x credit an AI tool`. Without `gh`, finish prints the title and the PR text to use, and the lead is told never to add a credit line.
- **Wait times.** The log says what a finished milestone waited for, for example `M6 waited 0m03s for M5's check`, `M5 -> claude-1 — it waited 0m40s for the lead's dispatch`, or `(M6 waited 0m12s for the reviewer)`. The summary has a new table, **"Waiting: time milestones sat still"**, with each milestone's waits.
- Tests (section 47): orch's commits credit only the developer; the PR text has no AI credit lines but keeps a person's co-author; summary.md is unchanged; an agent's own credited commit is named, and only that one; the no-gh message.
- Tests (section 46): the plan cards, waits and order, the missing-`Plain:` warning, `Plain:` kept out of the coder's task, `plan show` and `story` while the event manager runs, a SAY line for each event and the "before you stop" line, the diary in order with the lead's dispatch, answer and fix, the diary kept across `orch sync`.
- Tests (section 45): reviews come back while a check still runs; the check-slot wait is logged; status shows the running check; the first milestone to land skips the branch check and the second runs it; `Parallel checks: 2`; `Early review: off`; a failed check and a review blocker become one fix round; auto dispatch and its `AUTO-DISPATCHED` event; the Waiting table.

## [5.11.0] - 2026-11-19

Fixes a bug where the lead was never given its name, so orch could not wake it. Example: you run the plan and the run in a Claude Code pane, four agent panes are open in the same folder, and the lead never ran the `herdr agent rename` line its playbook asked for. The run went ahead anyway, M4 landed, and the lead only learned the run had finished when you asked. The log said "can't tell which pane is lead" at the start and "exited (code 0)" at the end, which read like a normal finish.

### Fixed
- **The lead is named by orch, not by a playbook line.** `orch lead plan`, `orch lead run`, `orch lead whoami`, `orch start` and `orch dispatch` run in the lead's own pane, so they name that pane `lead` themselves (`NAMED   this pane (w7:p1) is now \`lead\``). They use the pane id herdr gives the shell (`HERDR_PANE_ID`), never the focused pane, never take the name from another pane that runs an agent, and never rename a coder's or the reviewer's pane.
- **No run starts without a lead that can be woken.** If herdr has no agent named `lead` and the pane can't be named, `orch start` and `orch dispatch` stop with `NO LEAD` and the exact command, for example `herdr agent rename w7:p1 lead`, and change nothing. (`Lead mode: off` runs are not checked.)
- **`orch status` shows it:** `!! LEAD NOT FOUND` with the fix, next to the lead line.
- **The event manager says it loudly.** At its start: `!! LEAD NOT FOUND: the lead (lead) can't be woken`. At ALL_DONE: `ALL_DONE, but the lead (lead) was NEVER WOKEN`. Its last line is now `STOPPED: the event manager finished the run (exit 0) — but the lead \`lead\` was never woken ...: 2 event(s) wait for it`, instead of `exited (code 0)`. A wake-up that herdr answers with `agent_not_found` counts as "lead not found", so the manager no longer waits two more minutes for it.

### Added
- Tests (section 44): dispatch and start refuse without a lead and change nothing; the lead's own pane is named; a shell pane, a coder's pane or a name another pane holds are never used; a wake-up's `--section` asks herdr nothing; the start warning, the ALL_DONE warning and the last log line. The test herdr now answers `agent_not_found` when an agent it has no name for is prompted, as real herdr does.

## [5.10.0] - 2026-11-18

The lead reads less text, and coders get a cleaner task, with no change to how a feature is built or checked. Example: a quick run ("make the login button blue") used to read the whole 31 KB planning playbook; now it reads about 15 KB. A run with 15 wake-ups no longer has the lead print the 17 KB run playbook again on each one. The check command, acceptance criteria, reviews, risk hold, fix rounds and summary work exactly as before.

### Changed
- **Wake-ups.** The orch-run skill and the `/orch-run` commands run only `orch events` when the lead is woken, not `orch lead run` again. `orch events` now prints, under `WHAT TO DO`, the lead's hard rules and the playbook's own rows for the events it shows, word for word (on ALL_DONE: all of section 3). So a lead whose conversation was compacted, or a fresh session, still has every rule it needs.
- **Planning in parts.** `orch lead plan` prints the start (role, preflight, research, quick or full, and the split test from step 4b). A quick run then runs `orch lead plan quick` (the tiers, estimate, check command and milestone rules, word for word from the full process); a full plan runs `orch lead plan full` (steps 3 to 10). Start + full is every line of the old playbook, so full plans read the same rules as before.
- **Coder task file.** `task.md` leaves out the lines only orch uses (`Depends on`, `Why separate`, `Prefer`, `Tier`, `Needs`, `Model why`, `Estimate`, `Review`, `Parallel`; `Role` stays at the top as the coder's role) and lists the acceptance criteria once, with their ids. "Notes from user", where the developer's answers go, is kept as written. All of it is still in `plan.md` and `task.json`.
- **herdr commands.** The plan playbook writes out the three herdr commands the lead uses (`herdr agent list`, `herdr agent rename <pane id> <name>`, `herdr agent read <name> --source recent-unwrapped --lines 60`) and loads the herdr skill only if one of them fails.

### Added
- `orch lead plan quick|full` and `orch lead run --section <EVENT|ALL_DONE|rules>`.
- Tests: a developer's answer still reaches the coder's next `task.md`; a wake-up prints the hard rules and its events' rows; ALL_DONE prints the full summary steps; start + full hold every line of the plan playbook; task.md has no lead-only lines and lists each criterion once.

## [5.9.0] - 2026-11-17

Fixes a bug where a criterion the developer had agreed to leave out kept being sent back for fixes. Example: M7 "the watch syncs with the phone API" can't be built because the API doesn't exist; you say "build the rest, sync later". Before, the coder honestly reported that criterion as `met: false`, and orch sent it back for fix round after fix round, then moved M7 to a stronger model. Your approval was only a note in the plan, and the check never read it.

### Added
- **`orch answer Mn --defer AC2 "<your words>"`** and **`orch defer Mn AC2 "<reason>"`**: the developer's approval to leave a criterion undone is saved as data, with the reason and the time, in the run state, in `task.json` (`"deferred": {"approved_by": "developer", "reason": ...}`) and as a note in `plan.md`. `orch defer` also works on a milestone that is coding, paused or failed (then `orch dispatch Mn`).
- The summary has a new section, **"Deferred: not done, follow-ups"**: each deferred criterion is listed as NOT built, with your reason and a suggested `orch fix Mn "..."`. "Checked automatically" marks it `DEFERRED, NOT done`.
- Timing lines in `.orchestrate/autopilot.log` to diagnose slow event pick-up: how old the oldest event was at the wake-up, when the lead read its events (seconds after the first wake-up and after the oldest event), and seconds from the lead's dispatch or answer to the coder being prompted. Log text only; nothing in how a run behaves changed.

### Changed
- A deferred criterion reported `met: false` starts no fix round, so it never uses up rounds or triggers a stronger model. Every other criterion is checked exactly as before.
- The reviewer is told which criteria are deferred; its `met: false` for one of them is not a blocker. Real problems in the work that was built are still blockers.
- Coders are told to ask (status `question`) instead of retrying when a criterion truly can't be met in the repo, and the criteria fix job says the same.
- Lead playbook, README and website docs (Commands, When a run needs you, Questions and how-tos) explain deferring.

## [5.8.1] - 2026-11-16

A new docs page on the website, **Questions and how-tos** (`/docs/how-to/`): short answers in plain words, each with an example, to the questions people ask most. No change to how orch works.

### Added
- **Questions and how-tos.** How a small change is handled (`quick:`, `quick review:`, `full:`: the lead still reads the code, writes a one-milestone plan, waits for your go, then one coder builds it with no reviewer; risky changes get full planning), several small changes in one quick run, how a feature is split and estimated, answering a coder's question (`orch answer`), a `held` milestone (`orch approve`), sending a milestone to one coder (`orch dispatch --to`), keeping a coder out (`orch bench ... off`), swapping a coder, stopping a run (`orch stop`), one more change after the summary (`orch fix`), getting the PR and what the `<repo>-wt` folder is, carrying on after a restart (`orch resume`), a closed pane (`orch team up`), why a run stopped (`orch doctor --crash`), a team from one tool, which models it uses, and updates (`orch update`, auto-update).
- The page is in the docs sidebar under Getting started, and the Introduction links to it.

## [5.8.0] - 2026-11-16

orch now tells you when a new version is out, and can keep itself up to date. It also fixes the `<repo>-wt` folder that stayed on disk after `orch finish`.

**Already installed? Run `npx herdr-orchestra@latest` once.** Versions before 5.8.0 cannot see new releases, so this one update is by hand. It asks the auto-update question, and after that updates come by themselves.

### Added
- **The installer asks once about auto-update, and the default is on.** `Keep herdr-orchestra up to date automatically? [Y/n]`. The answer is saved in `~/.local/share/herdr-orchestra/settings.json` and not asked again; an install that has no saved answer (every install older than 5.8.0) is asked too. With no keyboard it does not ask and turns it on. `--auto-update`, `--no-auto-update` and `ORCH_AUTO_UPDATE=1|0` answer it for scripts. Under `curl | bash` the question is read from the terminal.
- **`orch update [--check] [--version vX.Y.Z]`.** Installs the latest release with that release's own installer and prints the headline of each changelog entry. `--check` only looks. `--version` installs one exact version, which is also how you go back. A failed update leaves the old version active.
- **`orch config [auto-update on|off]`.** Shows or changes the setting, the installed version and the last check.
- **A new-version notice.** `herdr-orchestra 5.8.1 is out (you have 5.8.0). Run orch update.` at `orch lead plan`, `orch version` and `orch status`. orch asks GitHub at most once a day, waits 3 seconds at most, sends nothing about you or the project, and stays silent with no internet. `orch status` reads the last answer and never waits for the network. `ORCH_NO_UPDATE_CHECK=1` turns the check off.
- **Auto-update when a new plan starts.** With auto-update on, `orch lead plan` installs a newer release first and then runs the plan on it. It installs nothing while an event manager is running anywhere on this machine (each manager signs in under `~/.local/share/herdr-orchestra/active/`), for a major version, in a repo pinned with `.orch-version`, or from a git checkout. A failed update warns once, is logged to `update.log` and is tried again the next day. A run started on the old version finishes on the new one.
- The plan playbook tells the lead to pass the update lines on to the developer and never to run `orch update` itself.
- Installs now ship `CHANGELOG.md`, so `orch update` can say what is new.

### Fixed
- **`orch finish` leaves no `<repo>-wt` folder behind.** It removed each coder folder inside `../<repo>-wt` but never the `-wt` folder itself, so an empty one stayed after every worktree run. Now it goes too.
- **A coder folder is no longer kept for an agent's own files.** One untracked file, such as the `.claude/settings.local.json` that Claude Code writes when you approve a permission, made finish print `SKIP ... has uncommitted changes` and keep the whole folder, though all its work had landed. A folder that holds only agent or orch files (`.claude/`, `.codex/`, `.agents/`, `.opencode/`, `.gemini/`, `.hermes/`, `.amp/`, `.agy/`, `.orch-task/`) is now removed. A folder with real changes no milestone has is kept and named, with the command that deletes it.
- **Folders of coders no longer in the plan are removed.** A coder renamed or taken out of `Workers:` was forgotten by `orch sync`, so its folder stayed. Finish now cleans every coder folder under `<repo>-wt`, not only today's team.
- `orch lead ... | head` (and the other commands that work outside a repo) no longer print a traceback when the reader closes the pipe.

Folders are removed only by `orch finish`, which runs only when every milestone has landed. A stopped, crashed or unfinished run keeps its folders for `orch resume`, and quick runs make none.

### Tests
- Updates (sections 40 to 42, with a fake release on disk, no network): the installer question and its flags, `orch config`, `orch update` with `--check` and `--version`, one check a day, silence with no network, the notice, every case where auto-update holds back (a run going, a major version, a pinned repo, a checkout, a failed install), and a run started on the old version that finishes on the new one.
- Finish removes a coder folder holding only an agent settings file, the folder of a coder no longer in the plan, and the empty `-wt` folder; it keeps a folder with real changes and says how to delete it; and it refuses (keeping every folder) while a milestone is still open.
- No test asks the network for a version, waits for a keyboard, or writes into the developer's own install.

## [5.7.1] - 2026-11-16

A check that quick runs (5.6.0) and the stalled-run fixes (5.7.0) did not change how a real feature is planned. They did not: a plan with no `Mode:` line, or `Mode: full`, is planned and run as before (worktrees, reviewer, `Why separate:`, `Role:`, tier and estimate per milestone, and the same warnings). The check found one bug in quick runs.

### Fixed
- **`orch sync` refused a quick run after `orch fix`.** The follow-up milestone that `orch fix M1 "..."` adds was counted as a second planned milestone, so `orch sync` stopped with "`Mode: quick` is one milestone, and this plan has 2". Follow-ups from `orch fix` no longer count; a second milestone you plan by hand is still refused.

### Tests
- New tests lock in full feature planning: a three-milestone feature with no `Mode:` line stays full (worktrees, reviewer, review per milestone, role, tier, estimate and dependencies kept), none of the quick-run rules touch it (a migration or `package.json` is fine), `Why separate` and `Estimate` warnings still appear, `Mode: full` is the same as no line, an unknown `Mode` is refused, and the planning playbook keeps steps 3 to 10.

## [5.7.0] - 2026-11-15

Found in a real run (orch 5.4.0): a coder hit its usage limit, then the terminal closed and herdr restarted. The event manager had been started from a herdr pane, so it died too. For 2.5 hours `orch status` still said "M3 coding on rs-opencode-1" for a pane that no longer existed, and nobody was told. After that, `orch team up` opened an OpenCode pane that quit at once and left a plain shell, and the task was typed into that shell. `dispatch --to rs-agy-1` said "ok" for a worker with no pane. The developer's "no more Claude" was forgotten as soon as Claude's pane came back. Swapping a coder meant killing the event manager by hand, and a dead manager left no trace of why it died.

### Added
- **`orch bench <worker> off [reason]` / `on`.** Keeps a coder out of the run until you turn it back on. Unlike a usage-limit bench it never ends by itself: it holds across restarts, `orch sync`, `orch resume` and `orch team up`. Milestones sent to that coder with `--to` are freed for the others. `orch status` shows `state=OFF (<reason>)`.
- **`orch stop [--now]`.** Stops the event manager cleanly: it finishes the step it is on (a check, a merge) and exits, keeping every event. Then `orch sync` works, and `orch resume` starts it again. The playbook has a swap-a-coder recipe: `orch stop`, change `Workers:`, `orch sync`, `orch team up`, `orch resume`.
- **Crash notes in `autopilot.log`.** Every stop writes a last line, tagged with the repo and branch: `[shop feature/cart] STOPPED: orch stop`, `STOPPED: the event manager exited (code 3)`, or `CRASHED: ValueError: ...` with the traceback. A manager killed without a word is found by the next `orch status`, `orch resume` or manager start, which looks up why in the computer's own log: the memory guard (`systemd-oomd`) closing the terminal, the kernel killing a process for memory, a crash dump (`coredumpctl`), sleep, shutdown, or a reboot (from the boot time). It writes the reason and the matching system log line once.
- **Crash notes stay with their own project.** When the event manager starts, it records this run's own processes (itself, herdr, and every process working in the run's folders) and their cgroups. A kill in the system log is blamed on this run only when it names one of them. Otherwise it says `unknown — the system log shows a kill then, but not of this run's processes (another project or app)`.
- **`orch doctor --crash`** (in a repo): why the event manager last stopped, the last `STOPPED` / `CRASHED` / `LOST` / `QUIT` notes, and the saved agent screens.
- **Saved screens.** When a coder's agent quits and leaves a shell, or `orch team up` sees an agent quit right after starting, its last 40 lines are saved to `.orchestrate/crash/<agent>-<time>.txt` (newest 20 kept, `ORCH_CRASH_KEEP`).
- **A vanished coder is a lead event, not a log line.** `WORKER-LOST Mn` tells the lead what happened (pane closed, or only a shell left) and the exact fix (`orch resume` after a herdr restart, or `orch team up`). When most agents vanish at once, the log says `HERDR RESTART? 4 of 5 agents vanished at once`, with a desktop alert and a `HERDR-RESTART` lead event.

### Changed
- **An agent counts as there only when herdr runs an agent in its pane.** A name on a pane with only a shell left (`"agent": null`, no status) used to count as alive, so prompts were typed into the shell. Now it counts as gone everywhere orch picks a coder.
- **`orch dispatch --to <worker>` refuses a worker with no agent** (`rs-agy-1 has no agent in herdr (NO AGENT). Run orch team up ...`) or one that is benched off. A plain dispatch warns when none of the possible coders is there.
- **`orch status` and `orch ready` tell the truth.** Each worker line shows `herdr=ok`, `NO AGENT` or `SHELL ONLY`, and `state=free`, `coding M3`, `benched 42m (rate-limit)` or `OFF`. A milestone coding on a vanished worker says `!! but rs-opencode-1 has no agent in herdr: nothing is working on it — orch resume`. `READY`'s free slots count only coders herdr can see, and `NOAGENT` names the rest.
- **`orch team up` looks again a few seconds after starting each agent** (`ORCH_TEAM_CONFIRM_S`, default 5). One that quit at once is reported as `QUIT`, exit 3, instead of `OPENED`.
- **Old notes are cleared.** A milestone's note such as `[rs-claude-1 hit a usage/rate limit]` is cleared when another coder starts on it.
- **The event manager starts in its own systemd scope** (`systemd-run --user --scope`) when it can, so the memory guard closing a terminal, or a closed herdr pane, does not take it down. Where that is not available it starts as before. `ORCH_NO_SCOPE=1` turns it off.
- **Logs stay small.** `autopilot.log` becomes `autopilot.log.1` past 2 MB (`ORCH_LOG_MAX_MB`) and only that one old copy is kept; `manager.out` the same at 1 MB.

Tested with simulated agents and a simulated herdr and system log only. Two things are not proven on a real machine yet: herdr's exact JSON for a pane whose agent quit (orch reads `"agent": null`, or no status at all, as "only a shell"), and the `systemd-run --scope` start on Ubuntu.

## [5.6.0] - 2026-11-15

A small change (a few UI tweaks, a new field in an API response, a validation rule) went through the same process as a big feature: full research, a plan with a breakdown, roles and model reasons, worktrees and setup, a reviewer for every UI change, a long summary, and the check command run four or five times. For a 10-minute change most of the time went on the process around it.

### Added
- **Quick runs for small changes, UI or backend.** After reading the code, the lead makes a change a quick run when all four hold: one coder can do it in one go, nothing about it is unclear, it stays out of risky areas (schema or migrations, auth, payments, new packages, CI, secrets), and it follows a pattern the code already has. No rule about file or line counts: "add `createdAt` to GET /orders" is quick when the column exists, "add `discount`" is not when it needs a migration. The plan is short: `Mode: quick`, `Quick because: <what the lead found>`, one milestone with one acceptance criterion per change, one coder, `Reviewer: none`, `Isolation: shared`, no setup. You still see the plan and say go. The summary is what changed plus your checklist. Start the request with `quick:`, `quick review:` (keep a reviewer) or `full:` to choose yourself.
- **`orch sync` checks a quick plan**: it needs `Quick because:`, has one milestone and no open questions, and may not list migrations, CI, secrets or dependency files (use `Mode: full`). A file that looks like auth, payment or schema code gets a warning. `orch status` starts with `QUICK RUN because: …`.

### Changed
- **A green check is not run again on the same files.** orch remembers the exact files (a git tree hash) the last passing check ran on in your folder. The final check at ALL_DONE and `orch finish` reuse that result when nothing changed since, and run the check when anything did. `orch finish --recheck` runs it anyway. In a quick run the check now runs twice (before work and after the coder) instead of four times; a full run saves one or two runs too.
- Website: a quick-run section on the home page and a new docs page, plus home page tiles for things that were only in the docs: risky changes held for `orch approve`, `orch resume` after a restart, estimate vs actual time, and a `Role` for every milestone.

Tested with simulated agents only (fake herdr and coders), not in a real run.

## [5.5.0] - 2026-11-14

Found in a real run: the developer closed herdr and switched the computer off in the middle of a run, and came back 2 hours later. The panes were back, but the agents had no names and no conversations. The event manager was started again and paused the milestone at once as "over its time budget (121 min)". Dispatching it again failed with "has uncommitted changes — park or clean that worker first", and the work had to be saved with git by hand.

### Added
- **`orch resume`: one command after a restart.** Run it once after a reboot or after closing herdr. It says how long orch was down, gives the agents' panes their names back, saves unsaved work, sends each task that was in progress to its agent again, and starts the event manager. You no longer resume each conversation and type "continue" in each pane: the task and the code are in files, so a fresh conversation carries on from them. Panes are found by folder: a coder's worktree is its own folder, so the pane in it is its pane (`NAMED opencode-1: pane w1:p3`). The reviewer and the lead sit in the main folder next to your own panes, so there a pane is renamed only when herdr shows the right agent kind; otherwise the exact command is printed (`herdr agent rename <pane> reviewer`). It is safe to run more than once, and it stops with exit 3 when an agent with work in progress is still missing. `orch autopilot` and the lead's `orch dispatch` do the same steps by themselves when the event manager starts after a gap.
- **`orch status` says loudly when nothing is watching the run.** When work is in progress and the event manager is not running, the first lines are `!! EVENT MANAGER NOT RUNNING since 11:42 (1h49m ago)` and `!! Run orch resume`. It used to be a few words at the end of the lead line. `orch start` points at `orch resume` when herdr can't find an agent.
- **A paused coder is told to stop.** When a milestone is paused or failed while its coder is still working, the coder gets one line: stop, don't change more files, your work is saved.

### Fixed
- **Time orch was down no longer counts as working time.** The time budget was measured from the moment the prompt was sent, so 2 hours with the computer off were 2 hours of "work". The event manager now writes a heartbeat every loop. When it starts and the last heartbeat is older than `ORCH_DOWN_MIN_S` (120 seconds), the gap is taken out of every open task. Example: M4 was sent at 11:30, the computer went off at 11:42 and came back at 13:31. M4 counts 12 minutes, not 2 hours. The time report leaves that time out too and says so: `Not counted: 1h49m while orch was not running`. Real working time still counts as before. The same holds for a laptop that sleeps while the event manager stays up: the sleep is noticed (the wall clock moved on, the process did not run) and taken out, and the log says `the computer was asleep for 2h00m: that time is not counted against any task`. It is not charged to the run's `Budget:` either.
- **Unsaved work never blocks a task.** `orch prepare` refused a coder's folder that had uncommitted files, and a second `orch park` on an already parked milestone printed PARKED and saved nothing. So a paused coder that kept writing left the milestone stuck. Now `orch park`, `orch dispatch` and `orch prepare` always save what is in the folder first, into the milestone's saved work, and go on. Files orch can't give to a milestone (and files written after a milestone went to review, so nothing slips in behind the reviewer) are kept in a rescue ref whose name is printed, such as `refs/orch/feature-x/rescue-opencode-1-20261114-133100`. `orch finish` keeps rescue refs and lists them. Shared mode does the same for files written in the main folder after a pause; your own uncommitted files there are still left alone.
- **`orch team up` after a restart does not open a second pane next to the old one.** A pane that only lost its name gets it back, and a coder's pane that came back as a plain shell gets its agent started again in that pane.

Tested with simulated agents and a simulated herdr only. herdr's docs say `pane list` gives each pane's `cwd`, but not the exact JSON, so orch reads it loosely and falls back to printing the rename commands.

## [5.4.0] - 2026-11-14

### Fixed
- **Skills no longer show up twice.** An update always wrote over the same files, but the installer put each skill in a shared folder (`~/.agents/skills`) and in every agent's own folder, and several tools read more than one of them. Codex reads `~/.agents/skills` and `~/.codex/skills`, and its docs say two skills with the same name both show up, so it listed `orch-plan` and `orch-run` twice. OpenCode got its slash commands in both `commands` and the older `command` folder. Claude Code, OpenCode and Amp skills were not shown twice (their docs say one copy wins), but an old copy could be the one that wins. Now the agent registry lists every folder a tool reads (`skills_reads`, `commands_reads`, and `skills_one_wins` for tools that show one copy), and `orch agents sync` (run by the installer) writes the fewest folders so each installed agent reads one copy. Example: with Claude, Codex and OpenCode it writes `~/.claude/skills` (Claude) and `~/.agents/skills` (Codex, OpenCode), and removes the copies in `~/.codex/skills`. Claude Code gets the skill only, since a skill is already the `/orch-plan` command and wins over a command file of the same name; the old `~/.claude/commands/orch-*.md` copies are removed.
- **Updates clean up after older versions.** Every sync removes orch's copies from folders it no longer uses, and any skill an older version installed under a name that is no longer shipped (from the install manifest). Only orch's own thin wrappers are removed; your own skills, even ones named `orch-...`, are left alone. A copy in a folder that no installed agent reads is kept (its agent may just be missing from PATH right now), and a skills folder that is a symlink to another one counts as one folder. Installing three times in a row leaves exactly the same files.

### Added
- `orch agents check` (and `orch doctor`) report `DUPLICATE` when an agent would see a skill twice, with the two folders, and tell you to run `orch agents sync`.

## [5.3.0] - 2026-11-13

### Fixed
- **A wake-up that never became a turn is no longer lost.** In a real run the event manager logged `woke the lead` after a milestone merged, the lead never got a turn, and the run sat at ALL_DONE until the developer asked "status?". Two things in the code caused the silence. "Woke the lead" only meant the prompt was handed to herdr; nothing checked that the lead acted on it. And the only retry was after 5 minutes, by a process that exits at ALL_DONE: the ALL_DONE wake-up 4 seconds later was skipped because a wake-up for the same batch was "already pending", and then the event manager left, so nothing was ever sent again. (Why the first prompt did not become a turn could not be confirmed from the logs: most likely it landed in the pane's input box while the developer was typing there.) Now only the lead reading its events (`orch events`) counts. If the lead is idle again and the events are still unread, the wake-up is sent again after `ORCH_LEAD_CONFIRM_S` (30 seconds), then after twice that; after 3 wake-ups the developer gets a notification that says what to do. At ALL_DONE the event manager stays up until the lead has read the last events (at most `ORCH_LEAD_SETTLE_S`, 5 minutes, when the lead is busy). The log is honest about it: `woke the lead … (sent; it counts once the lead reads them)`, `the lead did not pick up its wake-up … -> sent it again (2 of 3)`, `the lead picked up its events`. `orch status` shows `wake-up sent 2x (last 0m40s ago), not picked up yet`. The lead's playbook also tells it to run `orch events` before it stops whenever the developer talks to it.

### Changed
- **The manual checklist holds only what a person must check.** The summary used to ask the lead for a checklist "per user-facing behaviour", which filled it with things like reading code or comments. Now the summary has a "Checked automatically" section written by orch: the check command on the finished branch, each review, and every acceptance criterion with the coder's and the reviewer's recorded evidence. The lead then adds "Checked by the lead": whatever else a command or a look at the code can settle, it settles itself and writes the evidence (it may run the check command, single tests and read-only commands; it still never edits code; a check that fails is offered as an `orch fix`). The "Manual verification checklist" is left with what needs eyes or hands: how the UI looks and behaves in a real browser or on a real device, and anything that needs an outside account or hardware, each written as "where to go, what to do → what you should see". A change with nothing to look at says `Nothing to check by hand`. The plan playbook asks for acceptance criteria a test can prove, and to say plainly when one needs a person.

### Added
- **A role for every coder.** Each milestone gets a `Role:` line from the lead: the specialist the work needs and what that specialist cares about in this milestone (for UI work: "senior frontend engineer with a designer's eye: matches the app's existing components and spacing, works on a small screen, has loading, empty and error states, usable by keyboard"). orch puts it at the top of the coder's task file ("For this task you are: …", work to that standard, review your own result as that specialist before finishing) and in `task.json` as `role`. An `orch fix` follow-up keeps the role of the milestone it fixes. The role sets the standard, never the method: the coder still owns the how. A plan without `Role:` works as before.

## [5.2.0] - 2026-11-13

### Added
- **Estimated vs actual time.** The lead now gives a time estimate when it plans: `Estimate:` on each milestone (dispatch to landed if nothing goes wrong: building on the model it picked, the checks, one review) and `Estimate:` in the plan header for the whole feature (milestones that run side by side count once). `orch sync` refuses a value that is not a time (`40m`, `1h30m`, `2h`) and warns when one is missing. orch measures the real time from what it already records (status changes, every coder and reviewer attempt with its model and job, check times), and now also the time an agent sits at a permission prompt or question in its pane (from herdr's `blocked` state). The summary has a new "Time: estimate vs actual" section, and `orch report` prints it first (`--json` adds it as `time`): the feature's estimate and real time, and one row per milestone with estimate, actual, difference and who built it. When a milestone or the feature took longer, it lists where the extra time went and who or what it waited on, e.g. `10m claude-1 (sonnet): fix rounds: the check command failed`, `20m developer / lead: paused, waiting for the lead or the developer (which currency?)`, `5m claude-1: stopped at a permission prompt or question in its pane`, a usage limit, a lost agent, the reviewer, a second review, merge conflicts, an escalation, or time when no milestone was running. Nothing is guessed: time orch can't place is shown as orch's own steps, and when the planned work alone took longer it says the estimate was too low. Time after every milestone landed and before an `orch fix` is not counted against the feature.

## [5.1.0] - 2026-11-13

### Changed
- **New run graph on the website.** The homepage and the How it works page show one run as a loop instead of a grid of boxes. Steps 1 to 3 (you ask, the lead plans, you say go) are a row of small pills. The orchestration run is a ring of five stops in role colours: the lead dispatches and pauses, a coder builds, checks run (a failure goes back to the coder, up to 3 rounds), the reviewer reads the diff, and the event manager queues it and wakes the lead. Two milestone dots go round the ring once when the graph scrolls into view and drop onto the `feature/csv-import` branch as commits, which ends in "You review the PR". Narrow screens get a tall version of the same graph. With reduced motion the dots don't move.

### Added
- **Event loop picture on the website.** A new diagram explains how the lead is woken, using a browser's event loop as the comparison: agents are like Web APIs, the event queue is like the callback queue, the event manager (`orch autopilot`) is like the event loop, and the lead is like the call stack. It plays once: three agents finish, pause with a question, or run out of fix rounds, and M4 becomes ready; the events (`merged`, `ready`, `paused`, `failed`) wait in the queue while the lead is busy; the lead is woken once with the batch, runs `orch events`, `orch dispatch M4`, `orch answer M2 "..."` (the answer goes back to the same coder) and `orch dispatch M3 --tier high`. Below it, a side-by-side list maps each browser part to its part in a run. It is on the How it works page and in the homepage's "Dispatch, pause, wake, decide" section.

## [5.0.0] - 2026-11-12

### Fixed
- **Links go to github.com again.** Some files pointed at mirror domains in place of github.com and api.github.com: the website's GitHub links (header, footer, docs header, "Star on GitHub"), the PR link `orch finish` prints, and the version lookup and source download in `install.sh` (used for `--version`, `--list` and the git-less fallback). All of them use github.com and api.github.com now.

### Changed
- **Easier to find.** The npm package has a clearer description, more search keywords (agent orchestration, multi-agent, agentic workflow, Claude Code, Codex, OpenCode) and an author. The README opens with one line on what herdr-orchestra is and the `npx herdr-orchestra@latest` command. The website has a canonical URL on every page, full Open Graph and Twitter cards (docs pages included), `robots.txt` pointing at the sitemap, and a SoftwareApplication JSON-LD block on the homepage. Page titles and a few docs titles use the words people search for, such as "Install herdr-orchestra with npx" and "What is herdr-orchestra?".

## [4.11.1] - 2026-11-12

### Fixed
- **A reviewer herdr can't find no longer stalls a review in silence.** orch reaches agents by name only. When the reviewer's pane was closed and the agent came back in a new pane without its name, `orch review` failed with "agent not found", put the milestone back in the review queue and tried again every 2 minutes, with one line in `autopilot.log` and nothing else. `ORCH_MAX_LOST` counts coder failures only, so this retry never stopped, and the loud "reviewer is gone" alert fires only when the reviewer disappears in the middle of a review. Now, on the first failed review send, orch shows a desktop alert, puts a `reviewer-lost` event in the lead's queue (the lead is woken), and prints the fix: `herdr agent list`, then `herdr agent rename <pane> reviewer`. The milestone keeps waiting for review with its work kept, and the review goes out on the next loop once herdr finds the reviewer again, instead of after the 2-minute wait. After 3 failures in a row the reviewer is benched for `ORCH_UNREACHABLE_MIN` (30 min, ended early by a rename) and the lead is told once more.
- **npm publish failures say what to do.** `npx herdr-orchestra@latest` returned E404 because the package was never published: the 4.11.0 publish stopped with EOTP (the `NPM_TOKEN` secret was a token that needs two-factor codes). The Release workflow now explains EOTP and refused tokens in plain words. The fix is a Granular Access Token with Read and write on packages and "Bypass two-factor authentication" ticked (or a Classic Automation token) saved as `NPM_TOKEN`; this release, or a by-hand re-run of the Release workflow, then publishes. A re-run skips the GitHub Release that already exists and only publishes to npm.

### Changed
- The website hero says in plain words what herdr-orchestra is: a skill you install into the coding agents you already use, plus a small `orch` command.

## [4.11.0] - 2026-11-12

### Added
- **Install with npx.** `npx herdr-orchestra@latest` installs herdr-orchestra, the same way the curl script did. The npm package carries the release files and a small launcher (`npm/cli.js`) that runs the bundled `install.sh`, so install behaviour lives in one place. Every `install.sh` option works after the name: `--version v4.2.0` (downloads that release from GitHub), `--list`, `--current`, `--uninstall`, `--no-herdr-skill`. Needs Node, bash, python3 and git (no native Windows; use WSL).
- **npm publish is part of the release.** After the GitHub Release is made, the Release workflow publishes the same version to npm (with provenance) when the `NPM_TOKEN` repository secret is set, and skips it with a warning when it is not. A version already on npm is left alone. CI and the release check that `package.json` and `VERSION` match, and CI installs from the packed tarball.

### Changed
- `install.sh` run from the npm package installs `vX.Y.Z` (not `-dev`). The README, website and install docs show npx first; the curl command stays as the way to install without Node.

## [4.10.1] - 2026-11-12

### Changed
- **Releases are made by themselves.** When a merge to main carries a `VERSION` that has no release yet, the Release workflow runs the tests, tags `vX.Y.Z` on that commit and publishes the GitHub Release with its own `install.sh`. Nobody has to push a tag after merging. A tag pushed by hand still works and must match `VERSION`; a version whose tag already sits on another commit fails loudly. `scripts/release.sh` no longer tags.

## [4.10.0] - 2026-11-12

One installed tool is enough for a whole team. A developer with only Codex (or only Claude Code, or only OpenCode) opens one pane, and the lead builds and opens the rest from that same tool.

### Added
- **`orch team <kind> [--coders N] [--models a,b] [--no-reviewer]`**: the plan's team built from one tool. It picks coders spread over the tiers the model catalog allows for that tool (two by default: the weakest and the strongest) and a reviewer on the strongest, and prints the `Workers:` and `Reviewer:` lines. For Codex: `codex-1 (codex: gpt-6-luna)`, `codex-2 (codex: gpt-6-sol)`, `reviewer (codex: gpt-6-sol)`. It says when the tool has no allowed high-tier model. Read-only, and it works outside a repo.
- **`orch team up [--dry-run]`**: after `orch start`, opens a herdr pane for every worker and the reviewer in the plan that herdr can't find. Each pane is split from the lead's pane, starts in the agent's folder (its worktree, or the repo), runs the tool on its plan model, and gets its plan name. Agents that already run are left alone, so it is safe to run again. It reports `WAITING` with the rename command when a new pane stops at a first-run question, and exits 3 while any agent is not ready.

### Changed
- **The plan playbook builds the team when the lead is alone.** When `herdr agent list` shows no agent pane besides the lead, the lead runs `orch team <its kind>`, writes the lines into the plan, and tells the developer how many windows will open. The run playbook runs `orch team up` when `orch start` shows a missing agent, then `orch start` again. Worktree setup no longer asks the lead to split panes by hand.
- The reviewer can be another pane of the same tool as the coders (the playbook and README no longer point to AGY).

## [4.9.0] - 2026-11-12

The feature decides how many milestones a plan has. Small features no longer get split because coders are free.

### Changed
- **The lead sizes the plan to the feature.** The planning playbook no longer has a milestone budget (1–2 small, 3–4 medium, never more than 4) or the rule that split backend and frontend "even when the feature is small". The lead now writes a `## Feature breakdown` first (the real pieces of work and how they connect), starts from one milestone, and splits a piece off only when another coder can build it in parallel, other work has to build on it first, or the whole is too big for one sitting. More coders never means more milestones. Contract, scaffold and integration milestones are made only when the feature needs them.
- **`orch sync` no longer warns above 4 milestones.** `ORCH_MAX_TASKS` is unset by default; set it to get the warning above a number of your own.

### Added
- **`Why separate:`** on a milestone: why it is its own milestone. In a plan with two or more enabled milestones, `orch sync` warns for each one without it. Plans written for 4.8 keep working (a warning, never an error); a plan with one milestone needs nothing. `orch fix` writes the line for the follow-up milestone it adds.

## [4.8.0] - 2026-11-12

### Added
- **`orch fix Mn "<change>" [--to <worker>]`**: a change to something a milestone already landed, without a new planning round. It adds one small follow-up milestone to `plan.md` (depends on Mn, same Likely files, tier and review setting), already dispatched to the coder who built Mn, and starts the event manager. The check, the review and the summary apply as for any milestone. It works after ALL_DONE and during a run; the developer or the lead may run it (`--to` names another coder). The lead playbook's ALL_DONE section now tells the lead to use it when the developer asks for a change after the summary.

### Changed
- When the summary is written again (a fix after ALL_DONE), the earlier one is kept as `.orchestrate/summary.prev.md`, so the lead's notes and checklist are not lost.

## [4.7.0] - 2026-11-11

The lead is back in the run, without giving up the single crash-safe driver: it plans, picks a model tier for every milestone, dispatches, pauses, and is woken by events. Plans written for 4.6 keep working.

### Added
- **Event-driven lead.** With a `Lead:` line in the plan, a run works like a call stack: the lead dispatches milestones (`orch dispatch M1 M2`) and pauses; `orch autopilot` is now the **event manager**: it sends the work, watches the agents, checks, reviews and merges as before, and wakes the lead with one prompt (`orch events`) when a milestone lands, a coder asks a question, a milestone fails or is held, or new work is ready. The lead decides and pauses again. At ALL_DONE the lead is woken to finish the summary.
- **A queue that loses nothing.** Each event is stored in `state.json` in the same write as the change that caused it. The lead is woken only when it is idle, once per batch; an unread batch is sent again after `ORCH_LEAD_REWAKE_S` (300 s), up to `ORCH_LEAD_MAX_WAKES` (3) times, and then you are told. Reading `orch events` is the acknowledgement (`--peek` looks without acknowledging). Blocking events stay open until their milestone moves on.
- **`orch answer Mn "<text>"`**: the developer's answer goes under the milestone's "Notes from user" in `plan.md`, and the milestone goes back to the same coder with its saved work.
- **`orch dispatch Mn... [--to <worker>] [--tier <tier>]`**: start or restart milestones. It starts the event manager when none is running (`ORCH_NO_AUTOSTART=1` turns that off). While the event manager waits for the lead or for you, it stays up and its waiting time does not count against `Budget:`.
- **A run never stalls on the lead.** Ready milestones the lead has not dispatched after `ORCH_LEAD_WAIT_MIN` (15) start by themselves; a lead pane that is gone is reported once. `Lead mode: off` gives the 4.6 behaviour: autopilot dispatches by itself and exits 3 when it needs you.
- **Model catalog** (`models.default.toml`, yours in `~/.config/herdr-orchestra/models.toml`): each model has a tier (small, medium, high), 1–5 ratings for reasoning, coding, architecture, instruction following, tool use, planning and speed, its context window, and the evidence for the ratings. A tier has a reasoning floor. `orch models`, `orch models show <id>`, `orch models check <id>`.
- **Model policy.** `[policy] deny` keeps ultra-premium models (`*fable*`, `*astra*`) out of runs: `orch sync` refuses a plan that names one, and `orch agents launch` refuses to build the command.
- **Tiers in the plan.** `Workers: claude-1 (claude: sonnet)` records the model each pane runs; milestones take `Tier:`, `Needs:` and `Model why:`. `orch sync` warns when no coder reaches a milestone's tier, when the reviewer is weaker than the work, when the lead is not on a high-tier model, and when a model is not in the catalog. `task.json` carries `tier` and `needs`.
- **Tier-aware dispatch.** `orch pick` gives a milestone to a free coder of its tier, or a stronger one; never a weaker one while a suitable coder exists.
- **One escalation.** A milestone out of fix or review rounds gets one fresh round on a coder with a stronger model (`orch escalate`), with the work so far, before it fails.
- **Planned against actual.** Every attempt records its model. `summary.md` has a table of planned tier, the models that ran, and escalations; `orch report` adds per-model rows (tries, merged, first pass, moved up).
- `orch agents launch <kind> --model <id>` and the registry key `model_flag`.

### Changed
- The lead playbooks: `orch lead plan` adds model discovery and a tier per milestone, and ends by waiting for your go; `orch lead run` is the dispatch, pause, wake, decide loop.
- With a lead in the run, a paused, failed or held milestone no longer ends autopilot: it wakes the lead and keeps waiting (up to `ORCH_LEAD_IDLE_MAX_MIN`, 720).
- One busy or unsuitable coder no longer blocks the dispatch of other ready milestones in the same pass.

### Upgrade notes
- A plan with a `Lead:` line now runs in `Lead mode: events`. Add `Lead mode: off` to keep driving it from a terminal only.
- The default model ratings are starting points with their sources, not benchmarks run by this project. Check the ids against your tools, and re-rate from `orch report`.

## [4.6.0] - 2026-11-11

Answers the architecture review: one driver, checked state transitions, nothing red committed, bounded retries, structured contracts, and a record of what each run did. Plan format and existing commands keep working; in-flight 4.5 runs are migrated on load.

### Changed
- **Autopilot is the only driver of a run.** While `orch autopilot` runs it holds a lease (`.orchestrate/driver.lock`): a second autopilot is refused, and so is any `orch` command that would change the run from another process (`status`, `ready`, `pick`, `report` and `approve` still work). The kernel frees the lease if autopilot dies. The AI-driven scheduler loop is gone from `orch lead run`: the lead now handles what autopilot stopped on (questions, failed or held milestones, a red baseline) and finishes the summary. Recovery rules live in one place, the code.
- **The check runs before the commit.** `orch merge` squashes the milestone, runs the check on the merged result and commits only if it passes. A milestone that passes alone but fails once merged commits nothing, and goes back to a coder as an `integration-fix` round (exit 6, counted against the 3 fix rounds). Before this, the commit landed first and the run stopped on a red branch.
- **Every status change goes through one function** with a transition table and a per-task history. `orch set` only accepts `pending`, `paused`, `failed` and `skipped`; anything else needs `--force` and is logged. `merged` is final.
- A conflict fix on a milestone the reviewer had already approved is reviewed again; the reviewer gets `resolution.patch` (what changed to resolve it).
- Milestones that share a `Likely files` entry run one after the other instead of only producing a warning. `Parallel: allow` on a milestone opts out.
- A red baseline stops autopilot with the failing lines; it no longer leaves a `baseline.txt` behind that made the next run skip the check.
- `orch poll` returns after 5 s when no agent is working, so a short bench doesn't cost a full wait.

### Added
- **Crash safety.** A prompt is recorded before it is sent; after a crash it is confirmed with herdr or re-sent to the same agent (`orch resend`, `UNCONFIRMED` event) and never handed to a second coder. A merge is journaled: the next run finishes it if the commit had landed, or undoes the staged squash and merges again from the saved work.
- **Bounded retries.** Attempts lost to an unreachable, vanished or rate-limited agent are counted (`orch park --lost`); at `ORCH_MAX_LOST` (4) the task fails with the reason. Three failed prompts in a row bench an agent for `ORCH_UNREACHABLE_MIN` (30).
- **Fresh dependencies.** A worktree's setup command runs again when its lockfiles or manifests changed since its last setup (or the files in `Setup inputs:`), and the main folder gets the same before the merge check.
- **Contracts as data** (`docs/contracts.md`): `task.json` per milestone, generated from `plan.md` (numbered acceptance criteria, allowed files, interfaces, the commits of its dependencies); `result-N.json` from coders (status, commit, the check, each criterion met or not, optional usage); `review-N.json` from the reviewer (a verdict per criterion, findings). An invalid result gets one request to rewrite it; an unmet criterion is a fix round or a blocker. The `COMMIT:` / `QUESTION:` / `BLOCKER:` line formats still work when the JSON file is missing.
- **Scope check.** The coder's real diff is compared with `Likely files`: `Scope: warn` (default) lists strays in the summary, `Scope: strict` sends them back.
- **Risk hold.** A milestone that deletes files, touches migrations, CI configuration or secrets files, changes dependency files it didn't list, or exceeds `ORCH_RISK_MAX_LINES` (1500) is `held` before it lands until `orch approve Mn`. `Risk hold: off` disables it.
- **Observability.** `.orchestrate/events.jsonl` (one line per transition), per-attempt timing and check timing in state, `orch report [--json]` (time, rounds, first-pass rate, wasted work; tokens and cost only when agents report them), and the report in `summary.md`. `Budget: 3h` in the plan header stops autopilot when its running time is used up.
- **`orch doctor [kind]`**: checks an installed agent against the real tool (version, whether each launch flag is still in its `--help`, skills, herdr detection). `orch start` warns about a launch flag that is gone. Optional registry keys `version_cmd` and `help_cmd`.
- `tests/live/`: an opt-in smoke run with real agents, and `tests/fixtures/panes/` for captured pane text. The fixtures shipped are synthetic and labelled so; no live run has been recorded yet.
- `state.json` carries `schema: 1` and is migrated on load. `ORCH_FAULT` is a test hook that kills orch at a named step.

### Upgrade notes
- A run that an AI lead was driving by hand should be finished with `orch autopilot`.
- Every worktree runs its setup command once more after the upgrade (no setup fingerprint was stored before).
- `orch sync` warns about a milestone without acceptance criteria. It is a warning, not an error, so existing plans keep running.

## [4.5.0] - 2026-11-10

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
- Curl install from the GitHub Release: `curl -fsSL https://github.com/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash`. Each release attaches an `install.sh` that installs that version (`/releases/download/vX.Y.Z/install.sh`).
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
