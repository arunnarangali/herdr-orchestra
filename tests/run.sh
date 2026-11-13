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
pass=0 fail=0
ok()   { echo "  ok   $*"; pass=$((pass+1)); }
bad()  { echo "  FAIL $*"; fail=$((fail+1)); }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

newrepo() {  # newrepo <name> ; sets APP and FH
  APP="$WORK/$1/app"; export FH="$WORK/$1/fh"; mkdir -p "$APP" "$FH"
  cd "$APP" && git init -q -b main && git config user.email t@t && git config user.name t
  echo base > shared.txt && git add . && git commit -qm init && mkdir .orchestrate
  echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"; echo "$APP/../app-wt/codex-1" > "$FH/codex-1.dir"
  echo "$APP" > "$FH/reviewer.dir"
}
status_of(){ python3 -c "import json;print(json.load(open('$APP/.orchestrate/state.json'))['tasks']['$1']['status'])"; }

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
check "commit subject is the coder's COMMIT line" 'git log --format=%s | grep -qx "feat(api): add the categories endpoint"'
check "no milestone-named commits on the branch" '! git log --format=%s | grep -qE "^(orch|wip)[( ]"'
check "the run made one branch, no milestone branches" '[ "$(git branch --format="%(refname:short)" | sort | tr "\n" " ")" = "feature/cat main " ]'
check "parked M4 keeps its work in a hidden ref only" '! git branch -a | grep -q M4'
check "a conflict fix on an approved milestone is reviewed again, with the resolution" '[ -s .orchestrate/review/M2/resolution.patch ] && grep -q "MERGE-CONFLICT RESOLUTION" .orchestrate/review/M2/review-task-3.md'

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
out=$("$ORCH" finish 2>&1); code=$?
check "finish pushes the feature branch" '[ $code -eq 0 ] && git --git-dir="$WORK/remote.git" rev-parse -q --verify feature/cat >/dev/null'
check "finish removes hidden refs and worktrees" '[ -z "$(git for-each-ref refs/orch)" ] && [ ! -d "$APP/../app-wt/claude-1" ]'
check "finish says how to open the PR" 'grep -q "OPEN A PR from feature/cat into main" <<<"$out"'
check "only the feature branch was pushed" '[ "$(git --git-dir="$WORK/remote.git" for-each-ref --format="%(refname)" | tr "\n" " ")" = "refs/heads/feature/cat " ]'

echo "3. rate limit moves the task (and its partial work) to the other coder"
newrepo rl
printf '# Plan: t\nBranch: orch/rl\nCheck command: true\nIsolation: worktree\nMax parallel: 2\nWorkers: claude-1 (claude), codex-1 (codex)\nReviewer: none\n\n## [x] M1: Model\nDepends on: none\nPrefer: codex\nOpen questions:\n- none\n' > .orchestrate/plan.md
touch "$FH/ratelimit-codex-1-M1"
timeout 120 "$ORCH" autopilot > "$WORK/rl.log" 2>&1; code=$?
check "finished (exit 0)" '[ $code -eq 0 ]'
check "codex benched" '"$ORCH" status | grep -q "codex-1 .*cooldown"'
check "claude finished it" '"$ORCH" status | grep -q "M1 .*merged .*claude-1"'
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
newrepo pl; touch "$FH/slow-review"
printf '# Plan: t\nBranch: orch/pl\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: codex-1 (codex)\nReviewer: reviewer (agy)\n\n## [x] M2: Endpoint\nDepends on: none\nReview: yes\nOpen questions:\n- none\n\n## [x] M6: Other screen\nDepends on: none\nReview: no\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 150 "$ORCH" autopilot > "$WORK/pl.log" 2>&1; code=$?
check "finished (exit 0)" '[ $code -eq 0 ]'
check "coder freed at handoff" 'grep -q "M2 saved for review; codex-1 is free" "$WORK/pl.log"'
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
check "ORCH_MAX_TASKS still warns when you set it" 'ORCH_MAX_TASKS=4 "$ORCH" sync | grep -q "5 enabled milestones"'
{ printf '# Plan: t\nBranch: orch/v\nCheck command: true\nWorkers: claude-1 (claude)\nReviewer: none\n\n## Feature breakdown\n- api and ui\n'; for i in 1 2; do printf '\n## [x] M%s: t\nDepends on: none\nWhy separate: built in parallel by another coder\nOpen questions:\n- none\n' $i; done; } > .orchestrate/plan.md
check "milestones that say why they are separate do not warn" '! "$ORCH" sync 2>&1 | grep -q "Why separate"'
printf '# Plan: t\nBranch: orch/v\nCheck command: true\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M1: t\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
check "a one-milestone plan needs no reason" '! "$ORCH" sync 2>&1 | grep -q "Why separate"'
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
check "orch version prints" '"$ORCH" version | grep -q "herdr-orchestra"'

