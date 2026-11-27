---
title: Questions and how-tos
description: Short answers, with examples, to the questions people ask most about herdr-orchestra. Small changes, fixes after a run, restarts, approvals, changing the team, updates and more.
---

Short answers to the questions people ask most. Each one ends with a link to the page that has every detail.

## Planning and small changes

### How is a small change handled? Does it skip planning?

Not fully, but planning is much lighter. Start your request with `quick:`:

```text
/orch-plan quick: make the Save button blue
```

1. **The lead still reads the code first.** It checks that the change is small and safe. Then it writes a short plan with **one milestone and one coder**, plus its reason for calling it quick (`Quick because: ...`).
2. **It waits for your "go".** That takes a few seconds, and you can catch a wrong guess before any code changes.
3. **One coder builds it, with no reviewer.** The check (lint, types, tests) runs 2 times instead of 4.

Risky changes, like a database migration, CI, secrets or package files, are never quick. They are refused as quick runs and get full planning instead. Normal feature planning has not changed. See [Quick runs for small changes](/docs/quick-runs/).

### Can I choose quick or full myself?

Yes, with the first word of your request:

| You type | What you get |
|---|---|
| `quick: make the Save button blue` | One coder, no reviewer |
| `quick review: reject an empty email on signup` | One coder, and the reviewer reads the diff |
| `full: add createdAt to GET /orders` | The full process: milestones, roles, a reviewer |
| nothing | The lead decides after reading the code, and tells you why |

If you write `quick:` but the lead finds the change is not small (for example it needs a new database column), it tells you which point failed and plans it in full, unless you insist.

### Can I put several small changes in one quick run?

Yes. Write them in one request, and each one gets its own line in the plan to check:

```text
/orch-plan quick: make the Save button blue, and add a spinner on the dashboard
```

### How does the lead split a big feature?

It sizes the milestones to the feature, with no fixed count. Each milestone says `Why separate:` (why it is not part of another one), the `Role:` its coder should work as (for example "senior frontend engineer with a designer's eye"), a tier (small, medium or high model) and an `Estimate:`. You read the plan, change anything in `.orchestrate/plan.md`, and say go. See [The orchestration plan](/docs/planning/).

### How long will it take?

