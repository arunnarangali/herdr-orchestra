# Changelog

All notable changes. Versions follow [semantic versioning](https://semver.org).

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
