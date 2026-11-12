---
title: Configuration
description: Environment variables, the agent registry, the model catalog, and version selection.
---

## Plan header

Most settings for a run live in the plan header: branch, base, commit style, check and setup commands, mode, the team and its models, and whether the lead takes part in the run (`Lead mode:`). See [The plan file](/docs/plan-file/).

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
| `ORCH_MAX_TASKS` | unset | Optional: `orch sync` warns above this many milestones. By default there is no limit; the feature decides |
| `ORCH_MAX_LOST` | 4 | Attempts a milestone may lose to unreachable or rate-limited agents before it fails |
| `ORCH_RISK_MAX_LINES` | 1500 | Diff size above which a milestone is held for approval |
| `ORCH_LEAD_WAIT_MIN` | 15 | Ready milestones the lead has not dispatched start by themselves after this |
| `ORCH_LEAD_REWAKE_S` | 300 | Wake the lead again if it has not read its events |
| `ORCH_LEAD_MAX_WAKES` | 3 | Wake-ups for one batch before you are notified instead |
| `ORCH_LEAD_IDLE_MAX_MIN` | 720 | How long the event manager waits for an answer before it stops |
| `ORCH_NO_AUTOSTART` | | Set to `1` and `orch dispatch` / `orch answer` never start the event manager |
| `ORCH_AGENTS_FILE` | `~/.config/herdr-orchestra/agents.toml` | Your agent registry overrides |
| `ORCH_MODELS_FILE` | `~/.config/herdr-orchestra/models.toml` | Your model catalog overrides |
| `ORCH_VERSION` | | Version the installer picks |
| `HERDR` | `herdr` | Path to the Herdr binary |

## Agent registry

Defaults ship in `agents.default.toml`. Add or change kinds in `~/.config/herdr-orchestra/agents.toml`, merged key by key:

```toml
[claude]
launch = "claude --permission-mode acceptEdits"
model_flag = "--model"

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
| `model_flag` | The option that picks the model, used by `orch agents launch <kind> --model <id>`. Leave it out when the tool has none |
| `herdr_detect` | Herdr can tell when it is idle, working or blocked |
| `roles` | Any of `lead`, `coder`, `reviewer` |
| `skills_dirs` | Folders the `orch-plan` / `orch-run` skills are copied into |
| `commands_dirs`, `commands_from` | Slash-command folders and flavour (`claude-commands` or `opencode-commands`) |
| `invoke` | How you start the plan playbook in that agent |

## Model catalog

Defaults ship in `models.default.toml`. Add or re-rate models, or change the policy, in `~/.config/herdr-orchestra/models.toml`, merged key by key:

```toml
[models."my-provider/qwen3.8-27b"]
kinds = ["opencode"]
tier = "medium"
reasoning = 3
coding = 4
context_k = 262
evidence = "my own runs, 2026-11"

[policy]
deny = ["*fable*", "*astra*"]
```

| Key | Meaning |
|---|---|
| `kinds` | Agent kinds that can run the model |
| `tier` | `small`, `medium` or `high`. Lowered automatically when `reasoning` is under that tier's floor |
| `reasoning`, `coding`, `architecture`, `instructions`, `tools`, `planning`, `speed` | Ratings from 1 to 5 |
| `context_k` | Context window in thousands of tokens |
| `open_weights` | The weights can be downloaded and self-hosted |
| `evidence` | Where the ratings come from |
| `[policy] deny` | Patterns for models nobody in a run may use |
| `[tiers]` | The reasoning floor of each tier |

See [Models and tiers](/docs/models/).

## Version selection

First match wins: the installer's `--version` flag, then `ORCH_VERSION`, then `./.orch-version` in the project, then the release the installer came from. See [Installation](/docs/installation/#versions).
