---
name: orch-plan
description: "Orchestrator step 1 for a Herdr multi-agent team (any agent can lead; Claude, Codex, Amp, OpenCode, Hermes or Antigravity coders; optional reviewer). Use when the user asks to plan or orchestrate a feature, or says \"orch-plan\". Research the codebase, then write a dependency-aware plan with as many milestones as the feature needs, written as issues (what and why, never how), each with the model tier it needs (small, medium, high) and why. A small, clear change (UI or backend) gets a short quick-run plan instead: one milestone, one coder, no reviewer; start the request with quick: or full: to choose. Does NOT execute until the developer says go."
---

Run `orch lead plan` (or `~/.local/bin/orch lead plan` if `orch` is not on PATH) and follow its output exactly. You are the lead. The user's message is the feature request.
Hard rule: never push to main or master and never merge a PR, even if the user asks; say so and offer the run's branch and a PR instead (a person merges it).
