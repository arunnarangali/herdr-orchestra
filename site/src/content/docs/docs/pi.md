---
title: "Use herdr-orchestra in Pi, step by step"
description: "Install herdr-orchestra as a Pi package, set up the orch command, pick panes or subagent mode, and run your first plan from inside Pi."
---

herdr-orchestra is also a [Pi](https://pi.dev) package. Inside Pi you get the `orch-plan`, `orch-run` and `orch-explain` skills, two commands (`/orch-setup` and `/orch-mode`), and a footer line that shows which mode you are in (`orch: panes` or `orch: subagent`).

You can run orch from Pi in two ways:

| Mode | Where the coder and reviewer run | Needs Herdr | Who drives the run |
|---|---|---|---|
| `panes` (default) | in Herdr panes next to Pi, like every other agent | yes | the event manager; Pi is the lead, it dispatches and pauses |
| `subagent` | inside the same Pi window, as Pi subagents ([pi-subagents](https://www.npmjs.com/package/@tintinweb/pi-subagents)) | no | Pi, the lead, one milestone at a time |

Pick `panes` when you want coders working in parallel. Pick `subagent` when you want everything in one Pi window and don't mind it being slower.

## Step 1: install Pi

Skip this if `pi` already runs in your terminal.

```bash
npm install -g @earendil-works/pi-coding-agent
```

## Step 2: add the herdr-orchestra package to Pi

In a normal terminal (Pi can be open or closed):

```bash
pi install git:github.com/arunnarangali/herdr-orchestra
```

This takes the package straight from GitHub. To pin a version, add its tag, for example `pi install git:github.com/arunnarangali/herdr-orchestra@v6.7.1` (every tag is on the [Releases page](https://github.com/arunnarangali/herdr-orchestra/releases)).

`pi install npm:herdr-orchestra` gives you the same files from npm, but use the GitHub command for now: the npm copy can lag behind the newest release.

## Step 3: install the orch command from inside Pi

Open Pi in your project folder (`pi`). The first time, Pi shows a warning that the `orch` command is not installed yet (or is older than the package). Type:

```text
/orch-setup
```

It runs this package's installer: the `orch` command goes to `~/.local/bin/orch` and the skills are copied for your other agents too. It turns automatic updates on; `orch config auto-update off` turns them off. You only do this once per machine.

Check it worked, in any terminal:

```bash
orch version
```

It should print the same version as the package. If Pi still says the orch command is older, type `/orch-setup` again.

Pi may warn once that `orch-plan` / `orch-run` were found twice: the installer also puts them in `~/.agents/skills` for Codex, Amp and OpenCode. Pi keeps one copy and works normally.

## Step 4: pick a mode

Type `/orch-mode` alone to see the current mode and where it came from. The footer shows it too.

### Panes mode (the default)

Nothing to set up in Pi. If you switched before, go back with:

```text
/orch-mode panes
```

You need [Herdr](https://herdr.dev): run Pi as the lead in one Herdr pane, and the coders and reviewer in other panes, as in the [Quick start](/docs/quick-start/). With only Pi open, the lead builds the team itself and `orch team up` opens the panes when you say go (see [One tool, whole team](/docs/agents/#one-tool-whole-team)).

### Subagent mode (one Pi window)

Type:

```text
/orch-mode subagent
```

That one command does the whole setup inside Pi, with no terminal step:

1. installs or updates the `orch` command if it is missing or old,
2. writes the `coder` and `reviewer` agents to `~/.pi/agent/agents/coder.md` and `reviewer.md` (the reviewer cannot edit files),
3. installs `npm:@tintinweb/pi-subagents`, which gives Pi the `Agent` tool,
4. reloads Pi so the `Agent` tool is ready at once.

It ends with:

```text
Done: subagent mode is ready. Plan with /orch-plan as usual.
```

If it says `Subagent setup is not finished`, fix what it lists and type `/orch-mode subagent` again. `/orch-setup --mode subagent` does the same job. Without Pi open, the terminal command is `orch setup --mode subagent`; restart Pi after it.

Both agents' descriptions say they are only for orch runs, so a normal Pi chat ("fix this typo") does not hand its work to them. When a newer orch changes their text, `orch lead run` and `orch sub next` refresh the two files by themselves and print `UPDATED <file>`. A file you edited yourself (with orch's line removed) is never touched.

## Step 5: plan and run

In Pi, in your project folder, start the plan:

```text
/skill:orch-plan add CSV import to the contacts page
```

(Plain words work too: "use the orch-plan skill: add CSV import to the contacts page".)

The lead reads the code, may ask you a few questions in one message, and writes the plan. Read it, then say **go**.

- **Panes mode:** the run works as everywhere else; see [How a run works](/docs/workflow/).
- **Subagent mode:** the plan's team is `Workers: coder (pi)`, `Reviewer: reviewer (pi)`, `Isolation: shared`. The lead then repeats for each milestone:

```text
orch sub next      the next milestone and its task file
coder subagent     builds it
orch check Mn      failures go back to the same coder
reviewer subagent  when the milestone has Review: yes
orch sub done Mn   orch commits it on the feature branch
```

After each milestone the lead writes one plain line, for example `M1 (Model) is saved on the branch: check PASS, review found nothing. Starting M2 (Endpoint).` Risky changes still wait for your `orch approve Mn`. At the end you get the summary; run `orch finish` to push the branch and open the pull request.

A run keeps the mode it was planned in. Switching with `/orch-mode` while a run is going only changes the mode for new runs.

## Step 6 (optional): pick the subagents' models

The mode and the subagent settings live in `~/.config/herdr-orchestra/config.json`. The mode is saved per agent, so `subagent` here is Pi's only: every other agent that leads (Claude Code, Codex, Antigravity, ...) stays in panes mode.

```json
{
  "modes": { "pi": "subagent" },
  "subagent": {
    "coder":    { "model": "anthropic/claude-sonnet-4-5", "thinking": "medium", "max_turns": 80 },
    "reviewer": { "model": "openai/gpt-5", "thinking": "high" }
  }
}
```

- `model` and `thinking`: with none set, the subagents use the lead's model. A model the policy denies (`orch models check <id>`) is refused.
- `modes`: the mode per agent. Only `pi` can be `subagent`; any agent not listed uses panes. An older file with one `"mode": "subagent"` is read as Pi's. `ORCH_MODE=panes` (or `subagent`, in Pi) overrides it for one command.
- `max_turns`: stops a subagent that loops after that many turns. The lead resumes it once, then asks you. Not set means no limit.

Run `/orch-mode subagent` (or `orch setup --mode subagent`) again after you change this file, so the agent files pick up the new models.

## Quick reference

| You type (in Pi) | What it does |
|---|---|
| `/orch-setup` | installs or updates the `orch` command from the package (once per machine) |
| `/orch-setup --mode subagent` | the same, and sets up subagent mode |
| `/orch-mode` | shows the current mode |
| `/orch-mode panes` | switch to panes mode (needs Herdr) |
| `/orch-mode subagent` | switch to subagent mode and set it up |
| `/skill:orch-plan <feature>` | start a plan; say go to run it |

## When something is off

| What you see | What to do |
|---|---|
| Typing `/orch-setup` does nothing, or Pi says the command is unknown | The package in Pi is old. Run `pi install git:github.com/arunnarangali/herdr-orchestra` again, then restart Pi |
| `orch` prints only `usage: orch <command>` | An old orch is installed. Type `/orch-setup` in Pi |
| `NO PI` during setup | `pi` is not on your PATH. Install it (step 1) and try again |
| The lead says the `Agent` tool is missing | Type `/orch-mode subagent`; it installs pi-subagents and reloads Pi |
| `This repo's run stays panes` | A run is in progress in this repo. New runs use the new mode |
