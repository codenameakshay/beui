import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { performance } from 'node:perf_hooks';
import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';

const root = fileURLToPath(new URL('./', import.meta.url));
const output = `${root}${process.argv[2] ?? 'matched-run1'}`;
await mkdir(output);
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const revision = spawnSync('git', ['-C', '/tmp/beui-v3-parity-components-source', 'rev-parse', 'HEAD'], { encoding: 'utf8' }).stdout.trim();
assert.equal(revision, 'a76e57c9bbc2837e96420b2610e9c82a3271bb05');
assert.equal(spawnSync('git', ['-C', '/tmp/beui-v3-parity-components-source', 'status', '--porcelain'], { encoding: 'utf8' }).stdout.trim(), '');
const expectedJs = sha(await readFile('example/build/approval-states-a76/main.dart.js'));
const tokens = ['background', 'foreground', 'card', 'card-foreground', 'popover', 'popover-foreground', 'primary', 'primary-foreground', 'secondary', 'secondary-foreground', 'muted', 'muted-foreground', 'accent', 'accent-foreground', 'destructive', 'border', 'input', 'ring'];
const browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
const records = [];
try {
  for (const phase of ['source', 'candidate']) {
    const dir = `${output}/${phase}`;
    await mkdir(dir);
    const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, deviceScaleFactor: 1, colorScheme: 'dark', reducedMotion: 'no-preference', locale: 'en-US', timezoneId: 'Asia/Kolkata' });
    const page = await context.newPage();
    const loaded = [];
    const reads = [];
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    page.on('response', response => {
      if (/\.js(?:\?|$)/.test(response.url())) reads.push(response.body().then(bytes => loaded.push({ url: response.url(), sha256: sha(bytes) })));
    });
    const url = phase === 'source'
      ? 'http://127.0.0.1:18128/components/agents/approval-card'
      : 'http://127.0.0.1:18127/approval-states-a76/?slug=approval-card&theme=dark&previewWidth=752&captureProbe=1&palette=source-default-a76e57c9';
    await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });
    if (phase === 'source') await page.getByRole('tab', { name: 'Dark theme', exact: true }).click();
    else await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(1000);
    if (phase === 'source') {
      await page.evaluate(() => {
        const input = document.querySelector('input[placeholder="Describe another scope…"]');
        const stage = [...function*(e) { while (e) { yield e; e = e.parentElement; } }(input)].find(e => e.classList.contains('max-w-lg'));
        scrollTo(0, stage.getBoundingClientRect().top + scrollY - 265);
      });
    }
    await page.mouse.move(10, 10);
    await page.waitForTimeout(350);
    await Promise.all(reads);
    const environment = await page.evaluate(tokenNames => {
      const probe = globalThis.__beuiCapture ?? null;
      const colors = Object.fromEntries(tokenNames.map(name => [name, getComputedStyle(document.documentElement).getPropertyValue(`--${name}`).trim()]));
      const canvas = document.createElement('canvas');
      canvas.width = canvas.height = 1;
      const ctx = canvas.getContext('2d');
      const resolvedColors = Object.fromEntries(Object.entries(colors).filter(([, value]) => value).map(([name, value]) => {
        ctx.clearRect(0, 0, 1, 1);
        ctx.fillStyle = value;
        ctx.fillRect(0, 0, 1, 1);
        return [name, [...ctx.getImageData(0, 0, 1, 1).data]];
      }));
      return { viewport: { width: innerWidth, height: innerHeight, dpr: devicePixelRatio }, reducedMotion: matchMedia('(prefers-reduced-motion: reduce)').matches, probe, colors, resolvedColors, htmlClass: document.documentElement.className, dataTheme: document.documentElement.dataset.theme ?? null, fonts: [...document.fonts].map(f => ({ family: f.family, status: f.status })) };
    }, tokens);
    const aria = await page.locator('body').ariaSnapshot();
    if (phase === 'candidate') {
      assert(loaded.some(script => script.sha256 === expectedJs), 'browser-loaded script differs from the local build');
      assert.equal(environment.probe.rect.width, 752);
      assert.equal(environment.probe.rect.height, 1000);
      assert.equal(environment.probe.disableAnimations, false);
      assert.equal(environment.probe.motionOverride, null);
      assert(aria.includes('palette source-default-a76e57c9'), 'actual capture palette label missing');
    } else {
      assert.equal(environment.dataTheme, null);
      assert(environment.htmlClass.includes('dark'));
      assert.equal(environment.colors.primary, '#0285f7');
    }
    const cdp = await context.newCDPSession(page);
    const field = phase === 'source' ? page.getByPlaceholder('Describe another scope…', { exact: true }) : page.getByRole('textbox');
    const snapshots = [];
    const frames = [];
    await mkdir(`${dir}/frames`);
    let sampling = true;
    const sampler = (async () => {
      while (sampling) {
        const requestedMs = performance.now();
        const shot = await cdp.send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
        const receivedMs = performance.now();
        const bytes = Buffer.from(shot.data, 'base64');
        const file = `frames/frame_${String(frames.length).padStart(6, '0')}.png`;
        await writeFile(`${dir}/${file}`, bytes);
        frames.push({ file, requestedMs, receivedMs, sha256: sha(bytes) });
      }
    })();
    try {
    for (const state of ['idle', 'focus', 'text-entry']) {
      if (state === 'focus') {
        await page.keyboard.press('Tab');
        await field.click();
      }
      if (state === 'text-entry') {
        await page.keyboard.type('Keep the release focused.', { delay: 35 });
      }
      await page.mouse.move(10, 10);
      await page.waitForTimeout(250);
      const observed = await page.evaluate(() => {
        const input = document.querySelector('input[placeholder="Describe another scope…"]');
        if (!input) return { active: { tag: document.activeElement.tagName, value: document.activeElement.value }, probe: globalThis.__beuiCapture };
        const style = getComputedStyle(input);
        const field = input.parentElement;
        const stage = [...function*(e) { while (e) { yield e; e = e.parentElement; } }(field)].find(e => e.classList.contains('max-w-lg'));
        return { value: input.value, focused: document.activeElement === input, placeholder: getComputedStyle(input, '::placeholder').color, fieldBackground: getComputedStyle(field).backgroundColor, fieldOpacity: getComputedStyle(field).opacity, fontSize: style.fontSize, lineHeight: style.lineHeight, field: field.getBoundingClientRect().toJSON(), stage: stage.getBoundingClientRect().toJSON() };
      });
      if (state !== 'idle') {
        if (phase === 'source') assert.equal(observed.focused, true);
        else assert(['INPUT', 'TEXTAREA'].includes(observed.active.tag));
      }
      if (state === 'text-entry') {
        assert.equal(phase === 'source' ? observed.value : observed.active.value, 'Keep the release focused.');
        assert((await page.locator('body').ariaSnapshot()).includes('Keep the release focused.'));
      }
      const stage = phase === 'source' ? observed.stage : { x: environment.probe.rect.x + (752 - 512) / 2, y: (1000 - 470) / 2, width: 512, height: 470 };
      assert.equal(stage.width, 512);
      assert.equal(stage.height, 470);
      const requestedMs = performance.now();
      const shot = await cdp.send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
      const receivedMs = performance.now();
      const bytes = Buffer.from(shot.data, 'base64');
      await writeFile(`${dir}/${state}.png`, bytes);
      snapshots.push({ state, stage, inputBounds: await field.boundingBox(), controls: { replay: await page.getByRole('button', { name: 'Replay', exact: true }).first().boundingBox(), next: await page.getByRole('button', { name: 'Next question', exact: true }).boundingBox() }, observed, requestedMs, receivedMs, sha256: sha(bytes), file: `${state}.png` });
    }
    } finally { sampling = false; await sampler; }
    const concat = ['ffconcat version 1.0'];
    frames.forEach((frame, i) => {
      concat.push(`file '${frame.file}'`, 'option framerate 1000000');
      if (i + 1 < frames.length) concat.push(`duration ${((frames[i + 1].receivedMs - frame.receivedMs) / 1000).toFixed(6)}`);
    });
    await writeFile(`${dir}/frames.ffconcat`, concat.join('\n') + '\n');
    const encode = spawnSync('ffmpeg', ['-nostdin', '-v', 'warning', '-f', 'concat', '-safe', '0', '-i', `${dir}/frames.ffconcat`, '-fps_mode', 'passthrough', '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '0', '-pix_fmt', 'yuv444p', '-video_track_timescale', '1000000', `${dir}/capture.mp4`], { encoding: 'utf8' });
    await writeFile(`${dir}/ffmpeg.txt`, encode.stderr);
    assert.equal(encode.status, 0, encode.stderr);
    const probe = spawnSync('ffprobe', ['-v', 'error', '-count_frames', '-show_streams', '-of', 'json', `${dir}/capture.mp4`], { encoding: 'utf8' });
    const video = JSON.parse(probe.stdout).streams[0];
    assert.equal(Number(video.nb_read_frames), frames.length);
    const gaps = frames.slice(1).map((f, i) => f.receivedMs - frames[i].receivedMs);
    const cadence = { samples: frames.length, decodedFrames: Number(video.nb_read_frames), width: video.width, height: video.height, measuredFps: (frames.length - 1) * 1000 / (frames.at(-1).receivedMs - frames[0].receivedMs), maxGapMs: Math.max(...gaps), noInterpolation: true, temporalEquivalence: false };
    const record = { phase, url, sourceRevision: revision, expectedJs: phase === 'candidate' ? expectedJs : null, loaded, environment, errors, snapshots, frames, cadence };
    records.push(record);
    await writeFile(`${dir}/record.json`, JSON.stringify(record, null, 2));
    await writeFile(`${dir}/idle-aria.txt`, aria);
    await context.close();
  }
} finally { await browser.close(); }
await writeFile(`${output}/records.json`, JSON.stringify(records, null, 2));
console.log(JSON.stringify(records.map(({ phase, errors, snapshots }) => ({ phase, errors, snapshots: snapshots.map(({ state, sha256, observed, stage }) => ({ state, sha256, observed, stage })) })), null, 2));
