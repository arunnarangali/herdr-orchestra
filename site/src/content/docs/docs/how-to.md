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

## During a run

### A coder has a question. How do I answer it?

You answer the lead, not the coder. The lead asks you in its pane, then runs:

```bash
orch answer M2 "skip empty rows"
```

The answer is written under that milestone's "Notes from user", and the **same coder** carries on. Other milestones keep running meanwhile. See [When a run needs you](/docs/when-it-stops/).

### A milestone says `held`. What do I do?

orch holds a milestone when its change looks risky: it deletes files, touches a migration, CI or secrets, changes packages, or is very large. You get a desktop notification. Look at the reasons in `orch status`, then:

```bash
orch approve M3          # let it land
orch set M3 paused       # or stop it for now
```

### How do I see what is going on?

```bash
orch status          # every coder and milestone, and why something waits
orch events --peek   # what is waiting for the lead, without marking it read
```

A worker line shows `herdr=ok` or `NO AGENT`, and `state=free`, `coding M3`, `benched 42m` or `OFF`.

### Can I make a milestone go to one particular coder?

Yes. Ask the lead, or run:

```bash
orch dispatch M2 --to claude-1
```

`--to` locks that milestone to that coder, which is useful for UI work you want one agent to own. The plan's `Prefer:` line is weaker: it only breaks ties. `--to` refuses a coder that has no agent open in herdr, or one you benched. See [Agents and roles](/docs/agents/).

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
