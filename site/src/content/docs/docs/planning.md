---
title: The orchestration plan
description: How the lead splits a feature into milestones, decides what runs in parallel, and picks a model tier for each.
---

The lead researches and plans; coders own the how. Each milestone is written as an issue: Goal, Why, Acceptance criteria, Constraints, Interfaces, Context (facts), Out of scope, Open questions. Each one also gets a model tier and the reason for it.

The result is the **orchestration plan**: what will be built, in what order, by which coder on which level of model, and why. The run then does what the plan says, and the summary shows where it didn't.

## Milestone budget

- Small feature: 1 to 2 milestones.
- Medium feature: 3 to 4.
- Never more than 4 per run. `orch sync` warns; override with `ORCH_MAX_TASKS`. Split anything bigger into separate runs.

## Split for the team you have

- **One coder:** never split for parallelism. 1 to 2 milestones in order, shared mode.
- **Two or more coders, and the feature spans backend and frontend:** split by side so both work at once, with a small contract milestone for the shared types first.
- **Three or more:** a third parallel milestone only when there is a real independent slice.

## Dependencies decide parallelism

For each pair, ask: *"Could B be built and pass its checks if A never existed?"* No → `Depends on: A (what B needs)`. Yes → they can run in parallel.

- **Contract first:** parallel milestones that must fit together depend on a milestone that defines the interface.
- **Scaffold first:** edits to shared hotspot files (routes, nav, `package.json` and lockfile, global store, shared types) go in one small first milestone; only it adds packages.
- **Integration last.**

```text
Frontend:   M1 scaffold (route, nav, packages, types) → M2 component A ∥ M3 component B → M4 wire-up
Full stack: M1 contract (API + types) → M2 backend ∥ M3 UI → M4 integration
```

## A tier for every milestone

The lead judges the milestone, not the model's name:

- **small:** mechanical and well specified. Renames, config, docs, a change that copies an existing pattern.
- **medium:** normal implementation inside one module or one side. Solid coding, little design.
- **high:** reasoning is the hard part. A contract others build on, architecture or data-model decisions, a refactor across modules, auth, payments or schema, a bug nobody has diagnosed.

It writes `Tier`, `Needs` (what the work leans on) and `Model why` (one line you can check) into each milestone, and shows you a table of milestone, tier, coder and model before you say go. It also checks the team: if a milestone needs a high-tier model and no coder runs one, it proposes the pane to start. See [Models and tiers](/docs/models/).

## What `orch sync` checks

It warns about dependencies without a reason, hotspot files in parallel milestones, "how" written into a milestone, independent milestones left in shared mode, plans that would leave coders idle, a tier no coder reaches, a reviewer weaker than the work, and a model that is not in the catalog. It rejects a lead that is also a worker or the reviewer, and any model the policy does not allow.

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
