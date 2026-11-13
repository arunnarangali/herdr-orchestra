#!/usr/bin/env bash
# Fake worker for tests: parses the one-line prompt orch sends and acts out a scripted scenario.
agent=$1; dir=$2; prompt=$3; FH=${FH:?}
cd "$dir" || exit 1
if [[ $prompt == orch:* ]]; then                        # the lead being woken by the event manager
  echo "$prompt" >> "$FH/lead-wakes.log"
  [ -f "$FH/lead-deaf" ] && { echo idle > "$FH/$agent.status"; exit 0; }
  # the wake-up that never became a turn: the first prompt is lost in the pane, later ones arrive
  [ -f "$FH/lead-deaf-once" ] && { rm "$FH/lead-deaf-once"; echo idle > "$FH/$agent.status"; exit 0; }
  sleep 1
  out=$(ORCH_NO_AUTOSTART=1 "$ORCH_BIN" events 2>&1); printf '%s\n' "$out" >> "$FH/lead-events.log"
  # a scripted lead: answer a coder's question with what the developer said, dispatch what is ready
  for tid in $(grep -oE '^#[0-9]+ PAUSED M[0-9]+' <<<"$out" | grep -oE 'M[0-9]+'); do
    [ -f "$FH/lead-answer" ] && ORCH_NO_AUTOSTART=1 "$ORCH_BIN" answer "$tid" "$(cat "$FH/lead-answer")" >> "$FH/lead-events.log" 2>&1
  done
  ready=$(grep -oE 'orch dispatch M[0-9]+$' <<<"$out" | grep -oE 'M[0-9]+' | sort -u | tr '\n' ' ')
  # shellcheck disable=SC2086
  [ -n "$ready" ] && ORCH_NO_AUTOSTART=1 "$ORCH_BIN" dispatch $ready >> "$FH/lead-events.log" 2>&1
  grep -q "ALL_DONE" <<<"$out" && echo "- [ ] check totals by hand" >> .orchestrate/summary.md
  echo idle > "$FH/$agent.status"; exit 0
fi
file=$(grep -oE '(\.orch-task|\.orchestrate/review)/M[0-9]+/[a-z0-9-]+\.md' <<<"$prompt" | head -1)
report=$(grep -oE '\.orch-task/M[0-9]+/report-[0-9]+\.md' <<<"$prompt" | head -1)
result=$(grep -oE '\.orch-task/M[0-9]+/result-[0-9]+\.json' <<<"$prompt" | head -1)
done_=$(grep -oE '\.orch-task/M[0-9]+/done-[0-9]+' <<<"$prompt" | head -1)
tid=$(grep -oE 'M[0-9]+' <<<"$file" | head -1); base=$(basename "$file")
sleep 1
# finish "<report text>" [result json]: the report, the result file (derived from the report unless given), the done file
finish(){
  [ -n "$report" ] && printf '%s\n' "$1" > "$report"
  if [ -n "$result" ] && [ ! -f "$FH/noresult" ]; then
    if [ -n "${2:-}" ]; then printf '%s\n' "$2" > "$result"
    else python3 - "$1" "$result" <<'PY'
import json, sys
text, out = sys.argv[1], sys.argv[2]
q = [l.split(":", 1)[1].strip() for l in text.splitlines() if l.upper().startswith("QUESTION:")]
c = [l.split(":", 1)[1].strip() for l in text.splitlines() if l.upper().startswith("COMMIT:")]
json.dump({"status": "question" if q else "done", "commit": c[-1] if c else "", "files_changed": [],
           "check": {"ran": True, "passed": True}, "criteria": [], "questions": q,
           "usage": {"input_tokens": 1000, "output_tokens": 200}}, open(out, "w"))
PY
    fi
  fi
  [ -n "$done_" ] && touch "$done_"; echo idle > "$FH/$agent.status"; }