The plan has an estimate for each milestone and for the whole feature. Milestones that run side by side count once. For example M1 30m, then M2 40m and M3 30m side by side, makes `Estimate: 1h10m`. At the end, the summary and `orch report` show the estimate next to the real time, and when it took longer, why and who it waited on. See [Estimate vs actual time](/docs/planning/#estimate-vs-actual-time).

### Why does the lead ask me questions before it shows a plan?

So the plan is written once, with your answers in it, instead of being rewritten after you answer. After reading the code, the lead asks only what the code can't settle, all in one message, each with its own suggestion:

```text
Before I plan, 3 questions:
1. Discount on the whole order or on each item? I suggest the whole order: the cart has no per-item prices today.
2. Percent, fixed amount, or both? I suggest both: the admin screen already has a type dropdown.
3. Can a discount bring the total to zero? I suggest no: the payment step refuses a zero total.
```

You answer `1 whole order, 2 both, 3 no`, and it writes the plan. Nothing runs until you say go. When the code settles everything, there are no questions. Want one question at a time? Start your request with `grill:`. See [The orchestration plan](/docs/planning/#questions-come-first).

### Can I click the answers instead of typing them?

Yes, when your lead's tool has a question picker. The lead then shows each question as a list you pick from with the arrow keys, its suggestion marked:

```text
Decisions before planning (1 of 3)
Discount on the whole order or on each item?
> (a) Whole order  [Recommended]
  (b) Each item
  Custom answer...
```

- **Claude Code** uses its own picker (`AskUserQuestion`), **OpenCode** its `question` tool, and **Antigravity** its own picker.
- **Codex** has one too (`request_user_input`), but only in Plan mode unless a setting is on. orch's start command for a Codex lead turns it on (`orch agents launch codex --role lead`, or the line `orch team codex` prints). Coders never get it, because nobody watches their panes.
- **Pi** has no picker of its own, so orch's Pi package adds one: the `orch_ask` tool.

Your answers are saved in `.orchestrate/questions.md` either way, and the lead goes straight on to the plan. Press Escape to stop: the lead pauses and asks again when you say so, and never guesses. With no picker (a headless run, or a lead started before this version) it asks in chat as above.

### How do I give the coders and the reviewer my project's rules?

Add any of these files to your repo (in `docs/`, or the folder a `Docs:` line in the plan names):

| File | What goes in it | Example |
|---|---|---|
| `docs/glossary.md` | The words your project uses, and words to avoid | `- **Discount**: money taken off an order total, in paise. Avoid: coupon, promo` |
| `docs/adr/0001-money-in-paise.md` | One past decision and why (a decision record) | `# Money is whole paise` and two lines on why |
| `docs/coding-standards.md` | Your coding rules, short | `No floats for money. Every API input is checked at the route.` |

Each coder's task file then gets a short **Project rules** block: only the glossary words its milestone uses, the title of each decision, and where the coding rules are. The reviewer checks the work against them, separately from "did it build what was asked". The lead uses the glossary's words, and `orch sync` warns when the plan uses a word to avoid. Without these files nothing changes. See [Checks, reviews and merges](/docs/reviews/#reviews).

### What does "hard to undo" mean on a milestone?

Most changes are easy to undo: if they are wrong, you revert them. Some are not: a migration that changes real data, a public API other apps call, deleting data, sending emails. The lead marks those `Door: one-way (why)` in the plan. Such a milestone:

1. always waits for your `orch approve`, even when no file looks risky;
2. comes with proof from its coder, for example `migration ran on a copy: 2M rows in 14s, no lock`;
3. shows how much it could break, measured by orch: risky files, how many milestones build on it, its size.

The summary and the pull request get a small table, so you know where to look hardest:

| Milestone | Undo | Could break | Proof |
|---|---|---|---|
| M2 Discount column | **hard**: adds a column to orders | medium: M3 builds on it | migration ran on a copy |
| M3 Discount badge | easy | small | - |

## During a run

### A coder has a question. How do I answer it?

You answer the lead, not the coder. The lead asks you in its pane, then runs:

```bash
orch answer M2 "skip empty rows"
```

The answer is written under that milestone's "Notes from user", and the **same coder** carries on. Other milestones keep running meanwhile. See [When a run needs you](/docs/when-it-stops/).

### Part of a milestone can't be built yet. Can I ship the rest?

Yes. Say a milestone has two criteria: AC1 "the watch shows the steps" and AC2 "the watch syncs with the phone API", and that API doesn't exist yet. The coder asks, the lead asks you, and you say "build the rest, AC2 later". The lead runs:

```bash
orch answer M7 --defer AC2 "build the rest; sync when the API exists"
```

Now when the coder reports AC2 as not met, it is not sent back to fix it, and it is not moved to a stronger model. The reviewer doesn't block on AC2 either. The summary has a "Deferred: not done, follow-ups" section that says AC2 was **not built**, gives your reason, and suggests `orch fix M7 "..."` for later. If the milestone already failed, the lead runs `orch defer M7 AC2 "<your reason>"`, then `orch dispatch M7`.

Only you can agree to leave something out. Writing it in the plan as a note is not enough: the check reads `--defer`.

### A milestone says `held`. What do I do?

orch holds a milestone when the plan says it is hard to undo (`Door: one-way`), or when its change looks risky: it deletes files, touches a migration, CI or secrets, changes packages, or is very large. You get a desktop notification. Look at the reasons in `orch status`: they include how much it could break and, for a hard-to-undo milestone, the coder's proof. Then:

```bash
orch approve M3          # let it land
orch set M3 paused       # or stop it for now
```

### How do I see what is going on?

```bash
orch status          # every coder and milestone, and why something waits
orch events --peek   # what is waiting for the lead, without marking it read
```

A worker line shows `herdr=ok` or `NO AGENT`, and `state=free`, `coding M3`, `stopping M3`, `benched 42m` or `OFF`. `stopping M3` means M3 was paused or moved while that coder worked: orch pressed Esc and told it to stop, and it gets no new work until herdr shows it idle.

### Can I make a milestone go to one particular coder?

Yes. Ask the lead, or run:

```bash
orch dispatch M2 --to claude-1
```

`--to` locks that milestone to that coder, which is useful for UI work you want one agent to own. The plan's `Prefer:` line is weaker: it only breaks ties. To lock a milestone to a model and thinking level rather than to one coder, pick it when the lead asks after the plan, or say "M3 use luna high" in the lead's chat (`orch plan model M3 gpt-6-luna@high`). `--to` refuses a coder that has no agent open in herdr, or one you benched. See [Agents and roles](/docs/agents/).

### I don't want one coder today (for example, no Claude). How?

```bash
orch bench claude-1 off "no Claude today"
orch bench claude-1 on      # later, to bring it back
```

It stays out until you turn it back on, even across restarts. Its milestones go to the other coders. To bench it for a while only, use `orch cooldown claude-1 60` (60 minutes).

### How do I swap a coder for another one?

```bash
orch stop        # stop the event manager cleanly; nothing is lost
# change the Workers: line in .orchestrate/plan.md
orch sync        # read the plan again
orch team up     # open the new coder's pane
orch resume      # carry on
```

### How do I stop a run?

`orch stop` stops the event manager after the step it is on (a check, a merge). Every event is kept, and `orch resume` starts it again. `orch stop --now` also stops the step it is on. To stop one milestone and keep its work, use `orch park M2 paused "why"`.

## After the run

### I read the summary and want one more change. Do I plan again?

No. Tell the lead, and it sends the change straight to the coder who built that part:

```text
you   →  "the login button should be blue"
lead  →  orch fix M1 "the login button should be blue"
```

orch adds a small follow-up milestone (for example M5 "Fix for M1"), the same coder makes the change, the check (and the review, if M1 had one) runs as usual, and the summary is written again. It works on quick runs too. You can run `orch fix` yourself, and `--to <worker>` gives it to another coder. If you type into a coder's pane instead, nothing checks the change and it is not in the summary. See [The lead and the event manager](/docs/lead/).

### How do I get the pull request?

Do the short manual checklist at the end of `.orchestrate/summary.md` (only what needs your eyes, like how the UI looks), then:

```bash
orch finish
```

It runs the final check (or reuses it when the files are exactly the same), removes the coders' folders and the `<repo>-wt` folder, pushes the feature branch and opens the PR. See [Git, commits and the PR](/docs/git/).

### Why is there a `<repo>-wt` folder next to my repo?

That is where coders work side by side, one folder each, so they don't touch each other's files. `orch finish` removes it when every milestone has landed. A stopped or crashed run keeps it on purpose, so `orch resume` can carry on. Quick runs never make one. A folder with real changes no milestone has is kept, and finish prints the command that deletes it.

## Restarts and crashes

### My computer restarted, or herdr closed. What now?

Open herdr and run one command in the repo:

```bash
orch resume
```

It leaves the time orch was down out of every time budget, gives the agents their names back, saves any unsaved work, sends each task in progress to its agent again, and starts the event manager. You don't type "continue" in each pane. It is safe to run more than once. See [After a restart](/docs/when-it-stops/#after-a-restart).

### A coder's pane closed, or only a shell is left.

The lead tells you (`WORKER-LOST`) with the exact fix. Usually:

```bash
orch team up     # opens every missing agent in its folder, on its model
```

The milestone waits with its work so far.

### Why did the run stop?

```bash
orch doctor --crash
```

It shows why the event manager last stopped, for example the computer's memory guard closing the terminal, and the last screen of any agent that quit. See [Why did it stop?](/docs/when-it-stops/#why-did-it-stop).

## Team and agents

### I only have one tool (for example Codex). Can I still run a team?

Yes. Open just the lead's pane. The lead sees it is alone and builds the team from that one tool: coders on its small, medium and high models, and a reviewer. When you say go, it opens the other panes for you with `orch team up`. See [One tool, whole team](/docs/agents/#one-tool-whole-team).

### Which models can it use?

Whatever your agents already reach. The lead picks a small, medium or high model for each milestone. Only ultra-premium models are blocked. `orch models` lists them all. See [Models and tiers](/docs/models/).

## Updates

### How do I update?

```bash
orch update            # install the latest release and show what is new
orch update --check    # only look
orch update --version v5.7.1   # install one exact version, also how you go back
```

On 5.7 or older, run `npx herdr-orchestra@latest` once. After that, orch tells you when a new version is out (`herdr-orchestra 5.8.1 is out (you have 5.8.0). Run orch update.`).

### Can it update itself?

Yes, it is on by default. When you start a new plan, orch installs a newer release first. It never updates in the middle of a run, for a major version, or in a repo pinned with `.orch-version`. Turn it off or on with:

```bash
orch config auto-update off
```

See [Updates](/docs/installation/#updates).

## More

Every command is listed in [Commands](/docs/commands/).
