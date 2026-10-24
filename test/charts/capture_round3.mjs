import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { resolve, join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { performance } from 'node:perf_hooks';
import puppeteer from '/tmp/puppeteer-orb/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';

const [configFile, destination] = process.argv.slice(2);
const config = JSON.parse(await readFile(configFile, 'utf8'));
const output = resolve(destination);
await mkdir(output);
await mkdir(join(output, 'frames'));
await writeFile(join(output, 'config.json'), JSON.stringify(config, null, 2));
if (!config.reference) {
  const bytes = await (await fetch('http://127.0.0.1:8109/main.dart.js')).arrayBuffer();
  const served = createHash('sha256').update(Buffer.from(bytes)).digest('hex');
  if (served !== config.jsSha256) throw Error(`Served JavaScript SHA mismatch: ${served}`);
  await writeFile(join(output, 'served-js.json'), JSON.stringify({served, expected: config.jsSha256}));
}
const browser = await puppeteer.launch({executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true});
const frames = [];
const events = [];
const errors = [];
const start = performance.now();
const elapsed = () => performance.now() - start;
try {
  const page = await browser.newPage();
  await page.setViewport({width: 1280, height: 1000, deviceScaleFactor: 1});
  await page.emulateTimezone('Asia/Kolkata');
  await page.emulateMediaFeatures([{name: 'prefers-color-scheme', value: config.theme || 'dark'}, {name: 'prefers-reduced-motion', value: config.reduce ? 'reduce' : 'no-preference'}]);
  page.on('pageerror', error => errors.push(String(error)));
  await page.evaluateOnNewDocument(() => {
    window.__suppressedTimers = [];
    for (const name of ['setTimeout', 'setInterval']) {
      const original = window[name].bind(window);
      window[name] = (callback, delay, ...args) => {
        if (delay === 900 || delay === 950) {
          window.__suppressedTimers.push({name, delay});
          return original(() => {}, 2147483647);
        }
        return original(callback, delay, ...args);
      };
    }
  });
  await page.goto(config.url, {waitUntil: 'networkidle0', timeout: 60000});
  await page.evaluate(theme => {
    document.documentElement.classList.toggle('dark', theme !== 'light');
    document.querySelector('flt-semantics-placeholder')?.click();
    return document.fonts.ready;
  }, config.theme);
  await new Promise(resolve => setTimeout(resolve, 900));
  const targets = await page.evaluate(({slug, reference}) => {
    const text = e => e.getAttribute('aria-label') || e.textContent;
    let nodes = [...document.querySelectorAll('main button, main input[type="range"], main [role="slider"], flt-semantics[role="button"], flt-semantics[role="slider"]')]
      .filter(e => {const r = e.getBoundingClientRect(); return r.width > 0 && r.height > 0 && r.y > 350 && r.y < 950 && r.x > 280;});
    const patterns = {
      treemap: /Technology \/ (AAPL|MSFT)/,
      'liquidity-heatmap': /14:0[02], \$250.00:/,
      'heat-calendar': /commits/,
      'returns-calendar': /2021/,
      'price-target-fan': /^(High|Mean) target/,
      'order-book': reference ? /^247\.(20|16)$/ : /ask, 247\.(20|16)/,
      'status-bar': reference ? /API status: inspect period/ : /Aug 2[12],/,
    };
    nodes = nodes.filter(e => patterns[slug].test(text(e)));
    const selected = nodes.slice(0, 2);
    return selected.map((e, i) => {
      e.setAttribute('data-round3-target', String(i));
      const r = e.getBoundingClientRect();
      return {name: text(e), x: r.x, y: r.y, width: r.width, height: r.height};
    });
  }, config);
  if (!targets.length) throw Error(`No targets for ${config.slug}`);
  const environment = await page.evaluate(() => ({url: location.href, viewport: [innerWidth, innerHeight], dpr: devicePixelRatio, reducedMotion: matchMedia('(prefers-reduced-motion: reduce)').matches, fonts: document.fonts.status, timers: window.__suppressedTimers, flutter: !!document.querySelector('flutter-view')}));
  await writeFile(join(output, 'environment.json'), JSON.stringify({...environment, targets, browser: await browser.version(), provenance: config.provenance}, null, 2));
  const cdp = await page.createCDPSession();
  let sampling = true;
  const sampler = (async () => {
    while (sampling) {
      const requestedMs = elapsed();
      const shot = await cdp.send('Page.captureScreenshot', {format: 'png', captureBeyondViewport: false});
      const receivedMs = elapsed();
      const file = `frames/${String(frames.length).padStart(6, '0')}.png`;
      const bytes = Buffer.from(shot.data, 'base64');
      await writeFile(join(output, file), bytes);
      frames.push({file, requestedMs, receivedMs, sha256: createHash('sha256').update(bytes).digest('hex')});
    }
  })();
  const sequence = elapsed();
  const actions = config.actions || [
    {atMs: 400, kind: 'hover', target: 0, caption: 'A'},
    {atMs: 1100, kind: 'hover', target: 1, caption: 'B'},
    {atMs: 1220, kind: 'hover', target: 0, caption: 'A reversal'},
    {atMs: 2000, kind: 'exit', caption: 'Pointer exit'},
    {atMs: 2400, kind: 'tab', caption: 'Actual Tab traversal'},
  ];
  for (const action of actions) {
    const wait = sequence + action.atMs - elapsed();
    if (wait > 0) await new Promise(resolve => setTimeout(resolve, wait));
    const dispatchBeforeMs = elapsed();
    if (action.kind === 'hover') {
      const target = targets[action.target] || targets[0];
      await page.mouse.move(target.x + target.width * (targets.length === 1 && action.target === 1 ? .6 : .5), target.y + target.height / 2);
    } else if (action.kind === 'exit') await page.mouse.move(1100, 250);
    else if (action.kind === 'key') await page.keyboard.press(action.key);
    else if (action.kind === 'tab') {
      await page.mouse.click(1100, 250);
      for (let i = 0; i < 100; i++) {
        await page.keyboard.press('Tab');
        const focus = await page.evaluate(() => {
          const e = document.activeElement;
          const r = e?.getBoundingClientRect();
          return {label: e?.getAttribute('aria-label'), chart: r && r.x > 280 && r.y > 350 && r.y < 950 && (e?.hasAttribute('data-round3-target') || e?.closest('flt-semantics'))};
        });
        events.push({kind: 'tab-step', ms: elapsed(), focus});
        if (focus.chart) break;
      }
    } else if (action.kind === 'reload') {
      await page.reload({waitUntil: 'domcontentloaded'});
    }
    const dispatchAfterMs = elapsed();
    const state = await page.evaluate(() => ({focus: {tag: document.activeElement?.tagName, label: document.activeElement?.getAttribute('aria-label')}, tooltips: [...document.querySelectorAll('[role="tooltip"]')].map(e => e.textContent), values: [...document.querySelectorAll('[aria-valuetext]')].map(e => e.getAttribute('aria-valuetext'))}));
    events.push({...action, dispatchBeforeMs, dispatchAfterMs, state});
  }
  await new Promise(resolve => setTimeout(resolve, config.finalHoldMs || 700));
  sampling = false;
  await sampler;
  const intervals = frames.slice(1).map((f, i) => f.receivedMs - frames[i].receivedMs);
  const duration = frames.at(-1).receivedMs - frames[0].receivedMs;
  const stats = {backend: 'screenshots', frames: frames.length, durationMs: duration, measuredFps: (frames.length - 1) * 1000 / duration, maxIntervalMs: Math.max(...intervals), timingVerdict: 'inconclusive; screenshot receipt timestamps are not native exposure timestamps', errors};
  await writeFile(join(output, 'timeline.json'), JSON.stringify({stats, events, frames}, null, 2));
  const concat = ['ffconcat version 1.0'];
  frames.forEach((frame, index) => {
    concat.push(`file '${frame.file}'`, 'option framerate 1000000');
    if (index + 1 < frames.length) concat.push(`duration ${((frames[index + 1].receivedMs - frame.receivedMs) / 1000).toFixed(6)}`);
  });
  await writeFile(join(output, 'frames.ffconcat'), concat.join('\n') + '\n');
  const encode = spawnSync('ffmpeg', ['-nostdin', '-v', 'warning', '-f', 'concat', '-safe', '0', '-i', join(output, 'frames.ffconcat'), '-fps_mode', 'passthrough', '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '0', '-pix_fmt', 'yuv444p', '-video_track_timescale', '1000000', join(output, 'capture.mp4')], {encoding: 'utf8'});
  await writeFile(join(output, 'ffmpeg.log'), encode.stderr);
  if (encode.status !== 0) throw Error(encode.stderr);
  const probe = spawnSync('ffprobe', ['-v', 'error', '-count_frames', '-show_streams', '-of', 'json', join(output, 'capture.mp4')], {encoding: 'utf8'});
  await writeFile(join(output, 'ffprobe.json'), probe.stdout);
  if (Number(JSON.parse(probe.stdout).streams[0].nb_read_frames) !== frames.length) throw Error('Decoded frame count mismatch');
  console.log(config.slug, stats);
} catch (error) {
  await writeFile(join(output, 'failure.json'), JSON.stringify({error: String(error), events, frames}, null, 2));
  throw error;
} finally {
  await browser.close();
}
