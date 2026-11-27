#!/usr/bin/env bash
# End-to-end tests for orch + autopilot, using a fake herdr and fake workers. No AI, no network.
# shellcheck disable=SC2034  # variables are read inside the eval strings passed to check()
#   bash tests/run.sh
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ORCH="$ROOT/bin/orch"
export HERDR="$ROOT/tests/sim/herdr" ORCH_POLL_STEP_S=1 ORCH_IDLE_GRACE_S=4 ORCH_BIN="$ORCH" ORCH_LEAD_CONFIRM_S=3
WORK=$(mktemp -d); trap 'pkill -f -- "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
export ORCH_AGENTS_FILE="$WORK/user-agents.toml"   # keep the developer's own agents.toml out of the tests
export ORCH_MODELS_FILE="$WORK/user-models.toml" ORCH_NO_AUTOSTART=1   # ...and their models.toml; no stray managers
# the computer's own logs are not read in tests (each crash test gives its own fake), and managers start plainly
export ORCH_JOURNALCTL=false ORCH_COREDUMPCTL=false ORCH_NO_SCOPE=1 ORCH_TEAM_CONFIRM_S=0.3
# no test asks the network for a new version, waits for a keyboard, or writes into the developer's own install
export ORCH_NO_UPDATE_CHECK=1 ORCH_TTY=/dev/null ORCH_SHARE="$WORK/share"
# ...nor asks an installed codex for its models: the shipped catalog is used (section 54 tests the asking)
export ORCH_MODELS_DISCOVER=0
# ...nor asks GitHub whether main is protected (section 55 tests the asking with a fake gh)
export ORCH_GUARD_GITHUB=0
# ...nor takes a run another section left going for a run of the developer's that uses the same agent names
# (section 61 tests that check)
export ORCH_NAME_CHECK=0
# ...nor into their orch config (mode) or their Pi agents folder
export ORCH_CONFIG_FILE="$WORK/config/config.json" PI_CODING_AGENT_DIR="$WORK/pi-agent" ORCH_PI="$WORK/pibin/pi"
# ...nor takes the agent running the tests (Claude Code, Pi, Codex) as the agent under test: each test says its agent
unset ORCH_AGENT ORCH_MODE AI_AGENT PI_CODING_AGENT CLAUDECODE OPENCODE
# a coder told to stop: short waits (section 49 tests the real behaviour with its own values)
export ORCH_HALT_WAIT_S=2 ORCH_HALT_SETTLE_S=1
# a coder or reviewer that got /compact between milestones: free again 1s after herdr shows it idle (section 59)
export ORCH_COMPACT_SETTLE_S=1
pass=0 fail=0
ok()   { echo "  ok   $*"; pass=$((pass+1)); }
bad()  { echo "  FAIL $*"; fail=$((fail+1)); }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }
# qgrep: grep that reads all of its input. `cmd | grep -q x` stops reading at the first match, so a busy machine can
# make cmd fail with "Broken pipe" while it is still writing, and pipefail then fails the check for nothing
qgrep(){ grep "$@"; local r=$?; cat >/dev/null; return $r; }

newrepo() {  # newrepo <name> ; sets APP and FH
  APP="$WORK/$1/app"; export FH="$WORK/$1/fh"; mkdir -p "$APP" "$FH"
  cd "$APP" && git init -q -b main && git config user.email t@t && git config user.name t
  echo base > shared.txt && git add . && git commit -qm init && mkdir .orchestrate
  echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"; echo "$APP/../app-wt/codex-1" > "$FH/codex-1.dir"
  echo "$APP" > "$FH/reviewer.dir"
}
status_of(){ python3 -c "import json;print(json.load(open('$APP/.orchestrate/state.json'))['tasks']['$1']['status'])"; }

# shared by several sections (kept up here so tests/parallel.sh can run any section on its own)
P1='# Plan: t\nBranch: feature/x\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: none\n\n'
MPLAN='# Plan: t\nBranch: feature/md\nCheck command: test ! -f broken.txt\nIsolation: worktree\nMax parallel: 2\nLEADLINE\nWorkers: claude-1 (claude: sonnet), codex-1 (codex: gpt-6-luna@high)\nReviewer: none\n\n## [x] M1: Model\nDepends on: none\nTier: medium\nNeeds: coding\nModel why: one module, a pattern to copy.\nOpen questions:\n- none\n\n## [x] M4: Totals\nDepends on: none\nTier: small\nModel why: one small function.\nOpen questions:\n- none\n'
FAKEBIN="$WORK/fakebin"; IH="$WORK/home"; mkdir -p "$FAKEBIN" "$IH"
for b in claude codex hermes agy; do printf '#!/bin/sh\n' > "$FAKEBIN/$b"; chmod +x "$FAKEBIN/$b"; done
# stpy '<python>': change the run's state.json directly (st = the state, now = the time)
stpy(){ python3 -c "
import json, time; p = '$APP/.orchestrate/state.json'; st = json.load(open(p)); now = int(time.time())
$1
json.dump(st, open(p, 'w'))"; }
PRS='# Plan: t\nBranch: feature/rs\nCheck command: true\nIsolation: ISO\nMax parallel: 2\nWorkers: claude-1 (claude), codex-1 (codex)\nReviewer: reviewer (agy)\n\n## [x] M9: Stalls\nDepends on: none\nPrefer: codex\nOpen questions:\n- none\n\n## [x] M5: e\nDepends on: none\nPrefer: claude\nOpen questions:\n- none\n'

PLAN5='# Plan: Categories
Branch: feature/cat
Check command: test ! -f broken.txt
Setup command: none
Isolation: ISO
Max parallel: 2
Workers: claude-1 (claude), codex-1 (codex)
Reviewer: reviewer (agy)

## Global instructions
Use INR everywhere.

## [x] M1: Model
Depends on: none
Prefer: claude
Likely files: shared.txt
Open questions:
- none

## [x] M2: Endpoint
Depends on: none
Prefer: codex
Review: yes
Likely files: shared.txt, b.txt
Parallel: allow
Open questions:
- none

## [x] M3: UI
Depends on: M1, M2
Open questions:
- none

## [x] M4: Totals
Depends on: none
Open questions:
- none
'

echo "1. worktree mode: parallel, deps, review blocker, conflict, failing check, question"
newrepo wt; printf '%s' "${PLAN5/ISO/worktree}" > .orchestrate/plan.md
timeout 180 "$ORCH" autopilot > "$WORK/wt.log" 2>&1; code=$?
check "stops for the human (exit 3)" '[ $code -eq 3 ]'
check "M1, M2, M3 merged" '[ "$(status_of M1)$(status_of M2)$(status_of M3)" = mergedmergedmerged ]'
check "M4 paused with its question" '[ "$(status_of M4)" = paused ] && grep -q "which currency" "$WORK/wt.log"'
check "M3 saw both dependencies" 'grep -q deps-ok c.txt'
check "review blocker was fixed" 'grep -q validated b.txt'
check "conflict resolved, both lines kept" 'grep -q "M1 line" shared.txt && grep -q "M2 line" shared.txt'
check "one commit per merged task" '[ "$(git log --format=%B | grep -c "^Milestone: M")" -eq 3 ]'
check "commit subject is the coder's COMMIT line" 'git log --format=%s | qgrep -qx "feat(api): add the categories endpoint"'
check "no milestone-named commits on the branch" '! git log --format=%s | qgrep -qE "^(orch|wip)[( ]"'
check "the run made one branch, no milestone branches" '[ "$(git branch --format="%(refname:short)" | sort | tr "\n" " ")" = "feature/cat main " ]'
check "parked M4 keeps its work in a hidden ref only" '! git branch -a | qgrep -q M4'
check "a conflict fix on an approved milestone is reviewed again, with the resolution" '[ -s .orchestrate/review/M2/resolution.patch ] && grep -q "MERGE-CONFLICT RESOLUTION" .orchestrate/review/M2/review-task-3.md'

out=$("$ORCH" finish --no-push 2>&1); code=$?
check "finish refuses while a milestone is still open, and keeps every coder folder" '[ $code -ne 0 ] && grep -q "not every milestone has landed: M4 (paused)" <<<"$out" && [ -d "$APP/../app-wt/claude-1" ] && [ -d "$APP/../app-wt/codex-1" ]'
echo "2. resume after the developer answers"
python3 - "$APP/.orchestrate/plan.md" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read()
s=s.replace("## [x] M4: Totals\nDepends on: none\nOpen questions:\n- none\n","## [x] M4: Totals\nDepends on: none\nOpen questions:\n- none\nNotes from user:\nINR only.\n")
open(p,"w").write(s)
PY
"$ORCH" set M4 pending >/dev/null
timeout 120 "$ORCH" autopilot > "$WORK/wt2.log" 2>&1; code=$?
check "ALL_DONE (exit 0)" '[ $code -eq 0 ]'
check "M4 merged with the answer" '[ "$(status_of M4)" = merged ] && [ -f d.txt ]'
check "summary written" 'grep -q "Final check on the branch: PASS" .orchestrate/summary.md'
git init -q --bare "$WORK/remote.git"; git remote add origin "$WORK/remote.git"
git update-ref refs/orch/feature-cat/M9 HEAD   # a leftover hidden ref
"$ORCH" sync >/dev/null   # a second sync keeps the reviewer's state readable
mkdir -p "$APP/../app-wt/claude-1/.claude" && echo '{}' > "$APP/../app-wt/claude-1/.claude/settings.local.json"
git worktree add -q --detach "$APP/../app-wt/gone-1" HEAD   # a coder that is no longer in the plan
out=$("$ORCH" finish 2>&1); code=$?
check "finish pushes the feature branch" '[ $code -eq 0 ] && git --git-dir="$WORK/remote.git" rev-parse -q --verify feature/cat >/dev/null'
check "finish removes hidden refs and worktrees" '[ -z "$(git for-each-ref refs/orch)" ] && [ ! -d "$APP/../app-wt/claude-1" ]'
check "finish removes a coder folder that holds only an agent's settings file" 'grep -q "REMOVED .*app-wt/claude-1 (only agent files: .claude/)" <<<"$out"'
check "finish removes the folder of a coder no longer in the plan" '[ ! -d "$APP/../app-wt/gone-1" ] && ! git worktree list | qgrep -q gone-1'
check "finish removes the empty app-wt folder" '[ ! -e "$APP/../app-wt" ] && grep -q "REMOVED .*/app-wt$" <<<"$out" && [ "$(git worktree list | wc -l)" -eq 1 ]'
check "finish says how to open the PR" 'grep -q "OPEN A PR from feature/cat into main" <<<"$out"'
check "finish with no lead and no checklist says the manual tests are not written, and wakes nobody" 'grep -q "^MANUAL TESTS: not written yet" <<<"$out" && ! grep -q "LEAD" <<<"$out"'
check "only the feature branch was pushed" '[ "$(git --git-dir="$WORK/remote.git" for-each-ref --format="%(refname)" | tr "\n" " ")" = "refs/heads/feature/cat " ]'
git worktree add -q --detach "$APP/../app-wt/keep-1" HEAD && echo "not in any milestone" >> "$APP/../app-wt/keep-1/shared.txt"
out=$("$ORCH" finish --no-push 2>&1); code=$?
check "finish keeps a coder folder with real changes, names it and says how to delete it" '[ $code -eq 0 ] && grep -q "KEPT .*app-wt/keep-1: changes no milestone has (shared.txt)" <<<"$out" && grep -q "git worktree remove --force" <<<"$out" && grep -q "not in any milestone" "$APP/../app-wt/keep-1/shared.txt"'
git worktree remove --force "$APP/../app-wt/keep-1" && rmdir "$APP/../app-wt"

echo "3. rate limit moves the task (and its partial work) to the other coder"
newrepo rl
printf '# Plan: t\nBranch: orch/rl\nCheck command: true\nIsolation: worktree\nMax parallel: 2\nWorkers: claude-1 (claude), codex-1 (codex)\nReviewer: none\n\n## [x] M1: Model\nDepends on: none\nPrefer: codex\nOpen questions:\n- none\n' > .orchestrate/plan.md
touch "$FH/ratelimit-codex-1-M1"
timeout 120 "$ORCH" autopilot > "$WORK/rl.log" 2>&1; code=$?
check "finished (exit 0)" '[ $code -eq 0 ]'
check "codex benched" '"$ORCH" status | qgrep -q "codex-1 .*cooldown"'
check "claude finished it" '"$ORCH" status | qgrep -q "M1 .*merged .*claude-1"'
check "partial work kept" '[ -f partial-M1.txt ]'

echo "4. shared mode"
newrepo sh; echo "$APP" > "$FH/claude-1.dir"; echo "$APP" > "$FH/codex-1.dir"
printf '%s' "${PLAN5/ISO/shared}" | sed 's/Notes from user:/&/' > .orchestrate/plan.md
sed -i 's/## \[x\] M4: Totals/## [ ] M4: Totals/' .orchestrate/plan.md
timeout 180 "$ORCH" autopilot > "$WORK/sh.log" 2>&1; code=$?
check "finished (exit 0)" '[ $code -eq 0 ]'
check "no worktrees created" '[ ! -d "$APP/../app-wt" ]'
check "tasks landed in order" '[ "$(git log --format=%B | grep -c "^Milestone: M")" -ge 2 ]'

echo "5. permission prompt alerts, early stop is nudged then parked"
newrepo bl
printf '# Plan: t\nBranch: orch/x\nCheck command: true\nIsolation: worktree\nMax parallel: 2\nWorkers: claude-1 (claude), codex-1 (codex)\nReviewer: none\n\n## [x] M8: Needs permission\nDepends on: none\nPrefer: claude\nOpen questions:\n- none\n\n## [x] M9: Stalls\nDepends on: none\nPrefer: codex\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 120 "$ORCH" autopilot > "$WORK/bl.log" 2>&1; code=$?
check "alerted about the permission prompt" 'grep -q PERMISSION "$WORK/bl.log"'
check "blocked task still finished" '[ "$(status_of M8)" = merged ]'
check "staller nudged then parked" 'grep -q "nudged once" "$WORK/bl.log" && [ "$(status_of M9)" = paused ]'
check "the permission alert is remembered in state (no second alert after a restart)" '[ "$(grep -c PERMISSION "$WORK/bl.log")" -eq 1 ] && python3 -c "import json; assert json.load(open(\".orchestrate/state.json\"))[\"notified\"]"'

echo "7. review pipelining: the coder takes another milestone while its work is in review"
newrepo pl; touch "$FH/slow-review"; echo 0 > "$FH/compact-secs"   # /compact before M6 takes no time here
printf '# Plan: t\nBranch: orch/pl\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: codex-1 (codex)\nReviewer: reviewer (agy)\n\n## [x] M2: Endpoint\nDepends on: none\nReview: yes\nOpen questions:\n- none\n\n## [x] M6: Other screen\nDepends on: none\nReview: no\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 150 "$ORCH" autopilot > "$WORK/pl.log" 2>&1; code=$?
check "finished (exit 0)" '[ $code -eq 0 ]'
check "coder freed at handoff" 'grep -qE "M2 (saved for review|passed its check while being reviewed); codex-1 is free" "$WORK/pl.log"'
check "M6 started while M2 was in review" '[ "$(grep -n "M6 -> codex-1" "$WORK/pl.log" | cut -d: -f1)" -lt "$(grep -n "M2 review: 1 blocker" "$WORK/pl.log" | cut -d: -f1)" ]'
check "blocker fix ran as a queued job" 'grep -q "M2 fix job -> codex-1" "$WORK/pl.log"'
check "fix kept on M2 and merged" '[ "$(status_of M2)$(status_of M6)" = mergedmerged ] && grep -q validated b.txt'
check "review findings are problems, not fixes" 'grep -q "Report PROBLEMS, not solutions" .orchestrate/review/M2/review-task-1.md'

echo "6. plan validation"
newrepo pv
printf '# Plan: t\nBranch: orch/v\nCheck command: true\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M1: a\nDepends on: M2\nOpen questions:\n- none\n\n## [x] M2: b\nDepends on: M1\nOpen questions:\n- none\n' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "dependency cycle rejected" '[ $code -eq 2 ] && grep -q cycle <<<"$out"'
{ printf '# Plan: t\nBranch: orch/v\nCheck command: true\nWorkers: claude-1 (claude)\nReviewer: none\n'; for i in 1 2 3 4 5; do printf '\n## [x] M%s: t\nDepends on: none\nOpen questions:\n- none\n' $i; done; } > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1)
check "the number of milestones alone is not a warning" '! grep -q "enabled milestones" <<<"$out"'
check "a split without a reason warns, per milestone" '[ "$(grep -c "has no .Why separate:" <<<"$out")" -eq 5 ]'
check "ORCH_MAX_TASKS still warns when you set it" 'ORCH_MAX_TASKS=4 "$ORCH" sync | qgrep -q "5 enabled milestones"'
{ printf '# Plan: t\nBranch: orch/v\nCheck command: true\nWorkers: claude-1 (claude)\nReviewer: none\n\n## Feature breakdown\n- api and ui\n'; for i in 1 2; do printf '\n## [x] M%s: t\nDepends on: none\nWhy separate: built in parallel by another coder\nOpen questions:\n- none\n' $i; done; } > .orchestrate/plan.md
check "milestones that say why they are separate do not warn" '! "$ORCH" sync 2>&1 | qgrep -q "Why separate"'
printf '# Plan: t\nBranch: orch/v\nCheck command: true\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M1: t\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
check "a one-milestone plan needs no reason" '! "$ORCH" sync 2>&1 | qgrep -q "Why separate"'
cat > .orchestrate/plan.md <<'PLAN'
# Plan: Insights
Branch: orch/ins
Check command: true
Isolation: worktree
Workers: claude-1 (claude), codex-1 (codex)
Reviewer: none

## [x] M1: Scaffold
Depends on: none
Likely files: src/routes.tsx, package.json
Open questions:
- none

## [x] M2: Charts
Depends on: M1 (uses the page shell M1 creates)
Likely files: src/charts/Chart.tsx, package.json
Open questions:
- none

## [x] M3: Filters
Depends on: M1
Likely files: src/filters/Filters.tsx
1. Create a function filterRows
Open questions:
- none
PLAN
out=$("$ORCH" sync 2>&1)
check "dependency without a reason warns" 'grep -q "M3 depends on M1 without a reason" <<<"$out"'
check "reason text is not parsed as a dependency" '! grep -q "depends on unknown" <<<"$out"'
check "hotspot file in parallel milestones warns" 'grep -q "M2 touches shared hotspot" <<<"$out"'
check "step-by-step how in a milestone warns" 'grep -q "M3 reads like step-by-step implementation" <<<"$out"'
sed -i 's/Isolation: worktree/Isolation: shared/' .orchestrate/plan.md
out=$("$ORCH" sync 2>&1)
check "shared mode suggests worktree for independent milestones" 'grep -q "M2 and M3 are independent" <<<"$out"'
printf '# Plan: t\nBranch: orch/v\nCheck command: true\nIsolation: shared\nWorkers: claude-1 (claude), codex-1 (codex)\nReviewer: none\n\n## [x] M1: api\nDepends on: none\nOpen questions:\n- none\n\n## [x] M2: web\nDepends on: M1 (needs the API)\nOpen questions:\n- none\n' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1)
check "2 coders on a fully sequential plan warns" 'grep -q "2 coders but every milestone depends" <<<"$out"'
sed -i 's/^Depends on: M1 (needs the API)/Depends on: none/; s/Isolation: shared/Isolation: worktree/' .orchestrate/plan.md
out=$("$ORCH" sync 2>&1)
check "backend and frontend in parallel: no idle-coder warning" '! grep -q "every milestone depends" <<<"$out"'
sed -i 's/^Workers: .*/Workers: claude-1 (claude)/' .orchestrate/plan.md
out=$("$ORCH" sync 2>&1)
check "1 coder with parallel milestones suggests shared" 'grep -q "1 coder: independent milestones" <<<"$out"'
check "orch version prints" '"$ORCH" version | qgrep -q "herdr-orchestra"'

echo "8. any agent can lead: playbooks, Lead header, agent registry"
out=$("$ORCH" lead plan)
check "lead plan prints version line + playbook" 'grep -q "^herdr-orchestra .* lead playbook: plan" <<<"$out" && grep -q "You are the LEAD" <<<"$out"'
out=$("$ORCH" lead run)
check "lead run prints version line + playbook" 'grep -q "lead playbook: run" <<<"$out" && grep -q "event manager" <<<"$out" && grep -q "orch dispatch" <<<"$out"'
check "lead commands work outside a git repo" '(cd "$WORK" && "$ORCH" lead plan >/dev/null && "$ORCH" agents >/dev/null)'
st=$("$ORCH" lead plan); qu=$("$ORCH" lead plan quick); fu=$("$ORCH" lead plan full)
check "lead plan prints only the start: the quick-or-full decision and the split test, not steps 3-10" 'grep -q "## 2b. Quick or full" <<<"$st" && grep -q "Step 4b, the split test" <<<"$st" && grep -q "Start from ONE milestone" <<<"$st" && ! grep -q "## 3. Discover the team" <<<"$st" && grep -q "orch lead plan quick" <<<"$st" && grep -q "orch lead plan full" <<<"$st"'
check "lead plan quick prints the rules a quick plan uses" 'grep -q "lead playbook: plan (quick)" <<<"$qu" && grep -q "Acceptance criteria are observable" <<<"$qu" && grep -q "Likely files is the scope" <<<"$qu" && grep -q "\*\*small\*\*: mechanical" <<<"$qu" && grep -q "Check command\*\*: one command" <<<"$qu" && grep -q "Estimate the time" <<<"$qu" && ! grep -q "## 3. Discover" <<<"$qu"'
check "lead plan full prints steps 3-10 with no markers" 'grep -q "## 3. Discover the team" <<<"$fu" && grep -q "## 10. Validate and show the plan" <<<"$fu" && ! grep -q "<!--" <<<"$fu$st$qu" && ! grep -q "Start from ONE milestone" <<<"$fu"'
check "start + full hold every line of the plan playbook (a full feature reads all of it, nothing lost)" 'python3 -c "
import collections,re,sys
src=[l for l in open(\"$ROOT/playbooks/plan.md\").read().splitlines() if not re.match(r\"^<!-- \",l)]
got=collections.Counter(sys.argv[1].splitlines()+sys.argv[2].splitlines())
sys.exit(any(got[l]<n for l,n in collections.Counter(src).items() if l.strip()))" "$st" "$fu"'
check "lead plan refuses an unknown part" '! "$ORCH" lead plan fast >/dev/null 2>&1'
check "lead run --section prints one part of the run playbook" '"$ORCH" lead run --section FAILED | qgrep -q "^| \`FAILED Mn\`: checks" && "$ORCH" lead run --section ALL_DONE | qgrep -q "^## 3. ALL_DONE" && "$ORCH" lead run --section rules | qgrep -q "^## Hard rules"'
check "a wake-up runs only orch events, not the whole run playbook again" 'for f in "$ROOT/skills/orch-run/SKILL.md" "$ROOT/claude-commands/orch-run.md" "$ROOT/opencode-commands/orch-run.md"; do grep -q "run only \`orch events\`" "$f" && grep -q "do not run \`orch lead run\` again" "$f" || exit 1; done'
check "the plan playbook spells out the herdr commands instead of loading the herdr skill first" 'grep -q "herdr agent rename <pane id> <name>" "$ROOT/playbooks/plan.md" && grep -q "Load the \`herdr\` skill (or run \`herdr --skill\`) only if one of these fails" "$ROOT/playbooks/plan.md" && ! grep -q "skill for exact CLI syntax if you have it" "$ROOT/playbooks/plan.md"'
check "lead whoami names the pane" 'env -u HERDR_PANE_ID "$ORCH" lead whoami | qgrep -q "herdr agent rename w1:p1 lead"'
check "lead check passes on HERDR_ENV=1" 'HERDR_ENV=1 "$ORCH" lead check | qgrep -q "^OK inside a Herdr pane"'
out=$(env -u HERDR_ENV "$ORCH" lead check 2>&1); code=$?
check "lead check passes when herdr answers but HERDR_ENV is unset (Hermes gateway)" '[ $code -eq 0 ] && grep -q "^OK herdr is reachable" <<<"$out" && grep -q "client_env_passthrough" <<<"$out"'
out=$(env -u HERDR_ENV HERDR=/nonexistent/herdr "$ORCH" lead check 2>&1); code=$?
check "lead check fails clearly when herdr is unreachable" '[ $code -ne 0 ] && grep -q "Herdr not detected" <<<"$out" && grep -q "Start this agent from a Herdr pane" <<<"$out"'
check "lead whoami warns when HERDR_PANE_ID is unset" 'env -u HERDR_PANE_ID "$ORCH" lead whoami | qgrep -q "FOCUSED pane"'
check "plan playbook preflight uses lead check, not \$HERDR_ENV" 'grep -q "orch lead check" "$ROOT/playbooks/plan.md" && ! grep -q "echo \$HERDR_ENV" "$ROOT/playbooks/plan.md"'
newrepo ld
printf '# Plan: t\nBranch: orch/ld\nCheck command: true\nLead: lead (claude)\nWorkers: claude-1 (claude), codex-1 (codex)\nReviewer: reviewer (agy)\n\n## [x] M1: a\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "Lead header stored by sync" '[ $code -eq 0 ] && python3 -c "import json,sys;s=json.load(open(\".orchestrate/state.json\"));sys.exit(s[\"lead\"]!={\"name\":\"lead\",\"kind\":\"claude\"} or s[\"lead_mode\"]!=\"events\")"'
sed -i 's/^Lead: .*/Lead: claude-1 (claude)/' .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "lead that is also a worker is an ERROR" '[ $code -eq 2 ] && grep -q "also listed in Workers" <<<"$out"'
sed -i 's/^Lead: .*/Lead: reviewer (agy)/' .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "lead that is also the reviewer is an ERROR" '[ $code -eq 2 ] && grep -q "also the Reviewer" <<<"$out"'
check "registry defaults load" 'grep -q "^hermes" <<<"$("$ORCH" agents)" && [ "$("$ORCH" agents launch claude)" = "claude --permission-mode acceptEdits" ]'
check "the Claude reviewer starts with its edit tools off" '[ "$("$ORCH" agents launch claude --role reviewer)" = "claude --permission-mode acceptEdits --disallowedTools Edit,NotebookEdit" ] && [ "$("$ORCH" agents launch claude --role reviewer --model opus)" = "claude --permission-mode acceptEdits --disallowedTools Edit,NotebookEdit --model opus" ]'
check "a kind with no review_launch starts its reviewer like a coder" '[ "$("$ORCH" agents launch codex --role reviewer)" = "$("$ORCH" agents launch codex)" ] && [ "$("$ORCH" agents launch claude --role coder)" = "claude --permission-mode acceptEdits" ] && ! "$ORCH" agents launch claude --role boss >/dev/null 2>&1'
printf '[claude]\nlaunch = "claude --model opus"\n\n[mystery]\nbinary = "mystery"\nlaunch = "mystery --yolo"\n' > "$ORCH_AGENTS_FILE"
check "user agents.toml overrides and adds kinds" '[ "$("$ORCH" agents launch claude)" = "claude --model opus" ] && [ "$("$ORCH" agents launch mystery)" = "mystery --yolo" ]'
check "your own launch command is used for the reviewer too when you set no review_launch" '[ "$("$ORCH" agents launch claude --role reviewer)" = "claude --model opus" ]'
rm -f "$ORCH_AGENTS_FILE"

echo "9. agents herdr can't watch rely on their done file"
newrepo nd; echo "$APP/../app-wt/odd-1" > "$FH/odd-1.dir"; touch "$FH/odd-1.gone"
printf '# Plan: t\nBranch: orch/nd\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: odd-1 (oddagent)\nReviewer: none\n\n## [x] M5: e\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1)
check "unknown kind warns, not an error" 'grep -q "WARN: Workers kind .oddagent. is not in the agent registry" <<<"$out"'
timeout 120 "$ORCH" autopilot > "$WORK/nd.log" 2>&1; code=$?
check "detect=false worker finished via its done file" '[ $code -eq 0 ] && [ "$(status_of M5)" = merged ]'
check "never parked as GONE" '! grep -qi "gone" "$WORK/nd.log" && grep -q "can.t watch odd-1" "$WORK/nd.log"'
check "status shows detect:off" '"$ORCH" status | qgrep -q "odd-1 .*detect:off"'

echo "10. @pane: workers get prompts typed into their pane"
newrepo pn; echo "$APP/../app-wt/hermes-1" > "$FH/hermes-1.dir"; echo hermes-1 > "$FH/pane-w9:p2.name"
printf '# Plan: t\nBranch: orch/pn\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: hermes-1 (hermes @pane:w9:p2)\nReviewer: none\n\n## [x] M6: g\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 120 "$ORCH" autopilot > "$WORK/pn.log" 2>&1; code=$?
check "pane worker finished" '[ $code -eq 0 ] && [ "$(status_of M6)" = merged ]'
check "prompt went through pane send-text + enter" 'grep -q "pane w9:p2 (hermes-1) <- Read .orch-task/M6/task.md" "$FH/pane-prompts.log" && grep -q "pane w9:p2 keys enter" "$FH/pane-prompts.log"'
check "agent prompt was not used for it" '! grep -q "^hermes-1 <-" "$FH/prompts.log" 2>/dev/null'
sed -i 's/@pane:w9:p2/@pane:w9:p7/' .orchestrate/plan.md; "$ORCH" sync >/dev/null
check "stale pane id reported by start" '"$ORCH" start | qgrep -q "STALE pane w9:p7"'

echo "12. recovery: an error in one task never crashes or hangs the run"
newrepo srl; echo "$APP" > "$FH/claude-1.dir"; echo "$APP" > "$FH/codex-1.dir"
printf '# Plan: t\nBranch: feature/srl\nCheck command: true\nIsolation: shared\nMax parallel: 1\nWorkers: claude-1 (claude), codex-1 (codex)\nReviewer: none\n\n## [x] M1: Model\nDepends on: none\nPrefer: codex\nOpen questions:\n- none\n' > .orchestrate/plan.md
touch "$FH/ratelimit-codex-1-M1"
timeout 120 "$ORCH" autopilot > "$WORK/srl.log" 2>&1; code=$?
check "shared mode: rate-limited task moves to the other coder" '[ $code -eq 0 ] && "$ORCH" status | qgrep -q "M1 .*merged .*claude-1"'
check "shared mode: partial work came along" 'git show --stat HEAD | qgrep -q partial-M1.txt && ! grep -q Traceback "$WORK/srl.log"'

newrepo rg; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"; touch "$FH/slow-review"
printf '# Plan: t\nBranch: feature/rg\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: reviewer (agy)\n\n## [x] M5: E\nDepends on: none\nReview: yes\nOpen questions:\n- none\n' > .orchestrate/plan.md
( for _ in $(seq 300); do grep -q review-task "$FH/prompts.log" 2>/dev/null && break; sleep 0.2; done
  touch "$FH/reviewer.gone"; sleep 4; rm -f "$FH/reviewer.gone" ) &
timeout 120 "$ORCH" autopilot > "$WORK/rg.log" 2>&1; code=$?; wait
check "reviewer gone: no crash, review waits, then lands" '[ $code -eq 0 ] && [ "$(status_of M5)" = merged ] && ! grep -q Traceback "$WORK/rg.log"'
check "reviewer gone: the coder did not rebuild it" '[ "$(grep -c "M5 -> claude-1" "$WORK/rg.log")" -eq 1 ] && grep -q "reviewer reviewer is gone" "$WORK/rg.log"'

newrepo fl; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
printf '#!/usr/bin/env bash\nif [ "$1 $2" = "agent prompt" ] && [ ! -f "$FH/failed-once" ]; then touch "$FH/failed-once"; echo "socket timeout" >&2; exit 1; fi\nexec "%s" "$@"\n' "$ROOT/tests/sim/herdr" > "$WORK/flaky-herdr"; chmod +x "$WORK/flaky-herdr"
printf '# Plan: t\nBranch: feature/fl\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M5: E\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
HERDR="$WORK/flaky-herdr" ORCH_SEND_RETRY_S=2 timeout 60 "$ORCH" autopilot > "$WORK/fl.log" 2>&1; code=$?
check "a failed prompt is retried, not a crash or a hang" '[ $code -eq 0 ] && grep -q "could not reach claude-1" "$WORK/fl.log" && [ "$(status_of M5)" = merged ]'

newrepo gn; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
printf '# Plan: t\nBranch: feature/gn\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M7: H\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 60 "$ORCH" autopilot > "$WORK/gn.log" 2>&1; code=$?
check "a GONE coder gets work again as soon as it is back (not 10 h later)" '[ $code -eq 0 ] && grep -q "LOST claude-1: herdr can.t find it" "$WORK/gn.log" && [ "$(status_of M7)" = merged ]'

newrepo orp; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
printf '# Plan: t\nBranch: feature/orp\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude), codex-1 (codex)\nReviewer: none\n\n## [x] M5: E\nDepends on: none\nOpen questions:\n- none\n\n## [ ] M6: G\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
"$ORCH" sync >/dev/null && "$ORCH" start >/dev/null && "$ORCH" prepare M5 claude-1 >/dev/null
out=$("$ORCH" poll 2 2>&1)
check "poll reports a task whose prompt never went out" 'grep -q "^ORPHAN M5" <<<"$out"'
"$ORCH" set M5 pending >/dev/null
check "set pending frees the coder" '"$ORCH" status | qgrep -q "claude-1 .*task=- "'
"$ORCH" prepare M5 claude-1 >/dev/null
python3 - .orchestrate/plan.md <<'PY'
import re, sys; p = sys.argv[1]; s = open(p).read()
open(p, "w").write(re.sub(r"## \[x\] M5: E\n(.*\n)*?(?=## )", "", s))
PY
out=$("$ORCH" sync 2>&1)
check "sync frees a coder whose milestone left the plan" 'grep -q "claude-1 was holding M5" <<<"$out" && "$ORCH" status | qgrep -q "claude-1 .*task=- "'
out=$("$ORCH" send M99 task.md 2>&1); code=$?
check "unknown task id is a clean error" '[ $code -eq 2 ] && grep -q "unknown task .M99" <<<"$out" && ! grep -q Traceback <<<"$out"'
out=$("$ORCH" cooldown reviewer 5 2>&1); code=$?
check "cooldown of an unknown agent is a clean error" '[ $code -eq 2 ] && ! grep -q Traceback <<<"$out"'

newrepo js; echo "$APP/../app-wt/working-1" > "$FH/working-1.dir"
printf '# Plan: t\nBranch: feature/js\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: working-1 (claude)\nReviewer: none\n\n## [x] M6: G\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 60 "$ORCH" autopilot > "$WORK/js.log" 2>&1; code=$?
check "herdr status is read from its JSON field (agent named working-1 is free)" '[ $code -eq 0 ] && [ "$(status_of M6)" = merged ]'

newrepo ib; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
printf '# Plan: t\nBranch: feature/ib\nCheck command: test "$(git rev-parse --abbrev-ref HEAD)" = HEAD || test ! -f boom.txt\nBranch check: always\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M10: Boom\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 90 "$ORCH" autopilot > "$WORK/ib.log" 2>&1; code=$?
check "a milestone that fails the check once merged is never committed" '[ $code -eq 3 ] && [ "$(git rev-parse feature/ib)" = "$(git rev-parse main)" ] && [ -z "$(git status --porcelain)" ]'
check "…it gets fix rounds, then fails with the reason" '[ "$(status_of M10)" = failed ] && grep -q "passes alone but fails the check on feature/ib" "$WORK/ib.log" && [ -f "$APP/../app-wt/claude-1/.orch-task/M10/integration-fix-1.md" ]'
echo boom > boom.txt && git add boom.txt && git commit -qm "break the branch by hand"
python3 -c "import json; p='.orchestrate/state.json'; s=json.load(open(p)); s['integration_broken']='a manual commit'; json.dump(s, open(p,'w'))"
timeout 60 "$ORCH" autopilot > "$WORK/ib2.log" 2>&1; code=$?
check "a branch broken by hand: the next run re-checks and stops" '[ $code -eq 3 ] && grep -q "still fails its check" "$WORK/ib2.log"'
git rm -q boom.txt && git commit -qm "fix: remove boom"
timeout 60 "$ORCH" autopilot > "$WORK/ib3.log" 2>&1; code=$?
check "after the fix it carries on" 'grep -q "passes its check again" "$WORK/ib3.log"'

echo "13. git flow: feature branch, plan header rules, legacy runs"
newrepo sg; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"; echo "$APP/../app-wt/codex-1" > "$FH/codex-1.dir"
printf '# Plan: Two things\nBranch: feature/sg\nCommits: single\nCheck command: true\nIsolation: worktree\nMax parallel: 2\nWorkers: claude-1 (claude), codex-1 (codex)\nReviewer: none\n\n## Global instructions\nBranch: never-use-this\nKeep it small.\n\n## [x] M5: E\nDepends on: none\nOpen questions:\n- none\n\n## [x] M6: G\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1)
check "Key: value lines in Global instructions don't override the header" 'grep -q "^OK" <<<"$out" && "$ORCH" status | qgrep -q "^branch=feature/sg "'
timeout 60 "$ORCH" autopilot > "$WORK/sg.log" 2>&1; code=$?
out=$("$ORCH" finish --no-push 2>&1); fcode=$?
check "Commits: single squashes the run into one commit" '[ $code -eq 0 ] && [ $fcode -eq 0 ] && [ "$(git rev-list --count main..feature/sg)" -eq 1 ] && git log -1 --format=%B | qgrep -q "Milestones: M5, M6"'
check "finish --no-push does not push" 'grep -q "NOT PUSHED" <<<"$out"'

newrepo lg; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
git switch -qc orch/lg-M6 && echo legacy > legacy.txt && git add legacy.txt && git commit -qm "wip(M6): parked" && git switch -q main
printf '# Plan: t\nBranch: orch/lg\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M6: G\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1)
check "orch/ branch prefix warns" 'grep -q "prefer .Branch: feature/<slug>." <<<"$out"'
timeout 60 "$ORCH" autopilot > "$WORK/lg.log" 2>&1; code=$?
check "a pre-4.5 task branch is picked up (in-flight runs keep their work)" '[ $code -eq 0 ] && [ -f legacy.txt ] && [ -f g.txt ]'
"$ORCH" finish --no-push >/dev/null 2>&1
check "finish deletes the old milestone branch" '! git rev-parse -q --verify orch/lg-M6 >/dev/null'

newrepo ob; git switch -qc feature/ob
printf '# Plan: t\nBranch: feature/ob\nCheck command: true\nIsolation: shared\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M6: G\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
"$ORCH" sync >/dev/null; "$ORCH" start >/dev/null 2>&1
check "starting on the branch itself still records the real base" '"$ORCH" status | qgrep -q "base=main "'

echo "14. one driver per run"
newrepo ls; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"; touch "$FH/slow-review"
printf '# Plan: t\nBranch: feature/ls\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: reviewer (agy)\n\n## [x] M5: E\nDepends on: none\nReview: yes\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 120 "$ORCH" autopilot > "$WORK/ls.log" 2>&1 & first=$!
for _ in $(seq 100); do "$ORCH" status 2>/dev/null | qgrep -q "^driven by" && break; sleep 0.2; done
out=$(timeout 30 "$ORCH" autopilot 2>&1); code=$?
check "a second autopilot is refused" '[ $code -eq 2 ] && grep -q "already driven by orch autopilot (pid" <<<"$out"'
out=$("$ORCH" set M5 paused 2>&1); code=$?
check "changing the run by hand is refused while autopilot drives" '[ $code -eq 2 ] && grep -q "driven by" <<<"$out"'
check "status still works and shows the driver" '"$ORCH" status | qgrep -q "^driven by orch autopilot (pid"'
wait $first; code=$?
check "the first autopilot was not disturbed" '[ $code -eq 0 ] && [ "$(status_of M5)" = merged ] && ! grep -q "orch error" "$WORK/ls.log"'
check "the lease is free again afterwards" '! "$ORCH" status | qgrep -q "^driven by" && "$ORCH" set M5 merged --force >/dev/null'

newrepo lk; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
{ printf '%b' "$P1"; printf '## [x] M8: Slow\nDepends on: none\nOpen questions:\n- none\n'; } > .orchestrate/plan.md
"$ORCH" autopilot > "$WORK/lk.log" 2>&1 & first=$!
for _ in $(seq 100); do grep -q "M8 -> claude-1" "$WORK/lk.log" 2>/dev/null && break; sleep 0.2; done
kill -9 $first; wait $first 2>/dev/null
timeout 120 "$ORCH" autopilot > "$WORK/lk2.log" 2>&1; code=$?
check "a killed autopilot leaves no stale lease; the next one finishes the run" '[ $code -eq 0 ] && [ "$(status_of M8)" = merged ]'
check "the restart did not hand the milestone to a coder twice" '[ "$(grep -c "M8/task.md" "$FH/prompts.log")" -eq 1 ]'

echo "15. crash safety: a crash at any step is recovered on the next run"
crash_then_resume() {   # crash_then_resume <fault point> <name>: sets ccode (crashed run) and code (resumed run)
  newrepo "$2"; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
  { printf '%b' "${3:-$P1}"; printf '## [x] M6: G\nDepends on: none\nOpen questions:\n- none\n'; } > .orchestrate/plan.md
  ORCH_FAULT=$1 timeout 60 "$ORCH" autopilot > "$WORK/$2-crash.log" 2>&1; ccode=$?
  sleep 2
  ORCH_CONFIRM_S=2 timeout 90 "$ORCH" autopilot > "$WORK/$2.log" 2>&1; code=$?
}
landed_once() { [ "$(git log --format=%B | grep -c "^Milestone: M6$")" -eq 1 ] && [ -z "$(git status --porcelain)" ] && [ -z "$(git for-each-ref refs/orch)" ]; }
crash_then_resume after-deliver cd1
check "crash right after a prompt went out: the run was really killed" '[ $ccode -ne 0 ] && [ $ccode -ne 3 ] && ! grep -q "orch error" "$WORK/cd1-crash.log"'
check "…the same coder's work is used, nobody else is prompted" '[ $code -eq 0 ] && [ "$(status_of M6)" = merged ] && [ "$(grep -c "M6/task.md" "$FH/prompts.log")" -eq 1 ] && ! grep -q ORPHAN "$WORK/cd1.log"'
crash_then_resume after-squash cs1
check "crash between squash and check: undone, merged again, one commit" '[ $ccode -ne 0 ] && [ $code -eq 0 ] && landed_once && grep -q "RECOVERED M6: undid the half-done merge" "$WORK/cs1.log"'
crash_then_resume after-check cc1
check "crash between check and commit: one commit" '[ $ccode -ne 0 ] && [ $code -eq 0 ] && landed_once'
crash_then_resume after-check cc2 "${P1/Check command:/Branch check: always\\nCheck command:}"
check "…the same with the check run again on the branch (Branch check: always)" '[ $ccode -ne 0 ] && [ $code -eq 0 ] && landed_once && ! grep -q SKIPPED_CHECK "$WORK/cc2-crash.log" "$WORK/cc2.log"'
crash_then_resume after-merge-commit cm1
check "crash right after the commit: not merged twice" '[ $ccode -ne 0 ] && [ $code -eq 0 ] && landed_once && grep -q "RECOVERED M6: its commit had landed" "$WORK/cm1.log"'

newrepo uc; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
{ printf '%b' "$P1"; printf '## [x] M6: G\nDepends on: none\nOpen questions:\n- none\n'; } > .orchestrate/plan.md
"$ORCH" sync >/dev/null && "$ORCH" start >/dev/null && "$ORCH" prepare M6 claude-1 >/dev/null && "$ORCH" write-task M6 >/dev/null
ORCH_FAULT=after-deliver "$ORCH" send M6 task.md >/dev/null 2>&1; code=$?
sleep 3; rm -f "$APP/../app-wt/claude-1/.orch-task/M6/"{done-1,result-1.json,report-1.md}   # as if the prompt was lost
out=$(ORCH_CONFIRM_S=0 "$ORCH" poll 2 2>&1)
check "a recorded prompt that herdr can't confirm is reported, not treated as an orphan" '[ $code -eq 99 ] && grep -q "^UNCONFIRMED M6 agent=claude-1" <<<"$out" && ! grep -q ORPHAN <<<"$out"'
out=$("$ORCH" resend M6 2>&1); sleep 3; out2=$("$ORCH" poll 5 2>&1)
check "orch resend sends it again to the same agent, same attempt" 'grep -q "^RESENT M6 -> claude-1" <<<"$out" && [ "$(grep -c "^claude-1 <- .*M6/task.md.*done-1" "$FH/prompts.log")" -eq 2 ] && grep -q "^DONE M6" <<<"$out2"'

echo "16. retries are bounded"
newrepo df; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"; touch "$FH/claude-1.deaf"
{ printf '%b' "$P1"; printf '## [x] M6: G\nDepends on: none\nOpen questions:\n- none\n'; } > .orchestrate/plan.md
ORCH_MAX_LOST=3 ORCH_SEND_RETRY_S=1 timeout 120 "$ORCH" autopilot > "$WORK/df.log" 2>&1; code=$?
check "an agent that never takes a prompt: the task fails after ORCH_MAX_LOST, no endless loop" '[ $code -eq 3 ] && [ "$(status_of M6)" = failed ] && grep -q "lost 3 attempts" "$WORK/df.log"'
check "…and the agent is benched after 3 failed prompts in a row" 'grep -q "BENCHED claude-1" "$WORK/df.log"'

echo "17. dependencies are installed again when lockfiles change"
newrepo dp; echo ".installed" >> .git/info/exclude
printf '# Plan: t\nBranch: feature/dp\nCheck command: test "$(git ls-files -s package-lock.json)" = "$(cat .installed 2>/dev/null)"\nSetup command: git ls-files -s package-lock.json > .installed\nIsolation: worktree\nMax parallel: 2\nWorkers: claude-1 (claude), codex-1 (codex)\nReviewer: none\n\n## [x] M11: Deps\nDepends on: none\nPrefer: claude\nLikely files: package-lock.json\nOpen questions:\n- none\n\n## [x] M13: Other\nDepends on: none\nPrefer: codex\nOpen questions:\n- none\n\n## [x] M12: Uses the dep\nDepends on: M11 (needs the package)\nPrefer: codex\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 120 "$ORCH" autopilot > "$WORK/dp.log" 2>&1; code=$?
fix_of(){ python3 -c "import json;print(json.load(open('$APP/.orchestrate/state.json'))['tasks']['$1']['fix'])"; }
check "all three landed" '[ $code -eq 0 ] && [ "$(status_of M11)$(status_of M12)$(status_of M13)" = mergedmergedmerged ]'
check "the worktree set up before the lockfile changed was set up again" 'grep -q "installing dependencies in .*(dependency files changed)" "$WORK/dp.log"'
check "…so the dependent milestone needed no fix round" '[ "$(fix_of M12)" = 0 ] && [ "$(fix_of M11)" = 0 ]'

echo "18. contracts: task.json, result.json, scope, overlap, risk hold"
newrepo rj; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
{ printf '%b' "$P1"; printf '## [x] M14: N\nDepends on: none\nOpen questions:\n- none\n\n## [x] M17: P\nDepends on: M14 (order)\nAcceptance criteria:\n- p has a test\n- p is documented\nOpen questions:\n- none\n'; } > .orchestrate/plan.md
timeout 120 "$ORCH" autopilot > "$WORK/rj.log" 2>&1; code=$?
check "an invalid result file gets one request to rewrite it, then lands" '[ $code -eq 0 ] && [ "$(status_of M14)" = merged ] && [ "$(grep -c "result file not usable" "$WORK/rj.log")" -eq 1 ]'
check "a criterion the coder reports as not met goes back for a fix" 'grep -q "M17: the coder reports AC1 not met" "$WORK/rj.log" && [ "$(status_of M17)" = merged ] && [ -f p.test ]'
check "task.json carries numbered acceptance criteria and the dependency's commit" 'python3 -c "
import json; c=json.load(open(\"$APP/../app-wt/claude-1/.orch-task/M17/task.json\"))
assert [a[\"id\"] for a in c[\"acceptance_criteria\"]] == [\"AC1\", \"AC2\"], c
assert c[\"depends_on\"][0][\"task\"] == \"M14\" and len(c[\"depends_on\"][0][\"commit\"]) == 40, c
assert \"status\" in c[\"result_format\"]"'
check "the commit subject comes from result.json" 'git log --format=%s | qgrep -qx "feat: p"'

newrepo nr; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"; touch "$FH/noresult"
{ printf '%b' "$P1"; printf '## [x] M6: G\nDepends on: none\nOpen questions:\n- none\n'; } > .orchestrate/plan.md
timeout 60 "$ORCH" autopilot > "$WORK/nr.log" 2>&1; code=$?
check "a coder that writes only the report still lands (fallback)" '[ $code -eq 0 ] && [ "$(status_of M6)" = merged ]'

newrepo sc; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
printf '# Plan: t\nBranch: feature/sc\nScope: strict\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M15: O\nDepends on: none\nLikely files: o.txt\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 60 "$ORCH" autopilot > "$WORK/sc.log" 2>&1; code=$?
check "Scope: strict sends back a change outside Likely files" '[ $code -eq 0 ] && grep -q "outside its Likely files: stray.txt -> fix round" "$WORK/sc.log" && [ -f o.txt ] && [ ! -f stray.txt ]'
newrepo sw; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
{ printf '%b' "$P1"; printf '## [x] M15: O\nDepends on: none\nLikely files: o.txt\nOpen questions:\n- none\n'; } > .orchestrate/plan.md
timeout 60 "$ORCH" autopilot > "$WORK/sw.log" 2>&1; code=$?
check "the default (warn) lands it and lists it in the summary" '[ $code -eq 0 ] && [ -f stray.txt ] && grep -q "M15: stray.txt" .orchestrate/summary.md'

newrepo ov
printf '# Plan: t\nBranch: feature/ov\nCheck command: true\nIsolation: worktree\nMax parallel: 2\nWorkers: claude-1 (claude), codex-1 (codex)\nReviewer: none\n\n## [x] M5: E\nDepends on: none\nLikely files: same.txt, e.txt\nOpen questions:\n- none\n\n## [x] M6: G\nDepends on: none\nLikely files: same.txt, g.txt\nOpen questions:\n- none\n' > .orchestrate/plan.md
"$ORCH" sync > "$WORK/ov-sync.log" 2>&1; "$ORCH" start >/dev/null 2>&1; out=$("$ORCH" ready)
check "milestones that share Likely files are not started together" 'grep -q "^READY M5" <<<"$out" && grep -q "^WAIT M6 shares files with M5" <<<"$out" && ! grep -q "^READY M6" <<<"$out"'
timeout 90 "$ORCH" autopilot > "$WORK/ov.log" 2>&1; code=$?
check "…they run one after the other and both land" '[ $code -eq 0 ] && [ "$(status_of M5)$(status_of M6)" = mergedmerged ] && ! grep -q "merge conflict" "$WORK/ov.log"'

newrepo rk; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
{ printf '%b' "$P1"; printf '## [x] M16: Remove a file\nDepends on: none\nOpen questions:\n- none\n\n## [x] M6: G\nDepends on: none\nOpen questions:\n- none\n'; } > .orchestrate/plan.md
timeout 90 "$ORCH" autopilot > "$WORK/rk.log" 2>&1; code=$?
check "a milestone that deletes a file is held, the rest lands" '[ $code -eq 3 ] && [ "$(status_of M16)" = held ] && [ "$(status_of M6)" = merged ] && grep -q "M16 is HELD for your approval: deletes shared.txt" "$WORK/rk.log" && [ -f shared.txt ]'
out=$("$ORCH" approve M16 2>&1)
timeout 60 "$ORCH" autopilot > "$WORK/rk2.log" 2>&1; code=$?
check "orch approve lets it land" 'grep -q "^APPROVED M16" <<<"$out" && [ $code -eq 0 ] && [ "$(status_of M16)" = merged ] && [ ! -f shared.txt ]'

newrepo rs; echo "$APP" > "$FH/claude-1.dir"
printf '# Plan: t\nBranch: feature/rs\nCheck command: true\nIsolation: shared\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M16: Remove a file\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 60 "$ORCH" autopilot > "$WORK/rs.log" 2>&1; code=$?
"$ORCH" approve M16 >/dev/null 2>&1; timeout 60 "$ORCH" autopilot > "$WORK/rs2.log" 2>&1; code2=$?
check "shared mode: held, then lands after approve" '[ $code -eq 3 ] && grep -q "M16 is HELD" "$WORK/rs.log" && [ $code2 -eq 0 ] && [ "$(status_of M16)" = merged ] && git show --stat HEAD | qgrep -q shared.txt'

echo "19. state: transitions, migration, events, report, budget"
out=$("$ORCH" set M16 coding 2>&1); code=$?
check "orch set refuses statuses that skip the real steps" '[ $code -eq 2 ] && grep -q "add --force" <<<"$out"'
out=$("$ORCH" set M16 pending 2>&1); code=$?
check "merged is final: no transition out of it" '[ $code -eq 2 ] && grep -q "merged -> pending is not an allowed transition" <<<"$out"'
check "no status is assigned outside move()" '[ "$(grep -cE "\[\"status\"\]\s*=[^=]|status=\"" "$ROOT/bin/orch")" -eq 1 ]'
check "every status has a transition entry" 'python3 -c "
import importlib.machinery, importlib.util
l = importlib.machinery.SourceFileLoader(\"orch\", \"$ROOT/bin/orch\"); m = importlib.util.module_from_spec(importlib.util.spec_from_loader(\"orch\", l)); l.exec_module(m)
assert set(m.TRANSITIONS) == m.STATUSES, set(m.TRANSITIONS) ^ m.STATUSES
assert all(v <= m.STATUSES for v in m.TRANSITIONS.values())"'
check "events.jsonl replays to the final state" 'python3 -c "
import json
st = json.load(open(\".orchestrate/state.json\")); last = {}
for l in open(\".orchestrate/events.jsonl\"): e = json.loads(l); last[e[\"task\"]] = e[\"to\"]
assert all(last.get(k, \"pending\") == v[\"status\"] for k, v in st[\"tasks\"].items()), (last, st[\"tasks\"])"'
python3 - <<'PY'
import json; p = ".orchestrate/state.json"; st = json.load(open(p))
for k in ("schema", "notified", "merging", "run", "root_setup_hash"): st.pop(k, None)
for t in st["tasks"].values():
    for k in ("history", "lost", "attempts"): t.pop(k, None)
json.dump(st, open(p, "w"))
PY
out=$("$ORCH" status 2>&1); code=$?; "$ORCH" sync >/dev/null 2>&1
check "a state file from 4.5 (no schema) loads and is migrated" '[ $code -eq 0 ] && grep -q "M16 .*merged" <<<"$out" && python3 -c "
import json; st = json.load(open(\".orchestrate/state.json\")); assert st[\"schema\"] == 1 and st[\"notified\"] == [] and st[\"tasks\"][\"M16\"][\"lost\"] == 0"'
cd "$WORK/rj/app" && FH="$WORK/rj/fh"; APP="$WORK/rj/app"
out=$("$ORCH" report 2>&1); code=$?
check "orch report: per-task rows, first-pass rate, usage the agents reported" '[ $code -eq 0 ] && grep -qE "^M14 +merged" <<<"$out" && grep -q "first pass 0/2" <<<"$out" && grep -q "input tokens" <<<"$out"'
check "orch report --json is machine-readable" '"$ORCH" report --json | python3 -c "import json,sys; r=json.load(sys.stdin); assert r[\"totals\"][\"merged\"] == 2 and r[\"totals\"][\"fix_rounds\"] >= 1"'
check "the summary includes the run report" 'grep -q "## Run report" .orchestrate/summary.md && grep -q "first pass" .orchestrate/summary.md'
check "the summary has the estimate vs actual section once, not again inside the run report" '[ "$(grep -c "Whole feature: estimated" .orchestrate/summary.md)" -eq 1 ] && grep -q "## Time: estimate vs actual" .orchestrate/summary.md && grep -q "| M14 | none |" .orchestrate/summary.md'

newrepo bg; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
printf '# Plan: t\nBranch: feature/bg\nBudget: 0.01m\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M8: Slow\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 60 "$ORCH" autopilot > "$WORK/bg.log" 2>&1; code=$?
check "Budget: stops the run cleanly when it is used up" '[ $code -eq 3 ] && grep -q "budget .* is used up" "$WORK/bg.log" && [ "$(status_of M8)" != failed ]'
printf '# Plan: t\nBranch: feature/bg\nBudget: soon\nCheck command: true\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M8: Slow\nDepends on: none\nOpen questions:\n- none\n' > "$WORK/badplan.md"
newrepo bb; cp "$WORK/badplan.md" .orchestrate/plan.md; out=$("$ORCH" sync 2>&1); code=$?
check "a Budget orch can't read is an error" '[ $code -eq 2 ] && grep -q "Budget must look like" <<<"$out"'

echo "20. orch doctor and real-output fixtures"
DOC="$WORK/docbin"; mkdir -p "$DOC"
printf '#!/bin/sh\ncase "$1" in --version) echo "goodagent 1.2.3";; --help) echo "  --yolo   approve everything";; esac\n' > "$DOC/goodagent"
printf '#!/bin/sh\ncase "$1" in --version) echo "oldagent 0.1";; --help) echo "  --careful   ask first";; esac\n' > "$DOC/oldagent"
chmod +x "$DOC/goodagent" "$DOC/oldagent"
printf '[goodagent]\nbinary = "goodagent"\nlaunch = "goodagent --yolo"\nherdr_detect = false\nroles = ["coder"]\n\n[oldagent]\nbinary = "oldagent"\nlaunch = "oldagent --yolo"\nherdr_detect = false\nroles = ["coder"]\n' > "$ORCH_AGENTS_FILE"
out=$(PATH="$DOC:$PATH" "$ORCH" doctor goodagent 2>&1); code=$?
check "doctor passes an agent whose launch flag is in --help" '[ $code -eq 0 ] && grep -q "^ok .*goodagent" <<<"$out" && grep -q "version: goodagent 1.2.3" <<<"$out"'
out=$(PATH="$DOC:$PATH" "$ORCH" doctor oldagent 2>&1); code=$?
check "doctor reports a launch flag the tool no longer has" '[ $code -eq 1 ] && grep -q "^BROKEN .*oldagent" <<<"$out" && grep -q "launch flag --yolo is NOT in" <<<"$out"'
printf '[revagent]\nbinary = "goodagent"\nlaunch = "goodagent --yolo"\nreview_launch = "goodagent --yolo --no-edits"\nherdr_detect = false\nroles = ["reviewer"]\n' >> "$ORCH_AGENTS_FILE"
out=$(PATH="$DOC:$PATH" "$ORCH" doctor revagent 2>&1); code=$?
check "doctor checks the reviewer launch flags too" '[ $code -eq 1 ] && grep -q "launch flag --no-edits is NOT in" <<<"$out" && grep -q "launch flag --yolo is listed" <<<"$out"'
out=$("$ORCH" doctor mystery-nope 2>&1); code=$?
check "doctor: unknown kind is reported, not a traceback" '[ $code -eq 1 ] && ! grep -q Traceback <<<"$out"'
rm -f "$ORCH_AGENTS_FILE"
check "pane fixtures: rate-limit samples match, others don't" 'python3 - "$ROOT" <<PY
import importlib.machinery, importlib.util, pathlib, sys
root = pathlib.Path(sys.argv[1])
l = importlib.machinery.SourceFileLoader("orch", str(root / "bin/orch")); m = importlib.util.module_from_spec(importlib.util.spec_from_loader("orch", l)); l.exec_module(m)
files = sorted((root / "tests/fixtures/panes").glob("*.txt"))
assert files, "no fixtures"
for f in files:
    hit = bool(m.RATE_RE.search(f.read_text()))
    assert hit == ("ratelimit" in f.name), (f.name, hit)
PY'
out=$("$ORCH" lead run)
check "the run playbook no longer has the lead drive the scheduler" '! grep -qE "orch (poll|send|prepare|merge)\b" <<<"$out" && grep -q "orch autopilot" <<<"$out"'

echo "21. models: catalog, policy, tiers in the plan"
out=$("$ORCH" models 2>&1)
check "orch models lists the three tiers" 'grep -qE "^opus +high" <<<"$out" && grep -qE "^sonnet +medium" <<<"$out" && grep -qE "^haiku +small" <<<"$out"'
check "ultra-premium models are not listed, and the policy says so" '! grep -qiE "^[a-z0-9.-]*(fable|astra)" <<<"$out" && grep -q "Not allowed in runs: .*fable.*astra" <<<"$out"'
"$ORCH" models check fable >/dev/null 2>&1; code=$?
check "models check refuses a denied model" '[ $code -eq 1 ] && grep -q DENIED <<<"$("$ORCH" models check gpt-6-astra-medium 2>&1)"'
check "models show prints the evidence" '"$ORCH" models show opus | qgrep -q "evidence"'
check "launch --model builds the command" '[ "$("$ORCH" agents launch claude --model haiku)" = "claude --permission-mode acceptEdits --model haiku" ]'
check "launch --model refuses a denied model" '! "$ORCH" agents launch claude --model fable >/dev/null 2>&1'
check "launch --model says when a kind has no model flag" 'grep -q "no \`model_flag\`" <<<"$("$ORCH" agents launch amp --model x 2>&1)"'
printf '[models.my-local]\nkinds = ["opencode"]\ntier = "high"\nreasoning = 2\n[policy]\ndeny = ["*fable*", "sonnet"]\n' > "$ORCH_MODELS_FILE"
check "user models.toml adds a model; a high tier needs the reasoning for it" '"$ORCH" models check my-local | qgrep -q "tier small"'
check "user models.toml can change the policy" 'grep -q DENIED <<<"$("$ORCH" models check sonnet 2>&1)" && "$ORCH" models check gpt-6-astra-light | qgrep -q UNRATED'
rm -f "$ORCH_MODELS_FILE"
newrepo md
printf "${MPLAN/LEADLINE/Lead mode: off}" > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "a plan with models and tiers syncs clean" '[ $code -eq 0 ] && ! grep -qiE "WARN.*(tier|model)" <<<"$out"'
check "state knows each coder model and tier" 'python3 -c "import json,sys;s=json.load(open(\".orchestrate/state.json\"));w=s[\"workers\"];sys.exit(not (w[\"claude-1\"][\"tier\"]==\"medium\" and w[\"codex-1\"][\"model\"]==\"gpt-6-luna@high\" and s[\"tasks\"][\"M1\"][\"tier\"]==\"medium\"))"'
check "pick sends medium work to the medium model, small work to the small one" '[ "$("$ORCH" pick M1)" = claude-1 ] && [ "$("$ORCH" pick M4)" = codex-1 ]'
sed -i 's/claude: sonnet/claude: fable/' .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "a denied model in Workers is an ERROR" '[ $code -eq 2 ] && grep -q "model policy does not allow" <<<"$out"'
sed -i 's/claude: fable/claude: mystery-9/; s/^Tier: medium/Tier: high/' .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "an unknown model warns; a tier nobody can serve warns" '[ $code -eq 0 ] && grep -q "not in the model catalog" <<<"$out"'
sed -i 's/claude: mystery-9/claude: haiku/' .orchestrate/plan.md
out=$("$ORCH" sync 2>&1)
check "a tier no coder reaches warns, and the strongest coder still gets it" 'grep -q "asks for a high-tier model, but no coder" <<<"$out" && [ -n "$("$ORCH" pick M1)" ]'
sed -i 's/^Tier: high/Tier: huge/' .orchestrate/plan.md
"$ORCH" sync >/dev/null 2>&1; code=$?
check "an unknown tier is an ERROR" '[ $code -eq 2 ]'

echo "22. escalation: out of fix rounds on a small model, one fresh round on a stronger one"
newrepo es
printf '# Plan: t\nBranch: feature/es\nCheck command: test ! -f broken.txt\nIsolation: worktree\nMax parallel: 2\nWorkers: claude-1 (claude: sonnet), codex-1 (codex: gpt-6-luna@high)\nReviewer: none\n\n## [x] M18: Report\nDepends on: none\nTier: small\nModel why: looks mechanical.\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 180 "$ORCH" autopilot > "$WORK/es.log" 2>&1; code=$?
check "finished (exit 0)" '[ $code -eq 0 ]'
check "the small model ran out of rounds and the milestone moved up" 'grep -q "medium-tier model gets one fresh round" "$WORK/es.log"'
check "the stronger coder finished it" '"$ORCH" status | qgrep -q "M18 .*merged .*claude-1" && [ -f r.txt ]'
check "report shows each model and the escalation" '"$ORCH" report --json | python3 -c "import json,sys; m={x[\"model\"]:x for x in json.load(sys.stdin)[\"models\"]}; sys.exit(not (m[\"gpt-6-luna@high\"][\"escalated_away\"]==1 and m[\"sonnet\"][\"merged\"]==1))" && "$ORCH" report | qgrep -q "moved up"'
check "summary has the planned-vs-actual model table" 'grep -q "Models: planned and actual" .orchestrate/summary.md && grep -q "| M18 | small | gpt-6-luna@high (small), sonnet (medium) | yes |" .orchestrate/summary.md'

echo "23. the lead's event queue (no event manager running)"
newrepo ev; echo "$APP" > "$FH/lead.dir"
printf "${MPLAN/LEADLINE/Lead: lead (claude: opus)}" > .orchestrate/plan.md
"$ORCH" sync >/dev/null
check "ready milestones wait for the lead's dispatch" '"$ORCH" ready | qgrep -q "HOLD M1" && ! "$ORCH" ready | qgrep -q "^READY"'
out=$("$ORCH" dispatch M1 2>&1)
check "dispatch releases a milestone and names who can take it" 'grep -q "DISPATCH M1 -> claude-1 (tier medium)" <<<"$out" && "$ORCH" ready | qgrep -q "^READY M1"'
check "dispatch says the event manager is not running (autostart off in tests)" 'grep -q "event manager is NOT running" <<<"$out"'
"$ORCH" set M4 paused "which currency should totals use?" >/dev/null
check "a pause is queued for the lead with nobody listening" '"$ORCH" events --peek | qgrep -q "PAUSED M4 .*which currency"'
check "peek does not acknowledge" '"$ORCH" events --peek | qgrep -q "1 new"'
out=$("$ORCH" events --peek)
check "a wake-up prints the hard rules and the playbook rows for its events, word for word" 'grep -q "^WHAT TO DO" <<<"$out" && grep -q "Never answer a worker.s permission prompt yourself" <<<"$out" && grep -q "orch answer Mn --defer AC<n>" <<<"$out" && grep -qF "$(grep "^| \`PAUSED Mn\` with a coder" "$ROOT/playbooks/run.md")" <<<"$out" && ! grep -q "^| \`HELD" <<<"$out"'
"$ORCH" events >/dev/null
check "reading acknowledges; the event stays open until the milestone moves on" '"$ORCH" events | qgrep -q "0 new, 1 still open"'
out=$("$ORCH" answer M4 "INR only" 2>&1)
check "answer writes the note into plan.md and requeues the milestone" 'grep -q "^- INR only" .orchestrate/plan.md && [ "$(status_of M4)" = pending ] && "$ORCH" ready | qgrep -q "^READY M4"'
check "the answered event is closed" '"$ORCH" events | qgrep -q "0 new, 0 still open"'
check "answer refuses a milestone that is not paused" '! "$ORCH" answer M1 "x" >/dev/null 2>&1'
check "sync keeps the queue and the dispatch" '"$ORCH" sync >/dev/null && "$ORCH" ready | qgrep -q "^READY M1"'

echo "24. event-driven run: the lead dispatches, pauses, is woken, answers, and the same coder carries on"
newrepo lr; echo "$APP" > "$FH/lead.dir"; echo "INR only" > "$FH/lead-answer"
printf "${MPLAN/LEADLINE/Lead: lead (claude: opus)}" > .orchestrate/plan.md
"$ORCH" sync >/dev/null && "$ORCH" dispatch M1 M4 >/dev/null
timeout 180 "$ORCH" autopilot > "$WORK/lr.log" 2>&1; code=$?
check "ALL_DONE with no human in between (exit 0)" '[ $code -eq 0 ] && [ "$(status_of M1)$(status_of M4)" = mergedmerged ]'
check "the lead was woken for the question" 'grep -q "woke the lead (lead)" "$WORK/lr.log" && grep -q "PAUSED M4" "$FH/lead-events.log"'
check "the answer reached plan.md and the task file" 'grep -q "^- INR only" .orchestrate/plan.md && [ -f d.txt ]'
check "the answer reached the coder: task.md for its second try has it under Notes from user" 'python3 -c "
import re,sys; t=open(\"$APP/../app-wt/codex-1/.orch-task/M4/task.md\").read()
sys.exit(not re.search(r\"^Notes from user:\\n(.*\\n)*- INR only\", t, re.M))"'
check "the same coder got the milestone back" '[ "$(grep -c "^codex-1 <- .*M4/task.md" "$FH/prompts.log")" -eq 2 ] && ! grep -q "^claude-1 <- .*M4/" "$FH/prompts.log"'
check "the lead was woken at ALL_DONE and finished the summary" 'grep -q "ALL_DONE" "$FH/lead-events.log" && grep -q "check totals by hand" .orchestrate/summary.md'
check "no duplicate wake-ups: one per batch of events" '[ "$(wc -l < "$FH/lead-wakes.log")" -le 4 ]'
check "every event was delivered and read" 'python3 -c "import json,sys;s=json.load(open(\".orchestrate/state.json\"));sys.exit(any(not e[\"read\"] for e in s[\"lead_events\"]) or not s[\"lead_events\"])"'

echo "27. orch fix: a change after ALL_DONE goes straight to the coder who built it"
out=$("$ORCH" fix M1 "the model must also say hello" 2>&1); code=$?
check "fix adds a small follow-up milestone for the coder who built M1" '[ $code -eq 0 ] && grep -q "^FIX M5 .*-> claude-1" <<<"$out" && grep -q "^## \[x\] M5: Fix for M1: the model must also say hello" .orchestrate/plan.md'
check "the fix milestone says why it is separate, so sync does not warn about it" 'grep -q "^Why separate: a change the developer asked for after M1 landed" .orchestrate/plan.md && ! "$ORCH" sync 2>&1 | qgrep -q "M5 has no .Why separate"'
check "it is dispatched already and tied to that coder, with no new plan round" 'python3 -c "import json,sys;t=json.load(open(\".orchestrate/state.json\"))[\"tasks\"][\"M5\"];sys.exit(not (t[\"go\"] and t[\"assign\"]==\"claude-1\" and t[\"fix_of\"]==\"M1\" and t[\"deps\"]==[\"M1\"] and t[\"tier\"]==\"medium\"))" && "$ORCH" ready | qgrep -q "^READY M5"'
check "the plan with the fix in it still syncs, and keeps the dispatch" '"$ORCH" sync >/dev/null 2>&1 && "$ORCH" ready | qgrep -q "^READY M5"'
out=$("$ORCH" fix M5 "x" 2>&1); code=$?
check "fix refuses a milestone that has not landed" '[ $code -eq 2 ] && grep -q "not landed yet" <<<"$out"'
timeout 180 "$ORCH" autopilot > "$WORK/lr2.log" 2>&1; code=$?
check "the fix ran through the check and landed (exit 0)" '[ $code -eq 0 ] && [ "$(status_of M5)" = merged ] && [ -f e.txt ]'
check "only the coder who built M1 was prompted for it" 'grep -q "^claude-1 <- .*M5/task.md" "$FH/prompts.log" && ! grep -q "^codex-1 <- .*M5/" "$FH/prompts.log"'
check "the summary was written again and the earlier one kept" 'grep -q "M5: Fix for M1" .orchestrate/summary.md && grep -q "summary.prev.md" .orchestrate/summary.md && grep -q "check totals by hand" .orchestrate/summary.prev.md'
out=$("$ORCH" fix M4 "totals need a header" --to claude-1 2>&1)
check "--to sends a fix to another coder" 'grep -q "^FIX M6 .*-> claude-1" <<<"$out"'

echo "25. the lead dispatches what becomes ready; a silent lead never stalls the run"
newrepo lw; echo "$APP" > "$FH/lead.dir"
printf '# Plan: t\nBranch: feature/lw\nAuto dispatch: off\nCheck command: true\nIsolation: worktree\nMax parallel: 2\nLead: lead (claude: opus)\nWorkers: claude-1 (claude: sonnet), codex-1 (codex: gpt-6-luna@high)\nReviewer: none\n\n## [x] M5: e\nDepends on: none\nOpen questions:\n- none\n\n## [x] M6: g\nDepends on: M5 (needs e)\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 180 "$ORCH" autopilot > "$WORK/lw.log" 2>&1; code=$?
check "woken with READY, the lead dispatches each milestone as it unlocks" '[ $code -eq 0 ] && [ "$(status_of M5)$(status_of M6)" = mergedmerged ] && grep -q "orch dispatch M6" "$FH/lead-events.log"'
check "the event manager waited for the lead instead of stopping" 'grep -q "waiting for the lead: dispatch M5" "$WORK/lw.log" && ! grep -q "started without it" "$WORK/lw.log"'
newrepo lsil; echo "$APP" > "$FH/lead.dir"; touch "$FH/lead-deaf"
printf '# Plan: t\nBranch: feature/ls\nCheck command: true\nIsolation: worktree\nMax parallel: 2\nLead: lead (claude: opus)\nWorkers: claude-1 (claude: sonnet)\nReviewer: none\n\n## [x] M5: e\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
ORCH_LEAD_WAIT_MIN=0 ORCH_LEAD_REWAKE_S=2 timeout 120 "$ORCH" autopilot > "$WORK/lsil.log" 2>&1; code=$?
check "a lead that never answers: ready work starts by itself" '[ $code -eq 0 ] && [ "$(status_of M5)" = merged ] && grep -q "M5: the lead did not dispatch it" "$WORK/lsil.log"'
check "its events are still in the queue, unread" '"$ORCH" events --peek | qgrep -q "AUTO-DISPATCHED M5" && "$ORCH" events --peek | qgrep -q "ALL_DONE"'
check "ALL_DONE in orch events carries the whole summary step, so the lead needs no playbook reload" 'out=$("$ORCH" events --peek); grep -q "^## 3. ALL_DONE" <<<"$out" && grep -q "Checked by the lead" <<<"$out" && grep -q "Manual verification checklist" <<<"$out" && grep -q "Run \`orch finish\` yourself only when the developer says so" <<<"$out"'
check "a wake-up nobody picked up is sent again, then the developer is told" 'grep -q "did not pick up its wake-up .*-> sent it again (2 of 3)" "$WORK/lsil.log" && grep -q "has not read its events after 3 wake-ups" "$WORK/lsil.log"'
check "status says the wake-up was not picked up" '"$ORCH" status | qgrep -q "wake-up sent 3x .*not picked up yet"'
# the bug report: the last wake-up of a run is lost in the lead's pane, and the event manager used to exit right after
newrepo llost; echo "$APP" > "$FH/lead.dir"; touch "$FH/lead-deaf-once"
printf '# Plan: t\nBranch: feature/ll\nCheck command: true\nIsolation: worktree\nLead: lead (claude: opus)\nWorkers: claude-1 (claude: sonnet)\nReviewer: none\n\n## [x] M5: e\nDepends on: none\nRole: senior backend engineer who cares about clear error messages\nAcceptance criteria:\n- e.txt exists\nOpen questions:\n- none\n' > .orchestrate/plan.md
"$ORCH" sync >/dev/null && "$ORCH" dispatch M5 >/dev/null
timeout 120 "$ORCH" autopilot > "$WORK/llost.log" 2>&1; code=$?
check "a lost wake-up at the end of a run is noticed and sent again before the event manager leaves" '[ $code -eq 0 ] && grep -q "did not pick up its wake-up" "$WORK/llost.log" && [ "$(wc -l < "$FH/lead-wakes.log")" -eq 2 ]'
check "the second wake-up became a turn: ALL_DONE was read and the log says so" 'grep -q "ALL_DONE" "$FH/lead-events.log" && grep -q "the lead (lead) picked up its events" "$WORK/llost.log" && "$ORCH" events --peek | qgrep -q "0 new"'
check "the summary lists what the run already checked, per acceptance criterion" 'grep -q "^## Checked automatically" .orchestrate/summary.md && grep -q "Check command \`true\` on the finished branch: PASS" .orchestrate/summary.md && grep -q "AC1 e.txt exists" .orchestrate/summary.md'
check "the summary asks for a manual checklist of only what a person must see or do" 'grep -q "Manual verification checklist: only what a person must see or do" .orchestrate/summary.md && grep -q "Checked by the lead" .orchestrate/summary.md'
check "the coder is given the role the lead wrote, in task.md and task.json" 'grep -q "For this task you are: \*\*senior backend engineer who cares about clear error messages\*\*" ../app-wt/claude-1/.orch-task/M5/task.md && grep -q "\"role\": \"senior backend engineer" ../app-wt/claude-1/.orch-task/M5/task.json'
check "task.md leaves out the lines only orch uses, and lists the criteria once, with their ids" 'T=../app-wt/claude-1/.orch-task/M5/task.md; ! grep -qE "^(Depends on|Role|Tier|Estimate|Prefer|Review|Model why|Needs|Why separate|Parallel):" $T && [ "$(grep -c "e.txt exists" $T)" -eq 1 ] && grep -q "^- AC1: e.txt exists" $T && grep -q "^Title: e" $T'
check "the playbooks ask for a role per milestone and a by-hand-only checklist" 'grep -q "^Role:" "$ROOT/playbooks/plan.md" && grep -q "Checked by the lead" "$ROOT/playbooks/run.md"'
echo "25b. orch finish: the manual tests go to the developer and to the lead's chat"
out=$("$ORCH" finish --no-push 2>&1); code=$?
check "finish prints the summary's manual tests, numbered, a wrapped line kept with its item" '[ $code -eq 0 ] && grep -q "^MANUAL TESTS: 2 to try by hand before you merge" <<<"$out" && grep -q "^  1. check totals by hand$" <<<"$out" && grep -q "^  2. open /totals on a phone -> the table fits the screen$" <<<"$out"'
check "...and saves them in manual-tests.md" 'grep -q "^2. open /totals on a phone" .orchestrate/manual-tests.md'
check "finish queues FINISHED for the lead and wakes it" 'grep -q "^TOLD THE LEAD (lead)" <<<"$out" && tail -1 "$FH/lead-wakes.log" | qgrep -q "orch finish. ran on feature/ll"'
for _ in $(seq 20); do grep -q "^#[0-9]* FINISHED" "$FH/lead-events.log" && break; sleep 0.5; done
check "the woken lead reads FINISHED with the list and the playbook row to post it in chat" 'grep -q "^#[0-9]* FINISHED: cleaned up, not pushed (--no-push).*2 manual test" "$FH/lead-events.log" && grep -q "^    MANUAL TESTS: 2 to try" "$FH/lead-events.log" && grep -q "^    SAY: The run is finished" "$FH/lead-events.log" && grep -q "^| \`FINISHED\` | .*Try these by hand before you merge" "$FH/lead-events.log"'
check "orch manual prints the same list again" '"$ORCH" manual | qgrep -q "^  2. open /totals on a phone"'
HERDR_PANE_ID=w9:p1; echo w9:p1 > "$FH/lead.paneid"; export HERDR_PANE_ID
nw=$(wc -l < "$FH/lead-wakes.log"); out=$("$ORCH" finish --no-push 2>&1)
check "the lead running finish itself is told to post the list, and not woken" 'grep -q "^LEAD: you ran .orch finish. yourself: post the MANUAL TESTS list" <<<"$out" && [ "$(wc -l < "$FH/lead-wakes.log")" -eq "$nw" ]'
unset HERDR_PANE_ID; rm -f "$FH/lead.paneid"
cp .orchestrate/summary.md "$WORK/sum.bak"; python3 - .orchestrate/summary.md <<'PY'
import re,sys; p=sys.argv[1]; s=open(p).read()
s=s[:s.index("## Manual verification checklist")]+"**Manual verification checklist**\nNothing to check by hand: a CLI change, its tests cover it.\n"
open(p,"w").write(s)
PY
check "a checklist with nothing by hand says so (bold heading too)" '"$ORCH" manual | qgrep -q "^MANUAL TESTS: none. Nothing to check by hand: a CLI change"'
sed -i "/Manual verification checklist\*\*/,\$d" .orchestrate/summary.md
check "no checklist yet: orch manual says the lead has not written it (the Still-to-write line is not a list)" '"$ORCH" manual | qgrep -q "^MANUAL TESTS: not written yet"'
cp "$WORK/sum.bak" .orchestrate/summary.md
newrepo lgone; echo "$APP" > "$FH/lead.dir"; touch "$FH/lead.gone"
printf '# Plan: t\nBranch: feature/lg\nCheck command: true\nIsolation: worktree\nLead: lead (claude: opus)\nWorkers: claude-1 (claude: sonnet)\nReviewer: none\n\n## [x] M5: e\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
ORCH_LEAD_WAIT_MIN=0 timeout 120 "$ORCH" autopilot > "$WORK/lgone.log" 2>&1; code=$?
check "a lead pane that is gone is reported once, and the run still finishes" '[ $code -eq 0 ] && [ "$(grep -c "is not in herdr" "$WORK/lgone.log")" -eq 1 ]'

echo "26. the lead's dispatch starts the event manager when none is running"
newrepo as; echo "$APP" > "$FH/lead.dir"
printf '# Plan: t\nBranch: feature/as\nCheck command: true\nIsolation: worktree\nLead: lead (claude: opus)\nWorkers: claude-1 (claude: sonnet)\nReviewer: none\n\n## [x] M5: e\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
"$ORCH" sync >/dev/null
out=$(ORCH_NO_AUTOSTART=0 "$ORCH" dispatch M5 --to claude-1 2>&1)
check "dispatch starts it and says so" 'grep -q "started the event manager" <<<"$out"'
for _ in $(seq 60); do grep -q "ALL_DONE" .orchestrate/autopilot.log 2>/dev/null && break; sleep 1; done
check "the run it started finishes" '[ "$(status_of M5)" = merged ] && grep -q "ALL_DONE" .orchestrate/autopilot.log'

echo "28. a reviewer herdr can't find: the lead and the developer hear it at once, review resumes after a rename"
newrepo rl; echo "$APP" > "$FH/lead.dir"
printf '# Plan: t\nBranch: feature/rl\nCheck command: true\nIsolation: shared\nMax parallel: 1\nLead: lead (claude: opus)\nWorkers: claude-1 (claude: sonnet)\nReviewer: reviewer (agy)\n\n## [x] M1: Model\nDepends on: none\nReview: yes\nOpen questions:\n- none\n' > .orchestrate/plan.md
"$ORCH" sync >/dev/null
python3 - "$APP" <<'PY'
import json, sys
p = sys.argv[1] + "/.orchestrate/state.json"; s = json.load(open(p))
s["tasks"]["M1"].update(status="awaiting-review", dir=sys.argv[1]); json.dump(s, open(p, "w"))
PY
touch "$FH/reviewer.missing" "$FH/reviewer.deaf"
out=$("$ORCH" review M1 2>&1); code=$?
check "an unreachable reviewer is reported with the rename fix (exit 5)" '[ $code -eq 5 ] && grep -q "REVIEWER_LOST reviewer (try 1)" <<<"$out" && grep -q "herdr agent rename <pane> reviewer" <<<"$out"'
check "the milestone keeps waiting for review" '[ "$(status_of M1)" = awaiting-review ]'
check "the lead gets an event on the first failure" '"$ORCH" events --peek | qgrep -qi "reviewer-lost M1 .*herdr agent rename <pane> reviewer"'
out=$("$ORCH" review M1 2>&1); code=$?
check "no new send while herdr still can't find the reviewer" '[ $code -eq 3 ] && grep -q "benched" <<<"$out"'
rm -f "$FH/reviewer.missing" "$FH/reviewer.deaf"
out=$("$ORCH" review M1 2>&1); code=$?
check "once the reviewer is found again the review goes out at once, no 2-minute wait" '[ $code -eq 0 ] && grep -q "SENT review M1 -> reviewer" <<<"$out"'

echo "11. installer puts the thin skills in every installed agent's folders"
SAFE_PATH="$FAKEBIN:/usr/local/bin:/usr/bin:/bin"
HOME="$IH" PATH="$SAFE_PATH" bash "$ROOT/install.sh" --no-herdr-skill > "$WORK/install.log" 2>&1; code=$?
check "installer ran" '[ $code -eq 0 ]'
check "skills in each installed agent's folder" '(for d in .claude/skills .hermes/skills .gemini/config/skills .agents/skills; do [ -f "$IH/$d/orch-plan/SKILL.md" ] && [ -f "$IH/$d/orch-run/SKILL.md" ] || exit 1; done)'
check "orch-explain installed next to orch-plan and orch-run in each folder" '(for d in .claude/skills .hermes/skills .gemini/config/skills .agents/skills; do cmp -s "$ROOT/skills/orch-explain/SKILL.md" "$IH/$d/orch-explain/SKILL.md" || exit 1; done) && [ ! -e "$IH/.codex/skills/orch-explain" ]'
check "codex gets one copy (from the shared ~/.agents/skills), not a second in ~/.codex/skills" '[ ! -e "$IH/.codex/skills/orch-plan" ]'
check "no claude slash command next to the skill of the same name" '[ ! -e "$IH/.claude/commands/orch-plan.md" ]'
check "agents that aren't installed are skipped" '[ ! -e "$IH/.config/agents/skills" ]'
check "installed skills are thin wrappers" 'grep -q "Run \`orch lead plan\`" "$IH/.hermes/skills/orch-plan/SKILL.md"'
check "playbooks installed" '[ -f "$IH/.local/share/herdr-orchestra/current/playbooks/plan.md" ]'
check "installer ran orch agents sync" 'grep -q "synced .* agent(s)" "$WORK/install.log"'

# a new agent installed later — no need to re-run the installer
printf '#!/bin/sh\n' > "$FAKEBIN/amp"; chmod +x "$FAKEBIN/amp"
out=$(HOME="$IH" PATH="$SAFE_PATH" "$ORCH" agents sync 2>&1); code=$?
check "orch agents sync picks up a newly installed agent" '[ $code -eq 0 ] && grep -qE "^ +(NEW|ok) +amp" <<<"$out"'
check "amp reads the shared copy, so no second copy in its own folder" '[ -f "$IH/.agents/skills/orch-plan/SKILL.md" ] && [ ! -e "$IH/.config/agents/skills/orch-plan" ] && grep -qE "^ +(NEW|ok) +amp +skills: ~/.agents/skills" <<<"$out"'
check "manifest records them for --uninstall" 'grep -q ".agents/skills/orch-plan" "$IH/.local/share/herdr-orchestra/manifest.txt"'
check "agents check passes after sync" 'HOME="$IH" PATH="$SAFE_PATH" "$ORCH" agents check >/dev/null 2>&1'
out=$(HOME="$IH" PATH="$SAFE_PATH" "$ORCH" agents sync 2>&1)
check "second sync is idempotent (ok, nothing NEW)" '[ -z "$(grep NEW <<<"$out")" ] && grep -qE "^ +ok +amp" <<<"$out"'
rm -rf "$IH/.agents/skills"
check "orch agents hints to sync when skills go missing" 'HOME="$IH" PATH="$SAFE_PATH" "$ORCH" agents 2>&1 | qgrep -q "orch agents sync"'
HOME="$IH" PATH="$SAFE_PATH" bash "$ROOT/install.sh" --uninstall > /dev/null 2>&1
check "uninstall removes them all" '[ -z "$(find "$IH" -name "orch-*")" ] && [ ! -e "$IH/.local/bin/orch" ]'

echo "11b. updates replace the skills, never add a second copy"
IH="$WORK/home2"; mkdir -p "$IH"
for b in amp opencode hermes; do rm -f "$FAKEBIN/$b"; done           # claude, codex, agy installed
printf '#!/bin/sh\n' > "$FAKEBIN/opencode"; chmod +x "$FAKEBIN/opencode"
# the layout an older version left behind: the same skill in every folder, slash commands in both OpenCode folders
for d in .claude/skills .codex/skills .agents/skills; do for s in orch-plan orch-run; do mkdir -p "$IH/$d/$s"; cp "$ROOT/skills/$s/SKILL.md" "$IH/$d/$s/"; done; done
mkdir -p "$IH/.claude/commands" "$IH/.config/opencode/commands" "$IH/.config/opencode/command" "$IH/.agents/skills/orch-old" "$IH/.agents/skills/orch-mine" "$IH/.agents/skills/my-skill" "$IH/.local/share/herdr-orchestra"
cp "$ROOT"/claude-commands/orch-*.md "$IH/.claude/commands/"
cp "$ROOT"/opencode-commands/orch-*.md "$IH/.config/opencode/commands/"; cp "$ROOT"/opencode-commands/orch-*.md "$IH/.config/opencode/command/"
echo "Run \`orch lead old\`" > "$IH/.agents/skills/orch-old/SKILL.md"      # a skill an older version shipped, since renamed
printf -- '---\nname: orch-plan\ndescription: Orchestrator step 1 for a Herdr multi-agent team\n---\n\nYou are the LEAD of a Herdr agent team.\n' > "$IH/.codex/skills/orch-plan/SKILL.md"   # the first (4.0) skill: a full playbook, before the manifest
echo "the developer's own skill" > "$IH/.agents/skills/orch-mine/SKILL.md"
echo "not ours" > "$IH/.agents/skills/my-skill/SKILL.md"
echo "$IH/.agents/skills/orch-old" > "$IH/.local/share/herdr-orchestra/manifest.txt"
out=$(HOME="$IH" PATH="$SAFE_PATH" "$ORCH" agents check 2>&1); code=$?
check "agents check finds a skill a tool would list twice" '[ $code -ne 0 ] && grep -q "DUPLICATE codex .*orch-plan  twice: ~/.agents/skills and ~/.codex/skills" <<<"$out" && grep -q "DUPLICATE opencode .*orch-plan.md  twice" <<<"$out"'
check "…but not for a tool whose docs say one copy wins (opencode skills)" '! grep -q "DUPLICATE opencode .*skill " <<<"$out"'
count() { find "$IH" -path "$IH/.local" -prune -o \( -name "orch-plan" -o -name "orch-plan.md" \) -print | sort; }
for i in 1 2 3; do HOME="$IH" PATH="$SAFE_PATH" bash "$ROOT/install.sh" --no-herdr-skill > "$WORK/install$i.log" 2>&1 || break; count > "$WORK/copies$i"; done
check "update: no tool lists a skill twice (codex reads exactly one copy)" 'HOME="$IH" PATH="$SAFE_PATH" "$ORCH" agents check >/dev/null 2>&1'
check "codex keeps the copy in its documented folder, the extra copies were removed" '[ -f "$IH/.agents/skills/orch-plan/SKILL.md" ] && [ ! -e "$IH/.codex/skills/orch-plan" ] && [ ! -e "$IH/.config/opencode/command/orch-plan.md" ] && [ ! -e "$IH/.claude/commands/orch-plan.md" ] && grep -q "removed  old copy ~/.codex/skills/orch-plan" "$WORK/install1.log"'
check "a 4.0 skill (full playbook, not in the manifest) counts as orch's own and is removed" '[ ! -e "$IH/.codex/skills/orch-plan" ]'
check "a skill an older version shipped (in the manifest) is removed" '[ ! -e "$IH/.agents/skills/orch-old" ]'
check "the developer's own skills are left alone" '[ -f "$IH/.agents/skills/orch-mine/SKILL.md" ] && [ -f "$IH/.agents/skills/my-skill/SKILL.md" ]'
check "installing 3 times leaves the same files (one copy per tool)" 'cmp -s "$WORK/copies1" "$WORK/copies3" && [ "$(wc -l < "$WORK/copies3")" -eq 4 ] && grep -q "0 old copies removed" "$WORK/install3.log"'
HOME="$IH" PATH="$SAFE_PATH" bash "$ROOT/install.sh" --uninstall > /dev/null 2>&1
check "uninstall still removes every orch copy, not the developer's" '[ -z "$(find "$IH" -name "orch-p*" -o -name "orch-r*")" ] && [ -f "$IH/.agents/skills/orch-mine/SKILL.md" ]'
# a skills folder that is a symlink to another one is one folder: no copy is deleted from under the other name
IH="$WORK/home3"; mkdir -p "$IH/.agents/skills" "$IH/.claude"; ln -s "$IH/.agents/skills" "$IH/.claude/skills"
out=$(HOME="$IH" PATH="$SAFE_PATH" "$ORCH" agents sync 2>&1); code=$?
check "a symlinked .claude/skills -> .agents/skills: sync keeps one copy and deletes nothing" '[ $code -eq 0 ] && [ -f "$IH/.agents/skills/orch-plan/SKILL.md" ] && grep -q "0 old copies removed" <<<"$out"'
check "…and opencode, which reads both names, is not flagged as a duplicate" 'HOME="$IH" PATH="$SAFE_PATH" "$ORCH" agents check >/dev/null 2>&1'
# an agent that is only missing from PATH right now keeps its copy
IH="$WORK/home4"; mkdir -p "$IH"
printf '#!/bin/sh\n' > "$FAKEBIN/amp"; chmod +x "$FAKEBIN/amp"
HOME="$IH" PATH="$SAFE_PATH" "$ORCH" agents sync >/dev/null 2>&1
rm -f "$FAKEBIN/amp" "$FAKEBIN/opencode" "$FAKEBIN/codex"
out=$(HOME="$IH" PATH="$SAFE_PATH" "$ORCH" agents sync 2>&1)
check "a copy no installed agent reads is left alone (its agent may be off PATH)" '[ -f "$IH/.agents/skills/orch-plan/SKILL.md" ] && grep -q "0 old copies removed" <<<"$out"'
printf '#!/bin/sh\n' > "$FAKEBIN/codex"; chmod +x "$FAKEBIN/codex"

echo "12. one installed tool builds the whole team: orch team <kind>, orch team up"
out=$("$ORCH" team codex 2>&1)
check "team codex: 2 coders across the codex tiers + reviewer on the strongest" 'grep -q "^Workers: codex-1 (codex: gpt-6-luna@high), codex-2 (codex: gpt-6.2-sol@medium)$" <<<"$out" && grep -q "^Reviewer: reviewer (codex: gpt-6.2-sol@medium)$" <<<"$out"'
check "team codex has a high Codex level now (Sol on medium thinking), so no high-tier note" '! grep -q "strongest allowed codex model is" <<<"$out" && grep -q "gpt-6.2-sol@medium  (high tier)" <<<"$out"'
check "team codex prints the lead's own start command on the strongest level, with Codex's question picker on" 'grep -q "^  codex --approve-for-me .* --model gpt-6.2-sol -c model_reasoning_effort=medium -c features.default_mode_request_user_input=true$" <<<"$out"'
out=$("$ORCH" team claude --coders 1 --no-reviewer 2>&1)
check "team claude --coders 1: one coder on the strongest model, no reviewer" 'grep -q "^Workers: claude-1 (claude: opus)$" <<<"$out" && grep -q "^Reviewer: none$" <<<"$out"'
out=$("$ORCH" team codex --models gpt-6-astra 2>&1); code=$?
check "team refuses a denied model" '[ $code -ne 0 ] && grep -q "not allowed by the model policy" <<<"$out"'
check "team works outside a git repo" '(cd "$WORK" && "$ORCH" team codex >/dev/null 2>&1)'
newrepo team
cat > .orchestrate/plan.md <<'PLAN'
# Plan: solo tool
Branch: feature/solo
Check command: true
Isolation: worktree
Max parallel: 2
Lead: lead (codex: gpt-6.2-sol@medium)
Workers: codex-1 (codex: gpt-6-luna@high), codex-2 (codex: gpt-6.2-sol@low)
Reviewer: reviewer (codex: gpt-6.2-sol@medium)

## [x] M1: a
Depends on: none
Open questions:
- none
PLAN
"$ORCH" sync >/dev/null 2>&1
check "a plan with only codex panes (lead, 2 coders, reviewer) passes sync" '"$ORCH" sync 2>&1 | qgrep -q "^OK: 1 tasks"'
out=$("$ORCH" team up 2>&1); code=$?
check "team up before orch start asks for orch start (worktrees first)" '[ $code -ne 0 ] && grep -q "run \`orch start\` first" <<<"$out"'
touch "$FH/codex-2.missing" "$FH/reviewer.missing"
"$ORCH" start >/dev/null 2>&1
out=$("$ORCH" start 2>&1)
check "orch start shows the missing codex panes" 'grep -q "WORKER codex-2 .*herdr=NOT FOUND" <<<"$out" && grep -q "REVIEWER reviewer .*herdr=NOT FOUND" <<<"$out"'
out=$(printf '[codex]\nreview_launch = "codex --sandbox read-only"\n' > "$WORK/rev-agents.toml"; ORCH_AGENTS_FILE="$WORK/rev-agents.toml" "$ORCH" team up --dry-run 2>&1)
check "team up starts the reviewer with the kind's review_launch, the coders with launch" 'grep -q "^WOULD   reviewer: .*codex --sandbox read-only --model gpt-6.2-sol -c model_reasoning_effort=medium" <<<"$out" && grep -q "^WOULD   codex-2: .*codex --approve-for-me .* --model gpt-6.2-sol -c model_reasoning_effort=low" <<<"$out"'
out=$("$ORCH" team up --dry-run 2>&1)
check "team up --dry-run only prints the commands" 'grep -q "^WOULD   codex-2: .*pane split --direction right --cwd .*app-wt/codex-2 --no-focus" <<<"$out" && [ ! -f "$FH/team.log" ]'
out=$(ORCH_TEAM_WAIT_S=2 "$ORCH" team up 2>&1); code=$?
check "team up skips the agent that already runs" 'grep -q "^ok      codex-1: already running" <<<"$out"'
check "team up opens the coder in its own worktree, on its plan model and thinking level" '[ $code -eq 0 ] && grep -q "^OPENED  codex-2: pane w1:p2 in .*app-wt/codex-2 running \`codex --approve-for-me .* --model gpt-6.2-sol -c model_reasoning_effort=low\`" <<<"$out"'
check "…and the Codex pane can reach herdr and write the repo .git (its sandbox blocks both otherwise)" 'grep -q "^OPENED  codex-2: .*sandbox_workspace_write.network_access=true -c .sandbox_workspace_write.writable_roots=\[\"$APP/.git\"\]. --model" <<<"$out"'
check "the reviewer opens in the repo, below the coder, and is named" 'grep -q "split w1:p2 --direction down --cwd $APP --no-focus" "$FH/team.log" && grep -q "rename w1:p3 reviewer" "$FH/team.log"'
out=$("$ORCH" start 2>&1)
check "after team up every agent is found" '! grep -q "NOT FOUND" <<<"$out"'
out=$("$ORCH" team up 2>&1)
check "team up again is a no-op" 'grep -q "^TEAM UP: every agent in the plan is running" <<<"$out"'
touch "$FH/codex-2.missing" "$FH/nodetect"
out=$(ORCH_TEAM_WAIT_S=1 "$ORCH" team up 2>&1); code=$?
# its pane (w1:p2) is still there in its own folder, so the agent is started again in it, not in a second pane
check "an agent herdr never detects is reported with the rename command (exit 3)" '[ $code -eq 3 ] && grep -q "^WAITING codex-2: .*herdr agent rename w1:p2 codex-2" <<<"$out"'
check "…and a coder's pane that is still there is used again, no second pane next to it" '[ "$(grep -c "^split " "$FH/team.log")" -eq 2 ] && [ "$(grep -c "^run w1:p2 " "$FH/team.log")" -eq 2 ]'
rm -f "$FH/nodetect"
check "playbook step 3 builds the team with orch team when the lead is alone" 'grep -q "orch team <your kind>" "$ROOT/playbooks/plan.md" && grep -q "orch team up" "$ROOT/playbooks/run.md"'

echo "29. estimate vs actual time, and why it took longer"
newrepo est
printf '# Plan: t\nBranch: feature/est\nEstimate: 1h30x\nCheck command: true\nIsolation: worktree\nMax parallel: 2\nWorkers: claude-1 (claude), codex-1 (codex)\nReviewer: none\n\n## [x] M1: a\nDepends on: none\nEstimate: 40m\nOpen questions:\n- none\n\n## [x] M2: b\nDepends on: none\nWhy separate: parallel\nOpen questions:\n- none\n' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "a feature Estimate that is not a duration is an ERROR" '[ $code -eq 2 ] && grep -q "Estimate must look like" <<<"$out"'
sed -i 's/^Estimate: 1h30x/Estimate: 1h30m/' .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "a milestone without Estimate warns; estimates are stored" '[ $code -eq 0 ] && grep -q "M2 has no \`Estimate:\`" <<<"$out" && python3 -c "
import json; st = json.load(open(\".orchestrate/state.json\")); assert st[\"estimate_s\"] == 5400 and st[\"tasks\"][\"M1\"][\"estimate_s\"] == 2400 and st[\"tasks\"][\"M2\"][\"estimate_s\"] is None"'
check "durations: 45m, 1h30m, 1.5h, 90 min, 2 hours; junk is refused" 'python3 -c "
import importlib.machinery, importlib.util
l = importlib.machinery.SourceFileLoader(\"orch\", \"$ROOT/bin/orch\"); m = importlib.util.module_from_spec(importlib.util.spec_from_loader(\"orch\", l)); l.exec_module(m)
assert [m.parse_dur(x) for x in (\"45m\", \"1h30m\", \"1.5h\", \"90 min\", \"2 hours\", \"soon\", \"\", \"3\")] == [2700, 5400, 5400, 5400, 7200, None, None, None]"'
# a finished run with known times: M1 (estimate 40m) took 1h40m, M2 (estimate 30m) took 25m
python3 - <<'PY'
import json; p = ".orchestrate/state.json"; st = json.load(open(p)); T = 1_000_000
st["run"] = {"started": T, "ended": T + 7200}
m1, m2 = st["tasks"]["M1"], st["tasks"]["M2"]
m2["estimate_s"] = 1800
ev = lambda tid, ts, frm, to, why="", agent="claude-1": {"ts": T + ts, "task": tid, "from": frm, "to": to, "why": why, "agent": agent}
evs = [ev("M1", 0, "pending", "coding"), ev("M1", 1200, "coding", "verifying"), ev("M1", 1260, "verifying", "coding"),
       ev("M1", 2160, "coding", "paused", "which currency?"), ev("M1", 3360, "paused", "pending", "answered: INR"),
       ev("M1", 3360, "pending", "coding"), ev("M1", 4800, "coding", "pending", "claude-1 hit a usage/rate limit"),
       ev("M1", 5400, "pending", "coding", agent="codex-1"), ev("M1", 5940, "coding", "verifying", agent="codex-1"),
       ev("M1", 6000, "verifying", "merged", agent="codex-1"),
       ev("M2", 0, "pending", "coding", agent="codex-1"), ev("M2", 1500, "coding", "merged", agent="codex-1")]
open(".orchestrate/events.jsonl", "w").write("".join(json.dumps(e) + "\n" for e in evs))
a = lambda s, e, agent, f, out="done", model=None, **k: dict(kind="coder", agent=agent, file=f, start=T + s, end=T + e, secs=e - s, outcome=out, **({"model": model} if model else {}), **k)
m1["attempts"] = [a(0, 1200, "claude-1", "task.md", model="sonnet"), a(1260, 2160, "claude-1", "fix-1.md", model="sonnet", blocked_s=300),
                  a(3360, 4800, "claude-1", "task.md", "parked as pending: claude-1 hit a usage/rate limit", model="sonnet"),
                  a(5400, 5940, "codex-1", "task.md", model="gpt-6-sol")]
m1["checks"] = [{"where": "worktree", "ok": False, "secs": 60, "ts": T + 1260}, {"where": "worktree", "ok": True, "secs": 60, "ts": T + 6000}]
m2["attempts"] = [a(0, 1500, "codex-1", "task.md", model="gpt-6-sol")]
for t in (m1, m2):
    t["status"] = "merged"
json.dump(st, open(p, "w"))
PY
out=$("$ORCH" report 2>&1); code=$?
check "report: feature estimate vs actual, and how much longer" '[ $code -eq 0 ] && grep -q "Whole feature: estimated 1h30m, actual 1h40m, 10m longer than estimated" <<<"$out"'
check "report: one row per milestone with estimate, actual, difference and who built it" 'grep -q "| M1 | 40m | 1h40m | +1h00m | claude-1 (sonnet), codex-1 (gpt-6-sol) |" <<<"$out" && grep -q "| M2 | 30m | 25m | -5m | codex-1 (gpt-6-sol) |" <<<"$out"'
check "why M1 was late: fix round by its coder, the developer answer, the usage limit, the permission prompt" 'grep -q "Why M1 took 1h00m longer than its 40m estimate" <<<"$out" && grep -qF "20m developer / lead: paused, waiting for the lead or the developer (which currency?)" <<<"$out" && grep -qF "10m claude-1 (sonnet): fix rounds: the check command failed" <<<"$out" && grep -qF "5m claude-1: stopped at a permission prompt or question in its pane" <<<"$out" && grep -qF "24m claude-1 (sonnet): work cut short (claude-1 hit a usage/rate limit)" <<<"$out" && grep -qF "10m claude-1: agent hit a usage limit: benched, work waited for another coder" <<<"$out" && grep -qF "1m check command: checks run again after fixes" <<<"$out" && grep -qF "(M1)" <<<"$out"'
check "a milestone quicker than its estimate gets no why" '! grep -q "Why M2" <<<"$out"'
check "report --json carries the time account" '"$ORCH" report --json | python3 -c "import json,sys; t=json.load(sys.stdin)[\"time\"]; assert t[\"feature\"][\"actual_s\"] == 6000 and t[\"feature\"][\"over_s\"] == 600 and t[\"tasks\"][0][\"over_s\"] == 3600"'
check "the plan playbook asks for estimates and the summary has the time section" 'grep -q "^Estimate:" "$ROOT/playbooks/plan.md" && grep -q "Time: estimate vs actual" "$ROOT/bin/orch"'

echo "30. after a restart: time orch was down is not agent time"
newrepo dn; WT="$APP/../app-wt"
printf '%b' "${PRS/ISO/worktree}" > .orchestrate/plan.md
"$ORCH" sync >/dev/null && "$ORCH" start >/dev/null && "$ORCH" prepare M9 codex-1 >/dev/null && "$ORCH" write-task M9 >/dev/null && "$ORCH" send M9 task.md >/dev/null
sleep 2; echo working > "$FH/codex-1.status"            # the coder is in the middle of M9
# the computer was off for about 2 hours: M9 was sent 2h05m ago, the event manager was last alive 2h ago
stpy "
w = st['tasks']['M9']['wait']; w['since'] -= 7500; w['started'] -= 7500
st['tasks']['M5']['go'] = True
st['run'].update(started=now - 8000, beat=now - 7200)"
out=$("$ORCH" status 2>&1)
check "status says loudly that the event manager is not running, since when, and what to run" 'head -1 <<<"$out" | qgrep -q "^!! EVENT MANAGER NOT RUNNING since .* (2h00m ago)" && grep -q "^!! Run \`orch resume\`" <<<"$out"'
"$ORCH" set M5 paused "kept out of this test" >/dev/null
timeout 12 "$ORCH" autopilot > "$WORK/dn.log" 2>&1
check "the 2 hours orch was down do not put the coder over its time budget" '! grep -q "over its time budget" "$WORK/dn.log" && [ "$(status_of M9)" = coding ]'
check "the event manager says it is back after a gap, and for how long" 'grep -q "back after a gap" "$WORK/dn.log" && grep -q "DOWN    orch was not running from .* (2h00m)" "$WORK/dn.log"'
check "a coder that is already working again is left alone (no second prompt)" 'grep -q "OK      M9: codex-1 is already working" "$WORK/dn.log" && [ "$(grep -c "M9/task.md" "$FH/prompts.log")" -eq 1 ]'
check "the gap is kept on the wait and in the run" 'python3 -c "
import json; st = json.load(open(\".orchestrate/state.json\")); w = st[\"tasks\"][\"M9\"][\"wait\"]
assert 7190 <= w[\"down_s\"] <= 7260, w; d = st[\"run\"][\"downs\"]; assert len(d) == 1 and 7190 <= d[0][\"to\"] - d[0][\"from\"] <= 7260, d"'
check "status has no warning for a run nobody has driven yet" '(newrepo dn0 && printf "%b" "${PRS/ISO/worktree}" > .orchestrate/plan.md && "$ORCH" sync >/dev/null && ! "$ORCH" status | qgrep -q "EVENT MANAGER")'
cd "$APP" && export FH="$WORK/dn/fh"
stpy "
w = st['tasks']['M9']['wait']; w['since'] -= 7200; w['started'] -= 7200     # 2 more hours went by, asleep
for d in st['run']['downs']:
    d['from'] -= 7200; d['to'] -= 7200"
out=$(ORCH_TEST_SLEPT_S=7200 "$ORCH" poll 1 2>&1)
check "a laptop that slept 2 hours while the event manager stayed up: the sleep is not working time either" '! grep -q TIMEOUT <<<"$out" && grep -q "^WAITING M9:coding" <<<"$out" && python3 -c "
import json; st = json.load(open(\".orchestrate/state.json\")); d = st[\"run\"][\"downs\"]
assert len(d) == 2 and 7195 <= d[1][\"to\"] - d[1][\"from\"] <= 7205, d; assert 14390 <= st[\"tasks\"][\"M9\"][\"wait\"][\"down_s\"] <= 14470"'
check "one sleep is taken out once, even when two processes notice it" 'python3 -c "
import importlib.machinery, importlib.util, json, time
l = importlib.machinery.SourceFileLoader(\"orch\", \"$ROOT/bin/orch\"); m = importlib.util.module_from_spec(importlib.util.spec_from_loader(\"orch\", l)); l.exec_module(m)
st = json.load(open(\".orchestrate/state.json\")); n = len(st[\"run\"][\"downs\"])
assert m.account_downtime(st, 7200) == 0 and len(st[\"run\"][\"downs\"]) == n, st[\"run\"][\"downs\"]
st[\"run\"][\"downs\"] = []; assert m.account_downtime(st, 7200) == 7200"'
stpy "st['tasks']['M9']['wait']['since'] -= 46 * 60"
out=$("$ORCH" poll 1 2>&1)
check "real working time still counts: 46 more minutes is over the budget" 'grep -q "^TIMEOUT M9 agent=codex-1 after 5[0-9] min" <<<"$out"'
out=$("$ORCH" park M9 paused "codex-1 over its time budget" 2>&1)
check "a coder that is still working when its milestone is paused is told to stop" 'grep -q "^STOP_NOTE M9 -> codex-1" <<<"$out" && grep -q "^codex-1 <- STOP: M9 is paused (codex-1 over its time budget). orch interrupted you: stop working on it now" "$FH/prompts.log" && grep -q "^codex-1 keys esc$" "$FH/keys.log"'
check "the attempt is charged its working time, not the 2 hours down" 'python3 -c "
import json; a = json.load(open(\".orchestrate/state.json\"))[\"tasks\"][\"M9\"][\"attempts\"][-1]
assert 14390 <= a[\"down_s\"] <= 14470 and 290 <= a[\"secs\"] <= 440, a"'
sleep 2
out=$("$ORCH" park M5 paused "again" 2>&1)
check "a milestone no coder is working on gets no stop note" '! grep -q STOP_NOTE <<<"$out"'

echo "31. unsaved work is always saved first: park, dispatch and prepare never refuse"
echo late > "$WT/codex-1/late.txt"                      # the paused coder kept writing after M9 was parked
out=$("$ORCH" dispatch M9 2>&1); code=$?
check "dispatch saves what the paused coder wrote meanwhile into the milestone's saved work" '[ $code -eq 0 ] && grep -q "^SAVED codex-1.s unsaved files into M9.s saved work (refs/orch/feature-rs/M9)" <<<"$out" && git show --stat refs/orch/feature-rs/M9 | qgrep -q late.txt && [ -z "$(git -C "$WT/codex-1" status --porcelain)" ]'
echo later > "$WT/codex-1/later.txt"; echo more >> "$WT/codex-1/late.txt"
out=$("$ORCH" park M9 pending "again" 2>&1)
check "orch park on an already parked milestone saves too (it used to print PARKED and save nothing)" 'grep -q "^SAVED codex-1" <<<"$out" && git show refs/orch/feature-rs/M9:late.txt | qgrep -q more && git show --stat refs/orch/feature-rs/M9 | qgrep -q later.txt'
echo last > "$WT/codex-1/last.txt"
out=$("$ORCH" prepare M9 codex-1 2>&1); code=$?
check "prepare with unsaved files in the folder saves them and goes on (no \"park or clean that worker first\")" '[ $code -eq 0 ] && grep -q "^SAVED codex-1" <<<"$out" && ! grep -q "park or clean" <<<"$out" && [ "$(status_of M9)" = coding ] && [ -f "$WT/codex-1/late.txt" ] && [ -f "$WT/codex-1/later.txt" ] && [ -f "$WT/codex-1/last.txt" ]'
echo whose > "$WT/claude-1/whose.txt"                   # files in a folder whose coder never had a milestone
"$ORCH" set M5 pending >/dev/null
out=$("$ORCH" prepare M5 claude-1 2>&1); code=$?
check "files orch can't give to a milestone go to a rescue ref, and the task still starts" '[ $code -eq 0 ] && grep -q "^RESCUED claude-1.s unsaved files: .* kept in refs/orch/feature-rs/rescue-claude-1-" <<<"$out" && [ "$(status_of M5)" = coding ] && [ ! -f "$WT/claude-1/whose.txt" ] && git show --stat "$(git for-each-ref --format="%(refname)" "refs/orch/feature-rs/rescue-claude-1-*")" | qgrep -q whose.txt'
# a milestone in review is never changed behind the reviewer's back: stray files there are rescued, not added
"$ORCH" park M5 pending >/dev/null; "$ORCH" prepare M5 claude-1 >/dev/null; echo e > "$WT/claude-1/e.txt"
"$ORCH" handoff M5 >/dev/null; stpy "st['tasks']['M5']['status'] = 'reviewing'"
echo sneaky > "$WT/claude-1/sneaky.txt"; before=$(git rev-parse refs/orch/feature-rs/M5)
stpy "st['tasks']['M9']['status'] = 'pending'; st['tasks']['M9']['worker'] = None; st['workers']['codex-1']['task'] = None"
out=$("$ORCH" prepare M9 claude-1 2>&1); code=$?
check "files written after a handoff do not slip into the work under review" '[ $code -eq 0 ] && grep -q "^RESCUED claude-1" <<<"$out" && [ "$(git rev-parse refs/orch/feature-rs/M5)" = "$before" ]'

newrepo dsh; echo "$APP" > "$FH/claude-1.dir"; echo "$APP" > "$FH/codex-1.dir"
printf '%b' "${PRS/ISO/shared}" > .orchestrate/plan.md
"$ORCH" sync >/dev/null && "$ORCH" start >/dev/null && "$ORCH" prepare M9 codex-1 >/dev/null && "$ORCH" write-task M9 >/dev/null && "$ORCH" send M9 task.md >/dev/null
sleep 2; echo one > w1.txt; "$ORCH" park M9 paused "stopped" >/dev/null
echo two > w2.txt; echo changed >> shared.txt             # written after the pause, in the shared folder
out=$("$ORCH" dispatch M9 2>&1); code=$?
check "shared mode: files written after the pause are added to the milestone's saved work" '[ $code -eq 0 ] && grep -q "^SAVED the unsaved files in the main folder into M9" <<<"$out" && [ -z "$(git status --porcelain)" ]'
out=$("$ORCH" prepare M9 codex-1 2>&1); code=$?
check "shared mode: the coder gets the milestone back with all of it" '[ $code -eq 0 ] && [ "$(cat w1.txt)" = one ] && [ "$(cat w2.txt)" = two ] && grep -q changed shared.txt'
"$ORCH" park M9 paused "stopped again" >/dev/null
echo other > w1.txt                                       # clashes with the saved w1.txt
out=$("$ORCH" prepare M9 codex-1 2>&1); code=$?
check "shared mode: files that clash with the saved work are kept in a rescue ref, the saved work comes back" '[ $code -eq 0 ] && grep -q "^RESCUED the unsaved files in the main folder" <<<"$out" && [ "$(cat w1.txt)" = one ] && [ "$(cat w2.txt)" = two ] && [ -n "$(git for-each-ref "refs/orch/feature-rs/rescue-M9-*")" ]'
"$ORCH" park M9 pending >/dev/null; stpy "st['tree_task'] = None"; echo mine > dev.txt
out=$("$ORCH" prepare M9 codex-1 2>&1); code=$?
check "shared mode: the developer's own uncommitted files are still not touched" '[ $code -ne 0 ] && grep -q "can.t be restored" <<<"$out" && [ -f dev.txt ]'

echo "32. orch resume: one command after a restart"
newrepo rs; WT="$APP/../app-wt"
printf '%b' "${PRS/ISO/worktree}" > .orchestrate/plan.md
"$ORCH" sync >/dev/null && "$ORCH" start >/dev/null && "$ORCH" prepare M9 codex-1 >/dev/null && "$ORCH" write-task M9 >/dev/null && "$ORCH" send M9 task.md >/dev/null
sleep 2
# (this folder's state.json is left from an earlier section, where claude-1 built M16: no /compact before M5 here)
ORCH_COMPACT=0 "$ORCH" prepare M5 claude-1 >/dev/null; echo half > "$WT/claude-1/half.txt"; "$ORCH" park M5 pending "claude-1 hit a usage/rate limit" >/dev/null
echo more > "$WT/claude-1/more.txt"                       # written after M5 was parked, before the power went
stpy "
w = st['tasks']['M9']['wait']; w['since'] -= 7500; w['started'] -= 7500
st['run'].update(started=now - 8000, beat=now - 7200)"
# herdr after the restart: the panes are back in their folders, the names are gone. codex-1's agent runs again
# (pane w1:p7), claude-1's pane is a plain shell (w1:p8), the reviewer's pane sits next to the developer's shell
touch "$FH/codex-1.missing" "$FH/claude-1.missing" "$FH/reviewer.missing"
echo "$WT/codex-1" > "$FH/pane-w1:p7.cwd"; echo codex > "$FH/pane-w1:p7.cmd"
echo "$WT/claude-1" > "$FH/pane-w1:p8.cwd"
echo "$APP" > "$FH/pane-w1:p20.cwd"; echo agy > "$FH/pane-w1:p20.cmd"; echo "$APP" > "$FH/pane-w1:p21.cwd"
out=$("$ORCH" start 2>&1)
check "orch start points at orch resume when herdr can't find an agent" 'grep -q "^HINT .*orch resume" <<<"$out"'
out=$("$ORCH" resume 2>&1); code=$?
check "resume says how long orch was down and what was in progress" '[ $code -eq 0 ] && grep -q "^DOWN    orch was not running from .* (2h00m). That time is not counted" <<<"$out" && grep -q "^WAS     M9 \"Stalls\": codex-1 was working on it" <<<"$out"'
check "resume gives a coder's pane its name back, found by its folder" 'grep -q "^NAMED   codex-1: pane w1:p7 " <<<"$out" && grep -q "^rename w1:p7 codex-1" "$FH/team.log" && [ ! -f "$FH/codex-1.missing" ]'
check "a pane with no agent in it: resume says how to start it and prints the rename command" 'grep -q "^LOST    claude-1: pane w1:p8 is in its folder .*orch team up.* starts it there.*herdr agent rename w1:p8 claude-1" <<<"$out"'
check "in the main folder a pane is only renamed when it shows the right kind; otherwise the command is printed" 'grep -q "^LOST    reviewer: can.t tell which pane is reviewer (w1:p20, w1:p21 are in .*herdr agent rename <pane> reviewer" <<<"$out" && ! grep -q "rename w1:p2[01]" "$FH/team.log"'
check "resume saves the unsaved files a coder left behind" 'grep -q "^SAVED claude-1.s unsaved files into M5" <<<"$out" && git show --stat refs/orch/feature-rs/M5 | qgrep -q more.txt'
check "resume sends the task in progress to its coder again, as a carry-on" 'grep -q "^RESENT  M9 -> codex-1" <<<"$out" && grep -q "^codex-1 <- orch was restarted .*carry on from there. Do not start over. Read .orch-task/M9/task.md .*done-1" "$FH/prompts.log"'
check "resume ends by starting the event manager (here: says it could not, autostart is off in tests)" 'grep -q "the event manager is NOT running" <<<"$out"'
check "the 2 hours are not on the coder's clock after resume" 'python3 -c "
import json, time; w = json.load(open(\".orchestrate/state.json\"))[\"tasks\"][\"M9\"][\"wait\"]
assert time.time() - w[\"since\"] < 60 and 7190 <= w[\"down_s\"] <= 7260 and not w[\"delivering\"], w"'
echo agy > "$FH/pane-w1:p20.kind"; sleep 2; echo working > "$FH/codex-1.status"   # codex-1 is on M9 again
out=$("$ORCH" resume 2>&1); code=$?
check "running resume again is safe: the reviewer is named once herdr shows its kind, nothing is sent twice" '[ $code -eq 0 ] && grep -q "^NAMED   reviewer: pane w1:p20 " <<<"$out" && ! grep -q "^DOWN" <<<"$out" && [ "$(grep -c "M9/task.md" "$FH/prompts.log")" -eq 2 ]'
out=$(ORCH_TEAM_WAIT_S=2 "$ORCH" team up 2>&1); code=$?
check "team up starts the agent again in its old pane instead of opening a second one" '[ $code -eq 0 ] && grep -q "^OPENED  claude-1: pane w1:p8 " <<<"$out" && grep -q "^run w1:p8 cd .*app-wt/claude-1 && claude" "$FH/team.log" && ! grep -q "^split" "$FH/team.log"'
touch "$FH/codex-1.missing"; rm -f "$FH"/pane-w1:p7.*; echo idle > "$FH/codex-1.status"
out=$("$ORCH" resume 2>&1); code=$?
check "an agent with work in progress that is really gone: resume stops (exit 3) and says what to do" '[ $code -eq 3 ] && grep -q "^LOST    codex-1: no pane is left in its folder .*orch team up" <<<"$out" && grep -q "^NOT SENT M9: codex-1 is not found" <<<"$out" && grep -q "^NOT STARTED: codex-1 (M9) must be running first" <<<"$out"'
touch "$FH/nolist"
out=$("$ORCH" resume 2>&1)
check "when herdr can't list panes, resume still prints the rename command to use" 'grep -q "^LOST    codex-1: .*herdr agent rename <pane> codex-1" <<<"$out"'
rm -f "$FH/nolist" "$FH/codex-1.missing"
"$ORCH" park M9 paused "kept" >/dev/null; "$ORCH" set M5 paused "kept" >/dev/null
newrepo rsm; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
{ printf '%b' "$P1"; printf '## [x] M6: G\nDepends on: none\nOpen questions:\n- none\n'; } > .orchestrate/plan.md
"$ORCH" sync >/dev/null && "$ORCH" start >/dev/null
stpy "st['run'].update(started=now - 8000, beat=now - 7200)"
out=$(ORCH_NO_AUTOSTART=0 "$ORCH" resume 2>&1); code=$?
check "resume starts the event manager and the run carries on to the end" '[ $code -eq 0 ] && grep -q "started the event manager" <<<"$out"'
for _ in $(seq 60); do grep -q "ALL_DONE" .orchestrate/autopilot.log 2>/dev/null && break; sleep 1; done
check "…the run it started finishes" '[ "$(status_of M6)" = merged ] && grep -q "ALL_DONE" .orchestrate/autopilot.log'
out=$("$ORCH" resume 2>&1)
check "the time report leaves the time orch was down out" '(cd "$WORK/est/app" && python3 - <<PY && "$ORCH" report
import json; p = ".orchestrate/state.json"; st = json.load(open(p)); T = 1_000_000
st["run"]["downs"] = [{"from": T + 2400, "to": T + 3000}]      # 10 of the 20 minutes M1 sat paused
json.dump(st, open(p, "w"))
PY
) > "$WORK/est-down.txt" 2>&1 && grep -q "Whole feature: estimated 1h30m, actual 1h30m, on time" "$WORK/est-down.txt" && grep -q "^Not counted: 10m while orch was not running" "$WORK/est-down.txt" && grep -q "| M1 | 40m | 1h30m | +50m |" "$WORK/est-down.txt" && grep -qF "10m developer / lead: paused" "$WORK/est-down.txt"'
check "the playbook and the README tell what to do after a restart" 'grep -q "orch resume" "$ROOT/playbooks/run.md" && grep -q "orch resume" "$ROOT/README.md"'

echo "30. quick runs: a small change without the full ceremony"
newrepo qk; echo "$APP" > "$FH/claude-1.dir"
QK='# Plan: Small things\nMode: quick\nQuick because: g.txt already exists as a pattern; one file, no schema, auth or payment code\nBranch: feature/qk\nCheck command: echo x >> '"$WORK"'/qk-checks; true\nEstimate: 15m\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M6: G\nDepends on: none\nTier: small\nEstimate: 15m\nLikely files: g.txt\nAcceptance criteria:\n- g.txt exists\nOpen questions:\n- none\n'
printf "$QK" | sed '/^Quick because:/d' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "quick plan without a reason is refused" '[ $code -eq 2 ] && grep -q "needs .Quick because:" <<<"$out"'
{ printf "$QK"; printf '\n## [x] M7: H\nDepends on: none\nLikely files: h.txt\nOpen questions:\n- none\n'; } > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "quick plan with two milestones is refused" '[ $code -eq 2 ] && grep -q "is one milestone, and this plan has 2" <<<"$out"'
printf "$QK" | sed 's#^Likely files: g.txt#Likely files: g.txt, db/migrations/001.sql, package.json#' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "quick plan that lists a migration or a dependency file is refused" '[ $code -eq 2 ] && grep -q "database migration: db/migrations/001.sql" <<<"$out" && grep -q "dependency file: package.json" <<<"$out"'
printf "$QK" | sed 's#^Likely files: g.txt#Likely files: g.txt, src/auth/login.ts#' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "quick plan that lists auth code warns" '[ $code -eq 0 ] && grep -q "WARN: M6 lists src/auth/login.ts, which looks like auth, payment or schema code" <<<"$out"'
printf "$QK" > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "quick plan: shared folder by default, mode shown" '[ $code -eq 0 ] && grep -q "^OK: 1 tasks, mode=quick, isolation=shared" <<<"$out" && "$ORCH" status | qgrep -q "^QUICK RUN because: g.txt already exists"'
rm -f "$WORK/qk-checks"
timeout 90 "$ORCH" autopilot > "$WORK/qk.log" 2>&1; code=$?
check "quick run lands" '[ $code -eq 0 ] && [ "$(status_of M6)" = merged ] && [ -f g.txt ] && [ ! -d "$APP/../app-wt" ]'
check "…the check ran twice (before and after the coder), the final check reused it" '[ "$(wc -l < "$WORK/qk-checks")" -eq 2 ] && grep -q "final check: the check already passed on exactly these files" "$WORK/qk.log"'
check "…short summary: the reason, what changed, no design notes" 'grep -q "^Quick run because: g.txt" .orchestrate/summary.md && grep -q "^- What changed" .orchestrate/summary.md && ! grep -q "Design decisions" .orchestrate/summary.md'
out=$("$ORCH" finish --no-push 2>&1); code=$?
check "finish reuses the green check on the same files" '[ $code -eq 0 ] && grep -q "^CHECK reused" <<<"$out" && [ "$(wc -l < "$WORK/qk-checks")" -eq 2 ]'
newrepo qk2; echo "$APP" > "$FH/claude-1.dir"
printf "$QK" | sed 's/feature\/qk/feature\/qk2/' > .orchestrate/plan.md
timeout 90 "$ORCH" autopilot > "$WORK/qk2.log" 2>&1
echo later > later.txt && git add later.txt && git commit -qm "a change by hand after the run"
out=$("$ORCH" finish --no-push 2>&1); code=$?
check "finish runs the check again when the files changed since it passed" '[ $code -eq 0 ] && ! grep -q "^CHECK reused" <<<"$out" && [ "$(wc -l < "$WORK/qk-checks")" -eq 5 ]'
check "the playbook explains quick runs and how the lead decides" 'grep -q "## 2b. Quick or full" "$ROOT/playbooks/plan.md" && grep -q "Quick because:" "$ROOT/playbooks/plan.md" && grep -q "QUICK RUN" "$ROOT/playbooks/run.md"'

echo "30b. feature planning is not changed by quick runs"
newrepo ff
FULL='# Plan: Discounts\nBranch: feature/disc\nCheck command: true\nSetup command: none\nEstimate: 1h10m\nMax parallel: 2\nWorkers: claude-1 (claude), codex-1 (codex)\nReviewer: reviewer (agy)\n\n## Feature breakdown\n- a discount column, the API that applies it, and the checkout UI\n\n## [x] M1: Discount column\nDepends on: none\nWhy separate: a foundation the API and the UI build on\nTier: medium\nEstimate: 30m\nRole: database engineer: reversible migration\nReview: yes\nLikely files: db/migrations/002_discount.sql, src/models.py\nOpen questions:\n- none\n\n## [x] M2: Apply discount in the API\nDepends on: M1\nWhy separate: the API shape must be fixed before the UI\nTier: high\nEstimate: 40m\nRole: backend engineer\nReview: yes\nLikely files: src/orders.py, package.json\nOpen questions:\n- none\n\n## [x] M3: Checkout UI\nDepends on: M2\nWhy separate: built by another coder once the API is fixed\nTier: medium\nEstimate: 30m\nRole: frontend engineer\nReview: yes\nLikely files: web/checkout.tsx\nOpen questions:\n- none\n'
printf "$FULL" > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "a feature plan with no Mode line is a full plan: worktrees, reviewer, every milestone" '[ $code -eq 0 ] && grep -q "^OK: 3 tasks, isolation=worktree" <<<"$out" && grep -q "reviewer=reviewer" <<<"$out" && ! grep -q "mode=quick" <<<"$out"'
check "…none of the quick-run rules touch it (migration, package.json, models.py are fine)" '! grep -qi "quick" <<<"$out"'
check "…state: full mode, review on, role, tier and estimate kept per milestone" 'python3 -c "
import json,sys; st=json.load(open(\".orchestrate/state.json\")); t=st[\"tasks\"]
sys.exit(0 if st[\"mode\"]==\"full\" and st.get(\"quick_because\") is None and all(t[m][\"review\"] for m in (\"M1\",\"M2\",\"M3\"))
 and t[\"M1\"][\"role\"].startswith(\"database\") and t[\"M2\"][\"tier\"]==\"high\" and t[\"M2\"][\"deps\"]==[\"M1\"] and t[\"M3\"][\"estimate_s\"]==1800 else 1)"'
check "…status does not call it a quick run" '! "$ORCH" status | qgrep -q "QUICK RUN"'
printf "$FULL" | sed '/^Why separate:/d; /^Estimate: 30m/d' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1)
check "…a full plan still warns about a missing Why separate and Estimate" '[ "$(grep -c "has no .Why separate:" <<<"$out")" -eq 3 ] && grep -q "M1 has no .Estimate:" <<<"$out"'
printf "$FULL" | sed 's/^Branch: feature\/disc/Mode: full\nBranch: feature\/disc/' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "Mode: full is the same as no Mode line" '[ $code -eq 0 ] && grep -q "^OK: 3 tasks, isolation=worktree" <<<"$out"'
printf "$FULL" | sed 's/^Branch: feature\/disc/Mode: fast\nBranch: feature\/disc/' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "an unknown Mode is refused, never guessed" '[ $code -eq 2 ] && grep -q "Mode must be quick or full" <<<"$out"'
check "the playbook keeps the full feature steps and sends anything not clearly small to them" 'for h in "## 3. Discover the team" "## 4. Milestones: as many as the feature needs" "## 5. Decide dependencies" "## 6. Give every milestone a tier" "## 7. Choose the isolation mode" "## 8. Check and setup commands" "## 9. Write" "## 10. Validate and show the plan"; do grep -qF "$h" "$ROOT/playbooks/plan.md" || exit 1; done; grep -q "If any is false, use the full process" "$ROOT/playbooks/plan.md" && grep -q "Why separate:" "$ROOT/playbooks/plan.md" && grep -q "^Role:" "$ROOT/playbooks/plan.md" && grep -q "as many milestones as the feature needs" "$ROOT/skills/orch-plan/SKILL.md"'
newrepo qk3; echo "$APP" > "$FH/claude-1.dir"
printf "$QK" | sed 's/feature\/qk/feature\/qk3/' > .orchestrate/plan.md
timeout 90 "$ORCH" autopilot > "$WORK/qk3.log" 2>&1
"$ORCH" fix M6 "make g.txt say hi" >/dev/null 2>&1
out=$("$ORCH" sync 2>&1); code=$?
check "a quick run with an orch fix follow-up still syncs (the fix is not a second planned milestone)" '[ $code -eq 0 ] && grep -q "^OK: 2 tasks, mode=quick" <<<"$out"'
printf '\n## [x] M9: Another\nDepends on: none\nLikely files: k.txt\nOpen questions:\n- none\n' >> .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "…but a second planned milestone is still refused" '[ $code -eq 2 ] && grep -q "is one milestone, and this plan has 2" <<<"$out"'

echo "33. a worker with no agent: dispatch --to refuses, status and READY tell the truth"
newrepo na; WT="$APP/../app-wt"
printf '%b' "${PRS/ISO/worktree}" > .orchestrate/plan.md
"$ORCH" sync >/dev/null && "$ORCH" start >/dev/null
touch "$FH/codex-1.shell" "$FH/claude-1.missing"
out=$("$ORCH" dispatch M9 --to codex-1 2>&1); code=$?
check "dispatch --to a worker whose pane only holds a shell is refused, with the fix" '[ $code -ne 0 ] && grep -q "codex-1 has no agent in herdr (SHELL ONLY: only a plain shell is left in its pane). Run \`orch team up\`" <<<"$out"'
out=$("$ORCH" dispatch M5 --to claude-1 2>&1); code=$?
check "dispatch --to a worker herdr can't find is refused" '[ $code -ne 0 ] && grep -q "claude-1 has no agent in herdr (NO AGENT)" <<<"$out"'
check "…and nothing was dispatched" 'python3 -c "import json,sys;t=json.load(open(\".orchestrate/state.json\"))[\"tasks\"];sys.exit(t[\"M9\"].get(\"go\") or t[\"M5\"].get(\"go\"))"'
out=$("$ORCH" status 2>&1)
check "status shows SHELL ONLY and NO AGENT, not free" 'grep -q "worker codex-1 .*herdr=SHELL ONLY .*orch team up" <<<"$out" && grep -q "worker claude-1 .*herdr=NO AGENT" <<<"$out" && ! grep -q "worker codex-1 .*herdr=ok" <<<"$out"'
out=$("$ORCH" ready 2>&1)
check "READY counts no free slot for coders herdr can't see, and names them" 'grep -q "^SLOTS 0" <<<"$out" && grep -q "^NOAGENT claude-1 codex-1" <<<"$out"'
out=$("$ORCH" dispatch M5 2>&1); code=$?
check "a plain dispatch warns when none of its coders is there" '[ $code -eq 0 ] && grep -q "WARN     none of them has an agent in herdr right now" <<<"$out"'
rm -f "$FH/codex-1.shell" "$FH/claude-1.missing"
out=$("$ORCH" status 2>&1)
check "once the agents are back, status says ok and free" 'grep -q "worker codex-1 .*herdr=ok state=free" <<<"$out" && grep -q "worker claude-1 .*herdr=ok state=free" <<<"$out"'
"$ORCH" prepare M9 codex-1 >/dev/null; "$ORCH" write-task M9 >/dev/null; "$ORCH" send M9 task.md >/dev/null; touch "$FH/codex-1.missing"
out=$("$ORCH" status 2>&1)
check "a milestone coding on a worker that vanished says nothing is working on it" 'grep -q "M9 .*coding .*!! but codex-1 has no agent in herdr (NO AGENT): nothing is working on it" <<<"$out"'
rm -f "$FH/codex-1.missing"; "$ORCH" park M9 pending "codex-1 hit a usage/rate limit" >/dev/null
check "the parked note shows while it waits" '"$ORCH" status | qgrep -q "M9 .*pending .*\[codex-1 hit a usage/rate limit\]"'
"$ORCH" prepare M9 claude-1 >/dev/null
check "a stale note is cleared once another coder works on it" '"$ORCH" status | grep "M9 " | qgrep -q coding && ! "$ORCH" status | qgrep -q "M9 .*hit a usage/rate limit"'
"$ORCH" park M9 pending "kept" >/dev/null

echo "34. orch bench <worker> off: a coder stays out until the developer says so"
"$ORCH" dispatch M5 --to claude-1 >/dev/null 2>&1
out=$("$ORCH" bench claude-1 off "developer: no Claude today" 2>&1)
check "bench off says what it does and frees milestones assigned to it" 'grep -q "^OFF     claude-1: gets no new work until \`orch bench claude-1 on\` (developer: no Claude today)" <<<"$out" && grep -q "M5 no longer wait for claude-1" <<<"$out"'
check "status shows the coder as OFF" '"$ORCH" status | qgrep -q "worker claude-1 .*state=OFF (developer: no Claude today)"'
check "pick skips it, even for a milestone that prefers it" '[ "$("$ORCH" pick M5)" = codex-1 ]'
out=$("$ORCH" dispatch M5 --to claude-1 2>&1); code=$?
check "dispatch --to an off coder is refused" '[ $code -ne 0 ] && grep -q "claude-1 is off (developer: no Claude today): \`orch bench claude-1 on\` first" <<<"$out"'
"$ORCH" sync >/dev/null
stpy "st['workers']['claude-1']['cooldown_until'] = 0"
check "off survives orch sync, resume and the end of any bench" '"$ORCH" status | qgrep -q "worker claude-1 .*state=OFF" && [ "$("$ORCH" pick M5)" = codex-1 ]'
"$ORCH" bench codex-1 off >/dev/null
out=$("$ORCH" pick M5 2>&1); code=$?
check "with every coder off, nothing is picked" '[ $code -eq 3 ] && grep -q NONE <<<"$out"'
out=$("$ORCH" bench claude-1 on 2>&1); "$ORCH" bench codex-1 on >/dev/null
check "bench on brings it back" 'grep -q "^ON      claude-1 takes work again" <<<"$out" && "$ORCH" status | qgrep -q "worker claude-1 .*state=free"'
out=$("$ORCH" bench reviewer off 2>&1); code=$?
check "the reviewer is not benched this way" '[ $code -ne 0 ] && grep -q "change \`Reviewer:\` in plan.md" <<<"$out"'

echo "35. orch team up checks the agent is still running a moment later"
newrepo tq
printf '# Plan: t\nBranch: feature/tq\nCheck command: true\nIsolation: worktree\nMax parallel: 2\nWorkers: codex-1 (codex: gpt-6-luna@high), codex-2 (codex: gpt-6.2-sol@low)\nReviewer: none\n\n## [x] M1: a\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
"$ORCH" sync >/dev/null && "$ORCH" start >/dev/null
touch "$FH/codex-2.missing" "$FH/codex-2.quits"; printf 'error: unknown option --approve-for-me\n$ ' > "$FH/codex-2.pane"
out=$(ORCH_TEAM_WAIT_S=2 "$ORCH" team up 2>&1); code=$?
check "an agent that quits right after it starts is reported (exit 3), not called OPENED and done" '[ $code -eq 3 ] && grep -q "^QUIT    codex-2: codex exited right after it started — only a plain shell is left in pane w1:p2, so nothing will be sent there" <<<"$out" && ! grep -q "^TEAM UP: done" <<<"$out"'
check "its last screen is kept in .orchestrate/crash/, with the project and run" 'f=$(ls .orchestrate/crash/codex-2-*.txt) && grep -q "^\[app feature/tq\] codex-2: codex quit" "$f" && grep -q "unknown option" "$f"'
check "the log says it too, with the project and run" 'grep -q "\[app feature/tq\] QUIT codex-2" .orchestrate/autopilot.log'
rm -f "$FH/codex-2.quits" "$FH/codex-2.shell"

echo "36. a coder that vanishes mid-run: the lead hears it at once, with the fix"
newrepo wl; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"; echo "$APP" > "$FH/lead.dir"
printf '# Plan: t\nBranch: feature/wl\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nLead: lead (claude: opus)\nWorkers: claude-1 (claude: sonnet)\nReviewer: none\n\n## [x] M7: H\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
"$ORCH" sync >/dev/null && "$ORCH" dispatch M7 >/dev/null 2>&1
timeout 90 "$ORCH" autopilot > "$WORK/wl.log" 2>&1; code=$?
check "the run still finishes once the coder is back" '[ $code -eq 0 ] && [ "$(status_of M7)" = merged ]'
check "the lead got a WORKER-LOST event with the exact fix" 'grep -q "WORKER-LOST M7 .*claude-1 is gone: herdr can.t find it .*Fix: run \`orch resume\` if herdr restarted" "$FH/lead-events.log" && grep -q "This is NOT routine" "$FH/lead-events.log"'
check "the log line names the project and run" 'grep -q "\[app feature/wl\] LOST claude-1" .orchestrate/autopilot.log'
check "the manager wrote its last line when it finished" 'tail -1 .orchestrate/autopilot.log | qgrep -q "\[app feature/wl\] STOPPED: the event manager finished the run (exit 0)"'

newrepo hr; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"; echo "$APP/../app-wt/codex-1" > "$FH/codex-1.dir"
printf '# Plan: t\nBranch: feature/hr\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude), codex-1 (codex)\nReviewer: none\n\n## [x] M19: S\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
ORCH_VANISH_CHECK_S=0.5 timeout 90 "$ORCH" autopilot > "$WORK/hr.log" 2>&1; code=$?
check "most agents vanishing at once is called out as a likely herdr restart, once" '[ $code -eq 0 ] && [ "$(grep -c "HERDR RESTART? 2 of 2 agents vanished at once (claude-1, codex-1)" "$WORK/hr.log")" -eq 1 ] && grep -q "run \`orch resume\`" "$WORK/hr.log"'

echo "37. crash notes: the manager's last line, why it died, this run's processes only"
newrepo cr; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
printf '%b' "$P1" > .orchestrate/plan.md; printf '## [x] M20: L\nDepends on: none\nOpen questions:\n- none\n' >> .orchestrate/plan.md
"$ORCH" sync >/dev/null
timeout 60 "$ORCH" autopilot > "$WORK/cr.log" 2>&1 & ap=$!
for _ in $(seq 40); do grep -q "M20 -> claude-1" "$WORK/cr.log" 2>/dev/null && break; sleep 0.5; done
out=$("$ORCH" sync 2>&1); code=$?
check "while the manager runs, sync still refuses" '[ $code -ne 0 ] && grep -q "driven by" <<<"$out"'
out=$("$ORCH" stop 2>&1); code=$?; wait $ap
check "orch stop stops the manager cleanly and says how to go on" '[ $code -eq 0 ] && grep -q "^STOPPED the event manager (pid [0-9]*). Nothing is lost.*orch resume" <<<"$out"'
check "its last line says it was orch stop, with the project and run" 'grep -q "\[app feature/x\] STOPPED: orch stop — nothing is lost" .orchestrate/autopilot.log'
check "after orch stop, sync works" '"$ORCH" sync >/dev/null 2>&1'
check "a stop is not mistaken for a crash later" '! "$ORCH" status | qgrep -q CRASHED'
out=$("$ORCH" stop 2>&1)
check "orch stop with nothing running says so" 'grep -q "the event manager is not running" <<<"$out"'
# a manager killed without a word (memory guard): the next look finds it and says why, for this run only
mkfake(){ printf '#!/usr/bin/env bash\n[ "$1" = list ] && exit 0\nfor a in "$@"; do [ "$a" = -k ] && exit 0; done\nprintf "%%s\\n" %s\n' "$1" > "$WORK/journal-$2"; chmod +x "$WORK/journal-$2"; }
mkfake '"2026-11-15T14:36:02 host systemd-oomd[811]: Killed /user.slice/user-1000.slice/app-term-77.scope due to memory pressure"' oomd
stpy "st['run']['manager'] = {'pid': 999999, 'host': __import__('socket').gethostname(), 'started': now - 900, 'procs': {'4242': 'opencode'}, 'cgroups': ['/user.slice/user-1000.slice/app-term-77.scope/vte-spawn-1.scope']}; st['run']['beat'] = now - 600"
out=$(ORCH_JOURNALCTL="$WORK/journal-oomd" ORCH_BOOT_TIME=1 "$ORCH" status 2>&1)
check "status finds the manager that died without a word, and the memory guard as the reason" 'grep -q "^!! \[app feature/x\] CRASHED: the event manager (pid 999999) stopped without a word; last alive .* Reason: the memory guard (systemd-oomd) closed the terminal" <<<"$out" && grep -q "system log: .*systemd-oomd.*Killed /user.slice" <<<"$out"'
check "the note and the system log line are written to autopilot.log" 'grep -q "\[app feature/x\] CRASHED: .*memory guard" .orchestrate/autopilot.log && grep -q "\[app feature/x\]   system log: .*systemd-oomd" .orchestrate/autopilot.log'
out=$(ORCH_JOURNALCTL="$WORK/journal-oomd" ORCH_BOOT_TIME=1 "$ORCH" status 2>&1)
check "it is said once, not on every status" '! grep -q CRASHED <<<"$out"'
mkfake '"2026-11-15T14:36:02 host systemd-oomd[811]: Killed /user.slice/user-1000.slice/app-other-12.scope due to memory pressure"' other
stpy "st['run']['manager'].pop('ended')"
out=$(ORCH_JOURNALCTL="$WORK/journal-other" ORCH_BOOT_TIME=1 "$ORCH" doctor --crash 2>&1)
check "a kill of another project's terminal is not blamed on this run" 'grep -q "Reason: unknown — the system log shows 1 kill(s) then, but not of this run.s processes (another project or app)" <<<"$out"'
mkfake '"2026-11-15T14:36:02 host kernel: Out of memory: Killed process 4242 (opencode) total-vm:9000kB"' koom
stpy "st['run']['manager'].pop('ended')"
out=$(ORCH_JOURNALCTL="$WORK/journal-koom" ORCH_BOOT_TIME=1 "$ORCH" doctor --crash 2>&1)
check "the kernel killing one of this run's processes is named" 'grep -q "Reason: out of memory: the system killed opencode (pid 4242)" <<<"$out"'
check "doctor --crash lists the last crash notes" 'grep -q "^Last notes in .orchestrate/autopilot.log:" <<<"$out" && grep -q "STOPPED: orch stop" <<<"$out"'
stpy "st['run']['manager'].pop('ended')"
out=$(ORCH_BOOT_TIME=$(( $(date +%s) - 60 )) "$ORCH" doctor --crash 2>&1)
check "a reboot after the last heartbeat is named as the reason" 'grep -q "Reason: the computer was restarted (it booted at" <<<"$out"'
stpy "st['run']['manager'].pop('ended')"
out=$(ORCH_BOOT_TIME=1 "$ORCH" doctor --crash 2>&1)
check "when the system log can't be read, it says so" 'grep -q "Reason: unknown — the system log could not be read" <<<"$out"'
ORCH_FAULT=autopilot-error timeout 30 "$ORCH" autopilot > "$WORK/cr2.log" 2>&1; code=$?
check "a Python error in the manager is logged with its traceback, then raised" '[ $code -ne 0 ] && grep -q "\[app feature/x\] CRASHED: ValueError: test crash" .orchestrate/autopilot.log && grep -q "\[app feature/x\]   Traceback" .orchestrate/autopilot.log'
check "…and is not reported as a silent death later" '! "$ORCH" status | qgrep -q "stopped without a word"'

echo "38. logs stay small"
head -c 300000 /dev/zero | tr '\0' 'x' > .orchestrate/autopilot.log
stpy "st['run']['manager'].pop('ended', None); st['run']['manager']['pid'] = 999998"
ORCH_LOG_MAX_MB=0.1 ORCH_BOOT_TIME=1 "$ORCH" status >/dev/null 2>&1
check "past its size autopilot.log becomes autopilot.log.1 and starts again" '[ -f .orchestrate/autopilot.log.1 ] && [ "$(wc -c < .orchestrate/autopilot.log)" -lt 5000 ] && grep -q CRASHED .orchestrate/autopilot.log'
head -c 300000 /dev/zero | tr '\0' 'x' > .orchestrate/autopilot.log; echo old > .orchestrate/autopilot.log.1
stpy "st['run']['manager'].pop('ended', None)"
ORCH_LOG_MAX_MB=0.1 ORCH_BOOT_TIME=1 "$ORCH" status >/dev/null 2>&1
check "only one old copy is kept" '! grep -q "^old$" .orchestrate/autopilot.log.1 && [ ! -f .orchestrate/autopilot.log.2 ]'
echo "screen" > "$FH/claude-1.pane"
for i in 1 2 3; do python3 - "$ORCH" <<'PY'
import runpy, sys, time
from pathlib import Path
g = runpy.run_path(sys.argv[1], run_name="orch_test")
g["ROOT"] = Path("."); g["ORCH"] = Path(".orchestrate"); g["STATE"] = Path(".orchestrate/state.json")
g["save_screen"].__globals__.update(ROOT=Path(".").resolve(), ORCH=Path(".orchestrate"), STATE=Path(".orchestrate/state.json"), CRASH_KEEP=2)
g["save_screen"]("claude-1", "test"); time.sleep(1.1)
PY
done
check "only the newest saved screens are kept" '[ "$(ls .orchestrate/crash/claude-1-*.txt | wc -l)" -eq 2 ]'

echo "39. the event manager starts in its own scope when it can, plainly when it can't"
mkdir -p "$WORK/sdbin"; printf '#!/usr/bin/env bash\necho "$@" >> "%s/systemd-run.log"\nexit 1\n' "$WORK" > "$WORK/sdbin/systemd-run"; chmod +x "$WORK/sdbin/systemd-run"
newrepo scope; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
{ printf '%b' "$P1"; printf '## [x] M6: G\nDepends on: none\nOpen questions:\n- none\n'; } > .orchestrate/plan.md
"$ORCH" sync >/dev/null
out=$(PATH="$WORK/sdbin:$PATH" ORCH_NO_SCOPE=0 ORCH_NO_AUTOSTART=0 "$ORCH" dispatch M6 2>&1)
check "it tries systemd-run --user --scope first, then starts it the plain way" 'grep -q "^--user --scope --quiet --collect --unit=orch-app-[0-9]* .*orch autopilot" "$WORK/systemd-run.log" && grep -q "started the event manager" <<<"$out"'
for _ in $(seq 60); do grep -q "ALL_DONE" .orchestrate/autopilot.log 2>/dev/null && break; sleep 1; done
check "…and that run finishes" '[ "$(status_of M6)" = merged ]'
check "the playbook, README and usage explain bench, stop, crash notes and logs" 'grep -q "orch bench" "$ROOT/playbooks/run.md" && grep -q "orch stop" "$ROOT/playbooks/run.md" && grep -q "WORKER-LOST" "$ROOT/playbooks/run.md" && grep -q "orch doctor --crash" "$ROOT/README.md" && "$ORCH" 2>&1 | qgrep -q "bench <worker> off"'

echo "40. installer asks about auto-update once (default on) and keeps the answer"
UH="$WORK/uhome"; USHARE="$UH/.local/share/herdr-orchestra"; UO="$UH/.local/bin/orch"; mkdir -p "$UH"
UPATH="/usr/local/bin:/usr/bin:/bin"
uinstall() { HOME="$UH" PATH="$UPATH" ORCH_PACKAGE=1 ORCH_SHARE="$USHARE" bash "$ROOT/install.sh" --no-herdr-skill "$@"; }
uset() { python3 -c "import json;print(json.load(open('$USHARE/settings.json')).get('$1'))" 2>/dev/null; }
V=$(cat "$ROOT/VERSION")
echo "" > "$WORK/tty-enter"; echo "n" > "$WORK/tty-no"
out=$(ORCH_TTY="$WORK/tty-enter" uinstall 2>&1); code=$?
check "first install asks, and Enter turns auto-update on" '[ $code -eq 0 ] && grep -q "Keep herdr-orchestra up to date automatically? \[Y/n\]" <<<"$out" && [ "$(uset auto_update)" = True ] && grep -q "auto-update: on" <<<"$out"'
check "the install ships the browser view and the herdr plugin (orch view finds its page)" '[ -f "$USHARE/current/view/index.html" ] && [ -f "$USHARE/current/view/herdr-plugin/herdr-plugin.toml" ] && [ -x "$USHARE/current/view/herdr-plugin/board.sh" ]'
out=$(ORCH_TTY="$WORK/tty-no" uinstall 2>&1)
check "a reinstall does not ask again and keeps the answer" '! grep -q "Keep herdr-orchestra up to date" <<<"$out" && [ "$(uset auto_update)" = True ]'
rm -f "$USHARE/settings.json"
out=$(ORCH_TTY="$WORK/tty-no" uinstall 2>&1)
check "an install with no saved answer (an older install) is asked, and n turns it off" 'grep -q "Keep herdr-orchestra up to date" <<<"$out" && [ "$(uset auto_update)" = False ] && grep -q "auto-update: off" <<<"$out"'
out=$(ORCH_TTY="$WORK/tty-no" uinstall --auto-update 2>&1)
check "--auto-update sets it without asking" '! grep -q "Keep herdr-orchestra up to date" <<<"$out" && [ "$(uset auto_update)" = True ]'
out=$(ORCH_TTY="$WORK/tty-enter" ORCH_AUTO_UPDATE=0 uinstall 2>&1)
check "ORCH_AUTO_UPDATE=0 sets it off without asking" '! grep -q "Keep herdr-orchestra up to date" <<<"$out" && [ "$(uset auto_update)" = False ]'
rm -f "$USHARE/settings.json"
if command -v setsid >/dev/null; then
  out=$(HOME="$UH" PATH="$UPATH" ORCH_PACKAGE=1 ORCH_TTY="" setsid -w bash "$ROOT/install.sh" --no-herdr-skill </dev/null 2>&1)
  check "with no keyboard it does not ask and turns auto-update on" '! grep -q "Keep herdr-orchestra up to date" <<<"$out" && [ "$(uset auto_update)" = True ] && grep -q "auto-update: on (turn it off with: orch config auto-update off)" <<<"$out"'
else
  uinstall --auto-update >/dev/null 2>&1
fi
check "the install ships the changelog and is a release install" '[ -f "$USHARE/current/CHANGELOG.md" ] && [ "$(readlink "$USHARE/current")" = "$USHARE/v$V" ]'

echo "41. orch config, orch update, and the new-version notice"
uo() { HOME="$UH" PATH="$UPATH" ORCH_SHARE="$USHARE" ORCH_NO_UPDATE_CHECK=0 ORCH_UPDATE_SOURCE="$WORK/usrc" "$UO" "$@"; }
mkrel() {  # mkrel <X.Y.Z>: a fake release of this checkout with that version number
  mkdir -p "$WORK/usrc/v$1"
  (cd "$ROOT" && cp -r bin skills opencode-commands claude-commands playbooks agents.default.toml models.default.toml CHANGELOG.md install.sh "$WORK/usrc/v$1/")
  echo "$1" > "$WORK/usrc/v$1/VERSION"
  printf '# Changelog\n\n## [%s] - 2026-01-01\n\n### Added\n- **A thing new in %s.** Details.\n\n### Tests\n- a test line\n\n## [0.0.1] - 2025-01-01\n- **old**\n' "$1" "$1" > "$WORK/usrc/v$1/CHANGELOG.md"
}
IFS=. read -r VMAJ VMIN VPAT <<<"$V"; N1="$VMAJ.$VMIN.$((VPAT+1))"; N2="$VMAJ.$VMIN.$((VPAT+2))"; N3="$VMAJ.$VMIN.$((VPAT+3))"; NMAJ="$((VMAJ+1)).0.0"
mkdir -p "$WORK/usrc"; mkrel "$N1"; mkrel "$V"; echo "v$V" > "$WORK/usrc/latest"
out=$(uo config auto-update off 2>&1)
check "orch config auto-update off saves it" 'grep -q "^auto-update: off" <<<"$out" && [ "$(uset auto_update)" = False ]'
out=$(uo config 2>&1)
check "orch config shows the setting, the version and the settings file" 'grep -q "^auto-update: off" <<<"$out" && grep -q "^installed: $V$" <<<"$out" && grep -q "settings.json" <<<"$out"'
check "ORCH_AUTO_UPDATE overrides the saved setting for that shell" 'ORCH_AUTO_UPDATE=1 uo config | qgrep -q "^auto-update: on (ORCH_AUTO_UPDATE=1 overrides"'
check "an unknown config is refused" '! uo config auto-update maybe >/dev/null 2>&1'
out=$(uo update --check 2>&1)
check "orch update --check: already the latest" 'grep -q "herdr-orchestra $V is the latest version" <<<"$out"'
out=$(uo version 2>&1)
check "no notice when nothing newer is out" '[ "$out" = "herdr-orchestra $V" ]'
echo "v$N1" > "$WORK/usrc/latest"
out=$(uo version 2>&1)
check "the latest release is asked for at most once a day" '[ "$out" = "herdr-orchestra $V" ]'
python3 - "$USHARE/settings.json" <<'PY'
import json, sys
p = sys.argv[1]; s = json.load(open(p)); s["last_check"] = 0; json.dump(s, open(p, "w"))
PY
out=$(uo version 2>&1)
check "a day later the notice names the new version and the command" 'grep -qx "herdr-orchestra $N1 is out (you have $V). Run \`orch update\`." <<<"$out"'
mkdir -p "$WORK/urepo" && (cd "$WORK/urepo" && git init -q -b main && git config user.email t@t && git config user.name t && echo x > f && git add . && git commit -qm init && mkdir .orchestrate && printf '%b' "$P1" > .orchestrate/plan.md && printf '## [x] M6: G\nDepends on: none\nOpen questions:\n- none\n' >> .orchestrate/plan.md)
out=$(cd "$WORK/urepo" && uo sync >/dev/null 2>&1; uo status 2>&1)
check "orch status shows the notice from the last check" 'grep -q "herdr-orchestra $N1 is out" <<<"$out"'
out=$(cd "$WORK/urepo" && HOME="$UH" PATH="$UPATH" ORCH_SHARE="$USHARE" ORCH_NO_UPDATE_CHECK=1 "$UO" version 2>&1; HOME="$UH" PATH="$UPATH" ORCH_SHARE="$USHARE" ORCH_NO_UPDATE_CHECK=1 "$UO" status 2>&1)
check "ORCH_NO_UPDATE_CHECK=1: no notice anywhere" '! grep -q "is out" <<<"$out"'
out=$(cd "$WORK" && uo lead plan 2>&1)
check "auto-update off: a new plan only shows the notice, nothing is installed" 'grep -q "herdr-orchestra $N1 is out (you have $V). Run \`orch update\`." <<<"$out" && grep -q "lead playbook: plan" <<<"$out" && [ "$(cat "$USHARE/current/VERSION")" = "$V" ]'
out=$("$ORCH" version 2>&1; cd "$WORK" && HOME="$UH" ORCH_SHARE="$USHARE" ORCH_NO_UPDATE_CHECK=0 ORCH_AUTO_UPDATE=1 ORCH_UPDATE_SOURCE="$WORK/usrc" "$ORCH" lead plan 2>&1 | head -3)
check "a git checkout never checks or updates itself" '! grep -q "is out\|UPDATED" <<<"$out" && [ "$(cat "$USHARE/current/VERSION")" = "$V" ]'
out=$(uo update --check 2>&1)
check "orch update --check says a new version is out and installs nothing" 'grep -q "herdr-orchestra $N1 is out" <<<"$out" && [ "$(cat "$USHARE/current/VERSION")" = "$V" ]'
out=$(uo update 2>&1); code=$?
check "orch update installs the new version and shows what is new" '[ $code -eq 0 ] && grep -q "^UPDATED herdr-orchestra $V -> $N1" <<<"$out" && grep -q "  - A thing new in $N1" <<<"$out" && ! grep -q "a test line" <<<"$out" && [ "$(uo version)" = "herdr-orchestra $N1" ]'
check "…keeps the auto-update answer, and says how to go back" '[ "$(uset auto_update)" = False ] && grep -q "orch update --version v$V" <<<"$out"'
out=$(uo update 2>&1)
check "orch update with nothing newer does nothing" 'grep -q "is the latest version. Nothing to do" <<<"$out"'
out=$(uo update --version "v$V" 2>&1); code=$?
check "orch update --version goes back to an older version" '[ $code -eq 0 ] && [ "$(HOME="$UH" PATH="$UPATH" ORCH_SHARE="$USHARE" "$UO" version)" = "herdr-orchestra $V" ]'
out=$(uo update --version v0.0.9 2>&1); code=$?
check "an unknown version fails and the old one stays active" '[ $code -ne 0 ] && grep -q "update failed, herdr-orchestra $V is still active" <<<"$out" && [ "$(cat "$USHARE/current/VERSION")" = "$V" ]'
out=$(HOME="$UH" PATH="$UPATH" ORCH_SHARE="$USHARE" ORCH_NO_UPDATE_CHECK=0 ORCH_UPDATE_SOURCE="$WORK/nowhere" "$UO" update 2>&1); code=$?
check "orch update with no network says so" '[ $code -ne 0 ] && grep -q "could not reach GitHub" <<<"$out"'
python3 - "$USHARE/settings.json" <<'PY'
import json, sys
p = sys.argv[1]; s = json.load(open(p)); s["last_check"] = 0; s.pop("latest_seen", None); json.dump(s, open(p, "w"))
PY
out=$(HOME="$UH" PATH="$UPATH" ORCH_SHARE="$USHARE" ORCH_NO_UPDATE_CHECK=0 ORCH_UPDATE_SOURCE="$WORK/nowhere" "$UO" version 2>&1)
check "the daily check with no network is silent, and waits a day before the next try" '[ "$out" = "herdr-orchestra $V" ] && [ "$(uset last_check)" != 0 ]'

echo "42. auto-update at the start of a new plan, never during a run"
uo config auto-update on >/dev/null
reset_check() { python3 - "$USHARE/settings.json" <<'PY'
import json, sys
p = sys.argv[1]; s = json.load(open(p)); s["last_check"] = 0; s.pop("last_auto_fail", None); json.dump(s, open(p, "w"))
PY
}
# a run going in another repo: its event manager holds the lease and has signed in
mkdir -p "$WORK/busy/.orchestrate" "$USHARE/active"
python3 - "$WORK/busy/.orchestrate/driver.lock" <<'PY' &
import fcntl, sys, time
f = open(sys.argv[1], "a+"); fcntl.flock(f, fcntl.LOCK_EX); time.sleep(600)
PY
holder=$!
printf '{"pid": %s, "root": "%s"}' "$holder" "$WORK/busy" > "$USHARE/active/$holder.json"
sleep 1; reset_check
out=$(cd "$WORK" && uo lead plan 2>&1)
check "a run going anywhere on the machine: not installed, and the plan still starts" 'grep -q "Not installed now: a run is going ($WORK/busy)" <<<"$out" && grep -q "lead playbook: plan" <<<"$out" && [ "$(cat "$USHARE/current/VERSION")" = "$V" ]'
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
mkdir -p "$WORK/pinned" && echo "v$V" > "$WORK/pinned/.orch-version"
out=$(cd "$WORK/pinned" && uo lead plan 2>&1)
check "a repo pinned with .orch-version is left alone" 'grep -q "this repo pins its version in .orch-version" <<<"$out" && [ "$(cat "$USHARE/current/VERSION")" = "$V" ]'
echo "v$NMAJ" > "$WORK/usrc/latest"; reset_check
out=$(cd "$WORK" && uo lead plan 2>&1)
check "a major version is not installed by itself" 'grep -q "herdr-orchestra $NMAJ is out (you have $V). It is a major version" <<<"$out" && grep -q "lead playbook: plan" <<<"$out" && [ "$(cat "$USHARE/current/VERSION")" = "$V" ]'
mkdir -p "$WORK/usrc/v$N3"; printf '#!/usr/bin/env bash\necho "download cut" >&2; exit 1\n' > "$WORK/usrc/v$N3/install.sh"
echo "v$N3" > "$WORK/usrc/latest"; reset_check
out=$(cd "$WORK" && uo lead plan 2>&1)
check "a failed update keeps the old version, warns once, and the plan still starts" 'grep -q "WARN auto-update to $N3 failed, $V is still active" <<<"$out" && grep -q "download cut" <<<"$out" && grep -q "lead playbook: plan" <<<"$out" && [ "$(uo version | head -1)" = "herdr-orchestra $V" ] && grep -q "FAILED" "$USHARE/update.log"'
out=$(cd "$WORK" && uo lead plan 2>&1)
check "…and it is not tried again on every plan that day" 'grep -q "Auto-update failed earlier today" <<<"$out" && ! grep -q "^WARN" <<<"$out"'
# a run started on the old version...
(cd "$WORK/urepo" && HOME="$UH" ORCH_SHARE="$USHARE" "$UO" sync >/dev/null 2>&1 && HOME="$UH" ORCH_SHARE="$USHARE" "$UO" start > "$WORK/urepo-start.log" 2>&1)
mkrel "$N2"; echo "v$N2" > "$WORK/usrc/latest"; reset_check
out=$(cd "$WORK" && uo lead plan 2>&1)
check "auto-update installs the new version when a plan starts" 'grep -q "^UPDATED herdr-orchestra $V -> $N2 (auto-update" <<<"$out" && grep -q "  - A thing new in $N2" <<<"$out" && [ "$(cat "$USHARE/current/VERSION")" = "$N2" ]'
check "…and that plan already runs on the new version" 'grep -q "herdr-orchestra $N2 — lead playbook: plan" <<<"$out" && [ "$(grep -c "lead playbook: plan" <<<"$out")" -eq 1 ]'
out=$(cd "$WORK" && uo lead plan 2>&1)
check "the next plan has nothing to install" '! grep -q "^UPDATED\|^WARN\|^herdr-orchestra .* is out" <<<"$out" && grep -q "herdr-orchestra $N2 — lead playbook: plan" <<<"$out"'
# ...finishes on the new one
export FH="$WORK/ufh"; mkdir -p "$FH"; echo "$WORK/urepo-wt/claude-1" > "$FH/claude-1.dir"
(cd "$WORK/urepo" && HOME="$UH" ORCH_SHARE="$USHARE" ORCH_BIN="$UO" timeout 120 "$UO" autopilot > "$WORK/urepo.log" 2>&1); code=$?
check "a run started on the old version finishes on the new one" '[ $code -eq 0 ] && grep -q "ALL_DONE" "$WORK/urepo.log" && (cd "$WORK/urepo" && HOME="$UH" ORCH_SHARE="$USHARE" "$UO" status | qgrep -q "M6 .*merged")'
check "the event manager signs out of the active list when it stops" '[ -z "$(ls "$USHARE/active" 2>/dev/null)" ]'
HOME="$UH" PATH="$UPATH" bash "$ROOT/install.sh" --uninstall >/dev/null 2>&1
check "uninstall removes the settings too" '[ ! -e "$USHARE" ]'
check "README, usage and the plan playbook explain updating" 'grep -q "orch update" "$ROOT/README.md" && grep -q "orch config auto-update off" "$ROOT/README.md" && "$ORCH" 2>&1 | qgrep -q "update \[--check\]" && grep -q "orch update" "$ROOT/playbooks/plan.md"'

echo "43. a criterion the developer approved deferring costs no fix rounds and no escalation"
newrepo df; echo "$APP" > "$FH/lead.dir"
echo "Build the rest; defer the watch sync until the API exists" > "$FH/lead-answer"; echo AC2 > "$FH/lead-defer"
DPLAN='# Plan: t\nBranch: feature/df\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nLead: lead (claude: opus)\nWorkers: claude-1 (claude: sonnet), codex-1 (codex: gpt-6-luna@high)\nReviewer: reviewer (agy)\n\n## [x] M21: Watch\nDepends on: none\nTier: small\nModel why: small.\nReview: yes\nAcceptance criteria:\n- the watch shows the steps\n- the watch syncs with the phone API\nOpen questions:\n- none\n'
printf "$DPLAN" > .orchestrate/plan.md
"$ORCH" sync >/dev/null && "$ORCH" dispatch M21 >/dev/null
timeout 180 "$ORCH" autopilot > "$WORK/df.log" 2>&1; code=$?
check "the coder asked, the lead answered with --defer, and M21 landed (exit 0)" '[ $code -eq 0 ] && [ "$(status_of M21)" = merged ] && grep -q "^DEFERRED M21 AC2" "$FH/lead-events.log"'
check "the deferred AC2 reported met:false started no fix round" '! ls "$APP"/../app-wt/*/.orch-task/M21/criteria-fix-* >/dev/null 2>&1 && ! grep -q "M21: the coder reports .* not met -> fix round" "$WORK/df.log" && grep -q "M21: AC2 not met, deferred with the developer.s approval -> no fix round" "$WORK/df.log" && [ "$(python3 -c "import json;print(json.load(open(\".orchestrate/state.json\"))[\"tasks\"][\"M21\"][\"fix\"])")" = 0 ]'
check "…and no escalation to a stronger model" '! grep -q "M21: .*gets one fresh round" "$WORK/df.log" && python3 -c "import json,sys;sys.exit(bool(json.load(open(\".orchestrate/state.json\"))[\"tasks\"][\"M21\"].get(\"escalated\")))"'
check "the reviewer was told about the deferral, and its AC2 met:false was not a blocker" 'grep -q "DEFERRED by the developer .*AC2 \"the watch syncs with the phone API\"" .orchestrate/review/M21/review-task-1.md && [ "$(python3 -c "import json;print(json.load(open(\".orchestrate/state.json\"))[\"tasks\"][\"M21\"][\"review_round\"])")" = 1 ]'
check "task.json and plan.md keep the approval and the reason" 'python3 -c "
import json; c=json.load(open(\"$APP/../app-wt/codex-1/.orch-task/M21/task.json\"))[\"acceptance_criteria\"]
assert \"deferred\" not in c[0] and c[1][\"deferred\"][\"approved_by\"] == \"developer\" and \"API exists\" in c[1][\"deferred\"][\"reason\"], c" && grep -q "^- Deferred with the developer.s approval (NOT built in this milestone, a follow-up): AC2" .orchestrate/plan.md'
check "the summary says AC2 was NOT done and names a follow-up" 'grep -q "^## Deferred: not done, follow-ups" .orchestrate/summary.md && grep -q "^- M21 AC2 \"the watch syncs with the phone API\": NOT done. Approved by the developer: Build the rest; defer the watch sync until the API exists. Follow-up:" .orchestrate/summary.md && grep -q "AC2 the watch syncs with the phone API — DEFERRED, NOT done" .orchestrate/summary.md'
check "the log says how long the lead took to read its events, and dispatch to start" 'grep -q "picked up its events (read [0-9]*s after the first wake-up, [0-9]*s after the oldest event" "$WORK/df.log" && grep -q "M21 -> codex-1 ([0-9]*s after the lead.s dispatch or answer)" "$WORK/df.log" && grep -q "woke the lead (lead): .*oldest event [0-9]*s old" "$WORK/df.log"'
# without a deferral, an honest met:false still gets its fix rounds (nothing else changed)
newrepo dg; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
{ printf '%b' "$P1"; printf '## [x] M22: V\nDepends on: none\nAcceptance criteria:\n- v syncs\nOpen questions:\n- none\n'; } > .orchestrate/plan.md
timeout 120 "$ORCH" autopilot > "$WORK/dg.log" 2>&1
check "with no deferral, met:false still goes to fix rounds and then fails" 'grep -q "M22: the coder reports AC1 not met -> fix round" "$WORK/dg.log" && [ "$(status_of M22)" = failed ]'
check "the criteria-fix job says to ask instead of retrying what can't be met" 'grep -q "set status .question., say which criterion and why" "$APP/../app-wt/claude-1/.orch-task/M22/criteria-fix-1.md"'
out=$("$ORCH" defer M22 AC9 "x" 2>&1); code=$?
check "defer refuses a criterion the milestone does not have" '[ $code -eq 2 ] && grep -q "has no acceptance criterion .AC9." <<<"$out"'
out=$("$ORCH" defer M22 ac1 "the sync API ships next quarter" 2>&1); code=$?
check "defer on a failed milestone records it and says to dispatch" '[ $code -eq 0 ] && grep -q "^DEFERRED M22 AC1" <<<"$out" && grep -q "orch dispatch M22" <<<"$out" && python3 -c "import json,sys;d=json.load(open(\".orchestrate/state.json\"))[\"tasks\"][\"M22\"][\"deferred\"];sys.exit(d[\"AC1\"][\"reason\"]!=\"the sync API ships next quarter\")"'
check "the deferral survives orch sync" '"$ORCH" sync >/dev/null 2>&1; python3 -c "import json,sys;sys.exit(\"AC1\" not in json.load(open(\".orchestrate/state.json\"))[\"tasks\"][\"M22\"].get(\"deferred\",{}))"'
"$ORCH" set M22 pending >/dev/null 2>&1
timeout 120 "$ORCH" autopilot > "$WORK/dg2.log" 2>&1; code=$?
check "sent on again, the same honest result lands with no more fix rounds" '[ $code -eq 0 ] && [ "$(status_of M22)" = merged ] && grep -q "M22: AC1 not met, deferred" "$WORK/dg2.log" && ! grep -q "M22: the coder reports" "$WORK/dg2.log"'
out=$("$ORCH" defer M22 AC1 "x" 2>&1); code=$?
check "defer refuses a milestone that already landed" '[ $code -eq 2 ] && grep -q "is merged" <<<"$out"'
check "usage and the run playbook explain defer" '"$ORCH" 2>&1 | qgrep -q "defer <Mn> <AC2,AC3> <reason>" && grep -q "orch defer" "$ROOT/playbooks/run.md" && grep -q -- "--defer" "$ROOT/playbooks/run.md"'

echo "44. the lead is named automatically, or the run refuses to start without it (bug: lead never named, never woken)"
LNPLAN='# Plan: t\nBranch: feature/ln\nCheck command: true\nIsolation: worktree\nLead: lead (claude: sonnet)\nWorkers: claude-1 (claude: sonnet)\nReviewer: none\n\n## [x] M1: e\nDepends on: none\nOpen questions:\n- none\n'
newrepo ln; printf "$LNPLAN" > .orchestrate/plan.md; touch "$FH/lead.missing"
"$ORCH" sync >/dev/null
out=$(env -u HERDR_PANE_ID "$ORCH" dispatch M1 2>&1); code=$?
check "dispatch refuses when herdr has no agent named lead, with the exact rename command" '[ $code -eq 2 ] && grep -q "NO LEAD: the lead .lead. can.t be woken (herdr has no agent with this name)" <<<"$out" && grep -q "herdr agent rename w1:p1 lead .*FOCUSED pane" <<<"$out" && grep -q "Lead mode: off" <<<"$out"'
check "…and changed nothing: M1 is not dispatched" 'python3 -c "import json,sys;sys.exit(bool(json.load(open(\".orchestrate/state.json\"))[\"tasks\"][\"M1\"].get(\"go\")))"'
out=$(env -u HERDR_PANE_ID "$ORCH" start 2>&1); code=$?
check "orch start refuses too, before it makes the branch" '[ $code -eq 2 ] && grep -q "orch start was refused" <<<"$out" && ! git rev-parse -q --verify feature/ln >/dev/null'
check "orch status shows LEAD NOT FOUND with the fix" '"$ORCH" status | qgrep -q "^!! LEAD NOT FOUND: .*herdr agent rename <its pane id> lead" && "$ORCH" status | qgrep -q "lead lead: .*!! LEAD NOT FOUND"'
echo "$APP" > "$FH/pane-w1:p9.cwd"; echo claude > "$FH/pane-w1:p9.cmd"        # the lead's own pane, an agent runs in it
out=$(HERDR_PANE_ID=w1:p9 "$ORCH" start 2>&1); code=$?
check "run from the lead's own pane, orch start names it lead and goes on" '[ $code -eq 0 ] && grep -q "^NAMED   this pane (w1:p9) is now .lead." <<<"$out" && grep -q "^rename w1:p9 lead" "$FH/team.log" && grep -q "^LEAD lead kind=claude herdr=found" <<<"$out" && git rev-parse -q --verify feature/ln >/dev/null'
check "status no longer warns" '! "$ORCH" status | qgrep -q "LEAD NOT FOUND"'
out=$(HERDR_PANE_ID=w1:p9 "$ORCH" dispatch M1 2>&1); code=$?
check "once named, dispatch goes ahead without renaming again" '[ $code -eq 0 ] && grep -q "^DISPATCH M1" <<<"$out" && [ "$(grep -c "^rename w1:p9 lead" "$FH/team.log")" -eq 1 ]'
rm -f "$FH/lead.paneid"; touch "$FH/lead.missing"; echo "$APP" > "$FH/pane-w1:p8.cwd"   # a plain shell pane: no agent
out=$(HERDR_PANE_ID=w1:p8 "$ORCH" dispatch M1 2>&1); code=$?
check "a pane with no agent in it is not named lead: refused, with herdr's reason" '[ $code -eq 2 ] && grep -q "herdr agent rename w1:p8 lead. failed: no agent detected" <<<"$out" && grep -q "name your own pane, then run it again:  herdr agent rename w1:p8 lead$" <<<"$out"'
echo w1:p5 > "$FH/claude-1.paneid"; echo claude > "$FH/pane-w1:p5.cmd"; echo "$APP" > "$FH/pane-w1:p5.cwd"
out=$(HERDR_PANE_ID=w1:p5 "$ORCH" dispatch M1 2>&1); code=$?
check "a coder's pane is never renamed to lead" '[ $code -eq 2 ] && grep -q "this pane (w1:p5) is claude-1, not the lead" <<<"$out" && ! grep -q "^rename w1:p5" "$FH/team.log"'
rm -f "$FH/claude-1.paneid"
# orch lead plan / run name the pane they run in, from the plan's Lead line; a wake-up's --section does not
newrepo lp; printf "${LNPLAN/Lead: lead/Lead: boss}" > .orchestrate/plan.md; touch "$FH/boss.missing"
echo "$APP" > "$FH/pane-w1:p9.cwd"; echo claude > "$FH/pane-w1:p9.cmd"
out=$(HERDR_PANE_ID=w1:p9 "$ORCH" lead plan 2>&1)
check "orch lead plan names its own pane with the plan's lead name" 'grep -q "^NAMED   this pane (w1:p9) is now .boss." <<<"$out" && grep -q "^rename w1:p9 boss" "$FH/team.log" && grep -q "You are the LEAD" <<<"$out"'
out=$(HERDR_PANE_ID=w1:p9 "$ORCH" lead run 2>&1)
check "orch lead run sees it is named already" 'grep -q "^LEAD    this pane (w1:p9) is .boss." <<<"$out" && [ "$(grep -c "^rename" "$FH/team.log")" -eq 1 ]'
HERDR_PANE_ID=w1:p9 "$ORCH" lead run --section FAILED >/dev/null 2>&1; HERDR_PANE_ID=w1:p9 "$ORCH" lead plan quick >/dev/null 2>&1
check "a wake-up's playbook section and the plan parts ask herdr nothing" '[ "$(grep -c "^rename" "$FH/team.log")" -eq 1 ]'
echo w1:p4 > "$FH/boss.paneid"
out=$(HERDR_PANE_ID=w1:p9 "$ORCH" lead plan 2>&1)
check "the name is never taken from another pane that runs an agent" 'grep -q "pane w1:p4 already has the name .boss. and runs an agent" <<<"$out" && [ "$(grep -c "^rename" "$FH/team.log")" -eq 1 ]'
rm -f "$FH/lead.missing"
out=$(HERDR_PANE_ID=w1:p9 "$ORCH" lead whoami 2>&1)
check "orch lead whoami keeps the plan's lead name (boss), never renames the pane to lead" 'grep -q "pane w1:p4 already has the name .boss." <<<"$out" && grep -q "Name it:  herdr agent rename .* boss$" <<<"$out" && ! grep -q "rename w1:p9 lead$" "$FH/team.log"'
# a run that starts without its lead (the developer ran `orch autopilot` by hand) says so at once and at the end
newrepo lnv; echo "$APP" > "$FH/lead.dir"; touch "$FH/lead.missing"; printf "$LNPLAN" > .orchestrate/plan.md
ORCH_LEAD_WAIT_MIN=0 timeout 120 "$ORCH" autopilot > "$WORK/lnv.log" 2>&1; code=$?
check "the event manager warns at its start that the lead can't be woken" '[ $code -eq 0 ] && grep -q "!! LEAD NOT FOUND: the lead (lead) can.t be woken (herdr has no agent with this name)" "$WORK/lnv.log"'
check "ALL_DONE says loudly the lead was never woken" 'grep -q "ALL_DONE, but the lead (lead) was NEVER WOKEN" "$WORK/lnv.log"'
check "the last line no longer reads like a normal finish: the lead was never woken" 'tail -1 .orchestrate/autopilot.log | qgrep -q "STOPPED: the event manager finished the run (exit 0) — but the lead .lead. was never woken (herdr has no agent with this name): [0-9] event(s) wait for it (.*ALL_DONE"'
rm -f "$FH/lead.missing"

echo "45. faster handoffs: checks in the background, no double check, early review, auto dispatch, wait times"
BGPLAN='# Plan: t\nBranch: feature/bg\nCheck command: sleep 3\nIsolation: worktree\nMax parallel: 2\nWorkers: claude-1 (claude), codex-1 (codex)\nReviewer: reviewer (agy)\n\n## [x] M5: e\nDepends on: none\nReview: yes\nOpen questions:\n- none\n\n## [x] M6: g\nDepends on: none\nReview: yes\nOpen questions:\n- none\n'
newrepo bgc; printf "$BGPLAN" > .orchestrate/plan.md
( for _ in $(seq 1 40); do "$ORCH" status 2>/dev/null | grep "check running" >> "$WORK/bgc-status.txt"; sleep 0.5; done ) &
spy=$!
timeout 180 "$ORCH" autopilot > "$WORK/bgc.log" 2>&1; code=$?; kill $spy 2>/dev/null; wait $spy 2>/dev/null
L=.orchestrate/autopilot.log
task_is(){ python3 -c "import json,sys; t=json.load(open('.orchestrate/state.json'))['tasks']['$1']; sys.exit(0 if ($2) else 1)"; }
line(){ grep -n "$1" $L | head -1 | cut -d: -f1; }
check "both land; the run ends normally" '[ $code -eq 0 ] && [ "$(status_of M5)$(status_of M6)" = mergedmerged ]'
check "the manager keeps going while a check runs: both reviews come back before M5's 3-second check ends" '[ "$(line "M6 reviewed")" -lt "$(line "M5 check passed")" ]'
check "early review: the review is sent alongside the check" 'grep -q "SENT review M5 -> reviewer (round 1) (alongside its check: .Early review: on.)" $L'
check "one check at a time by default: M6 waits for the check of M5, and the log says so" 'grep -q "M6 waited 0m0[0-9]s for M5.s check" $L'
check "orch status shows a running check" 'grep -q "M5 .*\[check running [0-9]m[0-9]*s in its folder\]" "$WORK/bgc-status.txt"'
check "the first milestone to land is not checked twice (nothing else landed)" 'grep -q "^.*SKIPPED_CHECK M5: the branch gets exactly the files whose check passed" $L && ! task_is M5 "any(c[\"where\"] == \"branch\" for c in t[\"checks\"])"'
check "the second one is checked again on the branch, because M5 landed in between" '! grep -q "SKIPPED_CHECK M6" $L && task_is M6 "any(c[\"where\"] == \"branch\" and c[\"ok\"] for c in t[\"checks\"])"'
check "the summary has a Waiting table with the wait of M6" 'grep -q "^## Waiting: time milestones sat still" .orchestrate/summary.md && grep -q "^| M6 | a free check slot 0m0[0-9]s |" .orchestrate/summary.md'
newrepo pch; printf "${BGPLAN/Max parallel: 2/Max parallel: 2\\nParallel checks: 2}" > .orchestrate/plan.md
timeout 180 "$ORCH" autopilot > "$WORK/pch.log" 2>&1; code=$?
check "Parallel checks: 2 runs both checks at once: nobody waits for a check" '[ $code -eq 0 ] && [ "$(status_of M6)" = merged ] && ! grep -q "waited .* check" .orchestrate/autopilot.log'
newrepo ero; printf "${BGPLAN/Max parallel: 2/Max parallel: 2\\nEarly review: off}" > .orchestrate/plan.md
timeout 180 "$ORCH" autopilot > "$WORK/ero.log" 2>&1; code=$?; L=.orchestrate/autopilot.log
check "Early review: off sends the review only after the check passed" '[ $code -eq 0 ] && [ "$(status_of M5)" = merged ] && [ "$(line "M5 check passed")" -lt "$(line "SENT review M5")" ] && ! grep -q "alongside its check" $L'
newrepo erf
printf '# Plan: t\nBranch: feature/erf\nCheck command: sleep 1; ! grep -qx b b.txt\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: reviewer (agy)\n\n## [x] M2: Endpoint\nDepends on: none\nReview: yes\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 180 "$ORCH" autopilot > "$WORK/erf.log" 2>&1; code=$?; L=.orchestrate/autopilot.log; F="$APP/../app-wt/claude-1/.orch-task/M2"
check "a failed check and a review blocker on the same version make ONE fix round" '[ $code -eq 0 ] && [ "$(status_of M2)" = merged ] && grep -q "M2 checks failed -> fix round 1 (with the reviewer.s 1 blocker(s))" $L && [ ! -e "$F/review-fix-1.md" ] && [ ! -e "$F/fix-2.md" ]'
check "that fix job names both the check and the blocker" 'grep -q "^# Checks failing for M2" "$F/fix-1.md" && grep -q "BLOCKER: b.txt:1 — b.txt must say validated" "$F/fix-1.md"'
check "the review of the failing version does not count against the review cap" 'task_is M2 "t.get(\"review_base\", 0) == 1"'
newrepo adp; echo "$APP" > "$FH/lead.dir"
printf '# Plan: t\nBranch: feature/ad\nCheck command: true\nIsolation: worktree\nMax parallel: 2\nLead: lead (claude: opus)\nWorkers: claude-1 (claude: sonnet), codex-1 (codex: gpt-6-luna@high)\nReviewer: none\n\n## [x] M5: e\nDepends on: none\nOpen questions:\n- none\n\n## [x] M6: g\nDepends on: M5 (needs e)\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 180 "$ORCH" autopilot > "$WORK/adp.log" 2>&1; code=$?; L=.orchestrate/autopilot.log
check "auto dispatch: M6 starts as soon as M5 lands, without waiting for the lead" '[ $code -eq 0 ] && [ "$(status_of M6)" = merged ] && grep -q "M6: M5 landed, so it starts now (auto dispatch); the lead is told" $L && ! grep -q "orch dispatch M6" "$FH/lead-events.log"'
check "the lead is told with AUTO-DISPATCHED and the reason" 'grep -q "AUTO-DISPATCHED M6 \"g\": started by the event manager as soon as M5 landed (.Auto dispatch: on. in plan.md)" "$FH/lead-events.log"'
check "the first milestone still waits for the lead's go" 'grep -q "waiting for the lead: dispatch M5" $L && grep -q "M5 -> claude-1 .*it waited [0-9]m[0-9]*s for the lead.s dispatch" $L'

echo "46. plain words: the plan as cards, a SAY line per event, the run diary"
newrepo pw; echo "$APP" > "$FH/lead.dir"; echo "INR only" > "$FH/lead-answer"
printf '# Plan: Totals\nBranch: feature/pw\nCheck command: true\nIsolation: worktree\nMax parallel: 2\nEstimate: 1h10m\nLead: lead (claude: opus)\nWorkers: claude-1 (claude: sonnet), codex-1 (codex: gpt-6-luna@high)\nReviewer: reviewer (agy)\n\n## [x] M5: e\nDepends on: none\nWhy separate: the totals build on it\nPlain: the page that lists every expense\nReview: yes\nEstimate: 30m\nOpen questions:\n- none\n\n## [x] M4: Totals\nDepends on: M5 (needs the expense list)\nWhy separate: needs the list first\nEstimate: 40m\nOpen questions:\n- none\n' > .orchestrate/plan.md
"$ORCH" sync >/dev/null 2>&1; out=$("$ORCH" plan show 2>&1)
check "orch plan show: one card per milestone, in the plan's plain words" 'grep -q "^PLAN in plain words: Totals — 2 milestone(s) on feature/pw, about 1h10m in all" <<<"$out" && grep -q "^M5 e — the page that lists every expense$" <<<"$out" && grep -q "^   Why its own step: the totals build on it" <<<"$out"'
check "each card says what it waits for and why, who builds it on which model, how long, and the review" 'grep -q "^   Waits for: nothing, it can start first" <<<"$out" && grep -q "^   Waits for: M5 (needs the expense list)" <<<"$out" && grep -q "^   Built by: claude-1 (sonnet) or codex-1 (gpt-6-luna@high) · about 30m · reviewed by reviewer" <<<"$out"'
check "the order is spelled out" 'grep -q "^  1. M5$" <<<"$out" && grep -q "^  2. M4 (after M5)$" <<<"$out"'
check "a milestone with no Plain: line is named, with the fix" 'grep -q "^WARN no .Plain:. line for M4" <<<"$out"'
timeout 180 "$ORCH" autopilot > "$WORK/pw.log" 2>&1 & ap=$!
sleep 3; out=$("$ORCH" plan show 2>&1); code=$?; sout=$("$ORCH" story 2>&1); scode=$?
wait $ap; code_ap=$?
check "plan show and story work while the event manager runs" '[ $code -eq 0 ] && [ $scode -eq 0 ] && grep -q "^PLAN in plain words" <<<"$out" && grep -q "^RUN DIARY" <<<"$sout"'
check "the run still lands everything" '[ $code_ap -eq 0 ] && [ "$(status_of M5)$(status_of M4)" = mergedmerged ]'
E="$FH/lead-events.log"
check "Plain: is for the developer: it is not in the coder's task file" 'f=$(ls "$APP"/../app-wt/*/.orch-task/M5/task.md | head -1); [ -n "$f" ] && grep -q "^# " "$f" && ! grep -q "Plain:\|lists every expense" "$f"'
check "every event in orch events has a SAY line in plain words" 'grep -q "^    SAY: Ready to start: M5 (e)\.$" "$E" && grep -q "^    SAY: M5 (e) is done: its check passed and the reviewer approved it, and it is on feature/pw\.$" "$E" && grep -q "^    SAY: M4 (Totals) has started by itself, because M5 landed\.$" "$E" && grep -q "^    SAY: M4 (Totals) is paused: the coder asks: which currency should totals use, INR or multi?$" "$E" && grep -q "^    SAY: Every milestone is done: final check PASS on feature/pw\.$" "$E"'
check "each wake-up tells the lead to say them before it stops" '[ "$(grep -c "^BEFORE YOU STOP, tell the developer in your chat, one short line per event" "$E")" -eq "$(grep -c "^EVENTS for the lead" "$E")" ] && grep -q "^7\. \*\*Never end a wake-up silently\.\*\*" "$E"'
out=$("$ORCH" story 2>&1)
check "orch story: what happened and what the lead did, in time order" 'grep -q "what happened: Ready to start: M5 (e)\." <<<"$out" && grep -q "the lead did: M5 (e) was sent to start$" <<<"$out" && grep -qE "the lead did: M4 \(Totals\) got the answer \"INR only\" and goes back to (claude-1|codex-1)" <<<"$out" && [ "$(grep -n "is paused" <<<"$out" | cut -d: -f1)" -lt "$(grep -n "got the answer" <<<"$out" | cut -d: -f1)" ]'
"$ORCH" sync >/dev/null 2>&1
check "orch sync keeps the diary (the plan is synced again after every answer)" '"$ORCH" story | qgrep -q "the lead did: M5 (e) was sent to start$"'
check "the diary is saved in .orchestrate/story.md" 'grep -q "^# Run diary: Totals (feature/pw)" .orchestrate/story.md && grep -q "^- .*what happened: Every milestone is done" .orchestrate/story.md'
out=$("$ORCH" plan show 2>&1)
check "after the run, the cards say each milestone is done" '[ "$(grep -c "^   Now: done, on the branch$" <<<"$out")" -eq 2 ]'
"$ORCH" fix M5 "the list shows newest first" >/dev/null 2>&1
check "orch fix is in the diary too" '"$ORCH" story | qgrep -q "the lead did: M6 added: a follow-up to M5 (\"the list shows newest first\")"'
pkill -f -- "$APP" 2>/dev/null; sleep 1

echo "47. the run's PR carries no AI tool's credit"
newrepo prc
printf '# Plan: t\nBranch: feature/prc\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M5: e\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 120 "$ORCH" autopilot > "$WORK/prc.log" 2>&1; code=$?
check "orch's own commits credit nobody but the developer" '[ $code -eq 0 ] && [ "$(status_of M5)" = merged ] && ! git log main..feature/prc --format="%an%n%B" | qgrep -qi "claude\|co-authored-by\|generated with"'
printf '\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\nhttps://claude.ai/code/session_01XYZ\nCo-authored-by: Jane <1+jane@users.noreply.github.com>\n' >> .orchestrate/summary.md
echo x > by-agent.txt; git add by-agent.txt
git -c user.name=Claude -c user.email=noreply@anthropic.com commit -qm "chore: by an agent" -m "Co-Authored-By: Claude <noreply@anthropic.com>"
git init -q --bare "$WORK/prc-remote.git"; git remote add origin https://github.com/acme/app.git
git config url."$WORK/prc-remote.git".pushInsteadOf https://github.com/acme/app.git
mkdir -p "$WORK/ghbin"; printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" > "%s/gh-args.txt"\nwhile [ $# -gt 0 ]; do [ "$1" = --body-file ] && cp "$2" "%s/gh-body.txt"; shift; done\necho https://github.com/acme/app/pull/7\n' "$WORK" "$WORK" > "$WORK/ghbin/gh"; chmod +x "$WORK/ghbin/gh"
out=$(PATH="$WORK/ghbin:$PATH" "$ORCH" finish 2>&1); code=$?
check "finish opens the PR with gh, from .orchestrate/pr-body.md" '[ $code -eq 0 ] && grep -q "^PR https://github.com/acme/app/pull/7" <<<"$out" && grep -qx -- "--body-file" "$WORK/gh-args.txt" && grep -q "pr-body.md" "$WORK/gh-args.txt"'
check "the PR text is the summary without AI credit lines; a person's co-author stays" 'grep -q "Final check on the branch" "$WORK/gh-body.txt" && ! grep -qi "noreply@anthropic\|generated with\|claude.ai/code/session" "$WORK/gh-body.txt" && grep -q "Co-authored-by: Jane" "$WORK/gh-body.txt"'
check "the summary itself is left as written" 'grep -q "Generated with \[Claude Code\]" .orchestrate/summary.md'
check "a commit an agent made with its own credit is named, and only that one" 'grep -q "^WARN 1 commit(s) on feature/prc credit an AI tool" <<<"$out" && grep -q "chore: by an agent" <<<"$out"'
git remote remove origin; git init -q --bare "$WORK/prc-remote2.git"; git remote add origin "$WORK/prc-remote2.git"
out=$("$ORCH" finish 2>&1)
check "without gh, finish names the title and the PR text to use, and says to add no credit line" 'grep -q "^OPEN A PR from feature/prc into main — title: .t., text: .orchestrate/pr-body.md (use them as they are: add no \"Generated with\" or Co-Authored-By line)" <<<"$out"'

echo "48. Pi: panes stays the default and unchanged; subagent mode runs in one Pi window"
newrepo pim
printf '# Plan: t\nBranch: feature/pim\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M1: e\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
"$ORCH" sync >/dev/null 2>&1
check "no config: the mode is panes (default)" '[ "$("$ORCH" mode)" = "mode: panes (this repo'"'"'s run)" ] && (cd "$WORK" && [ "$("$ORCH" mode)" = "mode: panes (default)" ])'
check "a run synced with no config is recorded as panes" '[ "$(python3 -c "import json;print(json.load(open(\".orchestrate/state.json\"))[\"orch_mode\"])")" = panes ]'
python3 -c "import json;p='.orchestrate/state.json';d=json.load(open(p));d.pop('orch_mode');json.dump(d,open(p,'w'))"
check "a run from before 6.2.0 (no orch_mode) is a panes run" '[ "$("$ORCH" mode)" = "mode: panes (this repo'"'"'s run)" ]'
out=$("$ORCH" lead run 2>&1)
check "panes: orch lead run prints the same run playbook as before" 'grep -q "lead playbook: run$" <<<"$out" && grep -qF "$(head -1 "$ROOT/playbooks/run.md")" <<<"$out" && ! grep -q "subagent" <<<"$out"'
out=$("$ORCH" lead plan 2>&1)
check "panes: orch lead plan has no subagent note" '! grep -q "SUBAGENT MODE" <<<"$out"'
out=$("$ORCH" setup 2>&1)
check "orch setup in panes mode changes nothing" 'grep -q "^mode panes: nothing to set up here" <<<"$out" && [ ! -e "$ORCH_CONFIG_FILE" ] && [ ! -e "$PI_CODING_AGENT_DIR" ]'
check "orch setup refuses an unknown mode" '! "$ORCH" setup --mode tabs >/dev/null 2>&1 && ! "$ORCH" mode tabs >/dev/null 2>&1'
mkdir -p "$WORK/pibin"; printf '#!/usr/bin/env bash\necho "$*" >> "%s/pi.log"\n[ "$1" = list ] && cat "%s/pi.list" 2>/dev/null\n[ "$1" = install ] && echo "$2" >> "%s/pi.list"\nexit 0\n' "$WORK/pibin" "$WORK/pibin" "$WORK/pibin" > "$WORK/pibin/pi"; chmod +x "$WORK/pibin/pi"
mkdir -p "$WORK/config"; printf '{"subagent": {"coder": {"model": "anthropic/claude-sonnet-4-5", "thinking": "medium", "max_turns": 80}}}\n' > "$ORCH_CONFIG_FILE"
out=$(cd "$WORK" && "$ORCH" setup --mode subagent 2>&1); code=$?
check "setup --mode subagent saves it for Pi only and keeps the rest of the config" '[ $code -eq 0 ] && python3 -c "import json,sys;d=json.load(open(sys.argv[1]));assert d[\"modes\"]=={\"pi\":\"subagent\"} and \"mode\" not in d and d[\"subagent\"][\"coder\"][\"thinking\"]==\"medium\"" "$ORCH_CONFIG_FILE"'
check "it writes coder.md with the config model, and reviewer.md that cannot edit" 'grep -qx "model: anthropic/claude-sonnet-4-5" "$PI_CODING_AGENT_DIR/agents/coder.md" && grep -qx "thinking: medium" "$PI_CODING_AGENT_DIR/agents/coder.md" && grep -qx "name: reviewer" "$PI_CODING_AGENT_DIR/agents/reviewer.md" && grep -qx "tools: read, bash, grep, find, ls" "$PI_CODING_AGENT_DIR/agents/reviewer.md" && ! grep -q "^model:" "$PI_CODING_AGENT_DIR/agents/reviewer.md"'
check "both agents say they are only for orch runs; the reviewer denies edit and write; max_turns only where set" 'grep -q "^description: Only for a herdr-orchestra run" "$PI_CODING_AGENT_DIR/agents/coder.md" && grep -q "^description: Only for a herdr-orchestra run" "$PI_CODING_AGENT_DIR/agents/reviewer.md" && grep -qx "disallowed_tools: edit, write" "$PI_CODING_AGENT_DIR/agents/reviewer.md" && grep -qx "max_turns: 80" "$PI_CODING_AGENT_DIR/agents/coder.md" && ! grep -q "^max_turns" "$PI_CODING_AGENT_DIR/agents/reviewer.md"'
check "it installs pi-subagents with pi, once" 'grep -qx "install npm:@tintinweb/pi-subagents" "$WORK/pibin/pi.log" && (cd "$WORK" && "$ORCH" setup --mode subagent | qgrep -q "^ok      npm:@tintinweb/pi-subagents is installed") && [ "$(grep -c "^install" "$WORK/pibin/pi.log")" -eq 1 ]'
printf -- '---\nname: coder\n---\nmy own coder\n' > "$PI_CODING_AGENT_DIR/agents/coder.md"
check "a coder.md the developer wrote is never overwritten" '(cd "$WORK" && "$ORCH" setup | qgrep -q "^KEPT .*coder.md: you edited it") && grep -qx "my own coder" "$PI_CODING_AGENT_DIR/agents/coder.md"'
rm "$PI_CODING_AGENT_DIR/agents/coder.md"
printf '{"mode": "subagent", "subagent": {"reviewer": {"model": "claude-fable-5"}}}\n' > "$ORCH_CONFIG_FILE"
out=$(cd "$WORK" && "$ORCH" setup 2>&1); code=$?
check "a model the policy denies is refused for a subagent" '[ $code -ne 0 ] && grep -q "^REFUSED reviewer" <<<"$out" && [ -e "$PI_CODING_AGENT_DIR/agents/coder.md" ]'
printf '{"mode": "subagent"}\n' > "$ORCH_CONFIG_FILE"
# bug (6.13.0): that machine-wide "mode" gave every lead (Antigravity, Claude Code, Codex) Pi's subagent steps
out=$(cd "$WORK" && AI_AGENT=antigravity "$ORCH" lead plan 2>&1)
check "an old config's \"mode\": \"subagent\" no longer reaches another agent: Antigravity plans in panes mode" '! grep -q "SUBAGENT MODE" <<<"$out" && grep -q "## 1. Preflight" <<<"$out"'
out=$(cd "$WORK" && CLAUDECODE=1 "$ORCH" lead plan 2>&1)
check "…nor Claude Code (found from CLAUDECODE)" '! grep -q "SUBAGENT MODE" <<<"$out"'
out=$(cd "$WORK" && CODEX_SANDBOX=seatbelt "$ORCH" lead plan 2>&1)
check "…nor Codex (found from CODEX_*)" '! grep -q "SUBAGENT MODE" <<<"$out"'
out=$(cd "$WORK" && "$ORCH" lead plan 2>&1)
check "…nor an agent orch cannot tell" '! grep -q "SUBAGENT MODE" <<<"$out"'
out=$(cd "$WORK" && PI_CODING_AGENT=true "$ORCH" lead plan 2>&1)
check "…but Pi still gets it (the old setting is read as Pi's)" 'grep -q "^SUBAGENT MODE" <<<"$out"'
check "orch mode: another agent sees panes, and Pi's saved mode and the old setting are named" '[ "$(cd "$WORK" && AI_AGENT=agy "$ORCH" mode | head -1)" = "mode: panes (agy: subagent mode is only for Pi)" ] && (cd "$WORK" && AI_AGENT=agy "$ORCH" mode | grep -q "^saved per agent: pi=subagent") && (cd "$WORK" && "$ORCH" mode | grep -q "^NOTE .*old machine-wide")'
check "Pi reads the old setting as its own" '[ "$(cd "$WORK" && AI_AGENT=pi "$ORCH" mode | head -1)" = "mode: subagent (pi, in $ORCH_CONFIG_FILE)" ] || [ "$(cd "$WORK" && AI_AGENT=pi "$ORCH" mode | head -1)" = "mode: subagent (pi, in ${ORCH_CONFIG_FILE/#$HOME/~})" ]'
check "subagent is refused for an agent that has none, by flag or by ORCH_MODE" '! (cd "$WORK" && "$ORCH" mode subagent --agent claude >/dev/null 2>&1) && ! (cd "$WORK" && AI_AGENT=agy ORCH_MODE=subagent "$ORCH" lead plan >/dev/null 2>&1) && grep -q "only for Pi" <<<"$(cd "$WORK" && AI_AGENT=agy ORCH_MODE=subagent "$ORCH" lead plan 2>&1)"'
out=$(cd "$WORK" && PI_CODING_AGENT=true ORCH_MODE=panes "$ORCH" lead plan 2>&1)
check "ORCH_MODE=panes overrides Pi's saved mode for one command" '! grep -q "SUBAGENT MODE" <<<"$out"'
out=$(cd "$WORK" && "$ORCH" lead plan --agent pi 2>&1)
check "--agent pi says which agent leads when orch cannot tell" 'grep -q "^SUBAGENT MODE" <<<"$out"'
printf '{"mode": "subagent", "subagent": {"coder": {"thinking": "low"}}}\n' > "$WORK/legacy.json"
out=$(cd "$WORK" && ORCH_CONFIG_FILE="$WORK/legacy.json" "$ORCH" mode subagent 2>&1)
check "saving a mode moves the old machine-wide setting to Pi's and keeps the rest" 'grep -q "^MOVED" <<<"$out" && python3 -c "import json,sys;d=json.load(open(sys.argv[1]));assert d[\"modes\"]=={\"pi\":\"subagent\"} and \"mode\" not in d and d[\"subagent\"][\"coder\"][\"thinking\"]==\"low\"" "$WORK/legacy.json"'
export PI_CODING_AGENT=true     # the rest of this section is Pi leading
check "the old panes run keeps panes after the machine switched to subagent" '[ "$("$ORCH" mode | head -1)" = "mode: panes (this repo'"'"'s run)" ]'
out=$("$ORCH" team up --dry-run 2>&1)
check "team up in a panes run still looks for panes" '! grep -q "mode subagent" <<<"$out"'
newrepo pis
printf '# Plan: t\nBranch: feature/pis\nCheck command: test ! -f broken.txt\nSetup command: none\nIsolation: shared\nLead: lead (pi)\nLead mode: off\nWorkers: coder (pi)\nReviewer: reviewer (pi)\n\n## [x] M1: one\nDepends on: none\nReview: yes\nLikely files: one.txt\nOpen questions:\n- none\n\n## [x] M2: two\nDepends on: M1 (needs one)\nLikely files: two.txt\nOpen questions:\n- none\n' > .orchestrate/plan.md
"$ORCH" sync >/dev/null 2>&1
check "a new run follows the machine's mode (subagent)" '[ "$("$ORCH" mode | head -1)" = "mode: subagent (this repo'"'"'s run)" ]'
out=$("$ORCH" lead run 2>&1)
check "subagent: orch lead run prints the subagent playbook" 'grep -q "lead playbook: run (subagent mode)" <<<"$out" && grep -q "subagent_type: \"coder\"" <<<"$out"'
out=$("$ORCH" lead plan 2>&1)
check "subagent: orch lead plan starts with the subagent team note, then the usual playbook" 'grep -q "^SUBAGENT MODE" <<<"$out" && grep -q "Workers: coder (pi)" <<<"$out" && grep -q "## 1. Preflight" <<<"$out"'
"$ORCH" start >/dev/null 2>&1
check "subagent: dispatch is refused (no event manager)" '! "$ORCH" dispatch M1 >/dev/null 2>&1 && [ "$(status_of M1)" = pending ]'
out=$("$ORCH" sub next 2>&1)
check "orch sub next starts M1 and prints its task file" 'grep -q "^NEXT M1: one" <<<"$out" && grep -q "^REVIEW yes" <<<"$out" && [ -f "$(sed -n "s/^TASK //p" <<<"$out")" ] && [ "$(status_of M1)" = coding ]'
check "orch sub next again names the same milestone, unsaved" '"$ORCH" sub next | qgrep -q "^CURRENT M1"'
echo 1 > one.txt; touch broken.txt
out=$("$ORCH" check M1 2>&1); code=$?
check "orch check fails with exit 1 when the check fails" '[ $code -eq 1 ] && grep -q "^CHECK FAIL M1" <<<"$out"'
rm broken.txt
check "orch check passes" '"$ORCH" check M1 | qgrep -q "^CHECK PASS M1"'
out=$("$ORCH" sub "done" M1 2>&1)
check "orch sub done commits M1 on the branch" 'grep -q "^MERGED M1" <<<"$out" && [ "$(status_of M1)" = merged ] && git log -1 --format=%s | qgrep -q . && git show --stat HEAD | qgrep -q one.txt && [ -z "$(git status --porcelain)" ]'
"$ORCH" sub next >/dev/null 2>&1; echo 2 > two.txt
out=$("$ORCH" sub "done" M2 2>&1)
check "the last one prints ALL_DONE" 'grep -q "^ALL_DONE" <<<"$out" && "$ORCH" sub next | qgrep -q "^ALL_DONE"'
out=$("$ORCH" finish --no-push 2>&1); code=$?
check "orch finish works on a subagent run, reusing the passing check" '[ $code -eq 0 ] && grep -q "^CLEAN feature/pis" <<<"$out"'
check "subagent finish tells the lead to post the manual tests in its chat" 'grep -q "^LEAD: post the MANUAL TESTS list above in your chat" <<<"$out"'
out=$(AI_AGENT=agy "$ORCH" lead run 2>&1)
check "this repo's last run was Pi's subagent run, yet Antigravity's orch lead run gets the panes playbook" 'grep -q "lead playbook: run$" <<<"$out" && ! grep -q "subagent" <<<"$out"'
cp .orchestrate/plan.md "$WORK/pis-plan.md"
sed -i 's/^Branch: feature\/pis$/Branch: feature\/pis-agy/; s/^Lead: lead (pi)$/Lead: lead (agy)/; s/^Workers: coder (pi)$/Workers: agy-1 (agy)/; s/^Reviewer: reviewer (pi)$/Reviewer: none/; s/^Review: yes$/Review: no/' .orchestrate/plan.md
AI_AGENT=agy "$ORCH" sync >/dev/null 2>&1
check "a new Antigravity-led plan synced over Pi's subagent run is a panes run" '[ "$(python3 -c "import json;print(json.load(open(\".orchestrate/state.json\"))[\"orch_mode\"])")" = panes ] && [ "$(AI_AGENT=agy "$ORCH" mode | head -1)" = "mode: panes (this repo'"'"'s run)" ]'
out=$("$ORCH" mode subagent 2>&1)
check "orch mode subagent from Pi: saved for Pi, and a run whose lead is not Pi stays panes" 'grep -q "^mode: subagent for pi" <<<"$out" && grep -q "stays panes: its lead is agy" <<<"$out" && [ "$(python3 -c "import json;print(json.load(open(\".orchestrate/state.json\"))[\"orch_mode\"])")" = panes ]'
cp "$WORK/pis-plan.md" .orchestrate/plan.md; sed -i 's/^Branch: feature\/pis$/Branch: feature\/pis-two/' .orchestrate/plan.md
AI_AGENT=agy "$ORCH" sync >/dev/null 2>&1
check "a new Pi-led plan follows Pi's saved mode (new \"modes\" format), whoever syncs it" '[ "$(python3 -c "import json;print(json.load(open(\".orchestrate/state.json\"))[\"orch_mode\"])")" = subagent ]'
out=$("$ORCH" mode panes 2>&1)
check "orch mode panes switches Pi and this run" 'grep -q "this repo.s run: panes" <<<"$out" && [ "$("$ORCH" mode)" = "mode: panes (this repo'"'"'s run)" ] && python3 -c "import json,sys;d=json.load(open(sys.argv[1]));assert d[\"modes\"]=={} and \"mode\" not in d" "$ORCH_CONFIG_FILE"'
check "orch sub refuses a panes run" '! "$ORCH" sub next >/dev/null 2>&1'
check "the Pi copy of orch-plan says exactly what skills/orch-plan says" 'python3 -c "
import json,re,sys
a=open(sys.argv[1]).read(); b=open(sys.argv[2]).read()
q=re.search(r\"^description: (.*)$\",b,re.M).group(1)
assert re.sub(r\"^description: .*$\",\"description: \"+json.loads(q),b,count=1,flags=re.M)==a
" "$ROOT/skills/orch-plan/SKILL.md" "$ROOT/pi/skills/orch-plan/SKILL.md"'
check "package.json: the pi block names files that exist" 'python3 -c "
import json,os,sys
r=sys.argv[1]; d=json.load(open(r+\"/package.json\")); p=d[\"pi\"]
assert \"pi-package\" in d[\"keywords\"]
assert all(os.path.exists(os.path.join(r,x,\"SKILL.md\")) for x in p[\"skills\"])
assert all(os.path.exists(os.path.join(r,x)) for x in p[\"extensions\"])
assert {\"extensions\",\"pi\"} <= set(d[\"files\"])
" "$ROOT"'
echo "48b. Pi: /orch-mode subagent sets subagent mode up inside Pi (no terminal step)"
if node -e 'process.exit(process.features && process.features.typescript ? 0 : 1)' 2>/dev/null; then
  PX(){ (cd "$WORK" && NODE_NO_WARNINGS=1 PATH="$WORK/orchbin:$PATH" node "$ROOT/tests/pi-extension.mjs" "$@" 2>&1); }
  mkdir -p "$WORK/orchbin"; ln -sf "$ORCH" "$WORK/orchbin/orch"
  export PI_CODING_AGENT_DIR="$WORK/pi-agent2"; rm -f "$WORK/pibin/pi.list" "$WORK/pibin/pi.log"
  printf '{"mode": "panes"}\n' > "$ORCH_CONFIG_FILE"
  export AI_AGENT=pi; unset PI_CODING_AGENT     # what Pi sets for the commands it runs
  out=$(PX orch-mode subagent)
  check "/orch-mode subagent saves the mode for Pi, writes both agents and installs pi-subagents" 'python3 -c "import json,sys;d=json.load(open(sys.argv[1]));assert d[\"modes\"]=={\"pi\":\"subagent\"} and \"mode\" not in d" "$ORCH_CONFIG_FILE" && [ -f "$PI_CODING_AGENT_DIR/agents/coder.md" ] && [ -f "$PI_CODING_AGENT_DIR/agents/reviewer.md" ] && grep -qx "install npm:@tintinweb/pi-subagents" "$WORK/pibin/pi.log"'
  check "…says it is done, shows what it wrote, never says to use a terminal, and reloads Pi" 'grep -q "Done: subagent mode is ready" <<<"$out" && grep -q "WROTE .*coder.md" <<<"$out" && ! grep -q "NEXT" <<<"$out" && [ "$(tail -1 <<<"$out")" = RELOAD ] && grep -q "^STATUS orch orch: subagent" <<<"$out"'
  out=$(PX orch-mode subagent)
  check "…run again: everything is already there, no second install, no reload" 'grep -q "Done: subagent mode is ready" <<<"$out" && grep -q "ok      npm:@tintinweb/pi-subagents is installed" <<<"$out" && ! grep -q RELOAD <<<"$out" && [ "$(grep -c "^install" "$WORK/pibin/pi.log")" -eq 1 ]'
  rm -rf "$PI_CODING_AGENT_DIR"
  out=$(ORCH_PI="$WORK/no-such-pi" PX orch-mode subagent)
  check "…without pi on PATH it says what failed and to try again, with no reload" 'grep -q "^NOTIFY error" <<<"$out" && grep -q "NO PI" <<<"$out" && grep -q "type /orch-mode subagent again" <<<"$out" && ! grep -q "Done:" <<<"$out" && ! grep -q RELOAD <<<"$out"'
  out=$(PX orch-mode panes)
  check "/orch-mode panes is unchanged: it only switches the mode" 'grep -q "^NOTIFY info mode: panes" <<<"$out" && ! grep -q "WROTE\|RELOAD" <<<"$out" && python3 -c "import json,sys;d=json.load(open(sys.argv[1]));assert \"pi\" not in d[\"modes\"]" "$ORCH_CONFIG_FILE"'
  out=$(PX orch-setup --mode tabs)
  check "/orch-setup refuses an unknown mode" 'grep -q "^NOTIFY error Usage: /orch-setup \[--mode panes|subagent\]" <<<"$out"'
  check "the terminal NEXT hint names the Pi slash command too" '(cd "$WORK" && rm -rf "$PI_CODING_AGENT_DIR" && "$ORCH" mode subagent | qgrep -q "^NEXT .*orch setup --mode subagent. (in Pi, ./orch-mode subagent. does it for you)")'
else
  echo "  skip: this node cannot run TypeScript (needs 22.6+)"
fi
unset ORCH_CONFIG_FILE PI_CODING_AGENT_DIR ORCH_PI AI_AGENT PI_CODING_AGENT
echo "48d. Pi: /orch-board opens the board popup in herdr, else the browser page (orch view)"
if node -e 'process.exit(process.features && process.features.typescript ? 0 : 1)' 2>/dev/null; then
  PB(){ (cd "$WORK" && NODE_NO_WARNINGS=1 PATH="$WORK/orchbin:$PATH" node "$ROOT/tests/pi-extension.mjs" "$@" 2>&1); }
  mkdir -p "$WORK/orchbin" "$WORK/fakeherdr"; ln -sf "$ORCH" "$WORK/orchbin/orch"
  printf '#!/bin/sh\necho "$@" >> "%s/fakeherdr/calls"\n' "$WORK" > "$WORK/fakeherdr/herdr"; chmod +x "$WORK/fakeherdr/herdr"
  rm -f "$WORK/fakeherdr/calls"
  out=$(env -u HERDR_ENV -u HERDR_PANE_ID bash -c "cd '$WORK' && NODE_NO_WARNINGS=1 HERDR_ENV=1 HERDR_BIN_PATH='$WORK/fakeherdr/herdr' PATH='$WORK/orchbin:$PATH' node '$ROOT/tests/pi-extension.mjs' orch-board 2>&1")
  check "/orch-board inside herdr opens the board popup in this repo and does not start the browser page" 'grep -q "^NOTIFY info Board opened" <<<"$out" && grep -q "plugin pane open --plugin herdr-orchestra.board --entrypoint board --placement popup --cwd $WORK" "$WORK/fakeherdr/calls"'
  printf '#!/bin/sh\necho "no such plugin" >&2; exit 1\n' > "$WORK/fakeherdr/herdr"
  out=$(env -u HERDR_PANE_ID bash -c "cd '$WORK' && NODE_NO_WARNINGS=1 HERDR_ENV=1 HERDR_BIN_PATH='$WORK/fakeherdr/herdr' PATH='$WORK/orchbin:$PATH' node '$ROOT/tests/pi-extension.mjs' orch-board 2>&1")
  check "…when herdr refuses, it says why, names \`orch view plugin link\` and falls back to the browser page" 'grep -q "^NOTIFY warning Herdr could not open the board popup: no such plugin" <<<"$out" && grep -q "orch view plugin link" <<<"$out"'
  "$ORCH" view stop >/dev/null 2>&1 || true
fi
echo "48c. native question pickers: the lead asks in its agent's own picker (Pi: orch_ask), chat stays the fallback"
out=$("$ORCH" lead plan 2>&1)
check "the plan playbook has the native question rule: a picker when there is one, for every agent" 'grep -q "native question rule" <<<"$out" && for t in AskUserQuestion "\`question\` in OpenCode" request_user_input orch_ask Antigravity; do grep -q "$t" <<<"$out" || { echo "missing $t"; exit 1; }; done'
check "…answers go to questions.md under ## Answers, and planning goes straight on" 'grep -q "under \`## Answers\` in \`.orchestrate/questions.md\` (\`orch_ask\` saves the file itself), then go straight on" <<<"$out"'
check "…a closed picker pauses planning instead of guessing" 'grep -q "closed the picker without answering.*don.t guess and don.t plan" <<<"$out"'
check "…no picker: the chat questions as before, all in one message, and grill: is still one at a time" 'grep -q "No picker, or it can.t show here" <<<"$out" && grep -q "all in one message" <<<"$out" && grep -q "Answer by number" <<<"$out" && grep -q "one picker call per question" <<<"$out"'
newrepo nq
check "a Codex lead starts with its question picker on; coders and the reviewer never get it (unattended panes)" '"$ORCH" agents launch codex --role lead | qgrep -q " -c features.default_mode_request_user_input=true$" && ! "$ORCH" agents launch codex | qgrep -q request_user_input && ! "$ORCH" agents launch codex --role reviewer | qgrep -q request_user_input && [ "$("$ORCH" agents launch claude --role lead)" = "claude --permission-mode acceptEdits" ]'
check "a lead started on a model keeps the picker after the model and thinking options" '[ "$("$ORCH" agents launch codex --role lead --model gpt-6.2-sol@high)" = "$("$ORCH" agents launch codex --model gpt-6.2-sol@high) -c features.default_mode_request_user_input=true" ]'
if node -e 'process.exit(process.features && process.features.typescript ? 0 : 1)' 2>/dev/null; then
  PT(){ NODE_NO_WARNINGS=1 node "$ROOT/tests/pi-extension.mjs" "$@" 2>&1; }
  NQ='{"title":"Decisions before planning","questions":[{"id":"q1","question":"Discount on the whole order or each item?","options":[{"key":"a","label":"Whole order","recommended":true},{"key":"b","label":"Each item"}]},{"id":"q2","question":"Can a discount bring the total to zero?","options":[{"key":"a","label":"No"},{"key":"b","label":"Yes","description":"free orders"}],"allow_custom":true}]}'
  out=$(PICKS=0,1 PT tool orch_ask "$NQ")
  check "Pi orch_ask shows one picker per question, the suggestion marked [Recommended], with a custom answer" 'grep -q "^SELECT Decisions before planning (1 of 2) / Discount on the whole order or each item? | (a) Whole order \[Recommended\] | (b) Each item | Custom answer...$" <<<"$out" && grep -q "^SELECT Decisions before planning (2 of 2) / .* | (b) Yes - free orders | Custom answer...$" <<<"$out"'
  check "…returns the answers to the lead, who goes straight on" 'grep -q "^status: answered" <<<"$out" && grep -q "^1. q1: (a) Whole order$" <<<"$out" && grep -q "^2. q2: (b) Yes$" <<<"$out" && grep -q "carry on from step 2b" <<<"$out" && grep -q "^RESULT {\"status\":\"answered\"" <<<"$out"'
  check "…and saves questions, choices and answers to .orchestrate/questions.md" 'grep -q "^# Decisions before planning$" .orchestrate/questions.md && grep -q "^   (a) Whole order \[Recommended\]$" .orchestrate/questions.md && grep -q "^## Answers$" .orchestrate/questions.md && grep -q "^2. (b) Yes$" .orchestrate/questions.md'
  out=$(PICKS=custom,"Only on weekdays" PT tool orch_ask '{"questions":[{"id":"q3","question":"When?","options":[{"key":"a","label":"Always"}]}]}')
  check "…a custom answer is typed in and saved; a second round in the same planning adds to the file" 'grep -q "^INPUT When?$" <<<"$out" && grep -q "^1. q3: custom: Only on weekdays$" <<<"$out" && grep -q "^1. Only on weekdays$" .orchestrate/questions.md && grep -q "^# Decisions before planning$" .orchestrate/questions.md'
  echo "# Plan" > .orchestrate/plan.md; touch -d "+1 minute" .orchestrate/plan.md
  PICKS=0 PT tool orch_ask '{"questions":[{"id":"q1","question":"New feature?","options":[{"key":"a","label":"Yes"}]}]}' >/dev/null
  check "…questions from an earlier plan are replaced, not added to" '! grep -q "Whole order" .orchestrate/questions.md && grep -q "^1. New feature?$" .orchestrate/questions.md'
  rm -f .orchestrate/questions.md .orchestrate/plan.md
  out=$(PICKS=0,esc PT tool orch_ask "$NQ")
  check "…Escape stops it: status cancelled, the lead is told not to guess, nothing saved" 'grep -q "^status: cancelled at question 2 of 2 (q2)" <<<"$out" && grep -q "Don.t guess" <<<"$out" && [ ! -e .orchestrate/questions.md ]'
  out=$(PICKS=custom,esc PT tool orch_ask "$NQ")
  check "…an empty or cancelled custom answer is a cancel too" 'grep -q "^status: cancelled at question 1" <<<"$out"'
  out=$(NO_UI=1 PT tool orch_ask "$NQ")
  check "…without a screen (Pi print mode) it says no_ui and the lead asks in chat" 'grep -q "^status: no_ui" <<<"$out" && ! grep -q "^SELECT" <<<"$out" && [ ! -e .orchestrate/questions.md ]'
  git worktree add -q ../nq-wt -b nqwt 2>/dev/null
  (cd ../nq-wt && PICKS=1,0 PT tool orch_ask "$NQ" >/dev/null)
  check "…from a worktree the file goes to the main checkout's .orchestrate (like state.json)" '[ -f .orchestrate/questions.md ] && [ ! -e ../nq-wt/.orchestrate/questions.md ] && grep -q "^1. (b) Each item$" .orchestrate/questions.md'
  out=$(PT prompt)
  check "Pi's lead is told orch_ask is there for /orch-plan decisions; coders are told not to use it" 'grep -q "When you lead /orch-plan and need decisions only the developer can make, ask them with the orch_ask tool" <<<"$out" && grep -q "A coder or reviewer never uses it" <<<"$out" && grep -q "^herdr-orchestra (orch) mode:" <<<"$out"'
  check "orch_ask's parameters are plain JSON Schema (no typebox import: Pi validates JSON Schema)" '! grep -q "from \"typebox\"\|@sinclair/typebox" "$ROOT/extensions/orch-mode.ts" && grep -q "maxItems: 8" "$ROOT/extensions/orch-mode.ts"'
else
  echo "  skip: this node cannot run TypeScript (needs 22.6+)"
fi
cd "$WORK" || exit

echo "49. a coder moved off its milestone is really stopped (bug: STOP note queued, coder shown free while it still worked)"
HPLAN='# Plan: t\nBranch: feature/halt\nCheck command: true\nIsolation: worktree\nMax parallel: 2\nWorkers: claude-1 (claude), codex-1 (codex)\nReviewer: none\n\n## [x] M20: long job\nDepends on: none\nAcceptance criteria:\n- it works\nOpen questions:\n- none\n\n## [x] M8: next job\nDepends on: none\nOpen questions:\n- none\n'
newrepo halt; printf "$HPLAN" > .orchestrate/plan.md
"$ORCH" sync >/dev/null && "$ORCH" start >/dev/null && "$ORCH" prepare M20 codex-1 >/dev/null && "$ORCH" write-task M20 >/dev/null && "$ORCH" send M20 task.md >/dev/null
sleep 1.5; pkill -f -- "behave.sh codex-1 $WORK/halt" 2>/dev/null    # the fake coder never finishes by itself here
touch "$FH/codex-1.ignores-esc"; echo working > "$FH/codex-1.status"   # like agy: busy with a long step
# plan.md edited while codex-1 works on M20: its task.md is not rewritten, and sync says so
sed -i 's/^- it works$/- it works\n- it is fast/' .orchestrate/plan.md
out=$("$ORCH" sync 2>&1)
check "sync warns when a running milestone changed in plan.md, and says how to send the new text" 'grep -q "^WARN: M20 changed in plan.md, but codex-1 is already working from its old task.md" <<<"$out" && grep -q "orch set M20 paused., then .orch dispatch M20" <<<"$out"'
sed -i 's/^## \[x\] M8: next job$/## [x] M8: next job, renamed/' .orchestrate/plan.md
check "a change to a milestone nobody works on gives no warning" '! "$ORCH" sync 2>&1 | qgrep -q "M8 changed"'
out=$(ORCH_HALT_WAIT_S=1 ORCH_HALT_SETTLE_S=3 "$ORCH" set M20 paused "moving it to claude-1" 2>&1); code=$?
check "pausing a milestone whose coder still works presses its interrupt key (Esc) before the STOP note" '[ $code -eq 0 ] && grep -q "^codex-1 keys esc$" "$FH/keys.log" && grep -q "^STOP_NOTE M20 -> codex-1: interrupted (esc) and told to stop" <<<"$out" && grep -q "^codex-1 <- STOP: M20 is paused (moving it to claude-1). orch interrupted you" "$FH/prompts.log"'
check "…and it is not marked free: it stays busy (stopping) while herdr shows it working" 'grep -q "^STOPPING codex-1: herdr still shows it working; it stays busy" <<<"$out"'
out=$("$ORCH" status 2>&1)
check "orch status shows the coder as stopping M20, not free" 'grep -q "worker codex-1 .*state=stopping M20 (told to stop" <<<"$out" && ! grep -q "worker codex-1 .*state=free" <<<"$out"'
out=$("$ORCH" dispatch M20 --to claude-1 2>&1)
check "the milestone itself moves on to the other coder" 'grep -q "^DISPATCH M20 -> claude-1" <<<"$out"'
"$ORCH" bench claude-1 off "test" >/dev/null
out=$("$ORCH" pick M8 2>&1); code=$?
check "a stopping coder is never picked for new work (bug: M8 went to it)" '[ $code -eq 3 ] && grep -q "^NONE" <<<"$out"'
out=$("$ORCH" prepare M8 codex-1 2>&1); code=$?
check "…and can't be given work by hand either" '[ $code -eq 3 ] && grep -q "^BUSY codex-1 is still stopping M20" <<<"$out" && [ "$(status_of M8)" = pending ]'
out=$("$ORCH" ready 2>&1)
check "ready counts no free coder while it stops" 'grep -q "^SLOTS 0" <<<"$out"'
# the event manager presses the key again when it keeps going
ORCH_HALT_REPEAT_S=0 timeout 20 "$ORCH" autopilot > "$WORK/halt.log" 2>&1
check "the event manager interrupts it again when it is still working, and says so" '[ "$(grep -c "^codex-1 keys esc$" "$FH/keys.log")" -ge 2 ] && grep -q "codex-1 is still working .* after it was told to stop M20: pressed esc again" "$WORK/halt.log"'
check "…and still hands it no work" '[ "$(status_of M8)" = pending ] && ! grep -q "M8 -> codex-1" "$WORK/halt.log"'
rm -f "$FH/codex-1.ignores-esc"; echo idle > "$FH/codex-1.status"; sleep 1.2
out=$("$ORCH" status 2>&1)
check "once herdr shows it idle (and it stayed idle a moment), it is free again" 'grep -q "worker codex-1 .*state=free" <<<"$out"'
out=$("$ORCH" pick M8 2>&1)
check "…and it can take new work" '[ "$out" = codex-1 ]'
stpy "st['workers']['codex-1']['stopping'] = {'task': 'M20', 'ts': now}"
echo working > "$FH/codex-1.status"
out=$("$ORCH" free codex-1 2>&1)
check "orch free: you looked at its pane, it has stopped; it is free at once" 'grep -q "^FREE    codex-1: no longer waits to stop M20" <<<"$out" && python3 -c "import json,sys;sys.exit(\"stopping\" in json.load(open(\".orchestrate/state.json\"))[\"workers\"][\"codex-1\"])"'
echo idle > "$FH/codex-1.status"
check "every agent kind has an interrupt key; OpenCode needs Esc twice" 'python3 -c "
import importlib.machinery, importlib.util
l = importlib.machinery.SourceFileLoader(\"orch\", \"$ROOT/bin/orch\"); m = importlib.util.module_from_spec(importlib.util.spec_from_loader(\"orch\", l)); l.exec_module(m)
assert m.interrupt_keys(\"opencode\") == [\"esc\", \"esc\"], m.interrupt_keys(\"opencode\")
for k in (\"claude\", \"codex\", \"agy\", \"amp\", \"hermes\", \"pi\", \"unknown-kind\"): assert m.interrupt_keys(k) == [\"esc\"], k"'

# team up never names the lead's pane (or the pane it runs in) as the reviewer (bug: lead pane became rs-reviewer)
TPLAN='# Plan: t\nBranch: feature/tl\nCheck command: true\nIsolation: worktree\nLead: rs-lead (claude)\nWorkers: claude-1 (claude)\nReviewer: rs-reviewer (claude)\n\n## [x] M1: e\nDepends on: none\nOpen questions:\n- none\n'
newrepo tl; printf "$TPLAN" > .orchestrate/plan.md
echo "$APP" > "$FH/pane-w1:p1.cwd"; echo claude > "$FH/pane-w1:p1.kind"; echo claude > "$FH/pane-w1:p1.cmd"; echo w1:p1 > "$FH/rs-lead.paneid"
echo 1 > "$FH/pane-seq"; touch "$FH/rs-reviewer.missing"
"$ORCH" sync >/dev/null && HERDR_PANE_ID=w1:p1 "$ORCH" start >/dev/null 2>&1
out=$(env -u HERDR_PANE_ID ORCH_TEAM_WAIT_S=2 "$ORCH" team up 2>&1); code=$?
check "team up does not give the lead's pane (same kind, same folder) the reviewer's name" '! grep -q "rename w1:p1 rs-reviewer" "$FH/team.log" && grep -q "^OPENED  rs-reviewer: pane w1:p2 in " <<<"$out"'
check "the reviewer is started inside the repo folder, whatever folder the split starts in" "grep -q \"^run w1:p2 cd $APP && claude\" \"\$FH/team.log\""
check "orch start still finds the lead afterwards" 'HERDR_PANE_ID=w1:p1 "$ORCH" start 2>&1 | qgrep -q "^LEAD rs-lead kind=claude herdr=found"'
newrepo tl2; printf "$TPLAN" | grep -v "^Lead:" > .orchestrate/plan.md
echo "$APP" > "$FH/pane-w1:p1.cwd"; echo claude > "$FH/pane-w1:p1.kind"; echo claude > "$FH/pane-w1:p1.cmd"
echo 1 > "$FH/pane-seq"; touch "$FH/rs-reviewer.missing"
"$ORCH" sync >/dev/null && "$ORCH" start >/dev/null 2>&1
out=$(HERDR_PANE_ID=w1:p1 ORCH_TEAM_WAIT_S=2 "$ORCH" team up 2>&1)
check "with no lead in the plan, the pane team up runs in is never renamed either" '! grep -q "rename w1:p1 " "$FH/team.log" && grep -q "^OPENED  rs-reviewer: pane w1:p2" <<<"$out"'

# the lead's pane keeps the plan's lead name (bug: lead whoami / lead run renamed it to `lead`)
newrepo lw; printf "$TPLAN" > .orchestrate/plan.md; "$ORCH" sync >/dev/null
sed -i 's/^Lead: rs-lead/Lead: rs-boss/' .orchestrate/plan.md           # changed after the last sync
touch "$FH/rs-boss.missing"; echo "$APP" > "$FH/pane-w1:p9.cwd"; echo claude > "$FH/pane-w1:p9.cmd"
out=$(HERDR_PANE_ID=w1:p9 "$ORCH" lead whoami 2>&1)
check "orch lead whoami names the pane with the plan's Lead name, not lead" 'grep -q "^NAMED   this pane (w1:p9) is now .rs-boss." <<<"$out" && grep -q "Lead: rs-boss" <<<"$out" && ! grep -q "rename w1:p9 lead$" "$FH/team.log"'
touch "$FH/rs-boss.missing"
out=$(HERDR_PANE_ID=w1:p9 "$ORCH" lead run 2>&1)
check "orch lead run uses plan.md's Lead name even before orch sync" 'grep -q "^NAMED   this pane (w1:p9) is now .rs-boss." <<<"$out" && [ "$(grep -c "^rename w1:p9 lead$" "$FH/team.log")" -eq 0 ]'

# --help prints help and never runs the command (bug: `orch team up --help` opened panes)
rm -f "$FH/team.log"; touch "$FH/rs-reviewer.missing"
out=$(ORCH_TEAM_WAIT_S=1 "$ORCH" team up --help 2>&1); code=$?
check "orch team up --help prints the team up help and opens nothing" '[ $code -eq 0 ] && grep -q "^  team up \[--dry-run\]" <<<"$out" && [ ! -f "$FH/team.log" ]'
out=$("$ORCH" set M1 paused -h 2>&1); code=$?
check "orch set ... -h changes nothing" '[ $code -eq 0 ] && grep -q "^  set <Mn> <status>" <<<"$out" && [ "$(status_of M1)" = pending ]'
check "orch --help exits 0" '"$ORCH" --help >/dev/null 2>&1'

echo "50. house rules: the repo's words, decisions and coding rules reach the coder and the reviewer; two-question review"
newrepo hrules
mkdir -p docs/adr
printf '# Glossary\n\n- **Discount**: money taken off an order total, in paise. Avoid: coupon, promo\n- **Refund**: money sent back to a customer.\n' > docs/glossary.md
printf '# Money is whole paise\n\nWe store money as whole paise, never decimals.\n' > docs/adr/0001-money-in-paise.md
printf '# Coding rules\n- No floats for money.\n' > docs/coding-standards.md
git add docs && git commit -qm docs
HRPLAN='# Plan: Discounts\nBranch: feature/hr\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: reviewer (agy)\n\n## [x] M23: Discount\nDepends on: none\nReview: yes\nLikely files: dd.txt\nGoal: orders can have a WORD off the total\nAcceptance criteria:\n- an order shows its discount\nOpen questions:\n- none\n'
printf "$HRPLAN" | sed 's/WORD/discount/' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1)
check "a plan that uses the glossary's word gets no word warning" '! grep -q "glossary.md says to use" <<<"$out"'
printf "$HRPLAN" | sed 's/WORD/coupon/' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1)
check "orch sync warns when the plan uses a word the glossary says to avoid" "grep -q \"^WARN: M23 says 'coupon', but docs/glossary.md says to use 'Discount' instead\" <<<\"\$out\""
printf "$HRPLAN" | sed 's/WORD/discount/' > .orchestrate/plan.md
timeout 120 "$ORCH" autopilot > "$WORK/hrules.log" 2>&1; code=$?
T=$(ls "$APP"/../app-wt/claude-1/.orch-task/M23/task.md 2>/dev/null)
check "the run lands" '[ $code -eq 0 ] && [ "$(status_of M23)" = merged ]'
check "the coder's task file has the Project rules: only the words its milestone uses, every decision, the coding rules" '[ -n "$T" ] && grep -q "^## Project rules" "$T" && grep -q "^- \*\*Discount\*\*: money taken off an order total, in paise. Avoid: coupon, promo" "$T" && ! grep -q "Refund" "$T" && grep -q "^- docs/adr/0001-money-in-paise.md: Money is whole paise" "$T" && grep -q "^Coding rules: docs/coding-standards.md" "$T"'
check "task.json names the same rules" 'python3 -c "import json,sys; r=json.load(open(sys.argv[1]))[\"project_rules\"]; assert r[\"glossary\"]==[\"Discount\"] and r[\"decisions\"]==[\"docs/adr/0001-money-in-paise.md\"] and r[\"coding_rules\"]==\"docs/coding-standards.md\", r" "$(dirname "$T")/task.json"'
R=.orchestrate/review/M23/review-task-1.md
check "the reviewer answers two questions: spec and rules, with the repo's rules and the check named" 'grep -q "^Answer two questions, separately" $R && grep -q "^1. .spec.: did it build what the task asks, no more and no less" $R && grep -q "^2. .rules.: does it follow the project.s own written rules: docs/coding-standards.md, the decisions listed above, the words listed above" $R && grep -q "^## Project rules" $R && grep -q "runs on this work by itself: don.t report what lint" $R && grep -q "Report PROBLEMS, not solutions" $R'
check "the review format asks for axis and rule" 'grep -q "\"axis\": \"spec | rules\"" $R && grep -q "\"rule\":" $R'
S=.orchestrate/summary.md
check "the summary lists the findings by question, and the rules broken" 'grep -q "^## Review findings: spec and rules" $S && grep -q "^Spec (1):" $S && grep -q "^- M23 round 1, suggestion: dd.txt:1 — no test for a zero discount" $S && grep -q "^Rules (1):" $S && grep -q "^- M23 round 1, suggestion: \[ADR 0001: money is whole paise\] dd.txt:1 — discount kept as a decimal" $S && grep -q "^Rules broken most often: ADR 0001: money is whole paise (1x)" $S'
check "suggestions not applied carry their question" 'grep -q "^- M23: SUGGESTION: \[rules: ADR 0001: money is whole paise\] dd.txt:1" $S && grep -q "^- M23: SUGGESTION: \[spec\] dd.txt:1" $S'
out=$("$ORCH" report 2>&1)
check "orch report counts findings by question and each broken rule" 'grep -q "^review findings: 1 spec (built what was asked?), 1 rules" <<<"$out" && grep -q "^  rule broken 1x: ADR 0001: money is whole paise" <<<"$out" && "$ORCH" report --json | python3 -c "import json,sys; r=json.load(sys.stdin)[\"review_axes\"]; assert r[\"spec\"]==1 and r[\"rules\"]==1, r"'
newrepo norules; printf '# Plan: t\nBranch: feature/nd\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: reviewer (agy)\n\n## [x] M5: e\nDepends on: none\nReview: yes\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 120 "$ORCH" autopilot > "$WORK/norules.log" 2>&1; code=$?
check "a repo without these files: no Project rules block, no review section (same as before)" '[ $code -eq 0 ] && f=$(ls "$APP"/../app-wt/claude-1/.orch-task/M5/task.md) && ! grep -q "Project rules" "$f" && ! grep -q "Project rules" .orchestrate/review/M5/review-task-1.md && grep -q "rules.: does it follow the project.s own written rules: AGENTS.md / CLAUDE.md when the repo has them?" .orchestrate/review/M5/review-task-1.md && ! grep -q "Review findings: spec and rules\|Undo and blast" .orchestrate/summary.md' 
APP="$WORK/hrules/app"; cd "$APP" || exit 1
check "an old review file without axis is read as before (no tag)" 'python3 - "$ORCH" <<PY
import importlib.machinery, importlib.util, sys, json, tempfile, pathlib
loader = importlib.machinery.SourceFileLoader("orch", sys.argv[1]); spec = importlib.util.spec_from_loader("orch", loader)
m = importlib.util.module_from_spec(spec); loader.exec_module(m)
d = pathlib.Path(tempfile.mkdtemp()); (d / "review" / "M2").mkdir(parents=True)
(d / "review" / "M2" / "review-1.json").write_text(json.dumps({"findings": [{"severity": "blocker", "file": "b.txt", "line": 1, "problem": "p", "why": "w"}]}))
m.ORCH = d; m.load = lambda: {"tasks": {}}
b, s, k = m.review_findings("M2", 1)
assert b == ["BLOCKER: b.txt:1 — p — w"], b
PY'
mkdir -p docs2; printf '## Voucher\nA code a customer types to get a discount.\n' > docs2/glossary.md
check "a glossary with headings instead of bold words, in another Docs: folder, works too" 'python3 - "$ORCH" "$APP" <<PY
import importlib.machinery, importlib.util, sys, pathlib
loader = importlib.machinery.SourceFileLoader("orch", sys.argv[1]); spec = importlib.util.spec_from_loader("orch", loader)
m = importlib.util.module_from_spec(spec); loader.exec_module(m)
m.ROOT = pathlib.Path(sys.argv[2])
g = m.glossary({"docs": "docs2"})
assert g == [{"term": "Voucher", "text": "A code a customer types to get a discount.", "avoid": []}], g
assert m.glossary()[0]["avoid"] == ["coupon", "promo"], m.glossary()
PY'

echo "51. ask first: questions before the plan, new words and decisions get written down"
out=$("$ORCH" lead plan 2>&1)
check "the plan playbook asks before planning, in one message, and grill: asks one at a time" 'grep -q "^## 2a. Ask before you plan" <<<"$out" && grep -q "all in one message" <<<"$out" && grep -q "started the request with .grill:.: ask \*\*one question at a time\*\*" <<<"$out" && grep -q "docs/glossary.md defines Discount" <<<"$out"'
newrepo askfirst; mkdir -p docs/adr; printf -- '- **Discount**: money off. Avoid: coupon\n' > docs/glossary.md; git add docs && git commit -qm docs
AFPLAN='# Plan: t\nBranch: feature/af\nCheck command: true\nIsolation: shared\nWorkers: claude-1 (claude)\nReviewer: none\n\n## Glossary additions\n- **Voucher**: a code a customer types\n\n## [x] M5: e\nDepends on: none\nLikely files: e.txt FILES\nAcceptance criteria:\n- docs/adr/0002-vouchers.md records why vouchers expire\nOpen questions:\n- none\n'
printf "$AFPLAN" | sed 's/ FILES//' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1)
check "orch sync warns when a new word or decision record has no milestone that writes it" 'grep -q "^WARN: .## Glossary additions. lists 1 new word(s), but no milestone has docs/glossary.md in its Likely files" <<<"$out" && grep -q "^WARN: M5.s acceptance criteria name docs/adr/0002-vouchers.md, which is not in its Likely files" <<<"$out"'
printf "$AFPLAN" | sed 's| FILES|, docs/glossary.md, docs/adr/|' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1)
check "…and is quiet once a milestone lists those files" '! grep -q "Glossary additions\|acceptance criteria name" <<<"$out"'
out=$("$ORCH" plan show 2>&1)
check "orch plan show lists the new words" 'grep -q "^New words this feature adds to docs/glossary.md:" <<<"$out" && grep -q "^  - \*\*Voucher\*\*: a code a customer types" <<<"$out"'
printf 'Before I plan, 1 question\n' > .orchestrate/questions.md; touch -d "-1 minute" .orchestrate/plan.md
out=$("$ORCH" lead run 2>&1)
check "the answer to a question asked before the plan never starts a run from an old plan" 'grep -q "^PLANNING, NOT A RUN" <<<"$out" && ! grep -q "How a run works" <<<"$out"'
touch .orchestrate/plan.md
out=$("$ORCH" lead run 2>&1)
check "…once the plan is written after the questions, orch lead run is the run playbook again" '! grep -q "PLANNING, NOT A RUN" <<<"$out" && grep -q "How a run works" <<<"$out"'
rm -f .orchestrate/questions.md

echo "52. risky-change label: hard to undo waits for your OK with proof; how much it could break; the PR table"
newrepo door1; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
DRPLAN='# Plan: Discounts\nBranch: feature/dr\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M24: Discount column\nDepends on: none\nDOOR\nLikely files: col.txt\nOpen questions:\n- none\n\n## [x] M25: Badge\nDepends on: M24 (shows the column)\nLikely files: badge.txt\nOpen questions:\n- none\n'
printf "$DRPLAN" | sed 's/DOOR/Door: maybe/' > .orchestrate/plan.md; out=$("$ORCH" sync 2>&1)
check "a Door line that is not one-way or two-way is named" 'grep -q "^WARN: M24: .Door: maybe. — write .Door: one-way" <<<"$out"'
printf "$DRPLAN" | sed 's/DOOR/Door: one-way/' > .orchestrate/plan.md; out=$("$ORCH" sync 2>&1)
check "one-way without a reason is named" 'grep -q "^WARN: M24 is .Door: one-way. without a reason" <<<"$out"'
printf "$DRPLAN" | sed 's/DOOR/Door: one-way (adds a column to orders, 2M rows)/; s/^Reviewer: none/Reviewer: none\nRisk hold: off/' > .orchestrate/plan.md; out=$("$ORCH" sync 2>&1)
check "Risk hold: off with a one-way milestone is named" 'grep -q "^WARN: M24 is .Door: one-way., but .Risk hold: off. lets it land" <<<"$out"'
printf '# Plan: t\nMode: quick\nQuick because: one file\nBranch: feature/dq\nCheck command: true\nSetup command: none\nIsolation: shared\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M24: x\nDepends on: none\nDoor: one-way (drops a table)\nLikely files: col.txt\nOpen questions:\n- none\n' > .orchestrate/plan.md; out=$("$ORCH" sync 2>&1); code=$?
check "a quick run is never hard to undo" '[ $code -ne 0 ] && grep -q "^ERROR: M24 is .Door: one-way. (hard to undo) — a quick run never is" <<<"$out"'
printf "$DRPLAN" | sed 's/DOOR/Door: one-way (adds a column to orders, 2M rows)/' > .orchestrate/plan.md; out=$("$ORCH" sync 2>&1)
check "the plan syncs; the card says it is hard to undo and waits for your OK" '! grep -q "^ERROR\|Door" <<<"$out" && "$ORCH" plan show | qgrep -q "^   Hard to undo: adds a column to orders, 2M rows. It waits for your OK (.orch approve M24.) before it lands"'
timeout 120 "$ORCH" autopilot > "$WORK/door1.log" 2>&1; code=$?
T=$(ls "$APP"/../app-wt/claude-1/.orch-task/M24/task.md 2>/dev/null)
check "the coder is asked for proof, and does not see the Door line" '[ -n "$T" ] && grep -q "^## Hard to undo: show proof" "$T" && grep -q "hard to undo once it runs (adds a column to orders, 2M rows)" "$T" && ! grep -q "^Door:" "$T" && python3 -c "import json,sys; assert json.load(open(sys.argv[1]))[\"door\"][\"kind\"]==\"one-way\"" "$(dirname "$T")/task.json"'
check "a hard-to-undo milestone is held although no file looks risky, with how much it could break and the proof" '[ $code -eq 3 ] && [ "$(status_of M24)" = held ] && grep -q "M24 is HELD for your approval: hard to undo: adds a column to orders, 2M rows\. Could break: medium (M25 builds on it)\. Proof from the coder: migration ran on a copy: 2M rows in 14s, no lock\." "$WORK/door1.log"'
check "orch status shows the proof with the hold" '"$ORCH" status | qgrep -q "M24.*held.*could break: medium · proof: migration ran on a copy"'
"$ORCH" approve M24 >/dev/null 2>&1; timeout 120 "$ORCH" autopilot > "$WORK/door1b.log" 2>&1; code=$?
S=.orchestrate/summary.md
check "after orch approve, both land" '[ $code -eq 0 ] && [ "$(status_of M24)$(status_of M25)" = mergedmerged ]'
check "the summary (and so the PR) has the undo and blast radius table" 'grep -q "^## Undo and blast radius" $S && grep -q "^| M24 Discount column | \*\*hard\*\*: adds a column to orders, 2M rows | medium: M25 builds on it | migration ran on a copy: 2M rows in 14s, no lock |$" $S && grep -q "^| M25 Badge | easy | small: 1 file(s), 1 lines, nothing else builds on it | - |$" $S'
out=$("$ORCH" report 2>&1)
check "orch report lists it too" 'grep -q "^undo and blast radius" <<<"$out" && grep -q "^  M24 Discount column — undo: hard: adds a column to orders, 2M rows — could break: medium: M25 builds on it — proof: migration ran" <<<"$out"'
newrepo door2; echo "$APP" > "$FH/claude-1.dir"
printf '# Plan: t\nBranch: feature/d2\nCheck command: true\nIsolation: shared\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M24: Discount column\nDepends on: none\nDoor: one-way (adds a column)\nLikely files: col.txt\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 60 "$ORCH" autopilot > "$WORK/door2.log" 2>&1; code=$?
"$ORCH" approve M24 >/dev/null 2>&1; timeout 60 "$ORCH" autopilot > "$WORK/door2b.log" 2>&1; code2=$?
check "shared mode: held with its proof, lands after approve" '[ $code -eq 3 ] && grep -q "M24 is HELD for your approval: hard to undo: adds a column\. Could break: small" "$WORK/door2.log" && [ $code2 -eq 0 ] && [ "$(status_of M24)" = merged ]'

echo "53. Pi gets the 6.6.0 changes too: same plan playbook, project rules and proof in task files, refreshed subagents"
check "Pi's orch-plan skill runs the same command as the main skill (Pi only quotes its description)" '[ "$(sed "1,/^---$/d" "$ROOT/skills/orch-plan/SKILL.md" | sed "1,/^---$/d")" = "$(sed "1,/^---$/d" "$ROOT/pi/skills/orch-plan/SKILL.md" | sed "1,/^---$/d")" ] && [ "$(grep "^description:" "$ROOT/skills/orch-plan/SKILL.md" | cut -d" " -f2-)" = "$(grep "^description:" "$ROOT/pi/skills/orch-plan/SKILL.md" | cut -d" " -f2- | sed "s/^\"//; s/\"$//; s/\\\\\"/\"/g")" ]'
newrepo pi66; mkdir -p docs/adr
printf -- '- **Discount**: money off an order total, in paise. Avoid: coupon\n' > docs/glossary.md
printf '# Money is whole paise\n' > docs/adr/0001-money.md; git add docs && git commit -qm docs
export ORCH_CONFIG_FILE="$WORK/config66/config.json" PI_CODING_AGENT_DIR="$WORK/pi-agent66"; mkdir -p "$WORK/config66"
printf '{"mode": "subagent"}\n' > "$ORCH_CONFIG_FILE"
export AI_AGENT=pi
printf '# Plan: t\nBranch: feature/pi66\nCheck command: true\nSetup command: none\nIsolation: shared\nLead: lead (pi)\nLead mode: off\nWorkers: coder (pi)\nReviewer: reviewer (pi)\n\n## [x] M1: Discount column\nDepends on: none\nDoor: one-way (adds a column to orders)\nReview: yes\nLikely files: one.txt\nGoal: orders get a discount\nOpen questions:\n- none\n' > .orchestrate/plan.md
"$ORCH" sync >/dev/null 2>&1
out=$("$ORCH" lead plan 2>&1)
check "subagent: orch lead plan has the subagent note and the ask-first step" 'grep -q "^SUBAGENT MODE" <<<"$out" && grep -q "^## 2a. Ask before you plan" <<<"$out"'
mkdir -p "$PI_CODING_AGENT_DIR/agents"
printf -- '---\nname: reviewer\n---\n\n%s\n\nold reviewer text\n' "<!-- written by \`orch setup\` (herdr-orchestra). orch rewrites this file; delete this line to keep your own edits. -->" > "$PI_CODING_AGENT_DIR/agents/reviewer.md"
printf -- '---\nname: coder\n---\nmy own coder\n' > "$PI_CODING_AGENT_DIR/agents/coder.md"
out=$("$ORCH" lead run 2>&1)
check "an orch-written reviewer subagent from an older orch is refreshed with the two questions" 'grep -q "^UPDATED .*reviewer.md: the reviewer subagent now has this orch.s instructions" <<<"$out" && grep -q "BLOCKER: \[rules: <the rule>\]" "$PI_CODING_AGENT_DIR/agents/reviewer.md" && ! grep -q "old reviewer text" "$PI_CODING_AGENT_DIR/agents/reviewer.md"'
check "…a subagent file the developer wrote is left alone" 'grep -qx "my own coder" "$PI_CODING_AGENT_DIR/agents/coder.md" && ! grep -q "coder.md" <<<"$out"'
out=$("$ORCH" lead run 2>&1)
check "…and nothing is rewritten when it is current" '! grep -q "^UPDATED" <<<"$out"'
"$ORCH" start >/dev/null 2>&1; out=$("$ORCH" sub next 2>&1); T=$(sed -n "s/^TASK //p" <<<"$out")
check "subagent: the task file has the project rules and asks for proof on a hard-to-undo milestone" '[ -f "$T" ] && grep -q "^## Project rules" "$T" && grep -q "^- \*\*Discount\*\*" "$T" && grep -q "^- docs/adr/0001-money.md: Money is whole paise" "$T" && grep -q "^## Hard to undo: show proof" "$T"'
echo 1 > one.txt; "$ORCH" check M1 >/dev/null 2>&1; out=$("$ORCH" sub "done" M1 2>&1); code=$?
check "subagent: a hard-to-undo milestone is held, and the proof is the coder's PROOF line" '[ $code -eq 7 ] && grep -q "^HELD M1 for approval — hard to undo: adds a column to orders" <<<"$out" && grep -q "^Proof from the coder: the coder.s PROOF: line, in the lead.s chat" <<<"$out"'
unset ORCH_CONFIG_FILE PI_CODING_AGENT_DIR AI_AGENT

echo "54. an all-Codex team: sandbox doors, thinking levels, models found by asking Codex"
CX="$WORK/cxbin"; mkdir -p "$CX"
cat > "$CX/codex" <<'FAKE'
#!/bin/sh
case "$*" in
  "debug models")
    [ -f "$CODEX_FAKE_FAIL" ] && { echo "boom" >&2; exit 1; }
    echo "WARNING: some noise first" >&2
    cat <<'JSON'
{"models": [
 {"slug": "gpt-6.3-sol", "description": "Fast, go-to model for coding and everyday work.", "visibility": "list", "upgrade": null, "priority": 1},
 {"slug": "gpt-7-astra", "description": "Our most capable model.", "visibility": "list", "upgrade": null, "priority": 2},
 {"slug": "gpt-6.2-sol", "description": "Previous generation model for coding.", "visibility": "list", "upgrade": null, "priority": 3},
 {"slug": "gpt-6-luna", "description": "Fast and affordable model for easier tasks.", "visibility": "list", "upgrade": null, "priority": 7},
 {"slug": "gpt-5.6-luna", "description": "Legacy fast model.", "visibility": "list", "upgrade": {"model": "gpt-6-luna"}, "priority": 10},
 {"slug": "gpt-x-luna", "description": "Secret.", "visibility": "hide", "upgrade": null, "priority": 0}
]}
JSON
    ;;
  --help|-h) echo "Usage: codex [OPTIONS]"; echo "  -c, --config <key=value>"; echo "  -m, --model <MODEL>"; echo "      --approve-for-me";;
  --version) echo "codex-cli 0.172.0";;
esac
FAKE
chmod +x "$CX/codex"
export CODEX_FAKE_FAIL="$WORK/cx-fail"
DSH="$WORK/share-dx"
out=$(ORCH_MODELS_DISCOVER=1 ORCH_SHARE="$DSH" PATH="$CX:$PATH" "$ORCH" models 2>&1)
check "orch models asks codex: the newest Sol fills medium (low thinking) and high (medium thinking), Luna small (high thinking)" 'grep -qE "^gpt-6.3-sol@medium +high +codex" <<<"$out" && grep -qE "^gpt-6.3-sol@low +medium +codex" <<<"$out" && grep -qE "^gpt-6-luna@high +small +codex" <<<"$out"'
check "…the shipped Codex entries make way, hidden, legacy and Astra models are not used" '! grep -qE "^(gpt-6.2-sol|gpt-x-luna|gpt-5.6|gpt-7-astra)" <<<"$out" && grep -q "codex models found by \`codex debug models\`: gpt-6-luna, gpt-6.3-sol (not used, the tool calls them legacy: gpt-5.6-luna, gpt-6.2-sol)" <<<"$out"'
check "…the answer is cached in the share folder" 'grep -q "gpt-6.3-sol" "$DSH/models-codex.json"'
touch "$CODEX_FAKE_FAIL"
out=$(ORCH_MODELS_DISCOVER=1 ORCH_SHARE="$DSH" PATH="$CX:$PATH" "$ORCH" models 2>&1)
check "a fresh cached answer is used without asking again" 'grep -qE "^gpt-6.3-sol@medium +high" <<<"$out"'
out=$(ORCH_MODELS_DISCOVER=1 ORCH_MODELS_TTL_S=0 ORCH_SHARE="$DSH" PATH="$CX:$PATH" "$ORCH" models 2>&1)
check "when codex fails, the older cached answer still counts" 'grep -qE "^gpt-6.3-sol@medium +high" <<<"$out"'
out=$(ORCH_MODELS_DISCOVER=1 ORCH_SHARE="$WORK/share-dx2" PATH="$CX:$PATH" "$ORCH" models 2>&1)
check "when codex fails and nothing is cached, the shipped Codex entries are used" 'grep -qE "^gpt-6.2-sol@medium +high" <<<"$out" && grep -qE "^gpt-6.2-sol@low +medium" <<<"$out" && grep -qE "^gpt-6-luna@high +small" <<<"$out" && ! grep -q "found by" <<<"$out"'
rm -f "$CODEX_FAKE_FAIL"
out=$(ORCH_MODELS_DISCOVER=0 ORCH_SHARE="$WORK/share-dx3" PATH="$CX:$PATH" "$ORCH" models 2>&1)
check "ORCH_MODELS_DISCOVER=0 keeps the shipped list" 'grep -qE "^gpt-6.2-sol@medium +high" <<<"$out" && [ ! -f "$WORK/share-dx3/models-codex.json" ]'
printf '[discover.codex]\nsmall = { family = "sol", effort = "low" }\n' > "$ORCH_MODELS_FILE"
out=$(ORCH_MODELS_DISCOVER=1 ORCH_SHARE="$DSH" PATH="$CX:$PATH" "$ORCH" models 2>&1)
check "your models.toml can change which family and thinking level fills a tier" 'grep -qE "^gpt-6.3-sol@low +(small|medium)" <<<"$out" && ! grep -q "^gpt-6-luna" <<<"$out"'
rm -f "$ORCH_MODELS_FILE"
out=$(ORCH_MODELS_DISCOVER=1 ORCH_SHARE="$DSH" PATH="$CX:$PATH" "$ORCH" team codex 2>&1)
check "orch team codex uses the models codex reported" 'grep -q "^Workers: codex-1 (codex: gpt-6-luna@high), codex-2 (codex: gpt-6.3-sol@medium)$" <<<"$out" && grep -q "^Reviewer: reviewer (codex: gpt-6.3-sol@medium)$" <<<"$out"'
newrepo cx
out=$("$ORCH" agents launch codex --model gpt-6.2-sol@low)
check "a Codex pane starts with herdr's socket and this repo's .git opened, on Sol with low thinking" '[ "$out" = "codex --approve-for-me -c sandbox_workspace_write.network_access=true -c '"'"'sandbox_workspace_write.writable_roots=[\"$APP/.git\"]'"'"' --model gpt-6.2-sol -c model_reasoning_effort=low" ]'
out=$(cd "$WORK" && "$ORCH" agents launch codex)
check "outside a repo the .git setting is left out and the command still starts" '[ "$out" = "codex --approve-for-me -c sandbox_workspace_write.network_access=true" ]'
check "a kind with no thinking option keeps the whole id as its model (no change for others)" '[ "$("$ORCH" agents launch claude --model sonnet@x)" = "claude --permission-mode acceptEdits --model sonnet@x" ]'
check "a denied model is refused with a thinking level too" '! "$ORCH" agents launch codex --model gpt-6.2-astra@low >/dev/null 2>&1'
printf '# Plan: t\nBranch: feature/cx\nCheck command: true\nIsolation: worktree\nMax parallel: 2\nLead: lead (codex: gpt-6.2-sol@medium)\nWorkers: codex-1 (codex: gpt-6-luna@high @pane:w1:p7), codex-2 (codex: gpt-6.2-sol@medium)\nReviewer: reviewer (codex: gpt-6.2-sol@medium)\n\n## [x] M1: a\nDepends on: none\nTier: high\nModel why: a contract.\nOpen questions:\n- none\n' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "an all-Codex plan with thinking levels syncs clean: every model rated, high tier reachable" '[ $code -eq 0 ] && ! grep -qiE "WARN.*(high-tier|not in the model catalog|policy)" <<<"$out"'
check "…the model keeps its level and the pane id is still read after it" 'python3 -c "import json,sys;s=json.load(open(\".orchestrate/state.json\"));w=s[\"workers\"];sys.exit(not (w[\"codex-1\"][\"model\"]==\"gpt-6-luna@high\" and \"w1:p7\" in str(w[\"codex-1\"].get(\"pane\")) and w[\"codex-2\"][\"tier\"]==\"high\" and s[\"reviewer_info\"][\"model\"]==\"gpt-6.2-sol@medium\"))"'
check "the high milestone goes to the Sol coder, not the Luna one" '[ "$("$ORCH" pick M1)" = codex-2 ]'
out=$(CODEX_SANDBOX_NETWORK_DISABLED=1 "$ORCH" lead check 2>&1)
check "a lead in Codex's sandbox with the network off is warned, with the command to restart it" 'grep -q "^WARN this pane runs in Codex.s sandbox with the network off" <<<"$out" && grep -q "^    codex --approve-for-me -c sandbox_workspace_write.network_access=true" <<<"$out"'
out=$(CODEX_SANDBOX_NETWORK_DISABLED=1 "$ORCH" lead plan 2>&1 | head -5)
check "…orch lead plan says it at the top too" 'grep -q "^WARN this pane runs in Codex.s sandbox" <<<"$out"'
check "a normal pane gets no sandbox warning" '! "$ORCH" lead check 2>&1 | qgrep -q "Codex.s sandbox"'
out=$(PATH="$CX:$PATH" "$ORCH" doctor codex 2>&1)
check "doctor: the shipped Codex launch keeps both settings and its flags are in --help" '! grep -q "BAD launch" <<<"$out" && [ "$(grep -c "launch flag -c is listed" <<<"$out")" -eq 1 ] && grep -q "launch flag -c is listed" <<<"$out"'
printf '[codex]\nlaunch = "codex --approve-for-me"\n' > "$WORK/cx-agents.toml"
out=$(ORCH_AGENTS_FILE="$WORK/cx-agents.toml" PATH="$CX:$PATH" "$ORCH" doctor codex 2>&1); code=$?
check "doctor: your own Codex launch without the two settings is BROKEN, and says why" '[ $code -ne 0 ] && grep -q "BAD launch has no \`sandbox_workspace_write.network_access=true\`" <<<"$out" && grep -q "BAD launch has no \`sandbox_workspace_write.writable_roots\`" <<<"$out"'
unset CODEX_FAKE_FAIL

echo "orch-explain skill"
check "orch-explain: frontmatter parses as strict YAML (Pi loads it as is) with its name and description" 'python3 -c "
import sys,yaml
f=yaml.safe_load(open(sys.argv[1]).read().split(\"---\")[1])
assert f[\"name\"]==\"orch-explain\" and f[\"description\"].startswith(\"Explain any concept\")
" "$ROOT/skills/orch-explain/SKILL.md"'
check "orch-explain: the 4-part playbook and the 65-char flowchart rule" 'f="$ROOT/skills/orch-explain/SKILL.md"; for h in "Plain-English Summary" "Key Parts Involved" "Visual Flow" "Why It Matters" "under 65 chars wide" "one consistent example"; do grep -qF "$h" "$f" || exit 1; done'
check "orch-explain: the OpenCode and Claude commands carry the same playbook as the skill" 'body=$(sed "1,/^---$/d" "$ROOT/skills/orch-explain/SKILL.md" | sed "1{/^\$/d}"); for c in claude-commands opencode-commands; do [ "$(sed "1,/^---$/d" "$ROOT/$c/orch-explain.md" | sed "/^What to explain: /,\$d" | sed "\${/^\$/d}")" = "$body" ] && grep -q "^What to explain: \$ARGUMENTS" "$ROOT/$c/orch-explain.md" || exit 1; done'
check "orch-explain: the Pi package lists it and npm packs it" 'grep -q "\"./skills/orch-explain\"" "$ROOT/package.json" && python3 -c "import json;import sys;sys.exit(\"./skills/orch-explain\" not in json.load(open(sys.argv[1]))[\"pi\"][\"skills\"])" "$ROOT/package.json"'
check "orch-explain: uninstall and the old-Python fallback name it" '[ "$(grep -c orch-explain "$ROOT/install.sh")" -ge 4 ]'
XH="$WORK/explain-home"; mkdir -p "$XH"
HOME="$XH" PATH="$FAKEBIN:/usr/local/bin:/usr/bin:/bin" bash "$ROOT/install.sh" --no-herdr-skill >/dev/null 2>&1
check "orch-explain: a fresh install puts it in ~/.agents/skills and the OpenCode command folder" '[ -f "$XH/.agents/skills/orch-explain/SKILL.md" ] && [ -f "$XH/.config/opencode/commands/orch-explain.md" ] && grep -q "orch-explain" "$XH/.local/share/herdr-orchestra/manifest.txt"'
check "orch-explain: agents check sees it once per agent" 'HOME="$XH" PATH="$FAKEBIN:/usr/local/bin:/usr/bin:/bin" "$XH/.local/bin/orch" agents check >/dev/null 2>&1'
HOME="$XH" PATH="$FAKEBIN:/usr/local/bin:/usr/bin:/bin" bash "$ROOT/install.sh" --uninstall >/dev/null 2>&1
check "orch-explain: --uninstall removes every copy" '[ -z "$(find "$XH" -name "orch-explain*" -print -quit)" ]'

echo "55. no agent pushes to main: the pre-push guard, plans on main refused, doctor and status report it"
newrepo grd
git init -q --bare "$WORK/grd-remote.git"; git remote add origin "$WORK/grd-remote.git"; git push -q origin main 2>/dev/null
printf '# Plan: t\nBranch: main\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M1: e\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "a plan on main is refused by sync, with the rule" '[ $code -ne 0 ] && grep -q "Branch main is a protected branch" <<<"$out" && grep -q "No agent ever pushes to main" <<<"$out"'
sed -i 's/^Branch: main$/Branch: master/' .orchestrate/plan.md
check "…and so is master" '! "$ORCH" sync >/dev/null 2>&1'
sed -i 's/^Branch: master$/Branch: feature\/grd/' .orchestrate/plan.md
check "no guard before orch runs in the repo" '[ ! -e .git/hooks/pre-push ]'
timeout 120 "$ORCH" autopilot > "$WORK/grd.log" 2>&1; code=$?
check "a run installs the guard by itself (orch start)" '[ $code -eq 0 ] && [ "$(status_of M1)" = merged ] && [ -x .git/hooks/pre-push ] && grep -q "herdr-orchestra main guard v1" .git/hooks/pre-push'
out=$("$ORCH" finish 2>&1); code=$?
check "orch finish still pushes the run's branch with the guard on" '[ $code -eq 0 ] && git --git-dir="$WORK/grd-remote.git" rev-parse -q --verify feature/grd >/dev/null'
before=$(git --git-dir="$WORK/grd-remote.git" rev-parse main)
out=$(git push origin feature/grd:main 2>&1); code=$?
check "git push <branch>:main is refused, with the reason" '[ $code -ne 0 ] && grep -q "orch guard: REFUSED push to main" <<<"$out" && grep -q "no agent pushes to main, even when asked" <<<"$out"'
out=$(git push origin HEAD:main 2>&1); code=$?
check "git push origin HEAD:main is refused" '[ $code -ne 0 ] && grep -q "REFUSED push to main" <<<"$out"'
out=$(git push --force origin HEAD:refs/heads/main 2>&1); code=$?
check "a force push to refs/heads/main is refused" '[ $code -ne 0 ] && grep -q "REFUSED push to main" <<<"$out"'
git switch -q main; git merge -q --ff-only feature/grd
out=$(git push origin main 2>&1); code=$?
check "a plain git push origin main from main is refused" '[ $code -ne 0 ] && grep -q "REFUSED" <<<"$out"'
out=$(git push --all origin 2>&1); code=$?
check "git push --all is refused while it includes main" '[ $code -ne 0 ] && grep -q "REFUSED push to main" <<<"$out"'
out=$(git push origin HEAD:master 2>&1); code=$?
check "master is protected too" '[ $code -ne 0 ] && grep -q "REFUSED push to master" <<<"$out"'
out=$(git push origin :main 2>&1); code=$?
check "deleting main on the remote is refused" '[ $code -ne 0 ] && grep -q "REFUSED push to main" <<<"$out"'
check "…and the remote's main never moved" '[ "$(git --git-dir="$WORK/grd-remote.git" rev-parse main)" = "$before" ]'
git worktree add -q --detach "$WORK/grd-wt" HEAD
out=$(cd "$WORK/grd-wt" && git push origin HEAD:main 2>&1); code=$?
check "a coder's worktree shares the guard" '[ $code -ne 0 ] && grep -q "REFUSED push to main" <<<"$out"'
git switch -q -c fix/ok
check "pushing any other branch still works" 'git push -q origin fix/ok 2>/dev/null && git --git-dir="$WORK/grd-remote.git" rev-parse -q --verify fix/ok >/dev/null'
git push -q --no-verify origin HEAD:trunk; git fetch -q origin; git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk
echo more > grd.txt; git add grd.txt; git commit -qm more     # something new, so git runs the hook
out=$(git push origin HEAD:trunk 2>&1); code=$?
check "the remote's default branch is protected even when it is not called main" '[ $code -ne 0 ] && grep -q "REFUSED push to trunk" <<<"$out"'
git config --add orch.protected release
out=$(git push origin HEAD:release 2>&1); code=$?
check "git config orch.protected adds a branch to the list" '[ $code -ne 0 ] && grep -q "REFUSED push to release" <<<"$out"'
out=$("$ORCH" guard status 2>&1); code=$?
check "orch guard status: on, names every protected branch, exit 0" '[ $code -eq 0 ] && grep -q "No agent ever pushes to main" <<<"$out" && grep -q "ok  pre-push guard is on" <<<"$out" && grep -q "main, master, release, trunk" <<<"$out"'
out=$("$ORCH" guard 2>&1)
check "orch guard again changes nothing" 'grep -q "^GUARD on:" <<<"$out" && [ ! -e .git/hooks/pre-push.orch-orig ]'
printf '#!/bin/sh\ncat > "%s"\nexit 0\n' "$WORK/grd-own-hook.txt" > .git/hooks/pre-push; chmod +x .git/hooks/pre-push
out=$("$ORCH" guard status 2>&1); code=$?
check "status: someone else's pre-push hook means the guard is missing (exit 1)" '[ $code -ne 0 ] && grep -q "BAD pre-push guard is missing" <<<"$out" && grep -q "another pre-push hook is there" <<<"$out"'
out=$("$ORCH" doctor 2>&1); code=$?
check "plain orch doctor reports the missing guard and fails" '[ $code -ne 0 ] && grep -q "^BROKEN  main guard" <<<"$out" && grep -q "BAD pre-push guard is missing" <<<"$out"'
out=$("$ORCH" guard 2>&1)
check "orch guard keeps your own hook and runs it after its check" 'grep -q "your own pre-push hook still runs after it" <<<"$out" && [ -x .git/hooks/pre-push.orch-orig ] && git push -q origin HEAD:fix/ok2 2>/dev/null && grep -q "refs/heads/fix/ok2" "$WORK/grd-own-hook.txt"'
check "…while a push to main is still refused" '! git push origin HEAD:main >/dev/null 2>&1'
out=$("$ORCH" doctor 2>&1)
check "plain orch doctor: guard ok" 'grep -q "^ok      main guard" <<<"$out"'
sed -i 's/main guard v1/main guard v0/' .git/hooks/pre-push
check "a guard from an older orch is updated by orch guard" '"$ORCH" guard status >/dev/null 2>&1; [ $? -ne 0 ] && "$ORCH" guard 2>&1 | qgrep -q "^GUARD updated" && grep -q "main guard v1" .git/hooks/pre-push'
check "orch guard --print gives the hook script" '"$ORCH" guard --print | head -1 | qgrep -q "^#!/bin/sh" && "$ORCH" guard --print | qgrep -q "herdr-orchestra main guard v1"'
check "orch guard --help names the command" '"$ORCH" guard --help 2>&1 | qgrep -q "guard \[status|--print\]"'
mkdir -p .husky; git config core.hooksPath .husky
out=$("$ORCH" guard 2>&1); code=$?
check "hooks kept inside the project (husky): orch writes nothing there and says what to do" '[ $code -ne 0 ] && grep -q "WARN GUARD not installed" <<<"$out" && grep -q "orch guard --print" <<<"$out" && [ ! -e .husky/pre-push ]'
git config --unset core.hooksPath
check "orch guard outside a git repo says so" '! (cd "$WORK" && "$ORCH" guard >/dev/null 2>&1)'
check "orch lead plan outside a git repo still prints the playbook (no guard to install)" '(cd "$WORK" && "$ORCH" lead plan >/dev/null 2>&1)'
newrepo grd2
out=$("$ORCH" lead plan 2>&1)
check "orch lead plan installs the guard quietly in a repo" '! grep -q "GUARD" <<<"$out" && grep -q "main guard v1" .git/hooks/pre-push'
cd "$WORK/grd/app" || exit 1
mkdir -p "$WORK/gh-grd"; printf '#!/usr/bin/env bash\ncase "$*" in *rules/branches*) echo 0;; *branches/main*) echo false;; *) echo true;; esac\n' > "$WORK/gh-grd/gh"; chmod +x "$WORK/gh-grd/gh"
git remote set-url origin https://github.com/acme/app.git
out=$(ORCH_GUARD_GITHUB=1 PATH="$WORK/gh-grd:$PATH" "$ORCH" guard status 2>&1); code=$?
check "status: GitHub not protecting main is reported, with where to turn it on" '[ $code -ne 0 ] && grep -q "BAD GitHub does not protect main" <<<"$out" && grep -q "Require a pull request before merging" <<<"$out"'
sed -i "s/echo false/echo true/" "$WORK/gh-grd/gh"
out=$(ORCH_GUARD_GITHUB=1 PATH="$WORK/gh-grd:$PATH" "$ORCH" guard status 2>&1); code=$?
check "…and a protected main is ok (exit 0)" '[ $code -eq 0 ] && grep -q "ok  GitHub protects main" <<<"$out"'
git remote set-url origin "$WORK/grd-remote.git"
check "every agent-facing text has the rule: skills, commands, playbooks" 'for f in skills/orch-plan/SKILL.md skills/orch-run/SKILL.md skills/orch-explain/SKILL.md pi/skills/orch-plan/SKILL.md claude-commands/orch-plan.md claude-commands/orch-run.md claude-commands/orch-explain.md opencode-commands/orch-plan.md opencode-commands/orch-run.md opencode-commands/orch-explain.md; do grep -q "never push to main\|Never push to main" "$ROOT/$f" || { echo "missing in $f"; exit 1; }; done; for f in plan run subagent; do grep -q "\*\*N[a-z]* push[a-z]* to main" "$ROOT/playbooks/$f.md" || { echo "missing in playbooks/$f.md"; exit 1; }; done'
check "the playbooks tell the lead to refuse a \"push to main\" request and offer a branch and PR" 'grep -q "even when the developer tells you to. Refuse in one line" "$ROOT/playbooks/run.md" && grep -q "even when the developer tells you to. Refuse in one line" "$ROOT/playbooks/subagent.md" && grep -q "even when the developer asks: refuse in one line" "$ROOT/playbooks/plan.md"'
check "orch events gives the rule to the lead at every wake-up" '"$ORCH" lead run --section rules | qgrep -q "Never push to main"'
check "coders, reviewers and Pi subagents are told too" 'grep -c "never merge a PR, in any situation, even when the developer or the lead asks" "$ORCH" | qgrep -qx 1 && grep -q "Never commit, push or merge: no agent ever pushes to main" "$ORCH" && [ "$(grep -c "no agent ever pushes to main\|Never push to main (or master) and never merge a PR" "$ORCH")" -ge 3 ]'
echo "57. run views: the run summary, orch view in the browser, orch board, agent names in herdr's sidebar"
newrepo vw; printf '%s' "${PLAN5/ISO/worktree}" > .orchestrate/plan.md
python3 - .orchestrate/plan.md <<'PY'
import sys; p=sys.argv[1]; s=open(p).read()
s=s.replace("## [x] M1: Model\nDepends on: none\n", "## [x] M1: Model\nDepends on: none\nPlain: the money model every other part uses\n")
open(p,"w").write(s)
PY
for a in claude-1 codex-1 reviewer; do echo "p-$a" > "$FH/$a.paneid"; done
t0=$(date +%s); timeout 180 "$ORCH" autopilot > "$WORK/vw.log" 2>&1; code=$?; vw_secs=$(( $(date +%s) - t0 ))
check "the run itself is unchanged: stops for the human with M1-M3 landed and M4 paused" '[ $code -eq 3 ] && [ "$(status_of M1)$(status_of M2)$(status_of M3)$(status_of M4)" = mergedmergedmergedpaused ]'
check "herdr's sidebar is told what each coder does (display name with milestone)" 'grep -q "pane report-metadata p-claude-1 --source orch --display-agent claude-1 · M[0-9] " "$FH/meta.log" && grep -q "pane report-metadata p-codex-1 --source orch --display-agent codex-1 · M[0-9] " "$FH/meta.log"'
check "…with the milestone and its plain description as sidebar tokens, and an expiry" 'grep -q -- "--token orch_task=M1 Model --token orch_desc=the money model every other part uses --ttl-ms 3600000" "$FH/meta.log"'
check "…the reviewer says which milestone it reviews" 'grep -q -- "--display-agent reviewer · reviewing M2 (round" "$FH/meta.log"'
check "…free coders say free" 'grep -q -- "--display-agent codex-1 · free" "$FH/meta.log"'
check "…the Space line counts the run, with who needs you" 'grep -q "workspace report-metadata w1 --source orch --token orch=orch: 3/4 landed · 1 needs you" "$FH/meta.log"'
check "only changes are sent: never the same name twice in a row for one agent" 'python3 - "$FH/meta.log" <<PY
import sys
last = {}
for l in open(sys.argv[1]):
    k = l.split()[2]
    if last.get(k) == l: sys.exit(1)
    last[k] = l
PY'
out=$("$ORCH" status --json); code=$?
check "orch status --json: the stable run summary (view 1) with counts" '[ $code -eq 0 ] && python3 -c "import json,sys;d=json.loads(sys.argv[1]);c=d[\"counts\"];sys.exit(not (d[\"view\"]==1 and c==dict(total=4,landed=3,needs_you=1,active=0,waiting=0)))" "$out"'
check "…each milestone has its plain description, or its title when the plan has none" 'python3 -c "import json,sys;m={x[\"id\"]:x for x in json.loads(sys.argv[1])[\"milestones\"]};sys.exit(not (m[\"M1\"][\"desc\"]==\"the money model every other part uses\" and m[\"M2\"][\"desc\"]==\"Endpoint\" and m[\"M4\"][\"group\"]==\"needs_you\" and m[\"M3\"][\"deps\"]==[\"M1\",\"M2\"]))" "$out"'
check "…the agents and the recent status changes are in it" 'python3 -c "import json,sys;d=json.loads(sys.argv[1]);sys.exit(not ({a[\"name\"] for a in d[\"agents\"]}=={\"claude-1\",\"codex-1\",\"reviewer\"} and d[\"recent\"] and d[\"recent\"][0][\"ts\"]>=d[\"recent\"][-1][\"ts\"]))" "$out"'
out=$("$ORCH" board --once --no-color)
check "orch board draws the milestones with their descriptions and who needs you" 'grep -q "M4 Totals .*NEEDS YOU" <<<"$out" && grep -q "the money model every other part uses" <<<"$out" && grep -q "3 of 4 landed · 1 needs you" <<<"$out" && grep -q "^AGENTS" <<<"$out"'
check "orch status says the live view is off and how to start it" '"$ORCH" status | qgrep -q "^live view: off — \`orch view\`"'
out=$(ORCH_VIEW_PORT=47900 "$ORCH" view --bg 2>&1); code=$?
VU=$(python3 -c "import json;print(json.load(open('.orchestrate/view.json'))['url'])" 2>/dev/null)
check "orch view --bg starts the page on this computer only and prints its link" '[ $code -eq 0 ] && grep -q "^orch view: http://127.0.0.1:479" <<<"$out" && [ -n "$VU" ]'
check "…the page, the summary and the history are served" 'curl -sf "$VU" | qgrep -q "<title>orch view</title>" && curl -sf "${VU}api/state" | python3 -c "import json,sys;sys.exit(json.load(sys.stdin)[\"counts\"][\"landed\"]!=3)" && curl -sf "${VU}api/history" | python3 -c "import json,sys;sys.exit(len(json.load(sys.stdin)[\"events\"])<4)"'
sse=$(timeout 3 curl -sN "${VU}api/stream" 2>/dev/null)
check "…the live stream sends the run at once" 'grep -q "^event: state" <<<"$sse" && grep -q "^data: {\"view\": 1" <<<"$sse"'
check "…orch status and orch view status show its link" '"$ORCH" status | qgrep -q "^live view: http://127.0.0.1:" && "$ORCH" view status | qgrep -q "orch view is running: http://127.0.0.1:"'
check "…a second orch view does not start another server" '"$ORCH" view --bg | qgrep -q "already running"'
check "…another site can't reach it through a name it controls (only 127.0.0.1 or localhost)" '[ "$(curl -s -o /dev/null -w "%{http_code}" -H "Host: evil.example:80" "${VU}api/state")" = 403 ] && curl -sf -H "Host: localhost" "${VU}api/state" >/dev/null'
check "…it never changes the run: state.json is the same after a page load" 'a=$(md5sum < .orchestrate/state.json); curl -sf "${VU}api/state" >/dev/null; [ "$(md5sum < .orchestrate/state.json)" = "$a" ]'
python3 - <<'PY'
import json; p=".orchestrate/state.json"; s=json.load(open(p))
s["lead"]={"name":"lead","kind":"claude"}; s["lead_mode"]="events"
s["lead_events"]=[{"id":1,"ts":1,"kind":"paused","task":"M4","text":"which currency?","read":None}]
json.dump(s,open(p,"w"))
PY
out=$("$ORCH" events --peek 2>&1)
check "the lead's \"needs you\" event carries the page link to that milestone" 'grep -q "SEE: http://127.0.0.1:[0-9]*/#M4" <<<"$out"'
"$ORCH" view stop >/dev/null
check "orch view stop stops it, and status says so" '"$ORCH" view status | qgrep -q "not running" && ! curl -sf "$VU" >/dev/null'
check "…and the lead's line has no link when the page is off" '! "$ORCH" events --peek 2>&1 | qgrep -q "SEE:"'
python3 - <<'PY'
import json; p=".orchestrate/state.json"; s=json.load(open(p)); s.pop("lead"); s["lead_mode"]="off"; s["lead_events"]=[]; json.dump(s,open(p,"w"))
PY
out=$(ORCH_VIEW_PORT=47930 "$ORCH" view --bg --lan 2>&1)
LU=$(python3 -c "import json;print(json.load(open('.orchestrate/view.json'))['url'])")
check "orch view --lan: a phone link with a secret token, and the page refuses without it" 'grep -q "from your phone: http://.*?t=" <<<"$out" && [ "$(curl -s -o /dev/null -w "%{http_code}" "${LU%%\?*}api/state")" = 403 ] && curl -sf "${LU%%\?*}api/state?t=${LU##*t=}" >/dev/null'
"$ORCH" view stop >/dev/null
out=$("$ORCH" view herdr-config)
check "orch view herdr-config prints the sidebar rows and the popup key" 'grep -q "^\[ui.sidebar.agents\]" <<<"$out" && grep -q "orch_desc" <<<"$out" && grep -q "herdr-orchestra.board.open" <<<"$out"'
linkout=$("$ORCH" view plugin link 2>&1)
check "orch view plugin link prints the key lines to paste into herdr's config" 'grep -q "herdr-orchestra.board.open" <<<"$linkout" && grep -q "prefix+a" <<<"$linkout" && grep -q "plugin_action" <<<"$linkout"'
# herdr 0.9.x default prefix keys (src/main.rs sample config); the board key must not be one of them
check "…and its key is not one of herdr's default keys (prefix+o is herdr's notification key)" '! grep -qE "key = \"prefix\+(\?|s|q|shift\+r|o|w|g|shift\+n|shift\+g|shift\+w|shift\+d|c|shift\+t|p|n|[1-9]|shift\+x|shift\+p|e|h|j|k|l|tab|shift\+tab|v|minus|x|z|r|b|\[)\"" <<<"$linkout"'
check "orch view plugin link links the shipped herdr plugin" 'grep -q "^plugin link .*/view/herdr-plugin$" "$FH/team.log"'
check "…the plugin manifest is valid TOML with the board popup and its action" 'python3 -c "
import tomllib,sys
m=tomllib.load(open(\"$ROOT/view/herdr-plugin/herdr-plugin.toml\",\"rb\"))
sys.exit(not (m[\"id\"]==\"herdr-orchestra.board\" and m[\"min_herdr_version\"]==\"0.7.4\" and m[\"panes\"][0][\"placement\"]==\"popup\" and m[\"actions\"][0][\"id\"]==\"open\"))"'
"$ORCH" view plugin unlink >/dev/null 2>&1
check "…and unlinks it" 'grep -q "^plugin unlink herdr-orchestra.board$" "$FH/team.log"'
# the popup must start in the repo of the pane you were in (herdr starts it in the plugin's own folder otherwise)
OPEN="$ROOT/view/herdr-plugin/open.sh"; mkdir -p "$APP/sub" "$WORK/elsewhere"
popen(){ : > "$FH/team.log"; HERDR_BIN_PATH="$HERDR" HERDR_PLUGIN_CONTEXT_JSON="$1" sh "$OPEN" >/dev/null 2>&1; grep "^plugin pane open" "$FH/team.log"; }
check "board key: the popup opens in the focused pane's folder (herdr's own context field names)" '[[ "$(popen "{\"focused_pane_cwd\":\"$APP\",\"workspace_cwd\":\"$WORK/elsewhere\"}")" == *"--placement popup --cwd $APP" ]]'
check "…a pane in a folder inside the repo keeps that folder" '[[ "$(popen "{\"focused_pane_cwd\":\"$APP/sub\"}")" == *"--cwd $APP/sub" ]]'
check "…a pane outside any repo falls back to the space's folder" '[[ "$(popen "{\"focused_pane_cwd\":\"$WORK/elsewhere\",\"workspace_cwd\":\"$APP\"}")" == *"--cwd $APP" ]]'
check "…a pane outside any repo and a space with a worktree: the worktree's folder" '[[ "$(popen "{\"focused_pane_cwd\":\"$WORK/elsewhere\",\"worktree\":{\"path\":\"$APP\"}}")" == *"--cwd $APP" ]]'
git -C "$APP" worktree add -q --detach "$WORK/wt-board" 2>/dev/null
check "…a coder's worktree pane finds the run in the main repo and keeps the worktree folder" '[[ "$(popen "{\"focused_pane_cwd\":\"$WORK/wt-board\",\"workspace_cwd\":\"$WORK/elsewhere\"}")" == *"--cwd $WORK/wt-board" ]]'
git -C "$APP" worktree remove --force "$WORK/wt-board" 2>/dev/null
check "…the repo with the run is chosen over another repo (the pane's folder is not the run's repo)" '[[ "$(popen "{\"focused_pane_cwd\":\"$ROOT\",\"workspace_cwd\":\"$APP\"}")" == *"--cwd $APP" ]]'
check "…no folder in the context: it still opens, without --cwd" 'o=$(popen "{}"); [[ "$o" == *"--placement popup" && "$o" != *"--cwd"* ]]'
check "the popup program names the folder it is in when that is not a repo" 'o=$(cd "$WORK/elsewhere" && PATH="$ROOT/bin:$PATH" sh "$ROOT/view/herdr-plugin/board.sh" 2>&1 | head -1); [[ "$o" == "This folder ($WORK/elsewhere) is not a git repo"* ]]'
python3 - <<'PY'
import json; p=".orchestrate/state.json"; s=json.load(open(p)); s["orch_mode"]="subagent"; json.dump(s,open(p,"w"))
PY
check "subagent mode: the summary says there is no event manager, and the board still draws the run" '"$ORCH" status --json | python3 -c "import json,sys;m=json.load(sys.stdin)[\"manager\"];sys.exit(m[\"applies\"] is not False)" && "$ORCH" board --once --no-color | qgrep -q "M4 Totals"'
python3 - <<'PY'
import json; p=".orchestrate/state.json"; s=json.load(open(p)); s["orch_mode"]="panes"; json.dump(s,open(p,"w"))
PY
out=$("$ORCH" doctor 2>&1)
check "orch doctor says which views this herdr supports" 'grep -q "^views   ok  herdr 0.9.5: sidebar names, sidebar rows" <<<"$out"'
echo 0.6.5 > "$FH/version"
out=$("$ORCH" doctor 2>&1)
check "…an older herdr gets names only, and the rest is said" 'grep -q "^views   ok  herdr 0.6.5: sidebar names; the extra sidebar rows and the board popup need herdr 0.7.4+" <<<"$out"'
rm -f "$FH/version"
python3 - "$APP/.orchestrate/plan.md" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read()
s=s.replace("## [x] M4: Totals\nDepends on: none\nOpen questions:\n- none\n","## [x] M4: Totals\nDepends on: none\nOpen questions:\n- none\nNotes from user:\nINR only.\n")
open(p,"w").write(s)
PY
"$ORCH" set M4 pending >/dev/null
timeout 120 "$ORCH" autopilot > "$WORK/vw2.log" 2>&1; code=$?
check "the run finishes as before (ALL_DONE)" '[ $code -eq 0 ] && [ "$(status_of M4)" = merged ]'
check "…the board says all done" '"$ORCH" board --once --no-color | qgrep -q "ALL DONE"'
: > "$FH/meta.log"
out=$("$ORCH" finish --no-push 2>&1); code=$?
check "orch finish works as before and gives every agent its own name back in herdr" '[ $code -eq 0 ] && grep -q "pane report-metadata p-claude-1 --source orch --clear-display-agent --clear-token orch_task --clear-token orch_desc" "$FH/meta.log" && grep -q "workspace report-metadata w1 --source orch --clear-token orch" "$FH/meta.log" && ! grep -q -- "--display-agent" "$FH/meta.log"'

echo "58. the sidebar names never slow the event manager (herdr slow to answer them)"
ONE='# Plan: one
Branch: feature/one
Check command: true
Setup command: none
Isolation: worktree
Max parallel: 1
Workers: claude-1 (claude)

## [x] M1: Model
Depends on: none
Open questions:
- none
'
landing_secs(){ python3 -c "
import json
ev=[json.loads(l) for l in open('.orchestrate/events.jsonl')]
print(max(e['ts'] for e in ev if e['to']=='merged') - min(e['ts'] for e in ev))"; }
newrepo fast; printf '%s' "$ONE" > .orchestrate/plan.md; echo p-claude-1 > "$FH/claude-1.paneid"
timeout 120 "$ORCH" autopilot > "$WORK/fast.log" 2>&1; c1=$?; fast=$(landing_secs)
newrepo slow; printf '%s' "$ONE" > .orchestrate/plan.md; echo p-claude-1 > "$FH/claude-1.paneid"; echo 4 > "$FH/slowmeta"
timeout 120 "$ORCH" autopilot > "$WORK/slow.log" 2>&1; c2=$?; slow=$(landing_secs)
check "with herdr taking 4s per sidebar name, the milestone lands as fast as without ($fast s vs $slow s from start to landed)" '[ $c1 -eq 0 ] && [ $c2 -eq 0 ] && [ "$slow" -le $((fast + 2)) ] && [ -s "$FH/meta.log" ]'
check "…and still lands the milestone" '[ "$(status_of M1)" = merged ]'
newrepo off; printf '%s' "$ONE" > .orchestrate/plan.md; echo p-claude-1 > "$FH/claude-1.paneid"
ORCH_SIDEBAR=0 timeout 120 "$ORCH" autopilot > "$WORK/off.log" 2>&1; c3=$?
check "ORCH_SIDEBAR=0 turns the sidebar names off" '[ $c3 -eq 0 ] && [ ! -s "$FH/meta.log" ]'

echo "59. old runs are labelled, and a plan orch does not read is pointed out"
cd "$APP" || exit        # the finished 'off' run: all merged, no event manager
vm=$("$ORCH" status --json)
check "a finished run with nothing going says it is the last run, in the summary, the board and orch status" 'python3 -c "import json,sys;d=json.loads(sys.argv[1]);k=[n[\"kind\"] for n in d[\"notices\"]];sys.exit(0 if k==[\"old_run\"] else 1)" "$vm" && "$ORCH" board --once --no-color | qgrep -q "^! This is the last run" && "$ORCH" status | qgrep -q "^note: This is the last run"'
printf '# Plan: other\n' > .orchestrate/csv-import.md
vm=$("$ORCH" status --json)
check "a plan file with another name is pointed out: orch reads plan.md only" 'python3 -c "import json,sys;d=json.loads(sys.argv[1]);k=[n[\"kind\"] for n in d[\"notices\"]];sys.exit(0 if k==[\"old_run\",\"other_plan\"] else 1)" "$vm" && "$ORCH" board --once --no-color | qgrep -q "csv-import.md is not used: orch only reads .orchestrate/plan.md"'
check "…the files orch writes itself (summary, story, pr-body...) and the lead's questions.md are never mistaken for a plan" 'for f in summary.md summary.prev.md story.md pr-body.md manual-tests.md questions.md; do printf x > .orchestrate/$f; done; ! "$ORCH" status --json | qgrep -q "summary.md is not used"; ! "$ORCH" status --json | qgrep -q "story.md is not used" && ! "$ORCH" status --json | qgrep -q "questions\.md"'
sleep 1; touch .orchestrate/plan.md
check "a plan.md changed after the run says to run orch sync" '"$ORCH" status --json | qgrep -q "\"plan_unsynced\""'
cp .orchestrate/state.json "$WORK/state.keep"
python3 - <<'PY'
import json
p=".orchestrate/state.json"; st=json.load(open(p)); st["tasks"]["M1"]["status"]="coding"; json.dump(st,open(p,"w"))
PY
check "while a milestone is being worked on there is no old-run note and no plan note" '[ "$("$ORCH" status --json | python3 -c "import json,sys;print(len(json.load(sys.stdin)[\"notices\"]))")" = 0 ]'
cp "$WORK/state.keep" .orchestrate/state.json
mv .orchestrate/plan.md "$WORK/plan.keep"
out=$("$ORCH" sync 2>&1); code=$?
check "orch sync with no plan.md names the other plan file and says to rename it" '[ $code -ne 0 ] && grep -q "missing .orchestrate/plan.md (found csv-import.md, but orch only reads plan.md" <<<"$out"'
mv "$WORK/plan.keep" .orchestrate/plan.md
newrepo wp; printf '%s' "$ONE" > .orchestrate/plan.md
"$ORCH" sync >/dev/null 2>&1
out=$("$ORCH" sync 2>&1)
check "orch sync with only plan.md has no plan-name warning" '! grep -q "newer than plan.md" <<<"$out"'
sleep 1; printf '# Plan: other\n' > .orchestrate/csv-import.md
out=$("$ORCH" sync 2>&1)
check "orch sync warns when another plan file is newer than plan.md" 'grep -q "csv-import.md is newer than plan.md, but orch only reads plan.md" <<<"$out"'
check "…and still loads plan.md as before" '[ "$(status_of M1)" = pending ]'
check "the empty summary (no run yet) also points out the unread plan" 'rm -f .orchestrate/state.json; "$ORCH" status --json | qgrep -q "\"other_plan\""'

echo "60. a coder's and the reviewer's chat is compacted (/compact) between milestones, never mid-work, never the lead"
CPLAN='# Plan: c
Branch: feature/compact
Check command: true
Setup command: none
Isolation: worktree
Max parallel: 1
Workers: claude-1 (claude)

## [x] M1: First
Depends on: none
Open questions:
- none

## [x] M5: Second
Depends on: M1
Open questions:
- none

## [x] M6: Third
Depends on: M5
Open questions:
- none
'
newrepo cmp; printf '%s' "$CPLAN" > .orchestrate/plan.md
timeout 120 "$ORCH" autopilot > "$WORK/cmp.log" 2>&1; code=$?
order=$(grep -oE '^claude-1 <- (/compact|Read \.orch-task/M[0-9]+)' "$FH/prompts.log" | sed 's/claude-1 <- //; s/Read .orch-task\///' | tr '\n' ' ')
check "the run lands every milestone" '[ $code -eq 0 ] && [ "$(status_of M1)$(status_of M5)$(status_of M6)" = mergedmergedmerged ]'
check "the coder gets /compact after M1 and after M5, before the next milestone, and never twice in a row ($order)" '[ "$order" = "M1 /compact M5 /compact M6 " ] || [ "$order" = "M1 /compact M5 /compact M6 /compact " ]'
check "the event manager says so, and orch story has a line for it" 'grep -qE "claude-1 finished M1 and is idle: sent /compact so its chat does not keep growing|BUSY claude-1 is compacting its chat after M1 first" "$WORK/cmp.log" && story=$("$ORCH" story) && grep -q "the event manager did: claude-1 finished M1: orch sent /compact so its chat does not keep growing" <<<"$story" && [ "$(grep -c "the event manager did: claude-1.s chat after M1 is now a short summary (/compact)" <<<"$story")" = 1 ] && [ "$(grep -c "the event manager did: claude-1.s chat after M5 is now a short summary (/compact)" <<<"$story")" = 1 ]'
# the "compact is over" line is written by whichever step notices first: the event manager, or the next job sent
newrepo cmprace; printf '%s' "$CPLAN" > .orchestrate/plan.md
"$ORCH" sync >/dev/null && "$ORCH" start >/dev/null
stpy "st['workers']['claude-1'].update(ctx='M1', compacting={'ts': now - 30, 'after': 'M1', 'cmd': '/compact', 'before': 'M5'})"
"$ORCH" prepare M5 claude-1 >/dev/null && "$ORCH" write-task M5 >/dev/null && "$ORCH" send M5 task.md >/dev/null
check "a compact that ended before the event manager looked still gets its one line in orch story (bug: it was lost about 1 run in 10)" '[ "$(grep -c "claude-1.s chat after M1 is now a short summary (/compact)" <<<"$("$ORCH" story)")" = 1 ] && python3 -c "import json,sys; w=json.load(open(\".orchestrate/state.json\"))[\"workers\"][\"claude-1\"]; sys.exit(0 if \"compacting\" not in w and w[\"ctx\"] == \"M5\" else 1)"'
newrepo cmpoff; printf '%s' "$CPLAN" > .orchestrate/plan.md
ORCH_COMPACT=0 timeout 120 "$ORCH" autopilot > "$WORK/cmpoff.log" 2>&1; code=$?
check "ORCH_COMPACT=0: the same run, no /compact at all" '[ $code -eq 0 ] && [ "$(status_of M6)" = merged ] && ! grep -q "/compact" "$FH/prompts.log"'
newrepo cmpcfg; printf '%s' "$CPLAN" > .orchestrate/plan.md
out=$("$ORCH" config compact off 2>&1)
check "orch config compact off is saved and shown" 'grep -q "^compact: off" <<<"$out" && grep -q "^compact: off" <<<"$("$ORCH" config)"'
timeout 120 "$ORCH" autopilot > "$WORK/cmpcfg.log" 2>&1; code=$?
check "…and the run then sends no /compact" '[ $code -eq 0 ] && [ "$(status_of M6)" = merged ] && ! grep -q "/compact" "$FH/prompts.log"'
"$ORCH" config compact on >/dev/null
check "orch config compact on turns it back on and names the tools" 'grep -q "^compact: on — coders and the reviewer on claude, codex, agy get /compact between milestones" <<<"$("$ORCH" config)"'
# the rules, by hand
newrepo cmpr; printf '%s' "${PLAN5/ISO/worktree}" > .orchestrate/plan.md
"$ORCH" sync >/dev/null && "$ORCH" start >/dev/null
stpy "st['workers']['claude-1']['ctx'] = 'M1'; st['tasks']['M1']['status'] = 'needs-fix'"
out=$("$ORCH" prepare M1 claude-1 2>&1); code=$?
check "a fix round of the SAME milestone keeps the chat (no /compact)" '[ $code -eq 0 ] && ! grep -q "/compact" "$FH/prompts.log" 2>/dev/null'
stpy "st['workers']['claude-1']['task'] = None; st['tasks']['M1']['status'] = 'pending'; st['tasks']['M1']['worker'] = None"
echo working > "$FH/claude-1.status"
out=$("$ORCH" prepare M4 claude-1 2>&1); code=$?
check "a coder herdr shows working is never sent /compact" '! grep -q "claude-1 <- /compact" "$FH/prompts.log" 2>/dev/null'
stpy "st['workers']['claude-1']['task'] = None; st['tasks']['M4'].update(status='pending', worker=None)"
echo idle > "$FH/claude-1.status"; echo 3 > "$FH/compact-secs"
out=$("$ORCH" prepare M4 claude-1 2>&1); code=$?
check "another milestone for an idle coder: /compact first, the job waits (exit 3)" '[ $code -eq 3 ] && grep -q "^BUSY claude-1 is compacting its chat after M1 first (/compact); M4 starts there once herdr shows it idle" <<<"$out" && grep -q "^claude-1 <- /compact$" "$FH/prompts.log" && [ "$(status_of M4)" = pending ]'
out=$("$ORCH" status 2>&1)
check "orch status shows it compacting, not free" 'grep -q "worker claude-1 .*state=compacting its chat after M1 (/compact" <<<"$out"'
out=$("$ORCH" pick M4 2>&1); code=$?
check "…it is not picked for work while it compacts" '[ "$out" != claude-1 ]'
out=$("$ORCH" status --json 2>&1)
check "orch status --json (the views) says compacting" 'python3 -c "import json,sys; d=json.loads(sys.argv[1]); a=[x for x in d[\"agents\"] if x[\"name\"]==\"claude-1\"][0]; assert a[\"state\"]==\"compacting\", a" "$out"'
for _ in $(seq 20); do [ "$(cat "$FH/claude-1.status")" = idle ] && break; sleep 0.5; done; sleep 1.2
stpy "st['workers']['claude-1'].pop('compacting'); st['workers']['claude-1']['ctx'] = None"
out=$("$ORCH" prepare M4 claude-1 2>&1); code=$?
check "once compacted it takes the job, with no second /compact" '[ $code -eq 0 ] && [ "$(grep -c "^claude-1 <- /compact$" "$FH/prompts.log")" = 1 ]'
rm -f "$FH/compact-secs"
# the reviewer (agy here, 1.5): compacted before it reviews another milestone
mkdir -p "$WORK/agybin"; printf '#!/bin/sh\necho "Antigravity CLI v1.5.0"\n' > "$WORK/agybin/agy"; chmod +x "$WORK/agybin/agy"
stpy "st['reviewer_info']['ctx'] = 'M9'; st['tasks']['M2']['status'] = 'verifying'"
out=$(PATH="$WORK/agybin:$PATH" "$ORCH" review M2 2>&1); code=$?
check "the reviewer gets /compact before it reviews another milestone; the review waits (awaiting-review)" '[ $code -eq 3 ] && grep -q "^reviewer <- /compact$" "$FH/prompts.log" && [ "$(status_of M2)" = awaiting-review ]'
# AGY: only from 1.2.15
printf '#!/bin/sh\necho "agy 1.2.4"\n' > "$WORK/agybin/agy"
check "AGY older than 1.2.15 is not compacted, and orch says why" 'PATH="$WORK/agybin:$PATH" python3 -c "
import importlib.machinery, importlib.util
l = importlib.machinery.SourceFileLoader(\"orch\", \"$ROOT/bin/orch\"); m = importlib.util.module_from_spec(importlib.util.spec_from_loader(\"orch\", l)); l.exec_module(m)
cmd, why = m.compact_command({}, \"agy\")
assert cmd is None and \"agy 1.2.4 is older than 1.2.15\" in why, why"'
printf '#!/bin/sh\necho "Antigravity CLI v1.5.0"\n' > "$WORK/agybin/agy"
check "AGY 1.5 gets /compact; Claude Code and Codex always; OpenCode, amp, Pi and Hermes never" 'PATH="$WORK/agybin:$PATH" python3 -c "
import importlib.machinery, importlib.util
l = importlib.machinery.SourceFileLoader(\"orch\", \"$ROOT/bin/orch\"); m = importlib.util.module_from_spec(importlib.util.spec_from_loader(\"orch\", l)); l.exec_module(m)
for k in (\"agy\", \"claude\", \"codex\"): assert m.compact_command({}, k)[0] == \"/compact\", k
for k in (\"opencode\", \"amp\", \"pi\", \"hermes\"): assert m.compact_command({}, k)[0] is None, k"'
check "the lead is never compacted" 'python3 -c "
import importlib.machinery, importlib.util
l = importlib.machinery.SourceFileLoader(\"orch\", \"$ROOT/bin/orch\"); m = importlib.util.module_from_spec(importlib.util.spec_from_loader(\"orch\", l)); l.exec_module(m)
st = {\"workers\": {\"c\": {}}, \"reviewer\": \"r\", \"reviewer_info\": {}, \"lead\": {\"name\": \"lead\", \"kind\": \"claude\"}}
assert [n for n, _, _ in m.compact_agents(st)] == [\"c\", \"r\"]"'

echo "61. frontend and backend: a check per side, names two runs can share a machine with, a workspace of several repos"
# a monorepo's sides: `Check web:` + `Side: web` checks only that side; the whole check still runs before finish
newrepo sides
printf '# Plan: t\nBranch: feature/sd\nCheck command: test ! -f broken.txt\nCheck web: test -f shared.txt\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M1: UI\nSide: web\nDepends on: none\nOpen questions:\n- none\n\n## [x] M4: Totals\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "a plan with a side syncs; the side is saved on the milestone" '[ $code -eq 0 ] && python3 -c "import json; st=json.load(open(\".orchestrate/state.json\")); assert st[\"sides\"]=={\"web\":\"test -f shared.txt\"} and st[\"tasks\"][\"M1\"][\"side\"]==\"web\" and st[\"tasks\"][\"M4\"][\"side\"] is None"'
out=$("$ORCH" check M1 2>&1)
check "orch check M1 runs only its side's check" 'grep -q "^CHECK PASS M1 .*: test -f shared.txt$" <<<"$out"'
check "...and a side's pass is not taken as the whole check (orch finish runs that one)" 'python3 -c "import json; assert not json.load(open(\".orchestrate/state.json\")).get(\"green_tree\")"'
out=$("$ORCH" check M4 2>&1)
check "a milestone with no side gets the whole check" 'grep -q "^CHECK PASS M4 .*: test ! -f broken.txt$" <<<"$out" && python3 -c "import json; assert json.load(open(\".orchestrate/state.json\")).get(\"green_tree\")"'
"$ORCH" start >/dev/null 2>&1; "$ORCH" prepare M1 claude-1 >/dev/null 2>&1; "$ORCH" write-task M1 >/dev/null 2>&1
check "the coder's task names its side's check command" 'grep -q "\"check\": \"test -f shared.txt\"" "$APP/../app-wt/claude-1/.orch-task/M1/task.json" && grep -q "test -f shared.txt" "$APP/../app-wt/claude-1/.orch-task/M1/task.md" && ! grep -q "^Side:" "$APP/../app-wt/claude-1/.orch-task/M1/task.md"'
sed -i 's/^Side: web/Side: mobile/' .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "an unknown side is refused with the sides there are" '[ $code -ne 0 ] && grep -q "M1 has .Side: mobile., but the plan has no .Check mobile:. line (sides: web)" <<<"$out"'
# two runs on one machine: agent names another going run uses are refused; orch team picks names with the repo's name
newrepo other; OTHER=$APP
printf "$P1" > .orchestrate/plan.md; printf '## [x] M1: a\nDepends on: none\nOpen questions:\n- none\n' >> .orchestrate/plan.md
sed -i 's/^Workers: claude-1 (claude)/Lead: lead (claude)\nWorkers: claude-1 (claude)/' .orchestrate/plan.md
"$ORCH" sync >/dev/null 2>&1
export ORCH_NAME_CHECK=1 ORCH_SHARE_KEEP="$ORCH_SHARE" ORCH_SHARE="$WORK/share61"   # only the run this section starts
mkdir -p "$ORCH_SHARE/active"; printf '{"root": "%s"}' "$OTHER" > "$ORCH_SHARE/active/other.json"
flock "$OTHER/.orchestrate/driver.lock" sleep 60 & HOLDER=$!
sleep 0.3
newrepo clash
printf "$P1" > .orchestrate/plan.md; printf '## [x] M1: a\nDepends on: none\nOpen questions:\n- none\n' >> .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "a name another going run uses is refused, with the folder of that run and a new name to use" '[ $code -ne 0 ] && grep -q "claude-1: this name is already used by the run in $OTHER, which is going now" <<<"$out" && grep -q "e.g. .app-claude-1." <<<"$out"'
sed -i 's/^Workers: claude-1 (claude)/Workers: app-claude-1 (claude)/' .orchestrate/plan.md
check "...a name of its own is fine" '"$ORCH" sync >/dev/null 2>&1'
sed -i 's/^Workers: app-claude-1 (claude)/Lead: lead (claude)\nWorkers: app-claude-1 (claude)/' .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "two separate runs can't share a lead name either" '[ $code -ne 0 ] && grep -q "^ERROR.*lead: this name is already used" <<<"$out"'
out=$(PATH="$FAKEBIN:$PATH" "$ORCH" team claude --coders 1 2>&1)
check "orch team names the team after the repo while another run uses the plain names" 'grep -q "^NOTE: another run ($OTHER) is going" <<<"$out" && grep -q "^Workers: app-claude-1 (claude: opus)$" <<<"$out" && grep -q "^Reviewer: app-reviewer (claude: opus)$" <<<"$out" && grep -q "^Lead: app-lead (claude" <<<"$out"'
out=$(PATH="$FAKEBIN:$PATH" "$ORCH" team claude --coders 1 --prefix web 2>&1)
check "orch team --prefix picks the names" 'grep -q "^Workers: web-claude-1 (claude: opus)$" <<<"$out"'
kill $HOLDER 2>/dev/null; wait $HOLDER 2>/dev/null; rm -f "$ORCH_SHARE/active/other.json"
out=$(PATH="$FAKEBIN:$PATH" "$ORCH" team claude --coders 1 2>&1)
check "with no other run going, orch team keeps the plain names" 'grep -q "^Workers: claude-1 (claude: opus)$" <<<"$out" && ! grep -q "^NOTE: another run" <<<"$out"'
export ORCH_NAME_CHECK=0 ORCH_SHARE="$ORCH_SHARE_KEEP"
# a workspace: two repos in one folder, one plan, each repo its own run, worktrees, branch, check and PR
W="$WORK/shop"; export FH="$WORK/shop-fh"; mkdir -p "$W/.orchestrate" "$FH"
for r in frontend backend; do mkdir -p "$W/$r"; (cd "$W/$r" && git init -q -b main && git config user.email t@t && git config user.name t && echo base > shared.txt && git add . && git commit -qm init)
  echo "$W/$r-wt/$r-claude-1" > "$FH/$r-claude-1.dir"; echo "$W/$r" > "$FH/$r-reviewer.dir"; done
WSPLAN='# Plan: Discounts
Branch: feature/disc
Repos: frontend, backend
Check command: true
Check backend: test ! -f broken.txt
Check frontend: test -f shared.txt
Isolation: worktree
Max parallel: 1
Workers: claude-1 (claude)
Reviewer: none

## Global instructions
Use INR.

## [x] M5: API
Repo: backend
Depends on: none
Open questions:
- none

## [x] M6: UI
Repo: frontend
Depends on: M5 (the endpoint)
Open questions:
- none
'
printf '%s' "${WSPLAN/Repo: frontend/}" > "$W/.orchestrate/plan.md"
cd "$W" || exit
out=$("$ORCH" sync 2>&1); code=$?
check "in a workspace every milestone needs its repo" '[ $code -ne 0 ] && grep -q "M6 needs .Repo: <one of frontend, backend>." <<<"$out"'
printf '%s' "${WSPLAN/Repo: frontend/Repo: mobile}" > "$W/.orchestrate/plan.md"
out=$("$ORCH" sync 2>&1); code=$?
check "...one of the repos the plan names" '[ $code -ne 0 ] && grep -q "M6 has .Repo: mobile., but .Repos:. names only frontend, backend" <<<"$out"'
printf '%s' "$WSPLAN" > "$W/.orchestrate/plan.md"
out=$("$ORCH" sync 2>&1); code=$?
check "orch sync in the workspace writes one plan per repo and syncs each" '[ $code -eq 0 ] && grep -q "^== frontend ($W/frontend): M6" <<<"$out" && grep -q "^== backend ($W/backend): M5" <<<"$out" && [ "$(grep -c "^OK: 1 tasks" <<<"$out")" = 2 ]'
check "each repo's plan has its milestones, its check, its coders (named after the repo) and the shared sections" 'grep -q "^Workspace: $W$" frontend/.orchestrate/plan.md && grep -q "^Check command: test -f shared.txt$" frontend/.orchestrate/plan.md && grep -q "^Check command: test ! -f broken.txt$" backend/.orchestrate/plan.md && grep -q "^Workers: frontend-claude-1 (claude)$" frontend/.orchestrate/plan.md && grep -q "^Use INR.$" backend/.orchestrate/plan.md && ! grep -q "M5: API" frontend/.orchestrate/plan.md && ! grep -q "^Repos:" frontend/.orchestrate/plan.md'
check "a dependency on another repo's milestone is written repo:Mn" 'grep -q "^Depends on: backend:M5 (the endpoint)$" frontend/.orchestrate/plan.md'
out=$("$ORCH" check M5 2>&1)
check "a command for a milestone goes to its repo" 'grep -q "^CHECK PASS M5 .*: test ! -f broken.txt$" <<<"$out"'
out=$("$ORCH" ready 2>&1)
check "orch ready in the workspace asks every repo; the UI waits for the API" 'grep -q "^== frontend" <<<"$out" && grep -q "^WAIT M6 waits for another repo: backend M5 (pending)$" <<<"$out" && grep -q "^READY M5 API$" <<<"$out"'
timeout 120 "$ORCH" autopilot > "$WORK/ws.log" 2>&1; code=$?
check "orch autopilot in the workspace runs every repo's event manager until all is done" '[ $code -eq 0 ] && [ "$(grep -c "ALL_DONE on feature/disc" "$WORK/ws.log")" = 2 ]'
check "the UI started only after the API landed in the backend" 'grep -q "waiting for another repo: M6 waits for backend M5" "$WORK/ws.log" && python3 -c "
import json; h = lambda r, m: json.load(open(\"$W/\" + r + \"/.orchestrate/state.json\"))[\"tasks\"][m][\"history\"]
landed = min(e[\"ts\"] for e in h(\"backend\", \"M5\") if e[\"to\"] == \"merged\")
started = min(e[\"ts\"] for e in h(\"frontend\", \"M6\") if e[\"to\"] == \"coding\")
assert landed <= started, (landed, started)"'
check "each repo's milestone landed on that repo's own feature branch, checked with its own check" 'git -C backend log --format=%s feature/disc | qgrep -qx API && git -C frontend log --format=%s feature/disc | qgrep -qx UI && ! git -C frontend log --format=%s feature/disc | qgrep -qx API && grep -q "M6 check passed .*(test -f shared.txt)" "$WORK/ws.log" && grep -q "M5 check passed .*(test ! -f broken.txt)" "$WORK/ws.log"'
check "each side's coder worked in its own worktree of its own repo" '[ -f "$W/backend-wt/backend-claude-1/e.txt" ] && [ -f "$W/frontend-wt/frontend-claude-1/g.txt" ] && [ ! -f "$W/frontend-wt/frontend-claude-1/e.txt" ]'
out=$("$ORCH" status 2>&1)
check "orch status in the workspace shows every repo" 'grep -q "^== frontend" <<<"$out" && grep -q "^== backend" <<<"$out" && grep -q "M6 .*merged .*deps=backend:M5" <<<"$out"'
out=$("$ORCH" finish --no-push 2>&1)
check "orch finish in the workspace finishes every repo and removes its coder folders" '[ ! -e "$W/frontend-wt" ] && [ ! -e "$W/backend-wt" ] && [ "$(grep -c "^== " <<<"$out")" = 2 ]'
out=$(cd "$W/frontend" && "$ORCH" status 2>&1)
check "inside one repo, orch works on that repo's run only" '! grep -q "^== " <<<"$out" && grep -q "^  M6 " <<<"$out" && ! grep -q "^  M5 " <<<"$out"'
# a repo with its own run still going is not overwritten
printf '# Plan: own\nBranch: feature/own\nCheck command: true\nIsolation: shared\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M1: a\nDepends on: none\nOpen questions:\n- none\n' > "$W/backend/.orchestrate/plan.md"
(cd "$W/backend" && "$ORCH" sync >/dev/null 2>&1)
out=$("$ORCH" sync 2>&1); code=$?
check "a workspace sync never overwrites a repo's own run that is still going" '[ $code -ne 0 ] && grep -q "repo backend has its own run going (M1 not landed)" <<<"$out" && grep -q "^# Plan: own" "$W/backend/.orchestrate/plan.md"'
check "the playbook tells the lead about sides and workspaces" 'grep -q "Check <side>:" "$ROOT/playbooks/plan.md" && grep -q "Repos:" "$ROOT/playbooks/plan.md" && grep -q "backend:M" "$ROOT/playbooks/plan.md"'
cd "$WORK" || exit

echo "62. the developer picks the model and thinking level of each milestone and of the reviewer, after the plan"
newrepo mp
printf '%b' '# Plan: Discount\nBranch: feature/mp\nCheck command: true\nIsolation: worktree\nMax parallel: 2\nWorkers: codex-1 (codex: gpt-6-luna@high), codex-2 (codex: gpt-6.2-sol@medium)\nReviewer: reviewer (codex: gpt-6.2-sol@medium)\n\n## [x] M1: Discount in API\nDepends on: none\nTier: high\nModel why: a contract.\nReview: yes\nOpen questions:\n- none\n\n## [x] M2: Update docs\nDepends on: none\nTier: small\nModel why: docs only.\nOpen questions:\n- none\n' > .orchestrate/plan.md
"$ORCH" sync >/dev/null 2>&1
out=$("$ORCH" plan team 2>&1); code=$?
check "orch plan team: a row per milestone and the reviewer, with coder, model and thinking level" '[ $code -eq 0 ] && grep -q "^Step  *What  *Coder  *Model  *Thinking  *Chosen$" <<<"$out" && grep -q "^M1  *Discount in API  *codex-2  *gpt-6.2-sol  *medium  *by level (high)$" <<<"$out" && grep -q "^Reviewer  *checks the reviewed steps  *reviewer  *gpt-6.2-sol  *medium$" <<<"$out"'
check "…and what the developer can pick: the models and thinking levels of the tool, never a denied one" 'grep -q "^You can pick (codex): models gpt-6-luna, gpt-6.2-sol · thinking low, medium, high, xhigh, max$" <<<"$out" && grep -q "^Never allowed: .*\*astra\*" <<<"$out" && ! grep -q "astra," <<<"$out"'
out=$("$ORCH" plan model M2 gpt-6.2-sol low 2>&1); code=$?
check "orch plan model locks a milestone; no coder ran that model, so a new one joins the team" '[ $code -eq 0 ] && grep -q "^LOCKED  M2 to gpt-6.2-sol on low thinking: only codex-3 takes it" <<<"$out" && grep -q "^NEW     coder codex-3 (codex: gpt-6.2-sol@low) joins the team for M2: .orch team up. opens its panel when the run starts" <<<"$out" && grep -q "^Workers: codex-1 (codex: gpt-6-luna@high), codex-2 (codex: gpt-6.2-sol@medium), codex-3 (codex: gpt-6.2-sol@low)$" .orchestrate/plan.md && grep -A1 "^Tier: small" .orchestrate/plan.md | qgrep -qx "Model: gpt-6.2-sol@low"'
out=$("$ORCH" plan team 2>&1)
check "the table shows the choice as locked by the developer" 'grep -q "^M2  *Update docs  *codex-3  *gpt-6.2-sol  *low  *locked by you$" <<<"$out"'
check "orch plan show: only the coder on that model builds it" '"$ORCH" plan show | qgrep -q "^   Built by: codex-3 (gpt-6.2-sol@low) · locked by you to gpt-6.2-sol@low"'
check "the coder's task never gets the Model line (orch's own)" 'grep -q "\"model\", \"tier\"" "$ORCH"'
out=$("$ORCH" plan model M1 gpt-6.2-sol@medium 2>&1)
check "a model a coder already runs: locked to that coder, nobody new" 'grep -q "^LOCKED  M1 to gpt-6.2-sol on medium thinking: only codex-2 takes it" <<<"$out" && ! grep -q "^NEW" <<<"$out"'
out=$("$ORCH" plan model M1 gpt-6-astra@low 2>&1); code=$?
check "a denied model is refused" '[ $code -ne 0 ] && grep -q "gpt-6-astra@low is not allowed by the model policy" <<<"$out" && ! grep -q astra .orchestrate/plan.md'
out=$("$ORCH" plan model M1 gpt-6-luna@huge 2>&1); code=$?
check "a thinking level the tool doesn't have is refused" '[ $code -ne 0 ] && grep -q "codex has no thinking level .huge.: pick one of low, medium, high, xhigh, max" <<<"$out"'
out=$("$ORCH" plan model reviewer gpt-6-luna high 2>&1); code=$?
check "orch plan model reviewer changes the reviewer's model" '[ $code -eq 0 ] && grep -q "^REVIEWER reviewer now runs gpt-6-luna on high thinking" <<<"$out" && grep -q "^Reviewer: reviewer (codex: gpt-6-luna@high)$" .orchestrate/plan.md'
"$ORCH" start >/dev/null 2>&1
out=$("$ORCH" escalate M2 "out of rounds" 2>&1); code=$?
check "a locked milestone is never escalated to another model" '[ $code -eq 3 ] && grep -q "^NO_ESCALATION M2 (the developer locked it to gpt-6.2-sol@low" <<<"$out"'
out=$("$ORCH" dispatch M2 --to codex-1 2>&1); code=$?
check "dispatch --to a coder on another model is refused for a locked milestone" '[ $code -ne 0 ] && grep -q "M2 is locked to gpt-6.2-sol@low by the developer, and codex-1 runs gpt-6-luna@high" <<<"$out"'
out=$("$ORCH" dispatch M2 --tier high 2>&1); code=$?
check "…and so is --tier" '[ $code -ne 0 ] && grep -q "so --tier does not apply" <<<"$out" && ! python3 -c "import json,sys;sys.exit(not json.load(open(\".orchestrate/state.json\"))[\"tasks\"][\"M2\"].get(\"go\"))"'
out=$("$ORCH" plan model M2 gpt-6-luna@high 2>&1)
check "the developer changes it later: another lock, and the coder added for the old one is pointed out" 'grep -q "^LOCKED  M2 to gpt-6-luna on high thinking: only codex-1 takes it" <<<"$out" && grep -q "^NOTE    codex-3 (gpt-6.2-sol@low) stays in the team" <<<"$out" && [ "$(grep -c "^Model:" .orchestrate/plan.md)" = 2 ]'
out=$("$ORCH" plan model M2 auto 2>&1); code=$?
check "auto gives the milestone back to its level" '[ $code -eq 0 ] && grep -q "^UNLOCKED M2" <<<"$out" && [ "$(grep -c "^Model:" .orchestrate/plan.md)" = 1 ]'
python3 - <<'PY'
import re; p = ".orchestrate/plan.md"; s = open(p).read()
open(p, "w").write(s.replace("Model: gpt-6.2-sol@medium", "Model: gpt-6-luna@low"))
PY
out=$("$ORCH" sync 2>&1); code=$?
check "a Model line by hand that no coder runs stops sync, with the command that fixes it" '[ $code -eq 2 ] && grep -q "M1 has .Model: gpt-6-luna@low., but no coder in Workers runs gpt-6-luna@low — .orch plan model M1 gpt-6-luna@low. adds one" <<<"$out"'
out=$("$ORCH" lead plan quick 2>&1)
check "the plan playbook asks about models only after the plan is shown, in quick runs too" 'grep -q "^## Let the developer choose the models (from step 10)" <<<"$out" && grep -q "Keep this team?" <<<"$out" && grep -q "M3 sol low" <<<"$out" && grep -q "orch plan model reviewer" <<<"$out"'
check "the run playbook keeps the developer's choices and says how to change them" '"$ORCH" lead run --section rules | qgrep -q "The developer.s model choices stay" && grep -q "M3 use luna high" "$ROOT/playbooks/run.md"'
cd "$WORK" || exit

echo "63. the lead is told its own question picker by name (Antigravity: ask_question), or that it has none"
newrepo pk
PK(){ env -u HERDR_PANE_ID "$@" "$ORCH" lead plan 2>&1 | sed -n '/^QUESTION PICKER/p'; }
check "Claude Code: AskUserQuestion, with its limits, for every planning question incl. Keep this team?" 'PK AI_AGENT=claude-code_2-1 | qgrep -q "^QUESTION PICKER you are Claude Code: ask .* your \`AskUserQuestion\` tool (1 to 4 questions per call, 2 to 4 choices each" && PK AI_AGENT=claude | qgrep -q "Keep this team?\" / \"Which step?\" / \"Which model?\" after the plan"'
check "Antigravity (also AI_AGENT=antigravity): ask_question by name, never the choices as plain text" 'PK AI_AGENT=agy | qgrep -q "^QUESTION PICKER you are Antigravity: .*built-in \`ask_question\` tool (the one /grill-me uses" && PK AI_AGENT=antigravity | qgrep -q "Do not write the choices as plain text when you have this tool"'
check "Pi: orch_ask, and how to add it when the package is missing; OpenCode: question" 'PK AI_AGENT=pi | qgrep -q "^QUESTION PICKER you are Pi: .*\`orch_ask\` tool.*pi install npm:herdr-orchestra" && PK AI_AGENT=opencode | qgrep -q "^QUESTION PICKER you are OpenCode: .*your \`question\` tool"'
check "an agent with no known picker asks in chat; an agent orch can't tell gets every name" 'PK AI_AGENT=amp | qgrep -q "^QUESTION PICKER you are amp, and orch knows no question picker for it: ask your planning questions in chat" && PK | qgrep -q "^QUESTION PICKER orch can.t tell which agent you are.*\`ask_question\` (Antigravity)"'
check "…every line says what to do when the tool is missing or refuses: ask in chat (step 2a, point 3)" 'PK AI_AGENT=agy | qgrep -q "If the tool is missing or refuses .* ask in chat instead (step 2a, point 3)"'
echo "$APP" > "$FH/pane-w5:p1.cwd"; echo agy > "$FH/pane-w5:p1.kind"
check "Antigravity leaves no mark in its shell: orch asks herdr which agent runs in this pane" 'HERDR_PANE_ID=w5:p1 "$ORCH" lead plan 2>&1 | qgrep -q "^QUESTION PICKER you are Antigravity: "'
rm -f "$FH/pane-w5:p1.cwd" "$FH/pane-w5:p1.kind"
CXH="$WORK/pk-codex"; mkdir -p "$CXH"
check "Codex, started some way orch can't see: try request_user_input once, then chat and how to turn it on" 'PK CODEX_HOME="$CXH" CODEX_THREAD_ID=t | qgrep -q "^QUESTION PICKER you are Codex (orch can.t see how this Codex was started): try your \`request_user_input\` tool (1 to 3 questions per call.*once. If it answers \"unavailable in Default mode\", the picker is off: ask in chat.*default_mode_request_user_input = true\` under \`\[features\]\` in ~/.codex/config.toml"'
printf '[features]\ndefault_mode_request_user_input = true\n' > "$CXH/config.toml"
check "Codex with the picker on in config.toml: use it" 'PK CODEX_HOME="$CXH" CODEX_THREAD_ID=t | qgrep -q "^QUESTION PICKER you are Codex and its picker is on (turned on in $CXH/config.toml): ask with your \`request_user_input\` tool"'
rm "$CXH/config.toml"; mkdir -p "$WORK/pk-bin"; printf '#!/bin/sh\nexec "$ORCH" lead plan\n' > "$WORK/pk-bin/codex"; chmod +x "$WORK/pk-bin/codex"
PKC(){ env -u HERDR_PANE_ID CODEX_HOME="$CXH" CODEX_THREAD_ID=t ORCH="$ORCH" sh -c "\"$WORK/pk-bin/codex\" $1 2>&1 | sed -n \"/^QUESTION PICKER/p\""; }
check "Codex started by orch's lead command (-c features...=true or --enable): the picker is on" 'PKC "-c features.default_mode_request_user_input=true" | qgrep -q "picker is on (turned on in the command that started this Codex)" && PKC "--enable default_mode_request_user_input" | qgrep -q "picker is on"'
check "Codex opened by hand (no flag): OFF, ask in chat, and tell the developer how to get the picker" 'PKC "--approve-for-me" | qgrep -q "^QUESTION PICKER OFF: you are Codex and its picker is off (this Codex was started without it.*would only answer \"unavailable in Default mode\". Ask your planning questions in chat.*let orch open the lead (\`orch team codex\`)" && PKC "-c features.default_mode_request_user_input=false" | qgrep -q "^QUESTION PICKER OFF"'
check "the picker line comes with the start of the playbook only, not with the quick or full parts" '! AI_AGENT=agy "$ORCH" lead plan full 2>&1 | qgrep -q "^QUESTION PICKER" && ! AI_AGENT=agy "$ORCH" lead plan quick 2>&1 | qgrep -q "^QUESTION PICKER"'
out=$("$ORCH" lead plan 2>&1; "$ORCH" lead plan full 2>&1)
check "the playbook points to the picker line, names ask_question, and Keep this team? uses the same picker" 'grep -q "The \`QUESTION PICKER\` line at the top of this playbook names yours" <<<"$out" && grep -q "\`ask_question\` in Antigravity (the tool \`/grill-me\` uses)" <<<"$out" && grep -q "Never write the choices as plain text when you have a picker" <<<"$out" && grep -q "Keep this team?.*" <<<"$out" && grep -q "the tool the \`QUESTION PICKER\` line at the top of \`orch lead plan\` named, e.g. \`ask_question\` in Antigravity" <<<"$out"'
cd "$WORK" || exit

echo; echo "passed $pass, failed $fail"
[ $fail -eq 0 ]
