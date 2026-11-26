// One example run (CSV import), shared by the run log panel and the terminal simulation.
// Message formats come from bin/orch: `orch sync`, `orch plan show`, `orch dispatch`, the event manager's
// log (`orch autopilot`), the lead's SAY lines and `orch finish`.

/** [time, message, css class] lines of .orchestrate/autopilot.log. The laptop sleeps from 14:22:20 to 16:11:20:
 *  the event manager notices the gap and no task is charged for it (bin/orch account_downtime). */
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
  ['16:11:20', 'the computer was asleep for 1h49m: that time is not counted against any task', 't-dim'],
  ['16:13:40', 'M2 -> claude-1', 't-coder'],
  ['16:15:51', 'M3 checked and merged into feature/csv-import', 't-ok'],
  ['16:22:15', 'M2 review: 1 blocker(s) -> fix job queued (first free coder)', 't-bad'],
  ['16:22:16', 'M2 fix job -> claude-1', 't-coder'],
  ['16:30:10', 'M2 review passed', 't-ok'],
  ['16:30:11', 'M2 checked and merged into feature/csv-import', 't-ok'],
  ['16:30:12', 'woke the lead (lead): 2 event(s) — merged M2, ready', 't-lead'],
  ['16:30:40', 'M4 -> claude-2', 't-coder'],
  ['16:41:30', 'M4 checked and merged into feature/csv-import', 't-ok'],
  ['16:42:04', 'woke the lead (lead): 1 event(s) — all_done', 't-lead'],
  ['16:42:05', 'ALL_DONE on feature/csv-import — final check PASS. See .orchestrate/summary.md', 't-ok'],
];

/** Start of the run and the one window orch was not watching (seconds since midnight). */
const hms = (t: string) => t.split(':').reduce((a, x) => a * 60 + Number(x), 0);
export const RUN_START = hms('14:02:11');
export const ASLEEP = { from: hms('14:22:20'), to: hms('16:11:20') };

export const finishLines: [string, string?][] = [
  ['CLEAN feature/csv-import is the only branch this run made (4 hidden ref(s) removed)'],
  ['PUSHED feature/csv-import to origin', 't-lead'],
  ['PR https://github.com/you/app/pull/42', 't-ok'],
];

export type PaneId = 'lead' | 'claude-1' | 'claude-2' | 'reviewer';
export type PaneState = 'idle' | 'working' | 'paused' | 'reviewing' | 'asleep';
export type MsState = 'planned' | 'building' | 'checks' | 'fix' | 'question' | 'review' | 'merged';
export type Ms = 'M1' | 'M2' | 'M3' | 'M4' | 'PR';

/** A line of the terminal simulation. `prompt` makes it a typed command. `at` is the log's clock; `pane` and
 *  `ms` say what changed at this line (for the timeline scrubber and the branch diagram). */
export type SimLine = {
  stage: number; text: string; cls?: string; prompt?: string; at?: string;
  pane?: Partial<Record<PaneId, [PaneState, string]>>;
  ms?: Partial<Record<Ms, [MsState, string?]>>;
};

const log = (time: string, fx: Omit<SimLine, 'stage' | 'text' | 'cls' | 'at'> = {}, nth = 0): SimLine => {
  const [t, m, c] = autopilotLines.filter(([x]) => x === time)[nth];
  return { stage: 2, text: `[${t}] ${m}`, cls: c, at: t, ...fx };
};