echo "8. any agent can lead: playbooks, Lead header, agent registry"
out=$("$ORCH" lead plan)
check "lead plan prints version line + playbook" 'grep -q "^herdr-orchestra .* lead playbook: plan" <<<"$out" && grep -q "You are the LEAD" <<<"$out"'
out=$("$ORCH" lead run)
check "lead run prints version line + playbook" 'grep -q "lead playbook: run" <<<"$out" && grep -q "event manager" <<<"$out" && grep -q "orch dispatch" <<<"$out"'
check "lead commands work outside a git repo" '(cd "$WORK" && "$ORCH" lead plan >/dev/null && "$ORCH" agents >/dev/null)'
check "lead whoami names the pane" '"$ORCH" lead whoami | grep -q "herdr agent rename w1:p1 lead"'
check "lead check passes on HERDR_ENV=1" 'HERDR_ENV=1 "$ORCH" lead check | grep -q "^OK inside a Herdr pane"'
out=$(env -u HERDR_ENV "$ORCH" lead check 2>&1); code=$?
check "lead check passes when herdr answers but HERDR_ENV is unset (Hermes gateway)" '[ $code -eq 0 ] && grep -q "^OK herdr is reachable" <<<"$out" && grep -q "client_env_passthrough" <<<"$out"'
out=$(env -u HERDR_ENV HERDR=/nonexistent/herdr "$ORCH" lead check 2>&1); code=$?
check "lead check fails clearly when herdr is unreachable" '[ $code -ne 0 ] && grep -q "Herdr not detected" <<<"$out" && grep -q "Start this agent from a Herdr pane" <<<"$out"'
check "lead whoami warns when HERDR_PANE_ID is unset" 'env -u HERDR_PANE_ID "$ORCH" lead whoami | grep -q "FOCUSED pane"'
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
check "registry defaults load" '"$ORCH" agents | grep -q "^hermes" && [ "$("$ORCH" agents launch claude)" = "claude --permission-mode acceptEdits" ]'
printf '[claude]\nlaunch = "claude --model opus"\n\n[mystery]\nbinary = "mystery"\nlaunch = "mystery --yolo"\n' > "$ORCH_AGENTS_FILE"
check "user agents.toml overrides and adds kinds" '[ "$("$ORCH" agents launch claude)" = "claude --model opus" ] && [ "$("$ORCH" agents launch mystery)" = "mystery --yolo" ]'
rm -f "$ORCH_AGENTS_FILE"

echo "9. agents herdr can't watch rely on their done file"
newrepo nd; echo "$APP/../app-wt/odd-1" > "$FH/odd-1.dir"; touch "$FH/odd-1.gone"
printf '# Plan: t\nBranch: orch/nd\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: odd-1 (oddagent)\nReviewer: none\n\n## [x] M5: e\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1)
check "unknown kind warns, not an error" 'grep -q "WARN: Workers kind .oddagent. is not in the agent registry" <<<"$out"'
timeout 120 "$ORCH" autopilot > "$WORK/nd.log" 2>&1; code=$?
check "detect=false worker finished via its done file" '[ $code -eq 0 ] && [ "$(status_of M5)" = merged ]'
check "never parked as GONE" '! grep -qi "gone" "$WORK/nd.log" && grep -q "can.t watch odd-1" "$WORK/nd.log"'
check "status shows detect:off" '"$ORCH" status | grep -q "odd-1 .*detect:off"'

echo "10. @pane: workers get prompts typed into their pane"
newrepo pn; echo "$APP/../app-wt/hermes-1" > "$FH/hermes-1.dir"; echo hermes-1 > "$FH/pane-w9:p2.name"
printf '# Plan: t\nBranch: orch/pn\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: hermes-1 (hermes @pane:w9:p2)\nReviewer: none\n\n## [x] M6: g\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 120 "$ORCH" autopilot > "$WORK/pn.log" 2>&1; code=$?
check "pane worker finished" '[ $code -eq 0 ] && [ "$(status_of M6)" = merged ]'
check "prompt went through pane send-text + enter" 'grep -q "pane w9:p2 (hermes-1) <- Read .orch-task/M6/task.md" "$FH/pane-prompts.log" && grep -q "pane w9:p2 keys enter" "$FH/pane-prompts.log"'
check "agent prompt was not used for it" '! grep -q "^hermes-1 <-" "$FH/prompts.log" 2>/dev/null'
sed -i 's/@pane:w9:p2/@pane:w9:p7/' .orchestrate/plan.md; "$ORCH" sync >/dev/null
check "stale pane id reported by start" '"$ORCH" start | grep -q "STALE pane w9:p7"'

