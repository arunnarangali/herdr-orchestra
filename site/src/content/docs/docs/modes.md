---
title: Modes and branches
description: Worktree and shared modes, and how a run uses one feature branch and a pull request.
---

## Modes

- **worktree:** each coder works in `../<repo>-wt/<name>`. Independent milestones run in parallel, and each lands when it passes checks and review. Start each coder inside its own worktree.
- **shared:** everyone works in your folder, one milestone at a time. Two agents in one folder would overwrite each other's files, so this is only safe sequentially. Use it when every milestone depends on the previous one.

## Branches

A run lives on one `feature/<name>` branch.

- The branch is created when work starts.
- Each milestone lands as a real commit with a normal commit message. There are no bookkeeping branches and no milestone-labelled commits in your history.
- Milestones in progress are kept out of your branch list.
- When every milestone is in, the branch is pushed and a pull request is opened for you to review and merge.

:::note
This feature-branch flow is the intended behavior and is landing in an upcoming release. Earlier versions (4.4 and before) used an `orch/<slug>` integration branch that you merged yourself.
:::
