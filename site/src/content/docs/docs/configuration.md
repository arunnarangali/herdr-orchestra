---
title: Configuration
description: Environment variables, the agent registry file, and version selection.
---

## Plan header

Most settings for a run live in the plan header: branch, base, commit style, check and setup commands, mode, team. See [The plan file](/docs/plan-file/).

## Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `ORCH_CODER_BUDGET_MIN` | 45 | Minutes a coder gets per milestone before `TIMEOUT` |
| `ORCH_REVIEW_BUDGET_MIN` | 15 | Minutes the reviewer gets per review |
| `ORCH_CHECK_TIMEOUT_MIN` | 30 | Timeout for the check command |
| `ORCH_COOLDOWN_MIN` | 60 | How long a rate-limited agent is benched |
| `ORCH_GONE_COOLDOWN_MIN` | 10 | Bench for an agent that disappeared; ends early when it's back |
| `ORCH_SEND_RETRY_S` | 120 | Wait before retrying an agent that couldn't be prompted |
| `ORCH_HERDR_TIMEOUT_S` | 30 | Timeout for each Herdr call |
| `ORCH_IDLE_GRACE_S` | 120 | How long an agent may sit idle before it counts as stopped |
| `ORCH_POLL_STEP_S` | 10 | How often `poll` looks for events |
| `ORCH_MAX_TASKS` | 4 | Milestone limit per run |
| `ORCH_AGENTS_FILE` | `~/.config/herdr-orchestra/agents.toml` | Your agent registry overrides |
| `ORCH_VERSION` | | Version the installer picks |
| `HERDR` | `herdr` | Path to the Herdr binary |

## Agent registry

Defaults ship in `agents.default.toml`. Add or change kinds in `~/.config/herdr-orchestra/agents.toml`, merged key by key:

```toml
[claude]
launch = "claude --permission-mode acceptEdits --model opus"

[myagent]
binary = "myagent"
launch = "myagent --auto-approve"
herdr_detect = false
roles = ["coder"]
skills_dirs = ["~/.myagent/skills"]
```

| Key | Meaning |
|---|---|
| `binary` | Executable that must be on `PATH` for the kind to count as installed |
| `launch` | Command to start it in a pane, with edits auto-approved |
| `herdr_detect` | Herdr can tell when it is idle, working or blocked |
| `roles` | Any of `lead`, `coder`, `reviewer` |
| `skills_dirs` | Folders the `orch-plan` / `orch-run` skills are copied into |
| `commands_dirs`, `commands_from` | Slash-command folders and flavour (`claude-commands` or `opencode-commands`) |
| `invoke` | How you start the plan playbook in that agent |

## Version selection

First match wins: the installer's `--version` flag, then `ORCH_VERSION`, then `./.orch-version` in the project, then the release the installer came from. See [Installation](/docs/installation/#versions).
