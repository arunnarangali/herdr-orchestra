---
title: Files
description: What herdr-orchestra keeps in your repo and on your machine.
---

## In your repo: `.orchestrate/`

| File | What it is |
|---|---|
| `plan.md` | The orchestration plan: you and the lead edit it |
| `state.json` | Parsed plan plus run state, including the lead's event queue (owned by `orch`; don't edit) |
| `state.lock` | Lock so two `orch` commands can't lose updates |
| `baseline.txt` | The check's output before any work |
| `autopilot.log` | What the event manager did, when it woke the lead, and why it stopped |
| `manager.out` | Output of an event manager that the lead's `orch dispatch` started in the background |
| `events.jsonl` | One line per state change, for `orch report` |
| `driver.lock` | The lease that keeps a run to one driver |
| `review/Mn/review-N.json` (or `.md`) | Each review round's findings |
| `summary.md` | The run summary: commits, files, who did what, the model table (planned tier against the model that ran), estimated vs actual time with the reasons for any delay, design notes, test checklist |

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
| `~/.config/herdr-orchestra/models.toml` | Your model catalog overrides |
| `~/.agents/skills/` or an agent's own skills folder | The `orch-plan` / `orch-run` skills, one copy per agent |
