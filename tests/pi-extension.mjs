// Runs one slash command of extensions/orch-mode.ts outside Pi, with a stand-in for Pi's extension API:
//   node tests/pi-extension.mjs <command> [args...]
//   node tests/pi-extension.mjs tool <name> '<json params>'   runs a tool (PICKS = scripted answers, below)
//   node tests/pi-extension.mjs prompt                         prints what before_agent_start adds to the prompt
// Prints each ui.notify as "NOTIFY <level> <text>", and "RELOAD" when the command calls ctx.reload().
// Tools: each ui.select prints "SELECT <title> | <choice> | ...". PICKS is a comma list, one entry per dialog:
// a number picks that choice (0 first), `custom` picks the last choice, `esc` cancels, any other text is typed
// into ui.input. NO_UI=1 runs without a screen (hasUI false). Prints "RESULT <json>" with the tool's result.
// Needs a Node that strips TypeScript types (22.6+; tests/run.sh skips it otherwise).
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const ext = join(dirname(fileURLToPath(import.meta.url)), "..", "extensions", "orch-mode.ts");
const { default: orchMode } = await import(ext);

function exec(cmd, args, opts = {}) {
  return new Promise((done) => {
    const p = spawn(cmd, args, { cwd: opts.cwd, env: process.env });
    let stdout = "", stderr = "";
    p.stdout.on("data", (d) => (stdout += d));
    p.stderr.on("data", (d) => (stderr += d));
    p.on("error", (e) => done({ stdout, stderr: String(e), code: 127 }));
    p.on("close", (code) => done({ stdout, stderr, code: code ?? 1 }));
  });
}

const commands = {};
const tools = {};
const handlers = {};
const pi = {
  exec,
  on(event, fn) { handlers[event] = fn; },
  registerCommand(name, def) { commands[name] = def; },
  registerTool(def) { tools[def.name] = def; },
};
orchMode(pi);
const [name, ...rest] = process.argv.slice(2);
const ctx = {
  cwd: process.cwd(),
  ui: {
    notify: (text, level) => console.log(`NOTIFY ${level} ${text}`),
    setStatus: (key, text) => console.log(`STATUS ${key} ${text}`),
  },
  reload: async () => console.log("RELOAD"),
};
if (name === "tool" || name === "prompt") {
  const picks = (process.env.PICKS || "").split(",").filter((p) => p !== "");
  const next = () => (picks.length ? picks.shift() : "esc");
  ctx.hasUI = process.env.NO_UI !== "1";
  ctx.ui.select = async (title, choices) => {
    console.log(`SELECT ${title.replace(/\n/g, " / ")} | ${choices.join(" | ")}`);
    const p = next();
    if (p === "esc") return undefined;
    if (p === "custom") return choices[choices.length - 1];
    return choices[Number(p)];
  };
  ctx.ui.input = async (title) => {
    console.log(`INPUT ${title}`);
    const p = next();
    return p === "esc" ? undefined : p;
  };
  if (name === "prompt") {
    const r = await handlers.before_agent_start({ systemPrompt: "BASE" }, ctx);
    console.log(r.systemPrompt);
    process.exit(0);
  }
  const tool = tools[rest[0]];
  if (!tool) {
    console.error(`no tool ${rest[0]}`);
    process.exit(2);
  }
  const r = await tool.execute("t1", JSON.parse(rest.slice(1).join(" ")), undefined, undefined, ctx);
  console.log(r.content.map((c) => c.text).join("\n"));
  console.log("RESULT " + JSON.stringify(r.details));
  process.exit(0);
}
if (!commands[name]) {
  console.error(`no command ${name}`);
  process.exit(2);
}
await commands[name].handler(rest.join(" "), ctx);
