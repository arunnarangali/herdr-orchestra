// Runs one slash command of extensions/orch-mode.ts outside Pi, with a stand-in for Pi's extension API:
//   node tests/pi-extension.mjs <command> [args...]
// Prints each ui.notify as "NOTIFY <level> <text>", and "RELOAD" when the command calls ctx.reload().
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
const pi = { exec, on() {}, registerCommand(name, def) { commands[name] = def; } };
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
if (!commands[name]) {
  console.error(`no command ${name}`);
  process.exit(2);
}
await commands[name].handler(rest.join(" "), ctx);
