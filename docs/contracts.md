# Contracts: what orch gives agents, and what it reads back

`.orchestrate/plan.md` is the source you edit. Everything below is generated from it or written by agents, and
`orch` validates what it reads. Files live in the milestone's task folder, `.orch-task/Mn/` inside the coder's
working folder (git-excluded), or in `.orchestrate/review/Mn/` for reviews.

## task.json (orch → coder, reviewer)

Written by `orch write-task Mn` next to `task.md`.

```json
{
  "schema": 1,
  "task_id": "M2",
  "title": "Categories endpoint",
  "kind": "task",
  "goal": "…",
  "why": "…",
  "acceptance_criteria": [{"id": "AC1", "text": "POST /upload returns 400 when the amount column is missing"}],
  "files_allowed": ["server/routes/categories.ts", "server/test/"],
  "scope": "warn",
  "tier": "medium",
  "needs": ["coding", "tool-use"],
  "interfaces": ["GET /categories -> [{id, name}]"],
  "constraints": [],
  "out_of_scope": [],
  "depends_on": [{"task": "M1", "title": "Shared types", "commit": "<sha of M1's commit on the feature branch>"}],
  "check": "npm test",
  "attempt": 1,
  "lost_attempts": 0,
  "previous_work": null,
  "result_format": { "…": "the shape of result-N.json, below" }
}
```

- `acceptance_criteria` are the plan's `Acceptance criteria:` lines, numbered in order.
- `files_allowed` is the plan's `Likely files:`. A path, a folder (`src/auth/`) or a glob (`src/auth/**`).
- `tier` and `needs` are the plan's `Tier:` and `Needs:` (null and empty when the plan has none).
- `previous_work` is `{"by": "<coder>"}` when an earlier attempt left work in the folder.
- A fix, review-fix, conflict or integration-fix job also gets a small `job-N.json` (`kind`, `file`).

## result-N.json (coder → orch)

The prompt names the exact file. `N` is the attempt number.

```json
{
  "status": "done",
  "commit": "feat(api): add the categories endpoint",
  "files_changed": ["server/routes/categories.ts", "server/test/categories.test.ts"],
  "check": {"ran": true, "passed": true, "summary": "lint ok, 42 tests pass"},
  "criteria": [{"id": "AC1", "met": true, "evidence": "test 'rejects a missing amount column' passes"}],
  "questions": [],
  "usage": {"input_tokens": 182000, "output_tokens": 9400, "cost_usd": 1.12}
}
```

What orch does with it:

| Field | Rule |
|---|---|
| `status` | Required: `done`, `question` or `blocked`. `question`/`blocked` pause the milestone with `questions`. |
| `commit` | Becomes the commit subject (falls back to the report's `COMMIT:` line, then the milestone title). |
| `criteria` | Each entry needs `id` and `met` (true/false). Any `met: false` sends the milestone back for a fix round. |
| `usage` | Optional. Only what the agent's own tool reports; `orch report` sums it and says "unknown" otherwise. |
| invalid JSON or shape | One request to rewrite it; a second invalid file pauses the milestone. |
| no file at all | The short `report-N.md` is parsed as before (`QUESTION:`, `COMMIT:`). |

orch does not trust `files_changed` or `check`: it compares the real diff with `files_allowed` and runs the
check command itself, in the coder's folder and again on the merged result before committing.

## review-N.json (reviewer → orch)

```json
{
  "verdict": "changes",
  "criteria": [{"id": "AC1", "met": false, "note": "no test covers the missing column"}],
  "findings": [
    {"severity": "blocker", "file": "server/routes/upload.ts", "line": 42,
     "problem": "the amount column is read before it is validated", "why": "throws a 500", "criterion": "AC1"},
    {"severity": "suggestion", "file": "server/routes/upload.ts", "line": 10, "problem": "…", "why": "…"}
  ]
}
```

A `blocker` finding or an unmet criterion becomes a problem-only fix job for a coder. Suggestions go into the
summary. Without the JSON file, `review-N.md` lines starting `BLOCKER:`, `SUGGESTION:` or `NO FINDINGS` are read.

## events.jsonl (orch → you)

One line per status change, written when the state that contains it is saved:

```json
{"ts": 1731250000, "task": "M2", "from": "verifying", "to": "reviewing", "why": "", "agent": "codex-1", "attempt": 1}
```

Replaying the file gives every task's current status. `"forced": true` marks `orch sync` rebuilding state from
the plan, or a manual `orch set … --force`.

## The lead's event queue (orch → lead)

With a `Lead:` line in the plan (and not `Lead mode: off`), every change the lead should hear about is stored in
`state.json` under `lead_events`, in the same write as the change that caused it:

```json
{"id": 7, "ts": 1731250000, "kind": "paused", "task": "M2", "text": "skip empty rows or reject the file?", "read": null}
```

| `kind` | Raised when | Open until |
|---|---|---|
| `paused`, `failed`, `held`, `needs-answer` | a milestone enters that status | the milestone leaves it |
| `merged` | a milestone lands | read |
| `ready` | milestones are waiting for `orch dispatch` | read, or nothing is left to dispatch |
| `escalated`, `auto-dispatched` | orch moved a milestone to a stronger model, or started one the lead did not dispatch in time | read |
| `reviewer-lost` | a review prompt could not reach the reviewer (first failure, and again after `ORCH_UNREACHABLE_AFTER`); the text has the rename fix | read |
| `all_done` | every milestone has landed | read |

`orch events` prints the unread and still-open events and marks the unread ones read (`--peek` does not). The
event manager wakes the lead with one prompt per batch, only when the lead is idle, and again after
`ORCH_LEAD_REWAKE_S` if the batch was never read. The lead's requests are fields on the task, set under the state
lock and carried out by the event manager: `go` (dispatched), `assign` (one coder, for the next dispatch),
`min_tier` (a stronger model than the plan asked for).

Each attempt in a task's `attempts` list carries the `model` and `tier` of the agent that made it, which is where
the summary's model table and `orch report`'s per-model rows come from.
