// One example run (CSV import), shared by the run log panel and the terminal simulation.
// Message formats come from bin/orch: `orch sync`, `orch plan show`, `orch dispatch`, the event manager's
// log (`orch autopilot`), the lead's SAY lines and `orch finish`.

/** [time, message, css class] lines of .orchestrate/autopilot.log */
export const autopilotLines: [string, string, string?][] = [
  ['14:02:11', "autopilot started: worktree mode, max 2 parallel, workers ['claude-1 (sonnet)', 'claude-2 (haiku)']; events go to the lead (lead)", 't-dim'],
  ['14:02:12', 'M1 -> claude-1', 't-coder'],
  ['14:08:40', 'M1 done by claude-1 -> running checks'],
  ['14:09:05', 'M1 checked and merged into feature/csv-import', 't-ok'],
  ['14:09:06', 'woke the lead (lead): 2 event(s) — merged M1, ready', 't-lead'],
  ['14:09:31', 'M2 -> claude-1', 't-coder'],
  ['14:09:31', 'M3 -> claude-2', 't-coder'],
  ['14:17:48', 'M3 done by claude-2 -> running checks'],
  ['14:18:20', 'M3 checks failed -> fix round 1', 't-bad'],
  ['14:21:02', 'M2 paused: skip empty rows or reject the file?', 't-bad'],
  ['14:21:03', 'woke the lead (lead): 1 event(s) — paused M2', 't-lead'],
  ['14:24:40', 'M2 -> claude-1', 't-coder'],
  ['14:26:51', 'M3 checked and merged into feature/csv-import', 't-ok'],
  ['14:33:15', 'M2 review: 1 blocker(s) -> fix job queued (first free coder)', 't-bad'],
  ['14:33:16', 'M2 fix job -> claude-1', 't-coder'],
  ['14:41:10', 'M2 review passed', 't-ok'],
  ['14:41:11', 'M2 checked and merged into feature/csv-import', 't-ok'],
  ['14:41:12', 'woke the lead (lead): 2 event(s) — merged M2, ready', 't-lead'],
  ['14:41:40', 'M4 -> claude-2', 't-coder'],
  ['14:52:30', 'M4 checked and merged into feature/csv-import', 't-ok'],
  ['14:53:04', 'woke the lead (lead): 1 event(s) — all_done', 't-lead'],
  ['14:53:05', 'ALL_DONE on feature/csv-import — final check PASS. See .orchestrate/summary.md', 't-ok'],
];

export const finishLines: [string, string?][] = [
  ['CLEAN feature/csv-import is the only branch this run made (4 hidden ref(s) removed)'],
  ['PUSHED feature/csv-import to origin', 't-lead'],
  ['PR https://github.com/you/app/pull/42', 't-ok'],
];

/** A line of the terminal simulation. `prompt` makes it a typed command. */
export type SimLine = { stage: number; text: string; cls?: string; prompt?: string };

const pick = (...times: string[]) =>
  autopilotLines.filter(([t]) => times.includes(t)).map(([t, m, c]) => ({ stage: 2, text: `[${t}] ${m}`, cls: c }));

export const simLines: SimLine[] = [
  // 01 · the plan
  { stage: 0, prompt: 'lead ›', text: '/orch-plan CSV import for transactions' },
  { stage: 0, text: 'Researching server/routes, web/src/pages', cls: 't-dim' },
  { stage: 0, text: 'Writing .orchestrate/plan.md: 4 milestones, a tier and a reason for each', cls: 't-dim' },
  { stage: 0, prompt: '$', text: 'orch sync' },
  { stage: 0, text: "OK: 4 tasks, isolation=worktree, max_parallel=2, workers=['claude-1', 'claude-2'], reviewer=reviewer, lead=lead", cls: 't-ok' },
  // 02 · you read it and say go
  { stage: 1, prompt: '$', text: 'orch plan show' },
  { stage: 1, text: 'PLAN in plain words: CSV import for transactions — 4 milestone(s) on feature/csv-import, about 1h10m in all', cls: 't-lead' },
  { stage: 1, text: 'M1 Shared ImportRow type' },
  { stage: 1, text: 'M2 Import endpoint — users upload a bank CSV and get rows back' },
  { stage: 1, text: 'M3 Import page' },
  { stage: 1, text: 'M4 Wire the page to the endpoint' },
  { stage: 1, prompt: 'you ›', text: 'go' },
  // 03 · the run
  { stage: 2, prompt: 'lead ›', text: '/orch-run' },
  { stage: 2, prompt: '$', text: 'orch dispatch M1' },
  { stage: 2, text: 'DISPATCH M1 -> claude-1 (tier high)' },
  { stage: 2, text: 'started the event manager (`orch autopilot`, log: .orchestrate/autopilot.log)', cls: 't-dim' },
  ...pick('14:02:12', '14:08:40', '14:09:05', '14:09:06'),
  { stage: 2, text: '    SAY: M1 (Shared ImportRow type) is done: its check passed, and it is on feature/csv-import.', cls: 't-lead' },
  ...pick('14:09:31', '14:18:20', '14:21:02', '14:21:03'),
  { stage: 2, prompt: '$', text: 'orch answer M2 "skip empty rows"' },
  ...pick('14:24:40', '14:26:51', '14:33:15', '14:41:10', '14:41:11', '14:52:30', '14:53:05'),
  // 04 · the pull request
  { stage: 3, prompt: '$', text: 'orch finish' },
  ...finishLines.map(([text, cls]) => ({ stage: 3, text, cls })),
];