echo "12. recovery: an error in one task never crashes or hangs the run"
newrepo srl; echo "$APP" > "$FH/claude-1.dir"; echo "$APP" > "$FH/codex-1.dir"
printf '# Plan: t\nBranch: feature/srl\nCheck command: true\nIsolation: shared\nMax parallel: 1\nWorkers: claude-1 (claude), codex-1 (codex)\nReviewer: none\n\n## [x] M1: Model\nDepends on: none\nPrefer: codex\nOpen questions:\n- none\n' > .orchestrate/plan.md
touch "$FH/ratelimit-codex-1-M1"
timeout 120 "$ORCH" autopilot > "$WORK/srl.log" 2>&1; code=$?
check "shared mode: rate-limited task moves to the other coder" '[ $code -eq 0 ] && "$ORCH" status | grep -q "M1 .*merged .*claude-1"'
check "shared mode: partial work came along" 'git show --stat HEAD | grep -q partial-M1.txt && ! grep -q Traceback "$WORK/srl.log"'

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
check "a GONE coder gets work again as soon as it is back (not 10 h later)" '[ $code -eq 0 ] && grep -q "claude-1 is gone" "$WORK/gn.log" && [ "$(status_of M7)" = merged ]'

newrepo orp; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
printf '# Plan: t\nBranch: feature/orp\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude), codex-1 (codex)\nReviewer: none\n\n## [x] M5: E\nDepends on: none\nOpen questions:\n- none\n\n## [ ] M6: G\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
"$ORCH" sync >/dev/null && "$ORCH" start >/dev/null && "$ORCH" prepare M5 claude-1 >/dev/null
out=$("$ORCH" poll 2 2>&1)
check "poll reports a task whose prompt never went out" 'grep -q "^ORPHAN M5" <<<"$out"'
"$ORCH" set M5 pending >/dev/null
check "set pending frees the coder" '"$ORCH" status | grep -q "claude-1 .*task=- "'
"$ORCH" prepare M5 claude-1 >/dev/null
python3 - .orchestrate/plan.md <<'PY'
import re, sys; p = sys.argv[1]; s = open(p).read()
open(p, "w").write(re.sub(r"## \[x\] M5: E\n(.*\n)*?(?=## )", "", s))
PY
out=$("$ORCH" sync 2>&1)
check "sync frees a coder whose milestone left the plan" 'grep -q "claude-1 was holding M5" <<<"$out" && "$ORCH" status | grep -q "claude-1 .*task=- "'
out=$("$ORCH" send M99 task.md 2>&1); code=$?
check "unknown task id is a clean error" '[ $code -eq 2 ] && grep -q "unknown task .M99" <<<"$out" && ! grep -q Traceback <<<"$out"'
out=$("$ORCH" cooldown reviewer 5 2>&1); code=$?
check "cooldown of an unknown agent is a clean error" '[ $code -eq 2 ] && ! grep -q Traceback <<<"$out"'

newrepo js; echo "$APP/../app-wt/working-1" > "$FH/working-1.dir"
printf '# Plan: t\nBranch: feature/js\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: working-1 (claude)\nReviewer: none\n\n## [x] M6: G\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 60 "$ORCH" autopilot > "$WORK/js.log" 2>&1; code=$?
check "herdr status is read from its JSON field (agent named working-1 is free)" '[ $code -eq 0 ] && [ "$(status_of M6)" = merged ]'

newrepo ib; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"
printf '# Plan: t\nBranch: feature/ib\nCheck command: test "$(git rev-parse --abbrev-ref HEAD)" = HEAD || test ! -f boom.txt\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: none\n\n## [x] M10: Boom\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
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
check "Key: value lines in Global instructions don't override the header" 'grep -q "^OK" <<<"$out" && "$ORCH" status | grep -q "^branch=feature/sg "'
timeout 60 "$ORCH" autopilot > "$WORK/sg.log" 2>&1; code=$?
out=$("$ORCH" finish --no-push 2>&1); fcode=$?
check "Commits: single squashes the run into one commit" '[ $code -eq 0 ] && [ $fcode -eq 0 ] && [ "$(git rev-list --count main..feature/sg)" -eq 1 ] && git log -1 --format=%B | grep -q "Milestones: M5, M6"'
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
check "starting on the branch itself still records the real base" '"$ORCH" status | grep -q "base=main "'

