import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { performance } from 'node:perf_hooks';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const [phase = 'final', slug = 'chat-app', example = 'source', run = '1'] = process.argv.slice(2);
const reduced = process.env.CAPTURE_REDUCE === 'true';
const mobile = process.env.CAPTURE_MOBILE === 'true';
const stageWidth = mobile ? 390 : 752;
const root = fileURLToPath(new URL('./', import.meta.url));
const dir = `${root}flows/${phase}/${slug}-${example}${reduced ? '-reduced' : ''}${mobile ? '-mobile' : ''}-run${run}`;
await mkdir(`${root}flows/${phase}`, { recursive: true });
await mkdir(dir);
await mkdir(`${dir}/frames`);
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const url = phase === 'reference' ? `https://beui.dev/components/agents/${slug}` : `http://127.0.0.1:18107/agents-round2-${phase}/?slug=${slug}&theme=dark&stageWidth=${stageWidth}&captureProbe=1&reduce=${reduced}${example === 'source' ? '' : `&example=${example}`}`;
if (phase !== 'reference') {
  const index = await (await fetch(url)).text();
  assert(index.includes(`<base href="/agents-round2-${phase}/">`), 'index base does not select frozen build');
  const build = `example/build/agents-round2-${phase}/main.dart.js`;
  const local = sha(await readFile(build));
  const served = sha(Buffer.from(await (await fetch(new URL('main.dart.js', url))).arrayBuffer()));
  assert.equal(served, local, 'served main.dart.js differs from frozen build');
  await writeFile(`${dir}/build-verification.json`, JSON.stringify({ at: new Date().toISOString(), build, local, served, url }, null, 2));
}
const browser = await chromium.launch({ channel: 'chrome', headless: true });
const context = await browser.newContext({ viewport: { width: mobile ? 390 : 1440, height: 1000 }, deviceScaleFactor: 1, colorScheme: 'dark', reducedMotion: reduced ? 'reduce' : 'no-preference', locale: 'en-US', timezoneId: 'Asia/Kolkata' });
const page = await context.newPage();
const loadedScripts = [];
page.on('response', async response => {
  if (new URL(response.url()).pathname.endsWith('/main.dart.js')) loadedScripts.push({ url: response.url(), sha256: sha(await response.body()) });
});
const events = [];
const frames = [];
const origin = performance.now();
const elapsed = () => performance.now() - origin;
let sampling = false;
let sampler;
const record = async (name, expected, absent) => {
  const aria = await page.locator('body').ariaSnapshot();
  const event = { name, atMs: elapsed(), expected, absent, aria };
  events.push(event);
  if (expected) assert(aria.includes(expected), `Missing ${expected} in ${name}`);
  if (absent) assert(!aria.includes(absent), `Unexpected ${absent} in ${name}`);
};
const action = async (name, run) => {
  const event = { action: name, beforeMs: elapsed() };
  events.push(event);
  await run();
  event.afterMs = elapsed();
};
const button = name => page.getByRole('button', { name, exact: true });
const typeField = async (field, value) => {
  await page.keyboard.press('Tab');
  await field.click();
  await page.waitForTimeout(150);
  await page.keyboard.press('ControlOrMeta+A');
  await page.keyboard.type(value, { delay: 35 });
  await page.waitForTimeout(150);
  const focused = await page.evaluate(() => ({ tag: document.activeElement.tagName, value: document.activeElement.value }));
  const editors = await page.evaluate(() => [...document.querySelectorAll('textarea,input')].map(e => ({tag:e.tagName, parent:e.parentElement.tagName, value:e.value, active:e === document.activeElement, rect:e.getBoundingClientRect().toJSON()})));
  events.push({ composerBeforeSubmit: focused, editors, atMs: elapsed() });
  assert.equal(focused.value, value, 'actual focused composer text differs');
};
const enterComposer = async (field, value) => { await typeField(field, value); await page.keyboard.press('Enter'); };
try {
  await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 });
  if (phase !== 'reference') {
    await page.waitForSelector('flutter-view', { state: 'attached', timeout: 30000 });
    const local = sha(await readFile(`example/build/agents-round2-${phase}/main.dart.js`));
    assert(loadedScripts.some(script => script.sha256 === local && new URL(script.url).pathname === `/agents-round2-${phase}/main.dart.js`), 'browser did not load frozen main.dart.js');
    await writeFile(`${dir}/loaded-scripts.json`, JSON.stringify(loadedScripts, null, 2));
  }
  if (phase === 'reference') {
    await page.getByRole('tab', { name: 'Dark theme', exact: true }).first().click();
    if (slug === 'chat-app') await button('Expand preview').last().click();
  } else await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(700);
  await record('idle');
  if (phase !== 'reference') assert(events.at(-1).aria.includes(`Capture stage width ${stageWidth} height 1000 reduced ${reduced}`), 'measured stage differs from requested constraints');
  if (phase === 'probed' || phase.startsWith('favicons')) {
    const environment = await page.evaluate(() => ({ browser: matchMedia('(prefers-reduced-motion: reduce)').matches, flutter: globalThis.__beuiCapture }));
    await writeFile(`${dir}/motion-environment.json`, JSON.stringify(environment, null, 2));
    assert.equal(environment.browser, reduced);
    assert.equal(environment.flutter.disableAnimations, reduced);
    assert.equal(environment.flutter.motionOverride, null);
    assert.equal(environment.flutter.rect.width, stageWidth);
  }
  const cdp = await context.newCDPSession(page);
  sampling = true;
  sampler = (async () => {
    while (sampling) {
      const requestedMs = elapsed();
      const { data } = await cdp.send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
      const receivedMs = elapsed();
      const file = `frames/frame_${String(frames.length).padStart(6, '0')}.png`;
      const bytes = Buffer.from(data, 'base64');
      await writeFile(`${dir}/${file}`, bytes);
      frames.push({ file, requestedMs, receivedMs, sha256: sha(bytes) });
    }
  })();
  if (slug === 'chat-app') {
    if (mobile) {
      await action('open actual mobile sidebar', () => button('Show sidebar').click());
      await page.waitForTimeout(350);
      await record('mobile rail visible', 'Projects');
      const scrim = await button('Close navigation').boundingBox();
      assert(scrim, 'mobile close scrim missing');
      await action('dismiss mobile sidebar scrim', () => page.mouse.click(scrim.x + scrim.width - 8, scrim.y + scrim.height / 2));
      await page.waitForTimeout(300);
      await record('mobile rail dismissed', 'Show sidebar', 'Projects');
    }
    const field = page.getByRole('textbox', { name: /^Prompt(?: Ask the agent to continue…)?$/ });
    await action('actual composer keyboard entry and Enter', () => enterComposer(field, 'Round two verified composer'));
    await page.waitForTimeout(100);
    await record('submitted user echo', 'Round two verified composer');
    await record('source pending row', 'Reviewing your direction');
    await action('stop during pending', () => button('Stop generating').click());
    await page.waitForTimeout(500);
    await record('pending stop leaves no fabricated response', 'Round two verified composer', 'Reviewing your direction');
    await action('second submission', () => enterComposer(field, 'Exercise streamed output'));
    await page.waitForTimeout(780);
    await record('incremental response', 'I’ll keep the patch');
    await action('stop after tokens', () => button('Stop generating').click());
    await page.waitForTimeout(300);
    await record('stopped after tokens', 'Exercise streamed output');
    if (phase !== 'reference') {
      await record('additive stopped notice', 'Response stopped before it finished.');
      await action('continue same reply', () => button('Continue generating').click());
      await page.waitForTimeout(2000);
      await record('complete resumed response', 'I’ll keep the patch focused, preserve the current checkout layout, and run the same validation path before preparing the release.', 'Response stopped before it finished.');
      if (example === 'api-specimens') {
        await action('retry existing response', () => button('Retry').last().click());
        await page.waitForTimeout(1800);
        await record('retry completes without another user turn', 'Exercise streamed output', 'Stop generating');
        assert.equal(events.at(-1).aria.split('Exercise streamed output').length - 1, 1, 'retry duplicated the submitted user turn');
      }
    } else {
      await action('source fresh submission after stop', () => enterComposer(field, 'Finish the source response'));
      await page.waitForTimeout(2200);
      await record('source full completion', 'I’ll keep the patch focused, preserve the current checkout layout, and run the same validation path before preparing the release.');
    }
    await action('deny tool', () => button('Deny').click());
    await page.waitForTimeout(300);
    await record('denied tool is visible', 'No command was run.');
  } else if (slug === 'prompt-input') {
    const field = page.getByRole('textbox', { name: /^Prompt(?: Ask the agent to do something…)?$/ });
    await action('submit source prompt through composer', () => enterComposer(field, 'Review the current implementation and suggest the next improvement.'));
    await record('loading send becomes stop', 'Stop generating');
    await page.waitForTimeout(1150);
    await record('900ms notice rather than transcript', 'Prompt sent to the selected model.');
    await action('open actions', () => button('Add to prompt').click());
    await action('choose attach image', () => page.getByRole('button', { name: /Attach image/ }).last().click());
    await page.waitForTimeout(300);
    await record('sent notice priority survives action', 'Prompt sent to the selected model.', 'Attach image selected.');
  } else if (slug === 'approval-card') {
    await record('all source option descriptions', 'Ship a few polished pieces first.');
    await record('second description', 'Cover more ground with lighter depth.');
    await record('third description', 'Pour everything into a single showcase.');
    await action('select focused scope', () => page.getByRole('radio', { name: /^A focused starter set/ }).click());
    await page.waitForTimeout(500);
    await record('auto-advanced second question', 'Which checks should block publishing?');
    await action('select two checks', async () => { await page.getByRole('checkbox', { name: 'Type safety', exact: true }).click(); await page.getByRole('checkbox', { name: 'Accessibility', exact: true }).click(); });
    await action('continue', () => button('Next question').click());
    await page.waitForTimeout(300);
    await record('freeform question', 'Anything the agent should preserve?');
    const field = page.getByRole('textbox');
    await action('actual freeform keyboard entry', () => typeField(field, 'Preserve the source data'));
    await action('submit responses', () => page.getByRole('button', { name: /^Submit response(?: Submit response)?$/ }).click());
    await page.waitForTimeout(1000);
    await record('answered after 750ms', 'Three responses sent to the agent.');
  }
  await page.waitForTimeout(500);
} catch (error) {
  events.push({ failure: String(error), atMs: elapsed(), aria: await page.locator('body').ariaSnapshot().catch(String) });
  process.exitCode = 1;
} finally {
  sampling = false;
  if (sampler) await sampler;
  await writeFile(`${dir}/events.json`, JSON.stringify(events, null, 2));
  if (frames.length) {
    const concat = ['ffconcat version 1.0'];
    frames.forEach((f, i) => { concat.push(`file '${f.file}'`, 'option framerate 1000000'); if (i + 1 < frames.length) concat.push(`duration ${((frames[i + 1].receivedMs - f.receivedMs) / 1000).toFixed(6)}`); });
    await writeFile(`${dir}/frames.ffconcat`, concat.join('\n') + '\n');
    const encode = spawnSync('ffmpeg', ['-nostdin', '-v', 'warning', '-f', 'concat', '-safe', '0', '-i', `${dir}/frames.ffconcat`, '-fps_mode', 'passthrough', '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '0', '-pix_fmt', 'yuv444p', '-video_track_timescale', '1000000', `${dir}/capture.mp4`], { encoding: 'utf8' });
    await writeFile(`${dir}/ffmpeg.log`, encode.stderr);
    const gaps = frames.slice(1).map((f, i) => f.receivedMs - frames[i].receivedMs);
    await writeFile(`${dir}/timeline.json`, JSON.stringify({ url, frames, events, measuredFps: (frames.length - 1) * 1000 / (frames.at(-1).receivedMs - frames[0].receivedMs), maxGapMs: Math.max(...gaps), noInterpolation: true, verdict60fps: 'Unresolved' }, null, 2));
  }
  await browser.close();
}
