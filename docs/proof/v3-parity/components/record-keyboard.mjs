import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { spawn } from 'node:child_process';

const root = import.meta.dirname;
const output = join(root, 'tooltip-keyboard-recordings');
await mkdir(output);
const runs = [];
for (const origin of ['reference', 'candidate']) {
  for (const theme of ['light', 'dark']) {
    const id = `${origin}-${theme}-tooltip`;
    const config = JSON.parse(await readFile(join(root, 'release-recordings-run2/configs', `${id}.json`), 'utf8'));
    config.backend = origin === 'reference' ? 'compositor' : 'screenshots';
    config.provenance.scope = 'Mouse click Top, Tab to Left, Tab to Right, Shift+Tab to Left, Escape. Keyboard dispatch requires visible frame inspection.';
    config.events = [
      { atMs: 400, type: 'move', target: 'control0' },
      { atMs: 650, type: 'click', target: 'control0' },
      { atMs: 1100, type: 'key', key: 'Tab' },
      { atMs: 1800, type: 'key', key: 'Tab' },
      { atMs: 2500, type: 'key', key: 'Shift+Tab' },
      { atMs: 3200, type: 'key', key: 'Escape' },
      { atMs: 3600, type: 'move', target: 'outside' },
    ];
    const configPath = join(output, `${id}.json`);
    await writeFile(configPath, JSON.stringify(config, null, 2));
    const runDirectory = join(output, id);
    const result = await new Promise(resolve => {
      const child = spawn(process.execPath, ['/Users/codenameakshay/.t3/worktrees/beui/t3-6e9ab891/tool/parity_capture.mjs', configPath, runDirectory], {
        env: { ...process.env, PARITY_PLAYWRIGHT: '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs' }, stdio: ['ignore', 'pipe', 'pipe'],
      });
      let log = '';
      child.stdout.on('data', bytes => { log += bytes; });
      child.stderr.on('data', bytes => { log += bytes; });
      child.on('close', code => resolve({ code, log }));
    });
    await writeFile(join(output, `${id}.log`), result.log);
    let stats;
    try { stats = JSON.parse(await readFile(join(runDirectory, 'timeline.json'), 'utf8')).stats; } catch {}
    runs.push({ id, origin, theme, code: result.code, stats, runDirectory });
    await writeFile(join(output, 'index.json'), JSON.stringify(runs, null, 2));
    console.log(JSON.stringify({ id, code: result.code, stats }));
  }
}