echo "14. one driver per run"
P1='# Plan: t\nBranch: feature/x\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: none\n\n'
newrepo ls; echo "$APP/../app-wt/claude-1" > "$FH/claude-1.dir"; touch "$FH/slow-review"
printf '# Plan: t\nBranch: feature/ls\nCheck command: true\nIsolation: worktree\nMax parallel: 1\nWorkers: claude-1 (claude)\nReviewer: reviewer (agy)\n\n## [x] M5: E\nDepends on: none\nReview: yes\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 120 "$ORCH" autopilot > "$WORK/ls.log" 2>&1 & first=$!
for _ in $(seq 100); do "$ORCH" status 2>/dev/null | grep -q "^driven by" && break; sleep 0.2; done
out=$(timeout 30 "$ORCH" autopilot 2>&1); code=$?
check "a second autopilot is refused" '[ $code -eq 2 ] && grep -q "already driven by orch autopilot (pid" <<<"$out"'
out=$("$ORCH" set M5 paused 2>&1); code=$?
check "changing the run by hand is refused while autopilot drives" '[ $code -eq 2 ] && grep -q "driven by" <<<"$out"'
check "status still works and shows the driver" '"$ORCH" status | grep -q "^driven by orch autopilot (pid"'
wait $first; code=$?
check "the first autopilot was not disturbed" '[ $code -eq 0 ] && [ "$(status_of M5)" = merged ] && ! grep -q "orch error" "$WORK/ls.log"'
check "the lease is free again afterwards" '! "$ORCH" status | grep -q "^driven by" && "$ORCH" set M5 merged --force >/dev/null'

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
  { printf '%b' "$P1"; printf '## [x] M6: G\nDepends on: none\nOpen questions:\n- none\n'; } > .orchestrate/plan.md
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
check "the commit subject comes from result.json" 'git log --format=%s | grep -qx "feat: p"'

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
check "shared mode: held, then lands after approve" '[ $code -eq 3 ] && grep -q "M16 is HELD" "$WORK/rs.log" && [ $code2 -eq 0 ] && [ "$(status_of M16)" = merged ] && git show --stat HEAD | grep -q shared.txt'

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
check "models show prints the evidence" '"$ORCH" models show opus | grep -q "evidence"'
check "launch --model builds the command" '[ "$("$ORCH" agents launch claude --model haiku)" = "claude --permission-mode acceptEdits --model haiku" ]'
check "launch --model refuses a denied model" '! "$ORCH" agents launch claude --model fable >/dev/null 2>&1'
check "launch --model says when a kind has no model flag" 'grep -q "no \`model_flag\`" <<<"$("$ORCH" agents launch amp --model x 2>&1)"'
printf '[models.my-local]\nkinds = ["opencode"]\ntier = "high"\nreasoning = 2\n[policy]\ndeny = ["*fable*", "sonnet"]\n' > "$ORCH_MODELS_FILE"
check "user models.toml adds a model; a high tier needs the reasoning for it" '"$ORCH" models check my-local | grep -q "tier small"'
check "user models.toml can change the policy" 'grep -q DENIED <<<"$("$ORCH" models check sonnet 2>&1)" && "$ORCH" models check gpt-6-astra-light | grep -q UNRATED'
rm -f "$ORCH_MODELS_FILE"
newrepo md
MPLAN='# Plan: t\nBranch: feature/md\nCheck command: test ! -f broken.txt\nIsolation: worktree\nMax parallel: 2\nLEADLINE\nWorkers: claude-1 (claude: sonnet), codex-1 (codex: gpt-6-luna)\nReviewer: none\n\n## [x] M1: Model\nDepends on: none\nTier: medium\nNeeds: coding\nModel why: one module, a pattern to copy.\nOpen questions:\n- none\n\n## [x] M4: Totals\nDepends on: none\nTier: small\nModel why: one small function.\nOpen questions:\n- none\n'
printf "${MPLAN/LEADLINE/Lead mode: off}" > .orchestrate/plan.md
out=$("$ORCH" sync 2>&1); code=$?
check "a plan with models and tiers syncs clean" '[ $code -eq 0 ] && ! grep -qiE "WARN.*(tier|model)" <<<"$out"'
check "state knows each coder model and tier" 'python3 -c "import json,sys;s=json.load(open(\".orchestrate/state.json\"));w=s[\"workers\"];sys.exit(not (w[\"claude-1\"][\"tier\"]==\"medium\" and w[\"codex-1\"][\"model\"]==\"gpt-6-luna\" and s[\"tasks\"][\"M1\"][\"tier\"]==\"medium\"))"'
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
printf '# Plan: t\nBranch: feature/es\nCheck command: test ! -f broken.txt\nIsolation: worktree\nMax parallel: 2\nWorkers: claude-1 (claude: sonnet), codex-1 (codex: gpt-6-luna)\nReviewer: none\n\n## [x] M18: Report\nDepends on: none\nTier: small\nModel why: looks mechanical.\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 180 "$ORCH" autopilot > "$WORK/es.log" 2>&1; code=$?
check "finished (exit 0)" '[ $code -eq 0 ]'
check "the small model ran out of rounds and the milestone moved up" 'grep -q "medium-tier model gets one fresh round" "$WORK/es.log"'
check "the stronger coder finished it" '"$ORCH" status | grep -q "M18 .*merged .*claude-1" && [ -f r.txt ]'
check "report shows each model and the escalation" '"$ORCH" report --json | python3 -c "import json,sys; m={x[\"model\"]:x for x in json.load(sys.stdin)[\"models\"]}; sys.exit(not (m[\"gpt-6-luna\"][\"escalated_away\"]==1 and m[\"sonnet\"][\"merged\"]==1))" && "$ORCH" report | grep -q "moved up"'
check "summary has the planned-vs-actual model table" 'grep -q "Models: planned and actual" .orchestrate/summary.md && grep -q "| M18 | small | gpt-6-luna (small), sonnet (medium) | yes |" .orchestrate/summary.md'

