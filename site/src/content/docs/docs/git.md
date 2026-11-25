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
- The branch is never `main` or `master` (see below).

## Nobody's agent pushes to main

This is a hard rule. No agent (the lead, the coders, the reviewer, on any tool) pushes to `main`, `master` or the repo's default branch, or merges a PR, in any situation, **even when you ask it to**. It refuses and offers the run's branch and a PR instead, which you merge by hand.

```text
You:  just push this to main
Lead: I can't push to main, even when asked: that's a hard rule of this setup.
      The work is on feature/csv-import; `orch finish` pushes that branch and
      opens a PR, and you merge it yourself.
```

- **orch refuses it:** `orch sync` won't accept `Branch: main` (or `master`), and `orch start` and `orch finish` never work on or push such a branch.
- **git refuses it:** `orch start` installs a pre-push guard in `.git/hooks/pre-push`, which every coder's worktree shares. It refuses any push that would change `main`, `master`, the remote's default branch, or a branch you add with `git config --add orch.protected <branch>`. That covers `git push origin main`, `git push origin HEAD:main`, force pushes, `git push --all` and deleting main. A pre-push hook you already had is kept and still runs after the guard.
- **You can check it:** `orch guard status` (or `orch doctor`) says whether the guard is on, and, when `gh` is installed, whether GitHub protects `main`. `orch guard` installs it by hand. If your repo keeps its hooks inside the project (husky), orch doesn't write there: `orch guard --print` gives the script to add yourself.

A git hook can be skipped (`--no-verify`) and `gh pr merge` doesn't push at all. The agents are told never to do either, but the lock nobody can get around is on GitHub: **Settings > Rules > Rulesets > New branch ruleset**, target `main`, with "Require a pull request before merging" and "Block force pushes".

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

**No AI credit.** The run's commits are yours: orch makes them with your git name, and adds no `Co-Authored-By: Claude` or "Generated with" line. The PR text is `.orchestrate/pr-body.md`: the summary without any such line (`summary.md` itself stays as written). If an agent made a commit by itself with its own credit, `orch finish` names it (`WARN 1 commit(s) ... credit an AI tool`) so you can reword it before you push. To stop your own Claude Code adding the line to commits you make yourself, set `"includeCoAuthoredBy": false` in `~/.claude/settings.json`.

`orch finish --no-push` only cleans up. Neither the lead nor the event manager pushes on its own; finishing is always your call.

## Upgrading from 4.4 and earlier

Older versions used an `orch/<slug>` branch plus one branch per milestone. A run in progress keeps its work: an existing `orch/<slug>-Mn` branch is picked up into the hidden ref, and `orch finish` removes the old task branches.
