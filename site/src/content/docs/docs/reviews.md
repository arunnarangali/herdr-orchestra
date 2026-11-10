---
title: Checks, reviews and fixes
description: How a coder's work is checked and reviewed, and what happens when something fails.
---

## Checks

Your `Check command:` runs on every coder's result. Before the run starts it is saved as a baseline in `.orchestrate/baseline.txt`; the script needs it to pass, the lead can work with "no new failures".

A failing check goes back to the coder with the last 60 lines of output: "These checks fail. Diagnose and fix; you decide how. Don't weaken or skip tests." Up to 3 rounds, then the milestone is parked as failed and the work is kept.

After each milestone lands in worktree mode, the check runs again on the feature branch, so a merge that breaks something is caught right away.

## Reviews

A milestone with `Review: yes` goes to the reviewer once its checks pass. The reviewer gets the diff from the merge-base and reports only problems:

```text
BLOCKER: server/imports/parse.ts:41 — missing amount column returns 500 — the plan says 400
SUGGESTION: web/src/pages/Import.tsx:88 — the preview re-renders on every keystroke
```

- **No blockers:** the review passes. Suggestions are kept for the summary.
- **Blockers:** they become a problem-only **fix job** for the next free coder, preferring the one who built it. Up to 2 rounds.

### Review pipelining

In worktree mode the coder is freed as soon as its checks pass: the work is saved to a hidden ref and the coder takes the next ready milestone while the reviewer reads. Fix jobs are dispatched before new milestones.

## Conflicts

If a milestone no longer merges cleanly because others landed first, a conflict job goes to a coder: merge the feature branch in its worktree and resolve it so both sides keep working. Up to 2 rounds.

## Other things handled for you

| Situation | What happens |
|---|---|
| A coder hits a usage limit | It is benched for 60 minutes; another coder continues with the work so far |
| An agent disappears | A coder's task moves on with its work; for the reviewer only the review waits. It is used again as soon as it's back |
| A prompt can't be delivered | The task goes back in the queue and that agent is retried after 2 minutes |
| A permission prompt | You get a desktop alert; other tasks keep running |
| An agent stops early | It is nudged once, then the task is parked |
| A coder writes `QUESTION:` | That task and its dependents wait; everything else continues |
