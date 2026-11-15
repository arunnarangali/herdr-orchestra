---
title: Quick runs for small changes
description: How orch handles a small change, UI or backend, without the full planning and review process, and how the lead decides a change is small.
---

The full process (research, a milestone breakdown, roles, tiers, a reviewer) is built for features. A small change, such as a button colour, a new field in an API response, a validation rule or a bug fix in one function, gets a **quick run** instead. It keeps what protects you and drops what only big work needs.

## What changes

| Step | Full run | Quick run |
|---|---|---|
| Research | The whole area the feature touches | Only the files the change touches |
| Plan | Breakdown, and per milestone: role, tier, needs, model why, estimate, interfaces | One milestone: goal, one acceptance criterion per change, files, tier, estimate, and **why it is small** |
| You say go | Yes | Yes |
| Folder | Worktrees and their setup when work runs in parallel | Your folder as it is (`Isolation: shared`, no setup) |
| Agents | Coders and a reviewer | One coder. A reviewer only if you ask (`quick review:`) |
| Check | Before work, after the coder, after each merge, at the end, and in `orch finish` | Before work and after the coder. The final check and `orch finish` reuse that result when the files are exactly the same |
| Summary | Design notes, what the lead checked, your checklist | What changed (one line each, with how it was checked) and your checklist |

Several small changes go into one quick run: one acceptance criterion for each. After it lands, more small changes go straight to the same coder with `orch fix M1 "<change>"`, with no new plan.

## How the lead decides

The lead decides **after reading the code**, not from how the request sounds. A quick run needs all four:

1. **One coder, one go.** Nothing in it earns its own milestone: no part to build in parallel, no foundation, not too big for one sitting.
2. **Clear.** No open questions about what you want.
3. **Out of risky areas.** No database schema or migration, auth, login or permissions, payments or billing, new or upgraded packages, CI, secrets or `.env` files.
4. **Follows what is there.** It copies a pattern the code already has, and doesn't change how two parts talk to each other (an API shape another app depends on, shared types).

There is no rule about how many files or lines. The same words can go either way:

| Request | What the lead finds | Run |
|---|---|---|
| "Add `createdAt` to GET /orders" | The column exists; only the response changes | quick |
| "Add `discount` to GET /orders" | No discount column: a migration and a new calculation | full |

The plan says why, e.g. `Quick because: orders.created_at already exists; only the GET /orders response changes, no schema, auth or payment code`. Say **full** if you disagree.

## You can choose

```
/orch-plan quick: make the Save button blue and add a spinner on the dashboard
/orch-plan quick review: reject an empty email on signup with a 400
/orch-plan full: add createdAt to GET /orders
```

With `quick:` the lead still checks the four points. If one fails, it tells you which one and why, and plans in full unless you insist. A risky change is never quick: `orch sync` refuses a quick plan that lists migrations, CI, secrets or dependency files, and warns when a file looks like auth, payment or schema code.

## What stays the same

- **Checks.** Nothing lands on the branch unless the check command passes.
- **Risk hold.** If the coder's change turns out to delete files, touch a migration, CI or secrets, change dependencies or grow very large, it waits for your `orch approve`, as in any run.
- **Scope.** Files changed outside the plan's `Likely files` are listed in the summary.
- **Questions.** A coder's question still pauses the work and reaches you through the lead.
- **Git.** One `feature/` or `fix/` branch, and `orch finish` opens the PR.

## A quick plan

```
# Plan: Orders show when they were created
Mode: quick
Quick because: orders.created_at already exists and the serializer lists fields; only the response changes
Branch: feature/orders-created-at
Check command: npm test
Setup command: none
Isolation: shared
Estimate: 20m
Lead: lead (claude: opus)
Workers: claude-1 (claude: sonnet)
Reviewer: none

## Global instructions
none

## [x] M1: Return createdAt from GET /orders
Depends on: none
Tier: small
Estimate: 20m
Review: no
Likely files: src/orders/serializer.ts, src/orders/serializer.test.ts
Goal: GET /orders returns when each order was created.
Acceptance criteria:
- GET /orders returns `createdAt` for each order as ISO 8601; a test covers it
Context:
- Fields are listed in `src/orders/serializer.ts`; tests sit next to it
Open questions:
- none
```

`orch status` starts with `QUICK RUN because: …`, and the summary repeats the reason.
