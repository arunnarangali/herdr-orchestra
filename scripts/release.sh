#!/usr/bin/env bash
# Usage: bash scripts/release.sh 4.2.0
# Bumps VERSION, checks CHANGELOG has a section for it, runs tests and commits. No tag needed: when this commit
# reaches main (through a PR), the Release workflow tags vX.Y.Z and publishes the GitHub Release by itself.
set -euo pipefail
cd "$(dirname "$0")/.."
NEW="${1:?usage: scripts/release.sh X.Y.Z}"; NEW="${NEW#v}"
[[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must look like 4.2.0" >&2; exit 1; }
[[ -z "$(git status --porcelain -- . ':!VERSION' ':!CHANGELOG.md')" ]] || { echo "commit your other changes first" >&2; exit 1; }
git rev-parse "v$NEW" >/dev/null 2>&1 && { echo "tag v$NEW already exists" >&2; exit 1; }
grep -q "^## \[$NEW\]" CHANGELOG.md || { echo "add a '## [$NEW] - $(date +%F)' section to CHANGELOG.md first" >&2; exit 1; }
echo "$NEW" > VERSION
bash tests/run.sh
git add VERSION CHANGELOG.md
git commit -m "Release v$NEW"
echo "Committed v$NEW. Push it and merge the PR: the Release workflow tags v$NEW and publishes it."
