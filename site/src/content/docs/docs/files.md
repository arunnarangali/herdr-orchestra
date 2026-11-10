---
title: Files
description: What herdr-orchestra keeps in your repo and on your machine.
---

## In your repo: `.orchestrate/`

| File | What it is |
|---|---|
| `plan.md` | The plan: you and the lead edit it |
| `state.json` | Parsed plan plus run state (owned by `orch`; don't edit) |
| `state.lock` | Lock so two `orch` commands can't lose updates |
| `baseline.txt` | The check's output before any work |
| `autopilot.log` | What the script did and why it stopped |
| `review/Mn/review-N.md` | Each review round's findings |
| `summary.md` | The run summary: commits, files, who did what, design notes, test checklist |

Each coder's worktree also has a `.orch-task/` folder with its task file, fix files, report and done file. Both folders are kept out of your commits.

## In git

- The run's branch, `feature/<slug>`.
- Hidden refs under `refs/orch/<branch>/Mn` for work in progress. Not branches, never pushed, removed by `orch finish`.

## On your machine

| Path | What it is |
|---|---|
| `~/.local/bin/orch` | The CLI |
| `~/.local/share/herdr-orchestra/` | Every installed version, the active one, and the install manifest |
| `~/.config/herdr-orchestra/agents.toml` | Your agent registry overrides |
| `~/.agents/skills/`, each agent's skills folder | The `orch-plan` / `orch-run` skills |
