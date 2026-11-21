Pi-only copies of the orch skills, loaded through package.json `"pi".skills`.

`skills/orch-plan/SKILL.md` has a `description:` with `: ` inside it, which strict YAML parsers (Pi's) reject, so
Pi would skip the skill. This copy has the same text with the description in quotes. Every other agent keeps using
`skills/orch-plan/SKILL.md`, unchanged. `tests/run.sh` checks that the two say the same thing.
