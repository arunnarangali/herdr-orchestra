---
title: Writing a feature request
description: What to tell the lead so the plan comes out right the first time.
---

The lead plans from your request and the code. The more of these you give, the fewer open questions come back.

| Part | What to write | Example |
|---|---|---|
| **Feature** | The outcome, in a sentence | CSV import for transactions |
| **Why** | The user or business reason | Users copy rows from their bank by hand |
| **Must** | Things the result has to do | `POST /imports`; an import page; errors per row |
| **Must not** | Hard limits | No new packages; don't change the transactions table |
| **Already decided** | Choices you've made | Use the existing upload limit (10 MB) |
| **Done when** | How you'll know | A bank CSV shows up as transactions with no manual edits |
| **Mode** | `worktree` or `shared` (optional) | worktree |

## Example

```text
/orch-plan CSV import for transactions.
Why: users copy rows from their bank by hand.
Must: POST /imports that accepts a CSV; an import page with a preview.
Must not: add packages; change the transactions schema.
Already decided: reuse the 10 MB upload limit.
Done when: a bank CSV becomes transactions, and bad rows show an error.
```

## What happens to it

- Your "Must not" and "Already decided" lines become **Global instructions** and **Constraints** that every coder sees.
- Anything the lead can't decide from the code (a business rule, a data shape, a security trade-off) becomes an **Open question** with 2 or 3 options. The milestone waits until you answer.
- A clear request also saves questions later. When a coder asks something during the run, the lead answers it from your request if it can, and only comes to you when it can't.
- A feature too big for 4 milestones comes back as a proposal to split it into separate runs.