echo "23. the lead's event queue (no event manager running)"
newrepo ev; echo "$APP" > "$FH/lead.dir"
printf "${MPLAN/LEADLINE/Lead: lead (claude: opus)}" > .orchestrate/plan.md
"$ORCH" sync >/dev/null
check "ready milestones wait for the lead's dispatch" '"$ORCH" ready | grep -q "HOLD M1" && ! "$ORCH" ready | grep -q "^READY"'
out=$("$ORCH" dispatch M1 2>&1)
check "dispatch releases a milestone and names who can take it" 'grep -q "DISPATCH M1 -> claude-1 (tier medium)" <<<"$out" && "$ORCH" ready | grep -q "^READY M1"'
check "dispatch says the event manager is not running (autostart off in tests)" 'grep -q "event manager is NOT running" <<<"$out"'
"$ORCH" set M4 paused "which currency should totals use?" >/dev/null
check "a pause is queued for the lead with nobody listening" '"$ORCH" events --peek | grep -q "PAUSED M4 .*which currency"'
check "peek does not acknowledge" '"$ORCH" events --peek | grep -q "1 new"'
"$ORCH" events >/dev/null
check "reading acknowledges; the event stays open until the milestone moves on" '"$ORCH" events | grep -q "0 new, 1 still open"'
out=$("$ORCH" answer M4 "INR only" 2>&1)
check "answer writes the note into plan.md and requeues the milestone" 'grep -q "^- INR only" .orchestrate/plan.md && [ "$(status_of M4)" = pending ] && "$ORCH" ready | grep -q "^READY M4"'
check "the answered event is closed" '"$ORCH" events | grep -q "0 new, 0 still open"'
check "answer refuses a milestone that is not paused" '! "$ORCH" answer M1 "x" >/dev/null 2>&1'
check "sync keeps the queue and the dispatch" '"$ORCH" sync >/dev/null && "$ORCH" ready | grep -q "^READY M1"'

echo "24. event-driven run: the lead dispatches, pauses, is woken, answers, and the same coder carries on"
newrepo lr; echo "$APP" > "$FH/lead.dir"; echo "INR only" > "$FH/lead-answer"
printf "${MPLAN/LEADLINE/Lead: lead (claude: opus)}" > .orchestrate/plan.md
"$ORCH" sync >/dev/null && "$ORCH" dispatch M1 M4 >/dev/null
timeout 180 "$ORCH" autopilot > "$WORK/lr.log" 2>&1; code=$?
check "ALL_DONE with no human in between (exit 0)" '[ $code -eq 0 ] && [ "$(status_of M1)$(status_of M4)" = mergedmerged ]'
check "the lead was woken for the question" 'grep -q "woke the lead (lead)" "$WORK/lr.log" && grep -q "PAUSED M4" "$FH/lead-events.log"'
check "the answer reached plan.md and the task file" 'grep -q "^- INR only" .orchestrate/plan.md && [ -f d.txt ]'
check "the same coder got the milestone back" '[ "$(grep -c "^codex-1 <- .*M4/task.md" "$FH/prompts.log")" -eq 2 ] && ! grep -q "^claude-1 <- .*M4/" "$FH/prompts.log"'
check "the lead was woken at ALL_DONE and finished the summary" 'grep -q "ALL_DONE" "$FH/lead-events.log" && grep -q "check totals by hand" .orchestrate/summary.md'
check "no duplicate wake-ups: one per batch of events" '[ "$(wc -l < "$FH/lead-wakes.log")" -le 4 ]'
check "every event was delivered and read" 'python3 -c "import json,sys;s=json.load(open(\".orchestrate/state.json\"));sys.exit(any(not e[\"read\"] for e in s[\"lead_events\"]) or not s[\"lead_events\"])"'

