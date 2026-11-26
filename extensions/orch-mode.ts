// herdr-orchestra for Pi (https://pi.dev): shows which orch mode this window is in and lets you switch it.
//
//   panes     (default) coders and the reviewer run in herdr panes; the lead uses `orch dispatch`
//   subagent  one Pi window: the lead starts the coder and the reviewer as Pi subagents (@tintinweb/pi-subagents)
//
// Only Pi loads this file (package.json "pi".extensions). Claude Code, Codex, OpenCode and the other agents never
// read it, and `npx herdr-orchestra` ignores it.
//
// Where the mode comes from: this repo's run (.orchestrate/state.json, `orch_mode`; a run from before 6.2.0 is
// panes), else ~/.config/herdr-orchestra/config.json (`mode`), else panes.
//
// Commands:  /orch-mode [panes|subagent]       show or switch the mode; `subagent` also sets it up (below)
//            /orch-setup [--mode panes|subagent] install the `orch` command from this package (needed once)
//
// Tool:      orch_ask                            the lead's clickable questions before it writes the plan (/orch-plan
//                                                step 2a): one picker per question, answers saved in
//                                                .orchestrate/questions.md. Pi has no question tool of its own.
//
// Subagent mode is set up from inside Pi, with no terminal step: `/orch-mode subagent` runs
// `orch setup --mode subagent` (or this package's installer when orch is missing or old), which writes
// ~/.pi/agent/agents/coder.md and reviewer.md and runs `pi install npm:@tintinweb/pi-subagents`. When that install
// is new, the command reloads Pi (ctx.reload) so the Agent tool is there at once.
import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { appendFileSync, existsSync, mkdirSync, readFileSync, renameSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

type Mode = "panes" | "subagent";
const MODES: Mode[] = ["panes", "subagent"];
const STATUS_KEY = "orch";
/** `orch setup` result lines (bin/orch pi_setup and set_mode). */
const SETUP_LINE = /^(WROTE|ok |KEPT|REFUSED|NO PI|INSTALL|INSTALLED|FAILED|mode:|mode panes:|this repo|NOT CHANGED|run it yourself)/;

function packageRoot(): string {
  const here = typeof __dirname !== "undefined" ? __dirname : dirname(fileURLToPath(import.meta.url));
  return resolve(here, "..");
}

function configFile(): string {
  return process.env.ORCH_CONFIG_FILE || join(homedir(), ".config", "herdr-orchestra", "config.json");
}

function readJson(path: string): Record<string, unknown> | undefined {
  try {
    const data = JSON.parse(readFileSync(path, "utf8"));
    return data && typeof data === "object" && !Array.isArray(data) ? data : undefined;
  } catch {
    return undefined;
  }
}

function asMode(value: unknown): Mode | undefined {
  return typeof value === "string" && (MODES as string[]).includes(value.toLowerCase())
    ? (value.toLowerCase() as Mode)
    : undefined;
}

/** .orchestrate/state.json of the repo that holds cwd (orch keeps it in the main checkout, not in worktrees). */
async function stateFile(pi: ExtensionAPI, cwd: string): Promise<string | undefined> {
  try {
    const r = await pi.exec("git", ["rev-parse", "--path-format=absolute", "--git-common-dir"], { cwd, timeout: 5000 });
    if (r.code === 0 && r.stdout.trim()) {
      const p = join(dirname(r.stdout.trim()), ".orchestrate", "state.json");
      return existsSync(p) ? p : undefined;
    }
  } catch {
    // not a git repo, or no git: no run here
  }
  return undefined;
}

/** The main checkout's .orchestrate folder (the same place as stateFile(), also from a worktree); cwd's when no git. */
async function orchestrateDir(pi: ExtensionAPI, cwd: string): Promise<string> {
  try {
    const r = await pi.exec("git", ["rev-parse", "--path-format=absolute", "--git-common-dir"], { cwd, timeout: 5000 });
    if (r.code === 0 && r.stdout.trim()) return join(dirname(r.stdout.trim()), ".orchestrate");
  } catch {
    // no git: use cwd
  }
  return join(cwd, ".orchestrate");
}

type AskOption = { key: string; label: string; description?: string; recommended?: boolean };
type AskQuestion = { id: string; question: string; options: AskOption[]; allow_custom?: boolean };
type AskParams = { title?: string; questions: AskQuestion[] };
type AskAnswer = { id: string; question: string; key: string; label: string; custom: boolean };

const CUSTOM = "Custom answer...";

/** orch_ask's parameters, as plain JSON Schema (Pi validates JSON Schema; no typebox import needed). */
const ASK_SCHEMA = {
  type: "object",
  properties: {
    title: { type: "string", description: 'Short header, e.g. "Decisions before planning"' },
    questions: {
      type: "array",
      minItems: 1,
      maxItems: 8,
      description: "The decisions only the developer can make, asked one after another",
      items: {
        type: "object",
        properties: {
          id: { type: "string", description: "q1, q2, ..." },
          question: { type: "string", description: "One clear question" },
          options: {
            type: "array",
            minItems: 1,
            maxItems: 6,
            items: {
              type: "object",
              properties: {
                key: { type: "string", description: "a, b, c" },
                label: { type: "string", description: "The choice, in a few words" },
                description: { type: "string", description: "Optional: what it means, from what you found" },
                recommended: { type: "boolean", description: "true on your suggested choice (one per question)" },
              },
              required: ["key", "label"],
            },
          },
          allow_custom: { type: "boolean", description: 'Adds "Custom answer..." (default true)' },
        },
        required: ["id", "question", "options"],
      },
    },
  },
  required: ["questions"],
} as const;

function optionLine(o: AskOption): string {
  return `(${o.key}) ${o.label}${o.recommended ? " [Recommended]" : ""}${o.description ? ` - ${o.description}` : ""}`;
}

/** The questions and answers as markdown for .orchestrate/questions.md (questions with choices, then ## Answers). */
function questionsMarkdown(p: AskParams, answers: AskAnswer[]): string {
  const lines = [`# ${p.title?.trim() || "Questions before planning"}`, ""];
  p.questions.forEach((q, i) => {
    lines.push(`${i + 1}. ${q.question}`);
    for (const o of q.options) lines.push(`   ${optionLine(o)}`);
  });
  lines.push("", "## Answers", "");
  answers.forEach((a, i) => lines.push(`${i + 1}. ${a.custom ? a.label : `(${a.key}) ${a.label}`}`));
  return lines.join("\n") + "\n";
}

function textResult(text: string, details: Record<string, unknown>) {
  return { content: [{ type: "text" as const, text }], details };
}

async function readMode(pi: ExtensionAPI, cwd: string): Promise<{ mode: Mode; from: string }> {
  const state = await stateFile(pi, cwd);
  if (state) {
    const st = readJson(state);
    if (st) return { mode: asMode(st.orch_mode) ?? "panes", from: "this repo's run" };
  }
  const saved = asMode(readJson(configFile())?.mode);
  return saved ? { mode: saved, from: configFile() } : { mode: "panes", from: "default" };
}

function saveConfigMode(mode: Mode): void {
  const path = configFile();
  const data = readJson(path) ?? {};
  data.mode = mode;
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path + ".tmp", JSON.stringify(data, null, 2) + "\n");
  renameSync(path + ".tmp", path);
}

