import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { performance } from 'node:perf_hooks';
import { fileURLToPath } from 'node:url';

const [phase, selected = 'all', example, reduce = 'false', run = ''] = process.argv.slice(2);
const tag = `${phase}${run ? `-${run}` : ''}`;
const root = fileURLToPath(new URL('./', import.meta.url));
const inventory = JSON.parse(await readFile(new URL('../route-inventory.json', import.meta.url)));
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const urlFor = slug => phase === 'reference'
  ? `https://beui.dev/components/agents/${slug}`
  : `http://127.0.0.1:18107/agents-round2-${phase}/?slug=${slug}&theme=dark&stageWidth=752${example ? `&example=${example}` : ''}&reduce=${reduce}`;
const build = `example/build/agents-round2-${phase}/main.dart.js`;
if (phase !== 'reference') {
  const index = await (await fetch(urlFor('chat-app'))).text();
  if (!index.includes(`<base href="/agents-round2-${phase}/">`)) throw Error('Index base does not select the frozen build');
  const local = sha(await readFile(build));
  const served = sha(Buffer.from(await (await fetch(new URL('main.dart.js', urlFor('chat-app')))).arrayBuffer()));
  if (local !== served) throw Error(`Wrong server build ${local} != ${served}`);
  await writeFile(`${root}build-verification-${tag}-${selected}${example ? `-${example}` : ''}-${reduce}.json`, JSON.stringify({ at: new Date().toISOString(), build, local, served, url: urlFor('chat-app'), portSubstitution: '8107 occupied by unrelated Python server. Verified free 18107 before starting our server.' }, null, 2));
}
const browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
const routes = inventory.routes.filter(r => (selected === 'all' || selected.split(',').includes(r.slug)) && (phase !== 'reference' || r.sourceUrl));
try {
  for (const route of routes) {
    const dir = `${root}${example ? 'examples/' : ''}${tag}/${route.slug}${example ? `-${example}` : ''}${reduce === 'true' ? '-reduced' : ''}`;
    await mkdir(dir.substring(0, dir.lastIndexOf('/')), { recursive: true });
    await mkdir(dir);
    await mkdir(`${dir}/frames`);
    const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, deviceScaleFactor: 1, colorScheme: 'dark', reducedMotion: 'no-preference', locale: 'en-US', timezoneId: 'Asia/Kolkata' });
    const page = await context.newPage();
    const errors = [];
    const loadedScripts = [];
    page.on('response', async response => {
      if (new URL(response.url()).pathname.endsWith('/main.dart.js')) {
        loadedScripts.push({ url: response.url(), sha256: sha(await response.body()) });
      }
    });
    page.on('pageerror', e => errors.push(String(e)));
    await page.goto(urlFor(route.slug), { waitUntil: 'networkidle', timeout: 60000 });
    if (phase !== 'reference') {
      await page.waitForSelector('flutter-view', { state: 'attached', timeout: 30000 });
      const local = sha(await readFile(build));
      if (!loadedScripts.some(script => script.sha256 === local && new URL(script.url).pathname === `/agents-round2-${phase}/main.dart.js`)) throw Error('Browser did not load the frozen main.dart.js');
      await writeFile(`${dir}/loaded-scripts.json`, JSON.stringify(loadedScripts, null, 2));
    }
    if (phase === 'reference') await page.getByRole('tab', { name: 'Dark theme', exact: true }).first().click();
    else await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForTimeout(700);
    const aria = await page.locator('body').ariaSnapshot();
    await writeFile(`${dir}/idle-aria.txt`, aria);
    if (phase !== 'before' && phase !== 'reference') {
      const stage = aria.match(/Capture stage width ([\d.]+) height ([\d.]+) reduced (true|false)/);
      if (!stage || Number(stage[1]) !== 752 || Number(stage[2]) !== 1000 || stage[3] !== reduce) throw Error(`Actual capture stage constraints or reduced motion did not match: ${aria}`);
    }
    const geometry = await page.evaluate(() => ({ at: new Date().toISOString(), width: innerWidth, height: innerHeight, dpr: devicePixelRatio, reducedMotion: matchMedia('(prefers-reduced-motion: reduce)').matches, fonts: [...document.fonts].map(f => ({ family: f.family, status: f.status })), inputs: [...document.querySelectorAll('input,textarea')].map(e => ({ placeholder: e.placeholder, rect: e.getBoundingClientRect().toJSON() })), previews: [...document.querySelectorAll('[data-slot="preview-expand-stage"], [data-slot="prompt-input"], [data-slot="voice-orb"], [class*="max-w-lg"], [class*="max-w-xl"]')].map(e => ({ class: e.className, slot: e.getAttribute('data-slot'), rect: e.getBoundingClientRect().toJSON() })) }));
    await writeFile(`${dir}/geometry.json`, JSON.stringify(geometry, null, 2));
    const cdp = await context.newCDPSession(page);
    const origin = performance.now();
    const frames = [];
    while (performance.now() - origin < 3200) {
      const requestedMs = performance.now() - origin;
      const { data } = await cdp.send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
      const receivedMs = performance.now() - origin;
      const file = `frames/frame_${String(frames.length).padStart(6, '0')}.png`;
      const bytes = Buffer.from(data, 'base64');
      await writeFile(`${dir}/${file}`, bytes);
      frames.push({ file, requestedMs, receivedMs, sha256: sha(bytes) });
    }
    const intervals = frames.slice(1).map((f, i) => f.receivedMs - frames[i].receivedMs);
    const concat = ['ffconcat version 1.0'];
    frames.forEach((f, i) => {
      concat.push(`file '${f.file}'`, 'option framerate 1000000');
      if (i + 1 < frames.length) concat.push(`duration ${((frames[i + 1].receivedMs - f.receivedMs) / 1000).toFixed(6)}`);
    });
    await writeFile(`${dir}/frames.ffconcat`, concat.join('\n') + '\n');
    const encoded = spawnSync('ffmpeg', ['-nostdin', '-v', 'warning', '-f', 'concat', '-safe', '0', '-i', `${dir}/frames.ffconcat`, '-fps_mode', 'passthrough', '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '0', '-pix_fmt', 'yuv444p', '-video_track_timescale', '1000000', `${dir}/capture.mp4`], { encoding: 'utf8' });
    await writeFile(`${dir}/ffmpeg.log`, encoded.stderr);
    if (encoded.status !== 0) throw Error(encoded.stderr);
    const probe = spawnSync('ffprobe', ['-v', 'error', '-count_frames', '-show_streams', '-of', 'json', `${dir}/capture.mp4`], { encoding: 'utf8' });
    await writeFile(`${dir}/ffprobe.json`, probe.stdout);
    const decodedFrames = Number(JSON.parse(probe.stdout).streams[0].nb_read_frames);
    if (decodedFrames !== frames.length) throw Error('Frame count changed during encode');
    const stats = { url: urlFor(route.slug), backend: 'Page.captureScreenshot, CanvasKit pixels', frames: frames.length, decodedFrames, measuredFps: (frames.length - 1) * 1000 / (frames.at(-1).receivedMs - frames[0].receivedMs), maxGapMs: Math.max(...intervals), errors, noInterpolation: true, fastMotionVerdict: 'Unresolved. Native screenshot cadence is below 60 FPS. No interaction claim for idle videos.' };
    await writeFile(`${dir}/timeline.json`, JSON.stringify({ stats, frames }, null, 2));
    console.log(phase, route.slug, JSON.stringify(stats));
    await context.close();
  }
} finally { await browser.close(); }