echo "27. orch fix: a change after ALL_DONE goes straight to the coder who built it"
out=$("$ORCH" fix M1 "the model must also say hello" 2>&1); code=$?
check "fix adds a small follow-up milestone for the coder who built M1" '[ $code -eq 0 ] && grep -q "^FIX M5 .*-> claude-1" <<<"$out" && grep -q "^## \[x\] M5: Fix for M1: the model must also say hello" .orchestrate/plan.md'
check "the fix milestone says why it is separate, so sync does not warn about it" 'grep -q "^Why separate: a change the developer asked for after M1 landed" .orchestrate/plan.md && ! "$ORCH" sync 2>&1 | grep -q "M5 has no .Why separate"'
check "it is dispatched already and tied to that coder, with no new plan round" 'python3 -c "import json,sys;t=json.load(open(\".orchestrate/state.json\"))[\"tasks\"][\"M5\"];sys.exit(not (t[\"go\"] and t[\"assign\"]==\"claude-1\" and t[\"fix_of\"]==\"M1\" and t[\"deps\"]==[\"M1\"] and t[\"tier\"]==\"medium\"))" && "$ORCH" ready | grep -q "^READY M5"'
check "the plan with the fix in it still syncs, and keeps the dispatch" '"$ORCH" sync >/dev/null 2>&1 && "$ORCH" ready | grep -q "^READY M5"'
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
printf '# Plan: t\nBranch: feature/lw\nCheck command: true\nIsolation: worktree\nMax parallel: 2\nLead: lead (claude: opus)\nWorkers: claude-1 (claude: sonnet), codex-1 (codex: gpt-6-luna)\nReviewer: none\n\n## [x] M5: e\nDepends on: none\nOpen questions:\n- none\n\n## [x] M6: g\nDepends on: M5 (needs e)\nOpen questions:\n- none\n' > .orchestrate/plan.md
timeout 180 "$ORCH" autopilot > "$WORK/lw.log" 2>&1; code=$?
check "woken with READY, the lead dispatches each milestone as it unlocks" '[ $code -eq 0 ] && [ "$(status_of M5)$(status_of M6)" = mergedmerged ] && grep -q "orch dispatch M6" "$FH/lead-events.log"'
check "the event manager waited for the lead instead of stopping" 'grep -q "waiting for the lead: dispatch M5" "$WORK/lw.log" && ! grep -q "started without it" "$WORK/lw.log"'
newrepo lsil; echo "$APP" > "$FH/lead.dir"; touch "$FH/lead-deaf"
printf '# Plan: t\nBranch: feature/ls\nCheck command: true\nIsolation: worktree\nMax parallel: 2\nLead: lead (claude: opus)\nWorkers: claude-1 (claude: sonnet)\nReviewer: none\n\n## [x] M5: e\nDepends on: none\nOpen questions:\n- none\n' > .orchestrate/plan.md
ORCH_LEAD_WAIT_MIN=0 ORCH_LEAD_REWAKE_S=2 timeout 120 "$ORCH" autopilot > "$WORK/lsil.log" 2>&1; code=$?
check "a lead that never answers: ready work starts by itself" '[ $code -eq 0 ] && [ "$(status_of M5)" = merged ] && grep -q "M5: the lead did not dispatch it" "$WORK/lsil.log"'
check "its events are still in the queue, unread" '"$ORCH" events --peek | grep -q "AUTO-DISPATCHED M5" && "$ORCH" events --peek | grep -q "ALL_DONE"'
check "a wake-up nobody picked up is sent again, then the developer is told" 'grep -q "did not pick up its wake-up .*-> sent it again (2 of 3)" "$WORK/lsil.log" && grep -q "has not read its events after 3 wake-ups" "$WORK/lsil.log"'
check "status says the wake-up was not picked up" '"$ORCH" status | grep -q "wake-up sent 3x .*not picked up yet"'
# the bug report: the last wake-up of a run is lost in the lead's pane, and the event manager used to exit right after
newrepo llost; echo "$APP" > "$FH/lead.dir"; touch "$FH/lead-deaf-once"
printf '# Plan: t\nBranch: feature/ll\nCheck command: true\nIsolation: worktree\nLead: lead (claude: opus)\nWorkers: claude-1 (claude: sonnet)\nReviewer: none\n\n## [x] M5: e\nDepends on: none\nRole: senior backend engineer who cares about clear error messages\nAcceptance criteria:\n- e.txt exists\nOpen questions:\n- none\n' > .orchestrate/plan.md
"$ORCH" sync >/dev/null && "$ORCH" dispatch M5 >/dev/null
timeout 120 "$ORCH" autopilot > "$WORK/llost.log" 2>&1; code=$?
check "a lost wake-up at the end of a run is noticed and sent again before the event manager leaves" '[ $code -eq 0 ] && grep -q "did not pick up its wake-up" "$WORK/llost.log" && [ "$(wc -l < "$FH/lead-wakes.log")" -eq 2 ]'
check "the second wake-up became a turn: ALL_DONE was read and the log says so" 'grep -q "ALL_DONE" "$FH/lead-events.log" && grep -q "the lead (lead) picked up its events" "$WORK/llost.log" && "$ORCH" events --peek | grep -q "0 new"'
check "the summary lists what the run already checked, per acceptance criterion" 'grep -q "^## Checked automatically" .orchestrate/summary.md && grep -q "Check command \`true\` on the finished branch: PASS" .orchestrate/summary.md && grep -q "AC1 e.txt exists" .orchestrate/summary.md'
check "the summary asks for a manual checklist of only what a person must see or do" 'grep -q "Manual verification checklist: only what a person must see or do" .orchestrate/summary.md && grep -q "Checked by the lead" .orchestrate/summary.md'
check "the coder is given the role the lead wrote, in task.md and task.json" 'grep -q "For this task you are: \*\*senior backend engineer who cares about clear error messages\*\*" ../app-wt/claude-1/.orch-task/M5/task.md && grep -q "\"role\": \"senior backend engineer" ../app-wt/claude-1/.orch-task/M5/task.json'
check "the playbooks ask for a role per milestone and a by-hand-only checklist" 'grep -q "^Role:" "$ROOT/playbooks/plan.md" && grep -q "Checked by the lead" "$ROOT/playbooks/run.md"'
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
check "the lead gets an event on the first failure" '"$ORCH" events --peek | grep -qi "reviewer-lost M1 .*herdr agent rename <pane> reviewer"'
out=$("$ORCH" review M1 2>&1); code=$?
check "no new send while herdr still can't find the reviewer" '[ $code -eq 3 ] && grep -q "benched" <<<"$out"'
rm -f "$FH/reviewer.missing" "$FH/reviewer.deaf"
out=$("$ORCH" review M1 2>&1); code=$?
check "once the reviewer is found again the review goes out at once, no 2-minute wait" '[ $code -eq 0 ] && grep -q "SENT review M1 -> reviewer" <<<"$out"'

