---
title: Configuration
description: Environment variables, the agent registry, the model catalog, and version selection.
---

## Plan header

Most settings for a run live in the plan header: branch, base, commit style, check and setup commands, mode, the team and its models, and whether the lead takes part in the run (`Lead mode:`). See [The plan file](/docs/plan-file/).

## Pi mode file

`~/.config/herdr-orchestra/config.json` holds the mode per agent (`"modes": {"pi": "subagent"}`; only Pi has a subagent mode, every other agent uses panes) and the subagents' `model`, `thinking` and `max_turns`. See [Pi: setup and use](/docs/pi/#step-6-optional-pick-the-subagents-models).

## Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `ORCH_AGENT` | found by itself | Which agent runs `orch` (`pi`, `claude`, `codex`, `agy`, ...), when orch can't tell from the agent's own `AI_AGENT` / `PI_CODING_AGENT` / `CLAUDECODE` / `CODEX_*`. Picks the mode saved for that agent |
| `ORCH_MODE` | unset | `panes` or `subagent` for one command, over the saved mode. `subagent` only works in Pi |
| `ORCH_CODER_BUDGET_MIN` | 45 | Minutes a coder gets per milestone before `TIMEOUT` |
| `ORCH_REVIEW_BUDGET_MIN` | 15 | Minutes the reviewer gets per review |
| `ORCH_CHECK_TIMEOUT_MIN` | 30 | Timeout for the check command |
| `ORCH_COOLDOWN_MIN` | 60 | How long a rate-limited agent is benched |
| `ORCH_GONE_COOLDOWN_MIN` | 10 | Bench for an agent that disappeared; ends early when it's back |
| `ORCH_SEND_RETRY_S` | 120 | Wait before retrying an agent that couldn't be prompted (a reviewer herdr can't find is retried as soon as herdr sees it again) |
| `ORCH_HERDR_TIMEOUT_S` | 30 | Timeout for each Herdr call |
| `ORCH_IDLE_GRACE_S` | 120 | How long an agent may sit idle before it counts as stopped |
| `ORCH_POLL_STEP_S` | 10 | How often `poll` looks for events |
| `ORCH_MAX_TASKS` | unset | Optional: `orch sync` warns above this many milestones. By default there is no limit; the feature decides |
| `ORCH_MAX_LOST` | 4 | Attempts a milestone may lose to unreachable or rate-limited agents before it fails |
| `ORCH_RISK_MAX_LINES` | 1500 | Diff size above which a milestone is held for approval |
| `ORCH_LEAD_WAIT_MIN` | 15 | Ready milestones the lead has not dispatched start by themselves after this |
| `ORCH_DOWN_MIN_S` | 120 | An event manager silent for longer than this was down (computer off, herdr closed). That time is not counted against any task |
| `ORCH_LEAD_CONFIRM_S` | 30 | A wake-up the lead did not pick up (idle again, events unread) is sent again after this; the wait doubles each time |
| `ORCH_LEAD_REWAKE_S` | 300 | The longest wait before a wake-up is sent again, and the wait for a lead herdr can't watch |
| `ORCH_LEAD_SETTLE_S` | 300 | At the end of a run, how long the event manager stays up for a busy lead to pick up the last events |
| `ORCH_LEAD_MAX_WAKES` | 3 | Wake-ups for one batch before you are notified instead |
| `ORCH_LEAD_IDLE_MAX_MIN` | 720 | How long the event manager waits for an answer before it stops |
| `ORCH_COMPACT` | | `0` or `1`: overrides `orch config compact on\|off` for this shell |
| `ORCH_COMPACT_SETTLE_S` | 10 | After `/compact`, how long herdr must show the agent idle before it takes new work |
| `ORCH_COMPACT_MAX_S` | 300 | Still working this long after `/compact`: orch stops waiting for it and says so |
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
review_launch = "claude --permission-mode acceptEdits --disallowedTools Edit,NotebookEdit"
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
| `review_launch` | Optional: the command for the reviewer pane, with the tool's edit tools off (Claude Code: `--disallowedTools Edit,NotebookEdit`). `orch team up` uses it; `orch agents launch <kind> --role reviewer` prints it. Your own `launch` without a `review_launch` is used for the reviewer too |
| `model_flag` | The option that picks the model, used by `orch agents launch <kind> --model <id>`. Leave it out when the tool has none |
| `herdr_detect` | Herdr can tell when it is idle, working or blocked |
| `compact` | The command that shrinks the tool's chat to a short summary (`/compact` for Claude Code, Codex and AGY). orch types it into a coder's or the reviewer's pane between milestones. Leave it out (or `""`) where it is not known to work. See [Compact between milestones](/docs/agents/#compact-between-milestones) |
| `compact_min_version` | The first version of the tool that has that command (AGY: `1.2.15`). An older or unreadable `--version` means no compacting, said once in `orch story` |
| `roles` | Any of `lead`, `coder`, `reviewer` |
| `skills_dirs` | Folders the `orch-plan` / `orch-run` / `orch-explain` skills are copied into |
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
