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
// Commands:  /orch-mode [panes|subagent]   show or switch the mode
//            /orch-setup                   install the `orch` command from this package (needed once)
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

type Mode = "panes" | "subagent";
const MODES: Mode[] = ["panes", "subagent"];
const STATUS_KEY = "orch";

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

function showStatus(ctx: ExtensionContext, mode: Mode): void {
  ctx.ui.setStatus(STATUS_KEY, `orch: ${mode}`);
}

export default function orchMode(pi: ExtensionAPI) {
  let mode: Mode = "panes";

  pi.on("session_start", async (_event, ctx) => {
    mode = (await readMode(pi, ctx.cwd)).mode;
    showStatus(ctx, mode);
    if (!(await orchCommand(pi))) {
      ctx.ui.notify("herdr-orchestra: the `orch` command is not installed yet. Type /orch-setup once to install it.", "warning");
    }
  });

  // Pi knows the mode on every turn. Worded for anyone who reads it (a coder subagent loads this extension too).
  pi.on("before_agent_start", async (event, ctx) => {
    mode = (await readMode(pi, ctx.cwd)).mode;
    const line =
      mode === "subagent"
        ? "herdr-orchestra (orch) mode: subagent. When you lead an orch run, the coder and the reviewer are Pi subagents (the Agent tool), not herdr panes; `orch lead run` prints the steps."
        : "herdr-orchestra (orch) mode: panes. When you lead an orch run, coders and the reviewer run in herdr panes; `orch lead run` prints the steps.";
    return { systemPrompt: `${event.systemPrompt}\n\n${line}` };
  });

  pi.registerCommand("orch-mode", {
    description: "Show or switch the herdr-orchestra mode: panes (herdr panes) or subagent (one Pi window)",
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
      const orch = await orchCommand(pi);
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
        ctx.ui.notify(`orch mode: ${next} (saved in ${configFile()}). Type /orch-setup to install the orch command.`, "info");
      }
      const now = await readMode(pi, ctx.cwd);
      mode = now.mode;
      showStatus(ctx, mode);
      if (now.mode !== next) {
        ctx.ui.notify(`This repo's run stays ${now.mode} (${orch ? "something is in progress" : "switch it with /orch-mode once orch is installed"}). New runs use ${next}.`, "warning");
      }
    },
  });

  pi.registerCommand("orch-setup", {
    description: "Install the herdr-orchestra `orch` command from this package (and, in subagent mode, its Pi subagents)",
    handler: async (_args, ctx) => {
      const installer = join(packageRoot(), "install.sh");
      if (!existsSync(installer)) {
        ctx.ui.notify(`install.sh not found next to this extension (${installer}). Run: npx herdr-orchestra@latest`, "error");
        return;
      }
      const cur = await readMode(pi, ctx.cwd);
      ctx.ui.notify("Installing herdr-orchestra (orch)...", "info");
      // ORCH_TTY=/dev/null: the installer must not read Pi's terminal. An unanswered auto-update question gets the
      // installer's default (on); the output says how to turn it off (`orch config auto-update off`).
      const args = ["ORCH_PACKAGE=1", "ORCH_TTY=/dev/null", "bash", installer, ...(cur.mode === "subagent" ? ["--mode", "subagent"] : [])];
      const r = await pi.exec("env", args, { cwd: ctx.cwd, timeout: 600000 });
      const tail = (r.stdout + r.stderr)
        .replace(/\x1b\[[0-9;]*m/g, "")
        .split("\n")
        .filter((l) => /^(==>|warn:|error:)|auto-update|is active/.test(l.trim()))
        .slice(-12)
        .join("\n");
      ctx.ui.notify(tail || (r.code === 0 ? "Installed." : "The installer failed."), r.code === 0 ? "info" : "error");
      mode = (await readMode(pi, ctx.cwd)).mode;
      showStatus(ctx, mode);
    },
  });
}