echo "11. installer puts the thin skills in every installed agent's folders"
FAKEBIN="$WORK/fakebin"; IH="$WORK/home"; mkdir -p "$FAKEBIN" "$IH"
for b in claude codex hermes agy; do printf '#!/bin/sh\n' > "$FAKEBIN/$b"; chmod +x "$FAKEBIN/$b"; done
SAFE_PATH="$FAKEBIN:/usr/local/bin:/usr/bin:/bin"
HOME="$IH" PATH="$SAFE_PATH" bash "$ROOT/install.sh" --no-herdr-skill > "$WORK/install.log" 2>&1; code=$?
check "installer ran" '[ $code -eq 0 ]'
check "skills in each installed agent's folder" '(for d in .claude/skills .codex/skills .hermes/skills .gemini/config/skills .agents/skills; do [ -f "$IH/$d/orch-plan/SKILL.md" ] && [ -f "$IH/$d/orch-run/SKILL.md" ] || exit 1; done)'
check "claude slash commands installed" '[ -f "$IH/.claude/commands/orch-plan.md" ] && grep -q "orch lead plan" "$IH/.claude/commands/orch-plan.md"'
check "agents that aren't installed are skipped" '[ ! -e "$IH/.config/agents/skills" ]'
check "installed skills are thin wrappers" 'grep -q "Run \`orch lead plan\`" "$IH/.hermes/skills/orch-plan/SKILL.md"'
check "playbooks installed" '[ -f "$IH/.local/share/herdr-orchestra/current/playbooks/plan.md" ]'
check "installer ran orch agents sync" 'grep -q "synced .* row" "$WORK/install.log"'

