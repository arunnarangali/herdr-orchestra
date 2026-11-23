---
title: "Install herdr-orchestra with npx"
description: "Install herdr-orchestra with npx herdr-orchestra@latest (or curl), keep it up to date automatically, pick or pin a version, set up new agents, and uninstall."
---

## Install

```bash
npx herdr-orchestra@latest
```

`@latest` is the newest GitHub Release: the npm package is published from every release, not from `main`. After that orch [keeps itself up to date](#updates). An update replaces the skills, it never adds a second copy: each agent reads exactly one `orch-plan` and one `orch-run`, and orch's older copies in other folders are removed (your own skills are left alone). Check it any time with `orch agents check`.

### Without Node

The release script does the same job and needs only curl:

```bash
curl -fsSL https://github.com/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash
```

To install from git instead:

```bash
git clone https://github.com/arunnarangali/herdr-orchestra.git
cd herdr-orchestra && git checkout v4.11.1 && bash install.sh
```

### In Pi

Using [Pi](https://pi.dev)? Add the package with `pi install git:github.com/arunnarangali/herdr-orchestra`, then type `/orch-setup` once inside Pi. The [Pi page](/docs/pi/) has every step, including subagent mode (one Pi window, no Herdr).

### Requirements

- [Herdr](https://herdr.dev), where the agents run
- Node (for `npx`), git and python3 (3.11 or newer for the agent registry; older versions still run plans). Linux and macOS; on Windows use WSL.
- Node also installs the official Herdr skill for your agents

### What it installs

| What | Where |
|---|---|
| `orch` CLI | `~/.local/bin/orch` |
| `orch-plan`, `orch-run` skills | one folder per agent: `~/.agents/skills/` or the agent's own skills folder |
| `/orch-plan`, `/orch-run` slash commands | OpenCode's command folder (in Claude Code the skill is the command) |
| every installed version, side by side | `~/.local/share/herdr-orchestra/` |

## Adding an agent later

Install once. After you install Claude Code, Hermes, Amp or any other agent, run:

```bash
orch agents sync
```

It finds every installed agent, copies the skills and slash commands into its folders, and records them so uninstall removes exactly what was installed. `orch agents check` confirms everything is in place.

## Updates

**Already installed (5.7 or older)? Run `npx herdr-orchestra@latest` once.** That install asks the question below, and from then on orch keeps itself up to date.

The installer asks once:

```
==> Keep herdr-orchestra up to date automatically? [Y/n]
```

Enter means yes. The answer is saved for this machine and is not asked again. With no keyboard (CI, a script) it does not ask and turns it on. For scripts, `--auto-update`, `--no-auto-update` or `ORCH_AUTO_UPDATE=1|0` answer it.

```bash
orch update                    # install the latest release now and show what is new
orch update --check            # only say whether a new version is out
orch update --version v5.8.0   # install that exact version (also how you go back)
orch config                    # auto-update on/off, the installed version, the last check
orch config auto-update off    # or: on
```

| Situation | What orch does |
|---|---|
| Auto-update on, a new plan starts, a newer release is out | Installs it first; the plan runs on the new version |
| A run is going anywhere on this machine | Installs nothing; tries again at the next plan with no run going |
| The new release is a major version (5.x to 6.0) | Shows the notice only; you run `orch update` |
| The repo has a `.orch-version` file | Leaves that pinned version alone |
| The update fails (no network, download cut) | Keeps the version you have, warns once, tries again the next day |
| Auto-update off | Shows one line: `herdr-orchestra 5.8.1 is out (you have 5.8.0). Run orch update.` |

orch asks GitHub for the latest release at most once a day, waits 3 seconds at most, and sends nothing about you or your project. With no internet it stays silent. `ORCH_NO_UPDATE_CHECK=1` turns the check off.

The skills only call `orch`, so an updated `orch` is new logic for every agent at once.

## Versions

Every release is a git tag with a GitHub Release and an npm version, and every installed version is kept, so switching back is instant.

```bash
# install a specific version
npx herdr-orchestra@4.11.1                    # that npm release
npx herdr-orchestra@latest --version v4.11.1  # or download any tag from GitHub

# list versions
npx herdr-orchestra@latest --list

# pin a version for one project: commit this file, then run the installer from that folder
echo v4.11.1 > .orch-version

orch version   # what's active now
```

Version choice, first match wins: `--version` flag, then `ORCH_VERSION`, then `./.orch-version`, then the release the installer came from (the npm package or the release script).

With the curl script, put the options after `bash -s --`, for example `curl -fsSL https://github.com/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash -s -- --list`.

## Uninstall

```bash
npx herdr-orchestra@latest --uninstall
```

This removes `orch`, the skills and the slash commands it installed. The Herdr skill and your projects' `.orchestrate/` folders are left alone.
