#!/usr/bin/env node
// `npx herdr-orchestra@latest [install.sh options]` installs herdr-orchestra from this package.
// All the install logic stays in install.sh; this launcher only checks bash is there and runs it.
'use strict';
const { spawnSync } = require('node:child_process');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const args = process.argv.slice(2);

if (process.platform === 'win32') {
  console.error('herdr-orchestra needs bash, python3 and git (use WSL on Windows).');
  process.exit(1);
}
if (args.includes('-V') || args.includes('--package-version')) {
  console.log(require('../package.json').version);
  process.exit(0);
}

const r = spawnSync('bash', [path.join(root, 'install.sh'), ...args], {
  stdio: 'inherit',
  env: { ...process.env, ORCH_PACKAGE: '1' },
});
if (r.error) {
  console.error(r.error.code === 'ENOENT' ? 'bash not found on PATH.' : String(r.error));
  process.exit(1);
}
process.exit(r.status === null ? 1 : r.status);