# a new agent installed later — no need to re-run the installer
printf '#!/bin/sh\n' > "$FAKEBIN/amp"; chmod +x "$FAKEBIN/amp"
out=$(HOME="$IH" PATH="$SAFE_PATH" "$ORCH" agents sync 2>&1); code=$?
check "orch agents sync picks up a newly installed agent" '[ $code -eq 0 ] && grep -qE "^ +NEW +amp" <<<"$out"'
check "it installs that agent's skills" '[ -f "$IH/.config/agents/skills/orch-plan/SKILL.md" ] && [ -f "$IH/.config/agents/skills/orch-run/SKILL.md" ]'
check "manifest records them for --uninstall" 'grep -q ".config/agents/skills/orch-plan" "$IH/.local/share/herdr-orchestra/manifest.txt"'
check "agents check passes after sync" 'HOME="$IH" PATH="$SAFE_PATH" "$ORCH" agents check >/dev/null 2>&1'
out=$(HOME="$IH" PATH="$SAFE_PATH" "$ORCH" agents sync 2>&1)
check "second sync is idempotent (ok, nothing NEW)" '[ -z "$(grep NEW <<<"$out")" ] && grep -qE "^ +ok +amp" <<<"$out"'
rm -rf "$IH/.config/agents/skills"
check "orch agents hints to sync when skills go missing" 'HOME="$IH" PATH="$SAFE_PATH" "$ORCH" agents 2>&1 | grep -q "orch agents sync"'
HOME="$IH" PATH="$SAFE_PATH" bash "$ROOT/install.sh" --uninstall > /dev/null 2>&1
check "uninstall removes them all" '[ -z "$(find "$IH" -name "orch-*")" ] && [ ! -e "$IH/.local/bin/orch" ]'

echo "12. one installed tool builds the whole team: orch team <kind>, orch team up"
out=$("$ORCH" team codex 2>&1)
check "team codex: 2 coders across the codex tiers + reviewer on the strongest" 'grep -q "^Workers: codex-1 (codex: gpt-6-luna), codex-2 (codex: gpt-6-sol)$" <<<"$out" && grep -q "^Reviewer: reviewer (codex: gpt-6-sol)$" <<<"$out"'
check "team codex says no high-tier codex model is allowed" 'grep -q "strongest allowed codex model is gpt-6-sol (medium tier)" <<<"$out"'
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
Lead: lead (codex: gpt-6-sol)
Workers: codex-1 (codex: gpt-6-luna), codex-2 (codex: gpt-6-sol)
Reviewer: reviewer (codex: gpt-6-sol)

## [x] M1: a
Depends on: none
Open questions:
- none
PLAN
"$ORCH" sync >/dev/null 2>&1
check "a plan with only codex panes (lead, 2 coders, reviewer) passes sync" '"$ORCH" sync 2>&1 | grep -q "^OK: 1 tasks"'
out=$("$ORCH" team up 2>&1); code=$?
check "team up before orch start asks for orch start (worktrees first)" '[ $code -ne 0 ] && grep -q "run \`orch start\` first" <<<"$out"'
touch "$FH/codex-2.missing" "$FH/reviewer.missing"
"$ORCH" start >/dev/null 2>&1
out=$("$ORCH" start 2>&1)
check "orch start shows the missing codex panes" 'grep -q "WORKER codex-2 .*herdr=NOT FOUND" <<<"$out" && grep -q "REVIEWER reviewer .*herdr=NOT FOUND" <<<"$out"'
out=$("$ORCH" team up --dry-run 2>&1)
check "team up --dry-run only prints the commands" 'grep -q "^WOULD   codex-2: .*pane split --direction right --cwd .*app-wt/codex-2 --no-focus" <<<"$out" && [ ! -f "$FH/team.log" ]'
out=$(ORCH_TEAM_WAIT_S=2 "$ORCH" team up 2>&1); code=$?
check "team up skips the agent that already runs" 'grep -q "^ok      codex-1: already running" <<<"$out"'
check "team up opens the coder in its own worktree, on its plan model" '[ $code -eq 0 ] && grep -q "^OPENED  codex-2: pane w1:p2 in .*app-wt/codex-2 running \`codex --approve-for-me --model gpt-6-sol\`" <<<"$out"'
check "the reviewer opens in the repo, below the coder, and is named" 'grep -q "split w1:p2 --direction down --cwd $APP --no-focus" "$FH/team.log" && grep -q "rename w1:p3 reviewer" "$FH/team.log"'
out=$("$ORCH" start 2>&1)
check "after team up every agent is found" '! grep -q "NOT FOUND" <<<"$out"'
out=$("$ORCH" team up 2>&1)
check "team up again is a no-op" 'grep -q "^TEAM UP: every agent in the plan is running" <<<"$out"'
touch "$FH/codex-2.missing" "$FH/nodetect"
out=$(ORCH_TEAM_WAIT_S=1 "$ORCH" team up 2>&1); code=$?
check "an agent herdr never detects is reported with the rename command (exit 3)" '[ $code -eq 3 ] && grep -q "^WAITING codex-2: .*herdr agent rename w1:p4 codex-2" <<<"$out"'
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

echo; echo "passed $pass, failed $fail"
[ $fail -eq 0 ]