if [[ $file == .orchestrate/review/* ]]; then           # reviewer
  [ -f "$FH/slow-review" ] && sleep 4
  k=$(grep -oE 'review-task-[0-9]+' <<<"$base" | grep -oE '[0-9]+')
  out=.orchestrate/review/$tid/review-$k
  if [ "$tid" = M2 ] && [ "$k" = 1 ]; then
    if [ -f "$FH/review-md" ]; then echo "BLOCKER: b.txt must say validated" > $out.md; echo "SUGGESTION: add docs" >> $out.md
    else echo '{"verdict":"changes","criteria":[],"findings":[{"severity":"blocker","file":"b.txt","line":1,"problem":"b.txt must say validated","why":"AC1"},{"severity":"suggestion","file":"b.txt","line":1,"problem":"add docs","why":"readers"}]}' > $out.json; fi
  elif [ -f "$FH/review-md" ]; then echo "NO FINDINGS" > $out.md
  else echo '{"verdict":"approve","criteria":[],"findings":[]}' > $out.json; fi
  touch .orchestrate/review/$tid/done-$k; echo idle > "$FH/$agent.status"; exit 0
fi
# scenario hook: rate limit once for this agent+task
if [ -f "$FH/ratelimit-$agent-$tid" ]; then rm "$FH/ratelimit-$agent-$tid"; echo "partial" > partial-$tid.txt
  echo "Error: You've hit your usage limit. Try again in 3h." > "$FH/$agent.pane"; echo idle > "$FH/$agent.status"; exit 0; fi
case "$tid:$base" in
  M1:task.md) echo "M1 line" > shared.txt; echo a > a.txt; finish "built model
COMMIT: feat(model): add the category model";;
  M2:task.md) echo "M2 line" > shared.txt; echo b > b.txt; finish "built endpoint
COMMIT: feat(api): add the categories endpoint";;
  M2:review-fix-*) echo "b validated" > b.txt; finish "fixed blocker";;
  M2:conflict-*) git merge --no-commit "$(grep -oE 'git merge --no-commit [^`]+' "$file" | head -1 | cut -d' ' -f4)" >/dev/null 2>&1
                  printf 'M1 line\nM2 line\n' > shared.txt; git add shared.txt; finish "resolved";;
  M3:task.md) grep -q "M1 line" shared.txt && grep -q validated b.txt && echo deps-ok > c.txt; touch broken.txt; finish "built ui";;
  M3:fix-1.md) rm -f broken.txt; finish "fixed";;
  M4:task.md) if grep -q "INR only" .orch-task/M4/task.md; then echo d > d.txt; finish "built totals in INR"; else finish "QUESTION: which currency should totals use, INR or multi?"; fi;;
  M5:task.md) echo e > e.txt; finish "built e";;
  M6:task.md) echo g > g.txt; finish "built g";;
  M9:*) echo idle > "$FH/$agent.status";;
  M7:task.md) if [ ! -f "$FH/m7-once" ]; then touch "$FH/m7-once" "$FH/$agent.gone"; echo idle > "$FH/$agent.status"
                (sleep 3; rm -f "$FH/$agent.gone") & exit 0; fi
              echo h > h.txt; finish "built h";;
  M10:task.md) echo boom > boom.txt; finish "built boom";;
  M8:task.md) echo blocked > "$FH/$agent.status"; sleep 6; echo f > f.txt; finish "done after approval";;
  # dependency files: M11 changes the lockfile, M12 (after M11) must get a fresh setup, M13 sets a coder up early
  M11:task.md) echo '{"lockfileVersion": 3}' > package-lock.json; finish "added a dependency
COMMIT: build: add a dependency";;
  M12:task.md) echo l > l.txt; finish "built l";;
  M13:task.md) echo m > m.txt; finish "built m";;
  # an invalid result file first, a valid one after the result-fix prompt
  M14:task.md) echo n > n.txt; finish "built n" '{"status": "finished", "commit": 7}';;
  M14:result-fix-*) finish "rewrote the result";;
  # leaves its Likely files (scope check), then undoes it on the scope fix
  M15:task.md) echo o > o.txt; echo stray > stray.txt; finish "built o";;
  M15:scope-fix-*) rm -f stray.txt; finish "removed the stray file";;
  # deletes a tracked file: held for approval
  M16:task.md) git rm -q -f shared.txt; finish "removed shared.txt";;
  # says one acceptance criterion is not met, then meets it
  M17:task.md) echo p > p.txt; finish "built p" '{"status":"done","commit":"feat: p","criteria":[{"id":"AC1","met":false,"evidence":"no test yet"}]}';;
  # too hard for the small model: its checks keep failing until a stronger coder takes it over
  M18:task.md) echo r > r.txt; if [ "$agent" = codex-1 ]; then touch broken.txt; else rm -f broken.txt; fi; finish "built r";;
  M18:fix-*) finish "tried again";;
  M17:criteria-fix-*) echo t > p.test; finish "added the test" '{"status":"done","commit":"feat: p","criteria":[{"id":"AC1","met":true,"evidence":"p.test"}]}';;
  *) finish "nothing to do for $tid:$base";;
esac
