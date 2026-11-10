#!/usr/bin/env bash
# Fake worker for tests: parses the one-line prompt orch sends and acts out a scripted scenario.
agent=$1; dir=$2; prompt=$3; FH=${FH:?}
cd "$dir" || exit 1
file=$(grep -oE '(\.orch-task|\.orchestrate/review)/M[0-9]+/[a-z0-9-]+\.md' <<<"$prompt" | head -1)
report=$(grep -oE '\.orch-task/M[0-9]+/report-[0-9]+\.md' <<<"$prompt" | head -1)
done_=$(grep -oE '\.orch-task/M[0-9]+/done-[0-9]+' <<<"$prompt" | head -1)
tid=$(grep -oE 'M[0-9]+' <<<"$file" | head -1); base=$(basename "$file")
sleep 1
finish(){ [ -n "$report" ] && printf '%s\n' "$1" > "$report"; [ -n "$done_" ] && touch "$done_"; echo idle > "$FH/$agent.status"; }
if [[ $file == .orchestrate/review/* ]]; then           # reviewer
  [ -f "$FH/slow-review" ] && sleep 4
  k=$(grep -oE 'review-task-[0-9]+' <<<"$base" | grep -oE '[0-9]+')
  out=.orchestrate/review/$tid/review-$k.md
  if [ "$tid" = M2 ] && [ "$k" = 1 ]; then echo "BLOCKER: b.txt must say validated" > $out; echo "SUGGESTION: add docs" >> $out
  else echo "NO FINDINGS" > $out; fi
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
  *) finish "nothing to do for $tid:$base";;
esac
