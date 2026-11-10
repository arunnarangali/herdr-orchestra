---
title: Git, commits and the PR
description: One feature branch per run, one real commit per milestone, and a pull request at the end.
---

A run makes **one branch** and ends in **one pull request**. Nothing else shows up in your branch list or your history.

## The branch

- Planning never touches git.
- `orch start` creates the plan's `Branch:`, `feature/<slug>` (or `fix/<slug>`). It is the only branch a run creates.
- Coders work on detached worktrees. A milestone's work in progress (under review, parked, waiting for a fix) is kept in hidden refs under `refs/orch/<branch>/Mn`. `git branch` doesn't list them and `git push` doesn't send them.
- Coders never commit, push or switch branches themselves.

## The commits

Each landed milestone is one commit. Its subject is the coder's `COMMIT:` line, which says what changed in your repo's style, with a trailer naming the milestone:

```text
feat(api): add POST /imports for bank CSVs

Milestone: M2
```

With `Commits: single` in the plan header, the whole run is squashed into one commit at finish.

## Finishing

```bash
orch finish
```

1. Checks every milestone has landed and the tree is clean.
2. Runs the check command on the feature branch.
3. Squashes, if `Commits: single`.
4. Removes the worktrees and hidden refs.
5. Pushes the branch and opens a PR into `Base:` with `gh`, or prints the compare link if `gh` isn't available.

`orch finish --no-push` only cleans up. Neither the lead nor the script pushes on its own; finishing is always your call.

## Upgrading from 4.4 and earlier

Older versions used an `orch/<slug>` branch plus one branch per milestone. A run in progress keeps its work: an existing `orch/<slug>-Mn` branch is picked up into the hidden ref, and `orch finish` removes the old task branches.
