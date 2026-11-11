---
title: Models and tiers
description: How the lead picks a small, medium or high-reasoning model for each milestone, and how to change the catalog.
---

Not every milestone needs the strongest model. A rename does not need deep reasoning, and a schema change should not go to the fastest, cheapest model. The lead gives every milestone a **tier**, and the run sends it to a coder whose model serves that tier.

## The three tiers

| Tier | Use it for | Examples from the default catalog |
|---|---|---|
| **small** | Classification, renames, docs, config, mechanical edits that copy an existing pattern | `haiku`, `gpt-6-luna`, `qwen3.6-35b-a3b` |
| **medium** | Normal implementation, tests, debugging inside one module | `sonnet`, `gpt-6-sol`, `qwen3.8-27b` |
| **high** | The lead itself, contracts and architecture, refactors across modules, auth, payments and schema, bugs nobody has diagnosed | `opus`, `deepseek-v4-pro`, `glm-5.3` |

You use the models your installed agents already reach. Nothing new has to be set up. Open-weight models are in the catalog too, for teams that run them locally or through a provider.

## Chosen by capability, not by name

`orch models` prints the catalog. Each model is rated 1 to 5 on:

| Rating | What it means |
|---|---|
| `reasoning` | Multi-step problem solving, debugging without a hint, weighing trade-offs |
| `coding` | Writing and fixing code that passes its checks |
| `architecture` | Design across modules, contracts between parts, large refactors |
| `instructions` | Follows the task file, the scope and the output format reliably |
| `tools` | Tool calling and long agentic sessions without getting lost |
| `planning` | Breaking a goal into steps and keeping to them |
| `speed` | 5 is the fastest and cheapest to run |
| `context_k` | Context window, in thousands of tokens |

**Reasoning sets the ceiling.** A model may serve a tier only when its reasoning rating reaches that tier's floor (3 for medium, 4 for high). Strong coding alone never makes a model high-tier.

Every entry has an `evidence` line saying where its ratings come from. `orch models show <id>` prints it. The defaults are starting points, not benchmarks run by this project.

## In the plan

Each coder carries the model its pane runs, and each milestone says what it needs and why:

```markdown
Lead: lead (claude: opus)
Workers: claude-1 (claude: sonnet), claude-2 (claude: haiku)
Reviewer: reviewer (claude: opus)

## [x] M2: Import endpoint
Tier: medium
Needs: coding, tool-use
Model why: one module, a clear contract, an existing endpoint to copy; no design decisions.
```

`Needs` can list `reasoning`, `coding`, `architecture`, `long-context`, `tool-use`, `planning` and `speed`. `Model why` is one line you can check.

`orch agents launch claude --model haiku` prints the command that starts a pane on a model.

## What happens with a tier

- **Dispatch.** A milestone goes to a free coder of its tier. If none is free, a stronger one takes it. It never goes to a weaker coder while a suitable one exists.
- **Escalation.** A milestone that runs out of fix or review rounds gets one fresh round on a coder with a stronger model, with the work so far. Only then does it fail.
- **The lead can raise it.** `orch dispatch M2 --tier high` asks for a stronger model than the plan did.
- **Checks in `orch sync`.** It warns when no coder reaches a milestone's tier, when the reviewer is weaker than the work it reviews, when the lead is not on a high-tier model, and when a model is not in the catalog.

## Models kept out of runs

The catalog's policy denies ultra-premium models: any id matching `*fable*` or `*astra*`. `orch sync` refuses a plan that names one, and `orch agents launch` will not build the command. Everything else is allowed.

```bash
orch models check fable     # DENIED
orch models check sonnet    # OK sonnet: tier medium
```

## Planned against actual

The plan says what should happen; the run records what did.

- `.orchestrate/summary.md` has a table: each milestone's planned tier, the model that really did the work, whether it was escalated, and the lead's reason.
- `orch report` adds a row per model: milestones, tries, merged, first pass, and how many it had to hand up to a stronger model.

When a model does worse than its rating, lower the rating. Nothing changes ratings for you.

## Change the catalog

Add or re-rate models in `~/.config/herdr-orchestra/models.toml`. It is merged over the defaults key by key.

```toml
[models."my-provider/qwen3.8-27b"]
kinds = ["opencode"]
tier = "medium"
reasoning = 3
coding = 4
context_k = 262
evidence = "my own runs, 2026-11"

[models.sonnet]
architecture = 4              # re-rate one field

[policy]
deny = ["*fable*", "*astra*", "opus"]   # your own list
```

A model that is not in the catalog still works. It has no tier, so it can take any milestone, and `orch sync` says so.
