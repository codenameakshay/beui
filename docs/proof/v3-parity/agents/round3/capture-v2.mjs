import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';
import { performance } from 'node:perf_hooks';
import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';

const [phase, slug, run, theme = 'dark', motion = 'normal', width = '1440'] = process.argv.slice(2);
assert(['source', 'before', 'after'].includes(phase));
assert(['file-diff', 'approval-card', 'voice-orb'].includes(slug));
const output = resolve(`docs/proof/v3-parity/agents/round3/${run}`);
await mkdir(output);
await mkdir(`${output}/frames`);
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const source = phase === 'source';
const revision = 'a76e57c9bbc2837e96420b2610e9c82a3271bb05';
const sourceRoot = '/tmp/beui-v3-parity-components-source';
assert.equal(spawnSync('git', ['-C', sourceRoot, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).stdout.trim(), revision);
assert.equal(spawnSync('git', ['-C', sourceRoot, 'status', '--porcelain'], { encoding: 'utf8' }).stdout.trim(), '');
const build = process.env.BEUI_CAPTURE_BUILD ?? `agents-round3-${phase}`;
const expectedJs = source ? null : hash(await readFile(`example/build/${build}/main.dart.js`));
const reduced = motion === 'reduced';
const review = process.env.BEUI_CAPTURE_EXAMPLE === 'review';
const previewWidth = Number(process.env.BEUI_CAPTURE_PREVIEW_WIDTH ?? Math.min(752, Number(width)));
const browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
const record = { phase, slug, theme, motion, sourceRevision: revision, liveRevision: 'unknown', expectedJs, captureScriptSha256: hash(await readFile(new URL(import.meta.url))), loaded: [], fontAssets: [], errors: [], snapshots: [], frames: [] };
try {
  const context = await browser.newContext({ viewport: { width: Number(width), height: 1000 }, deviceScaleFactor: 1, colorScheme: theme, reducedMotion: reduced ? 'reduce' : 'no-preference', locale: 'en-US', timezoneId: 'Asia/Kolkata', permissions: ['clipboard-read', 'clipboard-write'] });
  const page = await context.newPage();
  const pending = [];
  page.on('pageerror', error => record.errors.push(String(error)));
  page.on('response', response => {
    if (/\.js(?:\?|$)/.test(response.url())) pending.push(response.body().then(bytes => record.loaded.push({ url: response.url(), sha256: hash(bytes) })).catch(error => record.errors.push(String(error))));
    if (/\.(?:ttf|otf|woff2?)(?:\?|$)|FontManifest\.json/.test(response.url())) pending.push(response.body().then(bytes => record.fontAssets.push({ url: response.url(), bytes: bytes.length, sha256: hash(bytes) })).catch(error => record.errors.push(String(error))));
  });
  record.url = source
    ? `http://127.0.0.1:18117/components/agents/${slug}`
    : `http://127.0.0.1:18117/${build}/?slug=${slug}&theme=${theme}&previewWidth=${previewWidth}&captureProbe=1&palette=source-default-a76e57c9${review ? '&example=review' : ''}`;
  await page.goto(record.url, { waitUntil: 'networkidle', timeout: 60000 });
  if (source) await page.getByRole('tab', { name: `${theme === 'dark' ? 'Dark' : 'Light'} theme`, exact: true }).click();
  else await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(2800);
  const replay = page.getByRole('button', { name: 'Replay', exact: true }).nth(source && review ? 1 : 0);
  const sourceStage = slug === 'voice-orb' ? page.getByRole('img', { name: 'Voice visualization', exact: true }) : replay.locator('..');
  const stageHeight = slug === 'file-diff' ? 300 : slug === 'approval-card' ? review ? 360 : 470 : Number(width) < 640 ? 256 : 288;
  if (source) {
    await sourceStage.evaluate((element, height) => scrollTo(0, element.getBoundingClientRect().top + scrollY - (1000 - height) / 2), stageHeight);
    await page.waitForTimeout(300);
  }
  const environment = await page.evaluate(() => ({
    viewport: { width: innerWidth, height: innerHeight, dpr: devicePixelRatio },
    browserReducedMotion: matchMedia('(prefers-reduced-motion: reduce)').matches,
    probe: globalThis.__beuiCapture ?? null,
    fonts: [...document.fonts].map(font => ({ family: font.family, status: font.status, weight: font.weight })),
    colors: Object.fromEntries(['background', 'foreground', 'muted', 'muted-foreground', 'primary', 'primary-foreground'].map(name => [name, getComputedStyle(document.documentElement).getPropertyValue(`--${name}`).trim()])),
    htmlClass: document.documentElement.className,
    dataTheme: document.documentElement.dataset.theme ?? null,
  }));
  record.environment = { ...environment, browser: await browser.version() };
  assert.equal(environment.browserReducedMotion, reduced);
  if (!source) {
    assert.equal(environment.probe.disableAnimations, reduced);
    assert.equal(environment.probe.motionOverride, null);
    assert.equal(environment.probe.rect.width, previewWidth);
    assert((await page.locator('body').ariaSnapshot()).includes('palette source-default-a76e57c9'));
  } else {
    assert.equal(environment.dataTheme, null);
    assert.equal(environment.colors.primary, '#0285f7');
  }
  const cdp = await context.newCDPSession(page);
  const start = performance.now();
  const elapsed = () => performance.now() - start;
  let sampling = true;
  const sampler = (async () => {
    while (sampling) {
      const requestedMs = elapsed();
      const shot = await cdp.send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
      const receivedMs = elapsed();
      const bytes = Buffer.from(shot.data, 'base64');
      const file = `frames/${String(record.frames.length).padStart(6, '0')}.png`;
      await writeFile(`${output}/${file}`, bytes);
      record.frames.push({ file, requestedMs, receivedMs, sha256: hash(bytes) });
    }
  })();
  const shot = async state => {
    if (source) {
      await sourceStage.evaluate((element, height) => scrollTo({ top: element.getBoundingClientRect().top + scrollY - (1000 - height) / 2, behavior: 'instant' }), stageHeight);
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    }
    await page.mouse.move(10, 10);
    const stage = source ? await sourceStage.boundingBox() : {
      x: (Number(width) - Math.min(512, previewWidth)) / 2,
      y: (1000 - stageHeight) / 2,
      width: Math.min(512, previewWidth), height: stageHeight,
    };
    if (slug === 'voice-orb' && !source) {
      stage.width = stage.height = stageHeight;
      stage.x = (Number(width) - stageHeight) / 2;
    }
    const aria = await page.locator('body').ariaSnapshot();
    const controls = await page.evaluate(() => [...document.querySelectorAll('button, input, [role="button"], [role="radio"], [role="checkbox"], textarea')].filter(e => { const r = e.getBoundingClientRect(); return r.width && r.height; }).map(e => {
      const style = getComputedStyle(e);
      return { tag: e.tagName, role: e.getAttribute('role'), label: e.getAttribute('aria-label') || e.textContent, checked: e.getAttribute('aria-checked'), disabled: e.disabled || e.getAttribute('aria-disabled'), bounds: e.getBoundingClientRect().toJSON(), font: style.font, background: style.backgroundColor, color: style.color, focused: e === document.activeElement, value: e.value };
    }));
    const requestedMs = elapsed();
    const image = await cdp.send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
    const receivedMs = elapsed();
    const bytes = Buffer.from(image.data, 'base64');
    await writeFile(`${output}/${state}.png`, bytes);
    const nativeRaster = { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
    assert(stage.x >= 0 && stage.y >= 0 && stage.x + stage.width <= nativeRaster.width && stage.y + stage.height <= nativeRaster.height, 'stage exceeds the original screenshot raster');
    const localControls = controls.filter(c => c.bounds.x >= stage.x && c.bounds.y >= stage.y && c.bounds.right <= stage.x + stage.width && c.bounds.bottom <= stage.y + stage.height).map(c => ({ ...c, bounds: { x: c.bounds.x - stage.x, y: c.bounds.y - stage.y, width: c.bounds.width, height: c.bounds.height } }));
    record.snapshots.push({ state, stage, nativeRaster, aria, controls, localControls, requestedMs, receivedMs, sha256: hash(bytes), file: `${state}.png` });
    await writeFile(`${output}/record.json`, JSON.stringify(record, null, 2));
  };
  try {
    if (slug === 'file-diff') {
      const disclosure = source ? page.getByRole('button', { name: /src\/runner\.ts/ }) : page.getByRole('button', { name: /Expand file diff/ });
      await shot('complete-collapsed');
      await disclosure.click();
      await page.waitForTimeout(350);
      await shot('complete-expanded');
      const copy = page.getByRole('button', { name: 'Copy diff', exact: true });
      await copy.click();
      await page.getByRole('button', { name: 'Copied', exact: true }).waitFor();
      record.clipboard = await page.evaluate(() => navigator.clipboard.readText());
      assert.equal(record.clipboard, 'export async function runTask() {\n  return execute(task);\n  const result = await execute(task);\n  return normalize(result);\n}');
      await shot('copied');
      await replay.click();
      const replayAt = elapsed();
      for (const [state, at] of [['row-1', 300], ['row-2', 660], ['row-3', 1020], ['row-4', 1380], ['row-5', 1740], ['stream-complete', 2600]]) {
        const delay = replayAt + at - elapsed();
        if (delay > 0) await page.waitForTimeout(delay);
        await shot(state);
      }
    } else if (slug === 'approval-card' && review) {
      for (const [action, outcome] of [['Approve', 'Publishing was approved.'], ['Request changes', 'The agent will wait for revision notes.'], ['Reject', 'Publishing was declined.']]) {
        if (record.snapshots.length) {
          await replay.click();
          await page.waitForTimeout(350);
        }
        await shot(`${action.toLowerCase().replaceAll(' ', '-')}-pending`);
        await page.getByRole('button', { name: action, exact: true }).click();
        await shot(`${action.toLowerCase().replaceAll(' ', '-')}-submitting`);
        await page.waitForFunction(text => [...document.querySelectorAll('p, [aria-label]')].some(e => (e.getAttribute('aria-label') || e.textContent).includes(text)), outcome);
        await page.waitForTimeout(350);
        await shot(`${action.toLowerCase().replaceAll(' ', '-')}-outcome`);
      }
    } else if (slug === 'approval-card') {
      await shot('idle');
      await page.getByRole('radio', { name: /A focused starter set/ }).click();
      await page.getByRole('checkbox', { name: 'Type safety', exact: true }).waitFor();
      await page.waitForTimeout(350);
      await shot('checks-idle');
      await page.getByRole('checkbox', { name: 'Type safety', exact: true }).click();
      await page.waitForTimeout(180);
      assert.equal(await page.getByRole('checkbox', { name: 'Type safety', exact: true }).getAttribute('aria-checked'), 'true');
      await page.getByRole('checkbox', { name: 'Accessibility', exact: true }).click();
      await page.waitForTimeout(180);
      assert.equal(await page.getByRole('checkbox', { name: 'Accessibility', exact: true }).getAttribute('aria-checked'), 'true');
      await shot('checks-selected');
      await page.getByRole('button', { name: 'Next question', exact: true }).click();
      await page.waitForTimeout(350);
      await shot('after-next-dispatch');
      const submit = page.getByRole('button', { name: /^Submit response(?: Submit response)*$/ });
      await submit.waitFor();
      await page.waitForTimeout(350);
      const field = source ? page.getByPlaceholder('Add a final constraint…', { exact: true }) : page.getByRole('textbox');
      await field.click();
      await page.waitForTimeout(300);
      assert(await field.evaluate(e => document.activeElement === e), 'actual field focus missing');
      await page.keyboard.type('Keep the release focused.', { delay: 35 });
      await page.waitForTimeout(250);
      assert.equal(await field.inputValue(), 'Keep the release focused.');
      await shot('constraint');
      await submit.click();
      await shot('submitting');
      await page.waitForFunction(() => [...document.querySelectorAll('p, [aria-label]')].some(e => (e.getAttribute('aria-label') || e.textContent).includes('Three responses sent to the agent.')));
      await page.waitForTimeout(350);
      await shot('answered');
    } else {
      await shot(reduced ? 'reduced-static' : 'running-unsynchronized');
      await page.waitForTimeout(350);
      await shot(reduced ? 'reduced-held' : 'running-held-unsynchronized');
    }
  } finally {
    sampling = false;
    await sampler;
  }
  await Promise.all(pending);
  if (!source) assert(record.loaded.some(script => script.sha256 === expectedJs), 'actual loaded JavaScript differs');
  const concat = ['ffconcat version 1.0'];
  record.frames.forEach((frame, i) => {
    concat.push(`file '${frame.file}'`, 'option framerate 1000000');
    if (i + 1 < record.frames.length) concat.push(`duration ${((record.frames[i + 1].receivedMs - frame.receivedMs) / 1000).toFixed(6)}`);
  });
  await writeFile(`${output}/frames.ffconcat`, concat.join('\n') + '\n');
  const encoded = spawnSync('ffmpeg', ['-nostdin', '-v', 'warning', '-f', 'concat', '-safe', '0', '-i', `${output}/frames.ffconcat`, '-fps_mode', 'passthrough', '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '0', '-pix_fmt', 'yuv444p', '-video_track_timescale', '1000000', `${output}/capture.mp4`], { encoding: 'utf8' });
  await writeFile(`${output}/ffmpeg.txt`, encoded.stderr);
  assert.equal(encoded.status, 0, encoded.stderr);
  const video = JSON.parse(spawnSync('ffprobe', ['-v', 'error', '-count_frames', '-show_streams', '-of', 'json', `${output}/capture.mp4`], { encoding: 'utf8' }).stdout).streams[0];
  const gaps = record.frames.slice(1).map((f, i) => f.receivedMs - record.frames[i].receivedMs);
  record.cadence = { samples: record.frames.length, decodedFrames: Number(video.nb_read_frames), width: video.width, height: video.height, measuredFps: (record.frames.length - 1) * 1000 / (record.frames.at(-1).receivedMs - record.frames[0].receivedMs), maxGapMs: Math.max(...gaps), interpolated: false, temporalEquivalence: false };
  assert.equal(record.cadence.samples, record.cadence.decodedFrames);
  await writeFile(`${output}/record.json`, JSON.stringify(record, null, 2));
  console.log(JSON.stringify({ run, states: record.snapshots.map(s => s.state), errorCount: record.errors.length, cadence: record.cadence }));
} catch (error) {
  record.failure = String(error.stack);
  await writeFile(`${output}/record.json`, JSON.stringify(record, null, 2));
  throw error;
} finally { await browser.close(); }
