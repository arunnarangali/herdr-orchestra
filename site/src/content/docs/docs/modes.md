---
title: Modes
description: Worktree mode runs milestones in parallel; shared mode runs them one at a time in your folder.
---

Set the mode with `Isolation:` in the plan header.

In Pi there is a second, separate choice: where the coder and reviewer run, in Herdr panes (`panes`) or inside one Pi window (`subagent`). See [Pi: setup and use](/docs/pi/#step-4-pick-a-mode).

## Worktree

Each coder works in its own git worktree next to your repo, `../<repo>-wt/<name>`. Independent milestones run at the same time, and each one lands when it passes checks and review.

```text
~/code/app                 # your folder, on feature/csv-import
~/code/app-wt/claude-1     # M2 backend
~/code/app-wt/codex-1      # M3 frontend
```

- Pick it when milestones can be built independently, which is usual with two or more coders.
- Each coder can run a different model, so a small milestone and a high-tier one can run side by side.
- Review is pipelined: coders move on while the reviewer reads.
- `Setup command:` runs once in each new worktree.

## Shared

Everyone works in your folder, one milestone at a time. Two agents in one folder would overwrite each other's files, so this mode is strictly sequential. Unfinished work is parked in the milestone's hidden ref and restored for the next coder, so the tree is clean between milestones.

- Pick it when every milestone depends on the one before, or when you have one coder.
- `orch sync` warns when independent milestones are left in shared mode.
