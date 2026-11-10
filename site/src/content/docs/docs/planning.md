---
title: Planning
description: How the lead splits a feature into milestones and decides what runs in parallel.
---

The lead researches and plans; coders own the how. Each milestone is written as an issue: Goal, Why, Acceptance criteria, Constraints, Interfaces, Context (facts), Out of scope, Open questions.

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

## What `orch sync` checks

It warns about dependencies without a reason, hotspot files in parallel milestones, "how" written into a milestone, independent milestones left in shared mode, and plans that would leave coders idle. It rejects a lead that is also a worker or the reviewer.

## Open questions

Missing business rules, undefined data shapes and security trade-offs go under **Open questions** with 2 to 3 options. `orch sync` marks such milestones `needs-answer`, and their dependents wait.
