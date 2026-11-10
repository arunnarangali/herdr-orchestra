#!/usr/bin/env bash
# End-to-end tests for orch + autopilot, using a fake herdr and fake workers. No AI, no network.
# shellcheck disable=SC2034  # variables are read inside the eval strings passed to check()
#   bash tests/run.sh
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ORCH="$ROOT/bin/orch"
export HERDR="$ROOT/tests/sim/herdr" ORCH_POLL_STEP_S=1 ORCH_IDLE_GRACE_S=4
WORK=$(mktemp -d); trap 'pkill -f -- "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
export ORCH_AGENTS_FILE="$WORK/user-agents.toml"   # keep the developer's own agents.toml out of the tests
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
check "more than 4 milestones warns" '"$ORCH" sync | grep -q "5 enabled milestones"'
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
check "lead run prints version line + playbook" 'grep -q "lead playbook: run" <<<"$out" && grep -q "Scheduler loop" <<<"$out"'
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
check "Lead header stored by sync" '[ $code -eq 0 ] && python3 -c "import json,sys;l=json.load(open(\".orchestrate/state.json\"))[\"lead\"];sys.exit(l!={\"name\":\"lead\",\"kind\":\"claude\"})"'
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
timeout 60 "$ORCH" autopilot > "$WORK/ib.log" 2>&1; code=$?
check "integration check failure stops the run" '[ $code -eq 3 ] && grep -q "Integration branch check FAILED" "$WORK/ib.log"'
timeout 60 "$ORCH" autopilot > "$WORK/ib2.log" 2>&1; code=$?
check "next run re-checks and stops while still broken" '[ $code -eq 3 ] && grep -q "still fails its check" "$WORK/ib2.log"'
git rm -q boom.txt && git commit -qm "fix: remove boom"
timeout 60 "$ORCH" autopilot > "$WORK/ib3.log" 2>&1; code=$?
check "after the fix it carries on" '[ $code -eq 0 ] && grep -q "passes its check again" "$WORK/ib3.log"'

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

echo; echo "passed $pass, failed $fail"
[ $fail -eq 0 ]
