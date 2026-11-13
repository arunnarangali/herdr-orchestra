---
title: The orchestration plan
description: How the lead splits a feature into milestones, decides what runs in parallel, and picks a model tier for each.
---

The lead researches and plans; coders own the how. Each milestone is written as an issue: Goal, Why, Acceptance criteria, Constraints, Interfaces, Context (facts), Out of scope, Open questions. Each one also gets a model tier and the reason for it.

The result is the **orchestration plan**: what will be built, in what order, by which coder on which level of model, and why. The run then does what the plan says, and the summary shows where it didn't.

## Milestones fit the feature

There is no target number. The feature decides how many milestones there are, not the size of the team.

1. **The lead understands the feature first.** It writes a `## Feature breakdown` in the plan: the real pieces of work, and how they connect.
2. **It starts from one milestone.** A piece becomes its own milestone only for one of these reasons:
   - **Parallel:** another coder can build it at the same time, and it is real work for them.
   - **Foundation:** other pieces have to build on it first (a contract both sides code against, a scaffold for shared files).
   - **Too big:** the whole is more than one coder can finish in one sitting.
3. **Every split says why.** In a plan with two or more milestones, each one has a `Why separate:` line you can check. If the lead cannot write a real reason, the piece is merged back.

More coders never means more milestones, and an idle coder is fine.

| Feature | Plan |
|---|---|
| Add a phone field to the profile (one API field, one form input) | 1 milestone, even with five coders |
| CSV import with a preview screen, two coders | 2 milestones: the import API and the preview UI, in parallel |
| The same, and both sides need one shared types file | 3 milestones: a small contract first, then the two sides |

A feature made of several loosely connected parts is better as separate runs, each with its own plan and branch. The lead says so and plans the first one.

## Then the split is fitted to the team

- **One coder:** nothing runs in parallel. One milestone, or a few in order when the work is too big for one sitting. Shared mode.
- **Two or more coders, and each side is real work:** split by side so both work at once, with the contract written in both milestones (or a small contract milestone first, when both need one shared types file).
- **A further parallel milestone** only when there is a real independent slice.

## Dependencies decide parallelism

For each pair, ask: *"Could B be built and pass its checks if A never existed?"* No → `Depends on: A (what B needs)`. Yes → they can run in parallel.

- **Contract first:** parallel milestones that must fit together depend on a milestone that defines the interface.
- **Scaffold first:** edits to shared hotspot files (routes, nav, `package.json` and lockfile, global store, shared types) go in one small first milestone; only it adds packages.
- **Integration last**, when the wiring is real work.

These milestones exist only when the feature needs them, never by default.

```text
Small change:   M1 the whole thing
Full stack:     M1 backend ∥ M2 UI          (or M1 contract → M2 backend ∥ M3 UI)
Big frontend:   M1 scaffold (route, nav, packages, types) → M2 part A ∥ M3 part B → M4 wire-up
```

## A tier for every milestone

The lead judges the milestone, not the model's name:

- **small:** mechanical and well specified. Renames, config, docs, a change that copies an existing pattern.
- **medium:** normal implementation inside one module or one side. Solid coding, little design.
- **high:** reasoning is the hard part. A contract others build on, architecture or data-model decisions, a refactor across modules, auth, payments or schema, a bug nobody has diagnosed.

It writes `Tier`, `Needs` (what the work leans on) and `Model why` (one line you can check) into each milestone, and shows you a table of milestone, tier, coder and model before you say go. It also checks the team: if a milestone needs a high-tier model and no coder runs one, it proposes the pane to start. See [Models and tiers](/docs/models/).

## Estimate vs actual time

The lead also says how long each milestone should take, and the whole feature. A milestone's `Estimate:` is the time from dispatch until it has landed if nothing goes wrong: the coder building it on the model the lead picked, the checks, and one review. The header's `Estimate:` is for the whole feature: milestones that run side by side count once, milestones that wait for another add up. For example M1 30m, then M2 40m and M3 30m side by side, makes `Estimate: 1h10m`.

orch records the real time of every step while the run goes, and the summary (and `orch report`) puts the two side by side:

```
Whole feature: estimated 1h30m, actual 1h40m, 10m longer than estimated

| Milestone | Estimate | Actual | Difference | Built by |
| M1        | 40m      | 1h40m  | +1h00m     | claude-1 (sonnet), codex-1 (gpt-6-sol) |
| M2        | 30m      | 25m    | -5m        | codex-1 (gpt-6-sol) |

Why M1 took 1h00m longer than its 40m estimate:
- 24m claude-1 (sonnet): work cut short (claude-1 hit a usage/rate limit); the next attempt carried on from it
- 20m developer / lead: paused, waiting for the lead or the developer (which currency?)
- 10m claude-1: agent hit a usage limit: benched, work waited for another coder
- 10m claude-1 (sonnet): fix rounds: the check command failed
- 5m claude-1: stopped at a permission prompt or question in its pane
```

Every reason comes from something orch measured: a coder's fix rounds (failed checks, unmet acceptance criteria, reviewer blockers, merge conflicts), a second review, waiting for the reviewer or a free coder, a question or a held change waiting for you, a permission prompt in an agent's pane, a usage limit, an agent that disappeared, an escalation to a stronger model, and time when no milestone was running. Nothing is guessed: time orch can't place shows as orch's own steps (setup, prompts, merge). When the planned work alone took longer than the estimate, it says so: the estimate was too low for that work.

## What `orch sync` checks

It warns about a milestone without `Why separate` (in a plan with more than one) or without `Estimate`, dependencies without a reason, hotspot files in parallel milestones, "how" written into a milestone, independent milestones left in shared mode, plans that would leave coders idle, a tier no coder reaches, a reviewer weaker than the work, and a model that is not in the catalog. It rejects a lead that is also a worker or the reviewer, and any model the policy does not allow.

## Open questions

Missing business rules, undefined data shapes and security trade-offs go under **Open questions** with 2 to 3 options. `orch sync` marks such milestones `needs-answer`, and their dependents wait.

## After the plan

The lead stops and waits for you. When you say go, it dispatches the milestones and the [orchestration run](/docs/driving/) begins.

## What goes in a milestone, and what doesn't

Research findings go in as **facts**, not instructions:

- Good: "Uploads are handled in `server/routes/upload.ts`; categories live in the `categories` table."
- Not allowed: "Add a `matchCategory()` function to upload.ts that loops over rows."

Acceptance criteria are observable ("`POST /upload` returns 400 when the amount column is missing"), not vague ("handles errors well"). Use `Review: yes` for UI, API contracts, auth, payments and schema; `no` for mechanical milestones.

The exact format is in [The plan file](/docs/plan-file/).
