import { readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const root = fileURLToPath(new URL('./', import.meta.url));
const recorder = '/Users/codenameakshay/.t3/worktrees/beui/t3-f7137276/tool/parity_capture.mjs';
const config = JSON.parse(await readFile(`${root}shared-guarded-providers/prompt-input.config.json`));
config.provenance.recorder = recorder;
config.provenance.recorderSha256 = createHash('sha256').update(await readFile(recorder)).digest('hex');
config.provenance.recorderRevision = 'd53695ffca9e4c9d1403e75712a9ff8e2ceed8ed';
config.provenance.stateClaim = 'Actual held input dispatch and visible picker video. Resulting selection is asserted separately in favicon_probe.mjs.';
config.provenance.targetGeometry = 'Trigger bounds observed in favicon-runtime-verified/live-observed.json. x477 y494 width208 height32. Points stay inside the trigger.';
config.targets = { model: { x: 581, y: 510 }, heldInside: { x: 600, y: 510 } };
config.events = [
  { atMs: 100, type: 'down', target: 'model' },
  { atMs: 400, type: 'move', target: 'heldInside' },
  { atMs: 700, type: 'up' },
  { atMs: 1100, type: 'key', key: 'ArrowDown' },
  { atMs: 1500, type: 'key', key: 'Enter' },
];
config.finalHoldMs = 1000;
const path = `${root}provider-held-pointer.config.json`;
await writeFile(path, JSON.stringify(config, null, 2));
const result = spawnSync(process.execPath, [recorder, path, `${root}provider-held-pointer`], {
  env: { ...process.env, PARITY_PLAYWRIGHT: '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs' }, encoding: 'utf8',
});
console.log(result.stdout);
console.error(result.stderr);
assert.equal(result.status, 0);