async function orchCommand(pi: ExtensionAPI): Promise<string | undefined> {
  const r = await pi.exec("sh", ["-c", 'command -v orch || { test -x "$HOME/.local/bin/orch" && echo "$HOME/.local/bin/orch"; }'], {
    timeout: 5000,
  });
  const path = r.stdout.trim().split("\n")[0];
  return r.code === 0 && path ? path : undefined;
}

function packageVersion(): string | undefined {
  try {
    return JSON.parse(readFileSync(join(packageRoot(), "package.json"), "utf8")).version;
  } catch {
    return undefined;
  }
}

/** "6.1.0" or "6.2.0-dev" -> [6, 1, 0]; undefined when it is not a version. */
function parseVersion(text: string | undefined): number[] | undefined {
  const m = /(\d+)\.(\d+)\.(\d+)/.exec(text ?? "");
  return m ? [Number(m[1]), Number(m[2]), Number(m[3])] : undefined;
}

function olderThan(a: number[], b: number[]): boolean {
  for (let i = 0; i < 3; i++) if (a[i] !== b[i]) return a[i] < b[i];
  return false;
}

/** What orch is on this machine: missing, older than this package (an old install next to a new Pi package, which
 *  has no `orch mode` yet), or ok. */
async function orchState(pi: ExtensionAPI): Promise<{ state: "missing" | "old" | "ok"; path?: string; version?: string }> {
  const path = await orchCommand(pi);
  if (!path) return { state: "missing" };
  const r = await pi.exec(path, ["version"], { timeout: 10000 });
  const have = parseVersion(r.stdout);
  const want = parseVersion(packageVersion());
  const version = have?.join(".");
  if (r.code !== 0 || !have || (want && olderThan(have, want))) return { state: "old", path, version };
  return { state: "ok", path, version };
}