export const simLines: SimLine[] = [
  // 01 · the plan
  { stage: 0, prompt: 'lead ›', text: '/orch-plan CSV import for transactions', pane: { lead: ['working', 'planning: CSV import'] } },
  { stage: 0, text: 'Researching server/routes, web/src/pages', cls: 't-dim', pane: { lead: ['working', 'reading server/routes, web/src/pages'] } },
  { stage: 0, text: 'Writing .orchestrate/plan.md: 4 milestones, a tier and a reason for each', cls: 't-dim',
    pane: { lead: ['working', 'writing .orchestrate/plan.md'] }, ms: { M1: ['planned'], M2: ['planned'], M3: ['planned'], M4: ['planned'] } },
  { stage: 0, prompt: '$', text: 'orch sync' },
  { stage: 0, text: "OK: 4 tasks, isolation=worktree, max_parallel=2, workers=['claude-1', 'claude-2'], reviewer=reviewer, lead=lead", cls: 't-ok',
    pane: { lead: ['paused', 'plan ready: waiting for your go'] } },
  // 02 · you read it and say go
  { stage: 1, prompt: '$', text: 'orch plan show' },
  { stage: 1, text: 'PLAN in plain words: CSV import for transactions — 4 milestone(s) on feature/csv-import, about 1h10m in all', cls: 't-lead' },
  { stage: 1, text: 'M1 Shared ImportRow type' },
  { stage: 1, text: 'M2 Import endpoint — users upload a bank CSV and get rows back' },
  { stage: 1, text: 'M3 Import page' },
  { stage: 1, text: 'M4 Wire the page to the endpoint' },
  { stage: 1, prompt: 'you ›', text: 'go', pane: { lead: ['working', 'you said go'] } },
  // 03 · the run
  { stage: 2, prompt: 'lead ›', text: '/orch-run' },
  { stage: 2, prompt: '$', text: 'orch dispatch M1' },
  { stage: 2, text: 'DISPATCH M1 -> claude-1 (tier high)' },
  { stage: 2, text: 'started the event manager (`orch autopilot`, log: .orchestrate/autopilot.log)', cls: 't-dim', at: '14:02:11',
    pane: { lead: ['paused', 'dispatched M1, waits for events'] } },
  log('14:02:12', { pane: { 'claude-1': ['working', 'M1 in ~/app-wt/claude-1'] }, ms: { M1: ['building', 'claude-1'] } }),
  log('14:08:40', { pane: { 'claude-1': ['idle', 'M1 done-1 written'] }, ms: { M1: ['checks'] } }),
  log('14:09:05', { ms: { M1: ['merged'] } }),
  log('14:09:06', { pane: { lead: ['working', 'woken: merged M1, ready'] } }),
  { stage: 2, text: '    SAY: M1 (Shared ImportRow type) is done: its check passed, and it is on feature/csv-import.', cls: 't-lead',
    pane: { lead: ['paused', 'dispatched M2 M3, waits'] } },
  log('14:09:31', { pane: { 'claude-1': ['working', 'M2 in ~/app-wt/claude-1'] }, ms: { M2: ['building', 'claude-1'] } }, 0),
  log('14:09:31', { pane: { 'claude-2': ['working', 'M3 in ~/app-wt/claude-2'] }, ms: { M3: ['building', 'claude-2'] } }, 1),
  log('14:18:20', { pane: { 'claude-2': ['working', 'M3 fix round 1'] }, ms: { M3: ['fix', 'claude-2'] } }),
  log('14:21:02', { pane: { 'claude-1': ['idle', 'QUESTION: skip empty rows or reject?'] }, ms: { M2: ['question'] } }),
  log('14:21:03', { pane: { lead: ['working', 'woken: M2 asks a question'] } }),
  log('16:11:20', { pane: { 'claude-2': ['working', 'M3 fix round 1, after the sleep'] } }),
  { stage: 2, prompt: '$', text: 'orch answer M2 "skip empty rows"', at: '16:13:12', pane: { lead: ['paused', 'answered M2, waits'] } },
  log('16:13:40', { pane: { 'claude-1': ['working', 'M2 again, with the answer'] }, ms: { M2: ['building', 'claude-1'] } }),
  log('16:15:51', { pane: { 'claude-2': ['idle', 'M3 merged'] }, ms: { M3: ['merged'] } }),
  log('16:22:15', { pane: { reviewer: ['idle', 'BLOCKER parse.ts:41: 500, must be 400'], 'claude-1': ['idle', 'M2 done, waits for review'] }, ms: { M2: ['review'] } }),
  log('16:22:16', { pane: { 'claude-1': ['working', 'M2 fix job'] }, ms: { M2: ['fix', 'claude-1'] } }),
  log('16:30:10', { pane: { reviewer: ['idle', 'M2 round 2: no blockers'], 'claude-1': ['idle', 'M2 fix done'] }, ms: { M2: ['review'] } }),
  log('16:30:11', { ms: { M2: ['merged'] } }),
  log('16:30:40', { pane: { 'claude-2': ['working', 'M4 in ~/app-wt/claude-2'] }, ms: { M4: ['building', 'claude-2'] } }),
  log('16:41:30', { pane: { 'claude-2': ['idle', 'M4 merged'] }, ms: { M4: ['merged'] } }),
  log('16:42:05', { pane: { lead: ['working', 'ALL_DONE: writing summary.md'] } }),
  // 04 · the pull request
  { stage: 3, prompt: '$', text: 'orch finish' },
  ...finishLines.map(([text, cls], i) => ({ stage: 3, text, cls, ...(i === finishLines.length - 1
    ? { pane: { lead: ['idle', 'PR #42 open'] as [PaneState, string] }, ms: { PR: ['merged'] as [MsState] } } : {}) })),
];

/** Where the run stands after each line: pane states, milestones, the log clock and the two time counters. */
export type Frame = {
  panes: Record<PaneId, [PaneState, string]>;
  ms: Record<Ms, [MsState, string?] | null>;
  clock: string;
  /** seconds of working time so far (asleep time left out) */
  active: number;
  /** seconds orch was not watching (not counted against any task) */
  down: number;
};

export const frames = (lines: SimLine[]): Frame[] => {
  let f: Frame = {
    panes: { lead: ['idle', 'waiting for /orch-plan'], 'claude-1': ['idle', ''], 'claude-2': ['idle', ''], reviewer: ['idle', ''] },
    ms: { M1: null, M2: null, M3: null, M4: null, PR: null },
    clock: '', active: 0, down: 0,
  };
  return lines.map((l) => {
    const panes = { ...f.panes, ...l.pane } as Frame['panes'];
    const ms = { ...f.ms };
    for (const [k, v] of Object.entries(l.ms ?? {}) as [Ms, [MsState, string?]][]) ms[k] = [v[0], v[1] ?? ms[k]?.[1]];
    let { clock, active, down } = f;
    if (l.at) {
      const t = hms(l.at);
      clock = l.at;
      down = t >= ASLEEP.to ? ASLEEP.to - ASLEEP.from : 0;
      active = t - RUN_START - down;
    }
    f = { panes, ms, clock, active, down };
    return f;
  });
};
