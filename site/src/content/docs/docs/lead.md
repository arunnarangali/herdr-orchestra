---
title: The lead and the event manager
description: The lead plans, dispatches and pauses; a plain script runs the work and wakes the lead when something needs a decision.
---

A run has one decision maker and one doer.

- The **lead** is an AI agent in a pane. It writes the orchestration plan, decides which level of model each milestone needs, hands out the work, and decides what happens when something comes up.
- The **event manager** is `orch autopilot`, a plain script with no AI in it. It prompts the coders and the reviewer, watches them, runs checks, sends fixes, merges, and keeps a queue of everything the lead should hear about.

The lead never watches or polls the agents. It works like a function on a call stack: it dispatches, **pauses**, and is **resumed by an event**.

## The loop

1. **Plan.** The lead researches the code and writes `.orchestrate/plan.md`. You read it, edit it, and say go.
2. **Dispatch.** The lead runs `orch dispatch M1 M2`. That starts the event manager if none is running. The lead tells you what is running where, and stops.
3. **Pause.** No AI is running for the lead now, so it costs nothing. The event manager sends each milestone to a free coder on a model of its tier and looks after checks, reviews, fixes and merges.
4. **Wake.** When something needs the lead, the event manager types one line into its pane: run `orch events`. The lead reads the events, handles each one, and pauses again.
5. **Repeat** until every milestone has landed. The last wake-up asks the lead to finish the summary.

## What wakes the lead

| Event | What the lead does |
|---|---|
| A milestone **landed** | Dispatches whatever that unlocked |
| Milestones are **ready** | `orch dispatch <Mn>...` |
| A coder asked a **question** | Answers it when the request, the plan or the code already settles it. Otherwise asks you, and passes your answer on |
| A milestone **failed** after its rounds | Reads the report, adds the missing fact to the plan, dispatches it again (with a stronger model if the work was harder than planned) |
| A milestone is **held** for a risky change | Shows you the reasons. Only you can run `orch approve Mn` |
| An agent **stopped**, timed out or is blocked | Tells you what to look at, then dispatches the milestone again |
| **All done** | Finishes the summary: design notes, what it checked itself (by running commands and reading the code, with the evidence), and a manual checklist of only what a person must see or do |

Routine recovery does not wake the lead: a failed check goes back to its coder, a rate-limited or vanished agent is benched and its work moves on, and a milestone out of fix rounds gets one fresh round on a stronger model.

## When a coder has a question

```text
coder-2  →  result file: status "question": "Skip empty rows or reject the file?"
event manager  →  pauses M2, queues the event, wakes the lead
lead  →  asks you in its pane, with options
you  →  "skip them"
lead  →  orch answer M2 "skip empty rows"
event manager  →  writes the answer under M2's "Notes from user", sends M2 back to coder-2
coder-2  →  carries on from its saved work; when it finishes, the lead is woken again
```

Other milestones keep running the whole time. `orch answer` always sends the milestone back to the coder that asked.

## When you want a change after the summary

The run is done, you read the summary, and something needs to change. Tell the lead, not the coder. There is no new planning round.

```text
you  →  "the login button should be blue"
lead  →  orch fix M1 "the login button should be blue"
orch  →  adds M5 "Fix for M1: ..." to the plan, already dispatched to coder-1 (who built M1)
coder-1  →  makes the change; the check (and the review, if M1 had one) runs as usual
event manager  →  lands M5, writes the summary again (the old one is kept as summary.prev.md), wakes the lead
```

You can run `orch fix` yourself as well. Add `--to <worker>` to give it to a different coder. If you type into a coder's pane instead, nothing checks the change and it is not in the summary.

## Nothing is lost, nothing is sent twice

- **Every event is stored first.** An event is written to `.orchestrate/state.json` in the same write as the change that caused it. If the lead is busy, paused, or its pane is closed, the event waits.
- **One wake-up per batch.** The lead is woken only when it is idle, with one prompt for everything that is waiting. A wake-up it has not acted on covers newer events too.
- **Reading is the acknowledgement.** `orch events` marks what it shows as read. A question, a failure or a hold stays listed as open until its milestone moves on.
- **Only one process changes the run.** The event manager holds the run's lease. `orch dispatch` and `orch answer` are requests it carries out, so the lead and the script never send a prompt or merge at the same time.
- **Everything resumes.** The state is on disk. If the event manager is killed, the next start confirms or re-sends an unconfirmed prompt and finishes or undoes a half-done merge. If the lead's session is new, it runs `orch events` and carries on.

## The manual checklist is only for your eyes and hands

At the end, the summary separates three things:

- **Checked automatically**: what the run already proved. The check command on the finished branch, each review, and every acceptance criterion with the coder's and the reviewer's evidence.
- **Checked by the lead**: anything else a command or a look at the code can settle. The lead does it and writes the evidence, for example `the 400 for a missing amount column is covered by upload.test.ts:42, which passes`.
- **Manual verification checklist**: only what needs a person. How the UI looks, how it behaves in a real browser or on a real device, and anything that needs an outside account or hardware.

```
- [ ] Open /imports on a phone-sized window and upload sample.csv → the preview table scrolls sideways, the Save button stays visible
- [ ] Upload a file with a missing amount column → the red message appears under the file field, in the same style as other form errors
```

You will not find "read the code", "check the comments" or "confirm the tests pass" there: that is the lead's job. A change with nothing to look at (a backend, CLI or docs change) says `Nothing to check by hand` and why.

## If the lead does not answer

A run never stalls on the lead.

- **A wake-up only counts when the lead reads its events.** Sending the prompt proves nothing: it can sit in the pane's input box, or collide with something you were typing there. So if the lead is idle again and the events are still unread, the wake-up is sent again after 30 seconds, then after 1 minute. After 3 wake-ups you get a desktop notification. `orch status` shows it too: `wake-up sent 2x (last 0m40s ago), not picked up yet`.
- The event manager does not leave at the end of a run until the lead has picked up the last events (or you have been told it did not).
- A lead herdr can't watch gets the wake-up again every 5 minutes instead.
- Ready milestones the lead has not dispatched after 15 minutes start by themselves.
- If the lead's pane is gone, you are told once. `orch events --peek` shows you what is waiting without acknowledging it.
- While a question or a hold waits for you, the event manager stays up (12 hours by default) and that time does not count against the run's `Budget:`.

## Running without a lead

Put `Lead mode: off` in the plan header. `orch autopilot` then dispatches by itself and exits with code 3 when it needs you, with the reason in `.orchestrate/autopilot.log`. See [When a run needs you](/docs/when-it-stops/).

## Commands the lead uses

| Command | What it does |
|---|---|
| `orch dispatch <Mn>... [--to <worker>] [--tier <tier>]` | Start or restart milestones; starts the event manager if needed |
| `orch events [--peek]` | What the lead was woken for, what is ready, who is free |
| `orch answer <Mn> "<text>"` | Your answer, into the plan and back to the same coder |
| `orch fix <Mn> "<change>" [--to <worker>]` | A change after Mn landed, as one small follow-up milestone for the coder who built Mn |
| `orch status` | Every worker and milestone |