function showStatus(ctx: ExtensionContext, mode: Mode): void {
  ctx.ui.setStatus(STATUS_KEY, `orch: ${mode}`);
}

export default function orchMode(pi: ExtensionAPI) {
  let mode: Mode = "panes";

  pi.on("session_start", async (_event, ctx) => {
    mode = (await readMode(pi, ctx.cwd)).mode;
    showStatus(ctx, mode);
    const o = await orchState(pi);
    if (o.state === "missing") {
      ctx.ui.notify("herdr-orchestra: the `orch` command is not installed yet. Type /orch-setup once to install it.", "warning");
    } else if (o.state === "old") {
      ctx.ui.notify(
        `herdr-orchestra: this Pi package is ${packageVersion() ?? "newer"} but the orch command on this machine is ${o.version ?? "older"}, which does not know the modes. Type /orch-setup to update it.`,
        "warning",
      );
    }
  });

  // Pi knows the mode on every turn. Worded for anyone who reads it (a coder subagent loads this extension too).
  pi.on("before_agent_start", async (event, ctx) => {
    mode = (await readMode(pi, ctx.cwd)).mode;
    const line =
      mode === "subagent"
        ? "herdr-orchestra (orch) mode: subagent. When you lead an orch run, the coder and the reviewer are Pi subagents (the Agent tool), not herdr panes; `orch lead run` prints the steps."
        : "herdr-orchestra (orch) mode: panes. When you lead an orch run, coders and the reviewer run in herdr panes; `orch lead run` prints the steps.";
    const ask =
      "When you lead /orch-plan and need decisions only the developer can make, ask them with the orch_ask tool " +
      "(clickable choices, saved to .orchestrate/questions.md). A coder or reviewer never uses it.";
    return { systemPrompt: `${event.systemPrompt}\n\n${line}\n${ask}` };
  });

  pi.registerTool({
    name: "orch_ask",
    label: "orch ask",
    description:
      "herdr-orchestra lead only, during /orch-plan (plan playbook step 2a): ask the developer the decisions only " +
      "they can make, as clickable choices, before you write .orchestrate/plan.md. Shows one picker per question, " +
      "saves questions and answers to .orchestrate/questions.md, and returns the answers. status `cancelled`: the " +
      "developer stopped; don't guess, say planning is paused until they answer. status `no_ui`: ask in chat instead. " +
      "Coders and reviewers never use it (a coder reports status `question` in its result file).",
    promptSnippet: "orch_ask: the orch lead's clickable questions for the developer before writing the plan",
    parameters: ASK_SCHEMA as any,
    async execute(_id: string, params: AskParams, _signal: AbortSignal | undefined, _onUpdate: unknown, ctx: ExtensionContext) {
      const qs = Array.isArray(params?.questions) ? params.questions : [];
      if (!qs.length) return textResult("orch_ask needs at least one question.", { status: "error" });
      if (!ctx.hasUI) {
        return textResult(
          "status: no_ui. This Pi has no screen for pickers (print or JSON mode). Write the questions to " +
            ".orchestrate/questions.md and ask them in chat, as plan playbook step 2a says.",
          { status: "no_ui" },
        );
      }
      const answers: AskAnswer[] = [];
      for (let i = 0; i < qs.length; i++) {
        const q = qs[i];
        const opts = Array.isArray(q.options) ? q.options : [];
        const choices = opts.map(optionLine);
        if (q.allow_custom !== false) choices.push(CUSTOM);
        const head = (params.title?.trim() || "Decisions before planning") + (qs.length > 1 ? ` (${i + 1} of ${qs.length})` : "");
        const picked: string | undefined = await ctx.ui.select(`${head}\n${q.question}`, choices);
        let answer: AskAnswer | undefined;
        if (picked === CUSTOM) {
          const typed: string | undefined = await ctx.ui.input(q.question, "Your answer");
          if (typed !== undefined && typed.trim()) answer = { id: q.id, question: q.question, key: "custom", label: typed.trim(), custom: true };
        } else if (picked !== undefined) {
          const o = opts[choices.indexOf(picked)];
          if (o) answer = { id: q.id, question: q.question, key: o.key, label: o.label, custom: false };
        }
        if (!answer) {
          return textResult(
            `status: cancelled at question ${i + 1} of ${qs.length} (${q.id}). The developer stopped answering. ` +
              "Don't guess and don't write the plan: tell them planning is paused until they answer, and ask again " +
              "when they say so. Nothing was saved.",
            { status: "cancelled", at: q.id, answers },
          );
        }
        answers.push(answer);
      }
      const dir = await orchestrateDir(pi, ctx.cwd);
      mkdirSync(dir, { recursive: true });
      const file = join(dir, "questions.md");
      const md = questionsMarkdown(params, answers);
      // The same planning (questions.md newer than plan.md: a second round, or `grill:` one at a time): add to it.
      // Otherwise it is from an earlier plan: start the file again.
      const plan = join(dir, "plan.md");
      const samePlanning =
        existsSync(file) && readFileSync(file, "utf8").trim() !== "" && (!existsSync(plan) || statSync(file).mtimeMs > statSync(plan).mtimeMs);
      if (samePlanning) appendFileSync(file, "\n" + md);
      else writeFileSync(file, md);
      const lines = answers.map((a, i) => `${i + 1}. ${a.id}: ${a.custom ? `custom: ${a.label}` : `(${a.key}) ${a.label}`}`);
      return textResult(
        `status: answered. Saved in ${file}. The developer's answers:\n${lines.join("\n")}\n` +
          "Write each answer into the plan where it applies (plan playbook step 2a), then carry on from step 2b.",
        { status: "answered", file, answers },
      );
    },
  });

  /** Lines worth showing from installer / `orch setup` output (both can be long). */
  function keyLines(out: string, extra: RegExp): string {
    return out
      .replace(/\x1b\[[0-9;]*m/g, "")
      .split("\n")
      .map((l) => l.trimEnd())
      .filter((l) => extra.test(l.trim()) || SETUP_LINE.test(l.trim()))
      .slice(-16)
      .join("\n");
  }

  /** Run the installer (always with install=true; also when orch is missing or older than this package), else
   *  `orch setup --mode subagent`; then reload Pi when pi-subagents was just installed. Returns true when Pi is reloading (the caller must return at once). */
  async function setUp(ctx: ExtensionCommandContext, want: Mode | undefined, install: boolean): Promise<boolean> {
    const o = await orchState(pi);
    let r: { stdout: string; stderr: string; code: number };
    let shown: string;
    if (!install && o.state === "ok" && want === "subagent") {
      ctx.ui.notify("Setting up subagent mode: the coder and reviewer agents, and pi-subagents (can take a minute)...", "info");
      r = await pi.exec(o.path!, ["setup", "--mode", "subagent"], { cwd: ctx.cwd, timeout: 600000 });
      shown = keyLines(r.stdout + r.stderr, /^$/);
    } else {
      const installer = join(packageRoot(), "install.sh");
      if (!existsSync(installer)) {
        ctx.ui.notify(`install.sh not found next to this extension (${installer}). Run: npx herdr-orchestra@latest`, "error");
        return false;
      }
      ctx.ui.notify(
        "Installing herdr-orchestra (orch)" + (want === "subagent" ? " and setting up subagent mode" : "") + "...",
        "info",
      );
      // ORCH_TTY=/dev/null: the installer must not read Pi's terminal. An unanswered auto-update question gets the
      // installer's default (on); the output says how to turn it off (`orch config auto-update off`).
      const args = ["ORCH_PACKAGE=1", "ORCH_TTY=/dev/null", "bash", installer, ...(want ? ["--mode", want] : [])];
      r = await pi.exec("env", args, { cwd: ctx.cwd, timeout: 600000 });
      shown = keyLines(r.stdout + r.stderr, /^(==>|warn:|error:)|auto-update|is active/);
    }
    const out = (r.stdout + r.stderr).replace(/\x1b\[[0-9;]*m/g, "");
    // the installer only warns when its `orch setup` step fails, so look at orch's own lines too
    const ok = r.code === 0 && !/^(FAILED|REFUSED|NO PI)\b|orch setup --mode \S+ did not finish/m.test(out);
    mode = (await readMode(pi, ctx.cwd)).mode;
    showStatus(ctx, mode);
    if (want === "subagent" && ok) {
      shown += "\nDone: subagent mode is ready. Plan with /orch-plan as usual.";
    } else if (want === "subagent") {
      shown += "\nSubagent setup is not finished: fix what it says above, then type /orch-mode subagent again.";
    }
    ctx.ui.notify(shown.trim() || (ok ? "Installed." : "The installer failed."), ok ? "info" : "error");
    if (ok && /^INSTALLED\s+npm:@tintinweb\/pi-subagents/m.test(out)) {
      // pi-subagents is new: reload so its Agent tool is loaded now, not after a restart.
      ctx.ui.notify("Reloading Pi so the new Agent tool loads...", "info");
      await ctx.reload();
      return true;
    }
    return false;
  }

  pi.registerCommand("orch-mode", {
    description: "Show or switch the herdr-orchestra mode: panes (herdr panes) or subagent (one Pi window, set up for you)",
    getArgumentCompletions: (prefix: string) =>
      MODES.filter((m) => m.startsWith(prefix.trim().toLowerCase())).map((m) => ({ value: m, label: m })),
    handler: async (args, ctx) => {
      const want = args.trim().toLowerCase();
      if (!want) {
        const cur = await readMode(pi, ctx.cwd);
        mode = cur.mode;
        showStatus(ctx, mode);
        ctx.ui.notify(`orch mode: ${cur.mode} (${cur.from}). Switch with /orch-mode panes or /orch-mode subagent.`, "info");
        return;
      }
      const next = asMode(want);
      if (!next) {
        ctx.ui.notify(`Unknown mode "${want}". Use /orch-mode panes or /orch-mode subagent.`, "error");
        return;
      }
      if (next === "subagent") {
        // `orch setup --mode subagent` saves the mode (and this repo's run, when nothing is in progress) and sets it up
        if (await setUp(ctx, "subagent", false)) return;
        const now = await readMode(pi, ctx.cwd);
        if (now.mode !== next) {
          ctx.ui.notify(`This repo's run stays ${now.mode} (something is in progress). New runs use ${next}.`, "warning");
        }
        return;
      }
      const o = await orchState(pi);
      const orch = o.state === "ok" ? o.path : undefined;
      if (orch) {
        // `orch mode` saves the machine's default and, when nothing is in progress, this repo's run too
        const r = await pi.exec(orch, ["mode", next], { cwd: ctx.cwd, timeout: 30000 });
        const out = (r.stdout + r.stderr).trim();
        if (r.code !== 0) {
          ctx.ui.notify(out || `orch mode ${next} failed`, "error");
          return;
        }
        ctx.ui.notify(out, "info");
      } else {
        saveConfigMode(next);
        ctx.ui.notify(
          `orch mode: ${next} (saved in ${configFile()}). ` +
            (o.state === "old" ? `The orch command here is ${o.version ?? "older"} and does not know the modes yet: ` : "") +
            "Type /orch-setup to install the orch command.",
          "info",
        );
      }
      const now = await readMode(pi, ctx.cwd);
      mode = now.mode;
      showStatus(ctx, mode);
      if (now.mode !== next) {
        ctx.ui.notify(`This repo's run stays ${now.mode} (${orch ? "something is in progress" : "switch it with /orch-mode after /orch-setup"}). New runs use ${next}.`, "warning");
      }
    },
  });

  pi.registerCommand("orch-setup", {
    description: "Install the herdr-orchestra `orch` command from this package; --mode subagent also sets up its Pi subagents",
    getArgumentCompletions: (prefix: string) =>
      ["--mode panes", "--mode subagent"].filter((m) => m.startsWith(prefix.trim().toLowerCase())).map((m) => ({ value: m, label: m })),
    handler: async (args, ctx) => {
      const words = args.trim().toLowerCase().split(/\s+/).filter(Boolean);
      if (words[0] === "--mode") words.shift();
      const named = words.length ? asMode(words[0]) : undefined;
      if (words.length > 1 || (words.length && !named)) {
        ctx.ui.notify("Usage: /orch-setup [--mode panes|subagent]", "error");
        return;
      }
      // No mode named: the saved one (in subagent mode the installer sets the agents up again, which is harmless)
      const want = named ?? ((await readMode(pi, ctx.cwd)).mode === "subagent" ? "subagent" : undefined);
      await setUp(ctx, want, true);
    },
  });
}
