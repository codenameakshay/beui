import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';

const root = fileURLToPath(new URL('./', import.meta.url));
const inventory = JSON.parse(await readFile(`${root}../route-inventory.json`));
const changes = {
  'prompt-input': 'Removed seeded attachments. Source notice priority and 3px entry. Provider favicon URLs.',
  message: 'Round one pending row and hidden response actions retained. No new library change.',
  'message-bubble': 'Canonical surfaces only. Avatars and show-more are independent examples.',
  'message-scroller': 'Round one pending and response behavior retained. Unread recovery still unverified.',
  'streaming-response': 'Removed unsourced outcome chips from canonical preview. Completion flush regression stays green.',
  'image-generation': 'Round one source artwork aspect and single canonical image retained.',
  citations: 'Standalone Stack and List moved to API specimens. Canonical paragraph and collection only.',
  'loading-states': 'Reasoning text at 384px. Shimmer and progress are independent examples.',
  'todo-list': 'Removed unsourced Empty and Cancelled sections. Canonical 330px stage centered.',
  'agent-activity': 'Six independently addressable source examples. Exact filled source search marks.',
  'tool-result': 'Terminal and request examples separated. Unsourced specimens require explicit selection.',
  'code-block': 'Wrapped API specimen removed from canonical TypeScript stream.',
  'file-diff': 'Final row 40 and 41 becomes source 20 and 21. Fabricated context expansion removed.',
  'tool-approval': 'Single source card. Unsourced severity and persisted grants moved to API specimens.',
  'approval-card': 'All three source descriptions restored. Questions and review examples separated.',
  'ai-sidebar': 'No round-two owned repair. Rename and keyboard state parity remain unverified.',
  'chat-app': '420ms pending before assistant mount. 600px shell fit. Mobile drawer width and toggle repaired.',
  'voice-orb': 'Source nonzero initial activity springs from rest. Full material and native 60 FPS remain unresolved.',
  'agent-theme': 'Local-only composition. No source equivalent and no source-parity claim.',
};
const run = (command, args, options = {}) => {
  const result = spawnSync(command, args, { maxBuffer: 64 * 1024 * 1024, ...options });
  assert.equal(result.status, 0, result.stderr?.toString());
  return result.stdout;
};
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const probe = path => JSON.parse(run('ffprobe', ['-v', 'error', '-count_frames', '-show_streams', '-of', 'json', path]));
await mkdir(`${root}side-by-side-v3`);
const browser = await chromium.launch({ channel: 'chrome', headless: true });
const page = await browser.newPage({ viewport: { width: 1504, height: 140 }, deviceScaleFactor: 1 });
const rows = [];
for (const route of inventory.routes) {
  const slug = route.slug;
  const before = `${root}baseline-wrapper/${slug}/capture.mp4`;
  const after = `${root}handoff/${slug}/capture.mp4`;
  const output = `${root}side-by-side-v3/${slug}.mp4`;
  const label = `${root}side-by-side-v3/${slug}-header.png`;
  const beforeSize = probe(before).streams[0];
  const afterSize = probe(after).streams[0];
  assert.equal(beforeSize.width, 1440);
  assert.equal(afterSize.width, 1440);
  assert.equal(beforeSize.height, afterSize.height);
  const height = beforeSize.height;
  await page.setContent(`<style>body{margin:0;background:#171717;color:white;font:16px Arial}.columns{display:flex}section{box-sizing:border-box;width:752px;padding:12px 16px}h2{font-size:20px;margin:0 0 8px}p{margin:6px 0;line-height:21px}</style><div class="columns"><section><h2>${slug} BEFORE 5ec78ac plus capture-only wrapper</h2><p>${changes[slug]}</p><p>Native timestamps. Unsynchronized mounts. Last-frame holds only.</p></section><section><h2>${slug} AFTER round two handoff build</h2><p>Measured 752px stage. Same gallery theme. CanvasKit pixels.</p><p>No interpolation. This derivative is not native 60 FPS proof.</p></section></div>`);
  await page.screenshot({ path: label });
  const filter = `[0:v]crop=752:${height}:344:0[b];[1:v]crop=752:${height}:344:0[a];[b][a]hstack=inputs=2,pad=1504:${height + 141}:0:140:color=0x171717[paired];[paired][2:v]overlay=0:0[out]`;
  run('ffmpeg', ['-nostdin', '-v', 'warning', '-i', before, '-i', after, '-i', label, '-filter_complex', filter, '-map', '[out]', '-fps_mode', 'passthrough', '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '18', '-pix_fmt', 'yuv420p', '-video_track_timescale', '1000000', output]);
  const frame = `${root}side-by-side-v3/${slug}.png`;
  run('ffmpeg', ['-nostdin', '-v', 'error', '-i', output, '-frames:v', '1', frame]);
  rows.push({ route: route.id, change: changes[slug], before: `baseline-wrapper/${slug}/capture.mp4`, after: `handoff/${slug}/capture.mp4`, output: `side-by-side-v3/${slug}.mp4`, image: `side-by-side-v3/${slug}.png`, sha256: sha(await readFile(output)), crop: { width: 752, height, x: 344, y: 0, clippedCssHeight: 1000 - height }, beforeProbe: probe(before), afterProbe: probe(after), outputProbe: probe(output), timestampPolicy: 'FFmpeg framesync uses the union of native input timestamps. The inactive input holds its last sample. Original inputs are retained. No generated intermediate image or 60 FPS claim.' });
}
await browser.close();
await writeFile(`${root}change-manifest.json`, JSON.stringify(rows, null, 2));
await writeFile(`${root}CHANGE_MANIFEST.md`, '# Round-two visible changes\n\nEvery video crops the measured 752px stage from both 1440px captures without scaling it. The left side is 5ec78ac plus the same capture-only wrapper. The right side is the frozen handoff build. Inputs are not event-synchronized. The derivative holds the last sample from one input while the other advances. No interpolation or native 60 FPS claim is made.\n\n| Route | Change | Side-by-side | New-badged route video |\n|---|---|---|---|\n' + rows.map(row => `| ${row.route} | ${row.change} | [Video](${row.output}) | [Native input](${row.after}) |`).join('\n') + '\n');
console.log(`Generated ${rows.length} labeled side-by-side videos and stills.`);
