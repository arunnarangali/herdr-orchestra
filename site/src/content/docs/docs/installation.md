---
title: Installation
description: Install herdr-orchestra with npx, pick or pin a version, set up new agents, and uninstall.
---

## Install

```bash
npx herdr-orchestra@latest
```

`@latest` is the newest GitHub Release: the npm package is published from every release, not from `main`. Run the same command again to update.

### Without Node

The release script does the same job and needs only curl:

```bash
curl -fsSL https://github.com/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash
```

To install from git instead:

```bash
git clone https://github.com/arunnarangali/herdr-orchestra.git
cd herdr-orchestra && git checkout v4.11.0 && bash install.sh
```

### Requirements

- [Herdr](https://herdr.dev), where the agents run
- Node (for `npx`), git and python3 (3.11 or newer for the agent registry; older versions still run plans). Linux and macOS; on Windows use WSL.
- Node also installs the official Herdr skill for your agents

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

Every release is a git tag with a GitHub Release and an npm version, and every installed version is kept, so switching back is instant.

```bash
# install a specific version
npx herdr-orchestra@4.11.0                    # that npm release
npx herdr-orchestra@latest --version v4.11.0  # or download any tag from GitHub

# list versions
npx herdr-orchestra@latest --list

# pin a version for one project: commit this file, then run the installer from that folder
echo v4.11.0 > .orch-version

orch version   # what's active now
```

Version choice, first match wins: `--version` flag, then `ORCH_VERSION`, then `./.orch-version`, then the release the installer came from (the npm package or the release script).

With the curl script, put the options after `bash -s --`, for example `curl -fsSL https://github.com/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash -s -- --list`.

## Uninstall

```bash
npx herdr-orchestra@latest --uninstall
```

This removes `orch`, the skills and the slash commands it installed. The Herdr skill and your projects' `.orchestrate/` folders are left alone.
