// The six states one milestone passes through, for the stage inspector under the run diagrams.
// Commands, wake-up texts and diary lines are copied from bin/orch (cmd_dispatch, cmd_send, cmd_review,
// cmd_answer, cmd_defer, cmd_approve, wake_lead, say_line, story_lines) for the CSV import example run.

export type StageId = 'PLAN_READY' | 'DISPATCHED' | 'CODING' | 'REVIEW_AUDIT' | 'GATE_HOLD' | 'MERGED';

export interface Stage {
  id: StageId;
  /** What happens in this state, one line. */
  what: string;
  /** Commands run here; the first is the main one. */
  cmds: string[];
  /** What orch prints for the main command. */
  out: string;
  /** Which role is woken. */
  wakes: 'lead' | 'coder' | 'reviewer';
  /** The exact text that role receives (shortened with … only where marked). */
  context: string;
  /** The line this state adds to `orch story` (.orchestrate/story.md). */
  story: string;
}

export const stages: Stage[] = [
  {
    id: 'PLAN_READY',
    what: 'The plan is parsed and shown to you. Nothing runs until you say go.',
    cmds: ['orch sync', 'orch plan show'],
    out: 'PLAN in plain words: CSV import for transactions — 4 milestone(s) on feature/csv-import, about 1h10m in all',
    wakes: 'lead',
    context: 'Your reply in its own pane: "go". The lead then runs /orch-run.',
    story: '14:02  what happened: Ready to start: M1 (Shared ImportRow type).',
  },
  {
    id: 'DISPATCHED',
    what: 'The lead hands out ready milestones and pauses. The event manager picks a free coder of the right tier.',
    cmds: ['orch dispatch M2 M3'],
    out: 'DISPATCH M2 -> claude-1 or claude-2 (tier medium)',
    wakes: 'coder',
    context:
      'Read .orch-task/M2/task.md and carry it out exactly (the milestone\'s contract is .orch-task/M2/task.json). When completely finished, write .orch-task/M2/result-1.json … then create the empty file .orch-task/M2/done-1 as your very last action.',
    story: '14:09  the lead did: M2 (Import endpoint) was sent to start',
  },
  {
    id: 'CODING',
    what: 'The coder works in its own worktree. Checks run on done. A question pauses the milestone and wakes the lead.',
    cmds: ['orch answer M2 "skip empty rows"'],
    out: 'ANSWERED M2: written to plan.md; it goes back to claude-1 with its work so far',
    wakes: 'lead',
    context: 'orch: 1 new event(s) in the run on feature/csv-import need the lead. Run `orch events` and handle what it prints, then stop.',
    story: '16:13  the lead did: M2 (Import endpoint) got the answer "skip empty rows" and goes back to claude-1',
  },
  {
    id: 'REVIEW_AUDIT',
    what: 'The reviewer reads the diff from the merge-base. It never edits code. A blocker becomes a fix job.',
    cmds: ['orch review M2', 'orch answer M2 --defer AC3 "preview comes later"'],
    out: 'DEFERRED M2 AC3: no fix rounds for them; the summary lists them as not done (follow-up)',
    wakes: 'reviewer',
    context:
      'Read .orchestrate/review/M2/review-task-1.md and do exactly what it says. (Spec: task.md · Changes: diff.patch · Do NOT edit any code.)',
    story: '16:22  the lead did: M2 (Import endpoint): AC3 left undone, as you approved (preview comes later)',
  },
  {
    id: 'GATE_HOLD',
    what: 'A risky change (migration, CI, secrets, a large diff) stops before it lands until you approve it.',
    cmds: ['orch approve M2'],
    out: 'APPROVED M2: it lands on the next autopilot step (or `orch merge M2`)',
    wakes: 'lead',
    context: 'orch: 1 new event(s) in the run on feature/csv-import need the lead. Run `orch events` and handle what it prints, then stop.',
    story:
      '16:30  what happened: M2 (Import endpoint) is finished but waits for your OK, because it has a risky change: database migration: server/migrations/0042_imports.sql.',
  },
  {
    id: 'MERGED',
    what: 'Checks passed and the review is clean: one commit lands on the feature branch. The lead is woken with the batch.',
    cmds: ['orch merge M2'],
    out: 'MERGED M2 into feature/csv-import',
    wakes: 'lead',
    context: 'orch: 2 new event(s) in the run on feature/csv-import need the lead. Run `orch events` and handle what it prints, then stop.',
    story: '16:30  what happened: M2 (Import endpoint) is done: its check passed and the reviewer approved it, and it is on feature/csv-import.',
  },
];
