#!/usr/bin/env node
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';
import { performance } from 'node:perf_hooks';
import { createHash } from 'node:crypto';

const [configPath, outputPath] = process.argv.slice(2);
if (!configPath || !outputPath || !process.env.PARITY_PLAYWRIGHT) {
  throw new Error('Usage: PARITY_PLAYWRIGHT=/absolute/playwright-core/index.mjs node tool/parity_capture.mjs CONFIG NEW_OUTPUT_DIRECTORY');
}
const config = JSON.parse(await readFile(configPath, 'utf8'));
const output = resolve(outputPath);
await mkdir(output);
await mkdir(join(output, 'original-frames'));
await writeFile(join(output, 'config.json'), JSON.stringify(config, null, 2));
const { chromium } = await import(pathToFileURL(process.env.PARITY_PLAYWRIGHT));
const browser = await chromium.launch({
  executablePath: config.chrome || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  headless: true,
});
const frames = [];
const events = [];
const errors = [];
const pending = [];
const origin = performance.now();
const originEpochMs = Date.now();
const elapsed = () => performance.now() - origin;
try {
  const context = await browser.newContext({
    viewport: config.viewport, deviceScaleFactor: 1,
    colorScheme: config.theme, reducedMotion: 'no-preference',
    locale: 'en-US', timezoneId: 'Asia/Kolkata',
  });
  const page = await context.newPage();
  page.setDefaultTimeout(20000);
  console.log('Navigating', config.url);
  await page.goto(config.url, { waitUntil: 'domcontentloaded', timeout: 60000 });
  if (config.reference) {
    await page.getByRole('tab', { name: `${config.theme === 'light' ? 'Light' : 'Dark'} theme`, exact: true }).click();
  }
  console.log('Waiting for renderer and fonts');
  await page.waitForTimeout(config.loadWaitMs || 8000);
  await page.evaluate(() => document.fonts.ready);
  console.log('Resolving targets');
  const targets = {};
  for (const [name, target] of Object.entries(config.targets)) {
    if (target.role) {
      const box = await page.getByRole(target.role, { name: target.name, exact: true }).boundingBox();
      if (!box) throw new Error(`Missing target ${name}`);
      targets[name] = { ...box, x: box.x + box.width / 2, y: box.y + box.height / 2 };
    } else targets[name] = target;
  }
  const environment = await page.evaluate(() => ({
    viewport: { width: innerWidth, height: innerHeight }, dpr: devicePixelRatio,
    scroll: { x: scrollX, y: scrollY }, locale: navigator.language,
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    reducedMotion: matchMedia('(prefers-reduced-motion: reduce)').matches,
    htmlClass: document.documentElement.className,
    background: getComputedStyle(document.body).backgroundColor,
    fonts: [...document.fonts].map(f => ({ family: f.family, status: f.status })),
    flutter: !!document.querySelector('flutter-view'),
  }));
  await writeFile(join(output, 'environment.json'), JSON.stringify({
    ...environment, browser: browser.version(), targets, provenance: config.provenance,
  }, null, 2));
  await page.mouse.move(10, 10);
  const cdp = await context.newCDPSession(page);
  let sampling = true;
  let sampler;
  const append = (data, metadata, requestedMs) => {
    const index = frames.length;
    const file = `original-frames/frame_${String(index).padStart(6, '0')}.png`;
    const bytes = Buffer.from(data, 'base64');
    frames.push({ index, file, requestedMs, receivedMs: elapsed(), metadata,
      sha256: createHash('sha256').update(bytes).digest('hex') });
    pending.push(writeFile(join(output, file), bytes));
  };
  cdp.on('Page.screencastFrame', event => {
    append(event.data, event.metadata);
    pending.push(cdp.send('Page.screencastFrameAck', { sessionId: event.sessionId }).catch(e => errors.push(String(e))));
  });
  const startMs = elapsed();
  if (config.backend === 'screenshots') {
    sampler = (async () => {
      try {
        while (sampling) {
          const requestedMs = elapsed();
          let timer;
          let result;
          try {
            result = await Promise.race([
              cdp.send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false }),
              new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('Screenshot exceeded 30000ms')), 30000); }),
            ]);
          } finally { clearTimeout(timer); }
          append(result.data, { timestamp: (originEpochMs + elapsed()) / 1000,
            timestampMeaning: 'response receipt; exposure lies inside request-response interval' }, requestedMs);
        }
      } catch (error) {
        errors.push(String(error));
        sampling = false;
      }
    })();
  } else await cdp.send('Page.startScreencast', { format: 'png', everyNthFrame: 1 });
  const sequenceStartMs = elapsed();
  const dispatch = {
    move: (action, target) => page.mouse.move(target.x, target.y),
    click: (action, target) => page.mouse.click(target.x, target.y),
    key: action => page.keyboard.press(action.key),
    text: action => page.keyboard.insertText(action.text),
  };
  for (const action of config.events) {
    const type = action.type ?? 'move';
    if (!Object.hasOwn(dispatch, type)) throw new Error(`Unknown event type ${type}`);
    const target = targets[action.target];
    if ((action.target !== undefined || type === 'move' || type === 'click') && !target) throw new Error(`Unknown target ${action.target}`);
    if (type === 'key' && typeof action.key !== 'string') throw new Error('Key event requires a string key');
    if (type === 'text' && typeof action.text !== 'string') throw new Error('Text event requires a string text');
    const requestedMs = sequenceStartMs + action.atMs;
    while (elapsed() < requestedMs) await page.waitForTimeout(Math.ceil(requestedMs - elapsed()));
    const event = { ...action, type, pointer: type === 'move' || type === 'click' ? target : undefined,
      requestedMs, dispatchBeforeMs: elapsed() };
    events.push(event);
    try {
      await dispatch[type](action, target);
    } catch (error) {
      event.error = String(error);
      throw error;
    } finally {
      event.dispatchAfterMs = elapsed();
    }
  }
  await page.waitForTimeout(config.finalHoldMs || 700);
  const stopMs = elapsed();
  sampling = false;
  if (sampler) await sampler;
  else await cdp.send('Page.stopScreencast');
  cdp.removeAllListeners('Page.screencastFrame');
  await Promise.all(pending);
  if (errors.length) throw new Error(errors.join('\n'));
  const sorted = [...frames].sort((a, b) => a.metadata.timestamp - b.metadata.timestamp);
  const timestamps = sorted.map(f => f.metadata.timestamp);
  if (sorted.length < 2 || timestamps.some(t => !Number.isFinite(t))) throw new Error('No usable compositor timestamps');
  const intervalsMs = timestamps.slice(1).map((t, i) => (t - timestamps[i]) * 1000);
  if (intervalsMs.some(t => t <= 0)) throw new Error('Duplicate compositor timestamps. Originals retained, refusing video.');
  const durationMs = (timestamps.at(-1) - timestamps[0]) * 1000;
  const stats = {
    originEpochMs, backend: config.backend || 'compositor', startMs, sequenceStartMs, stopMs, frames: frames.length, durationMs,
    measuredFps: (frames.length - 1) * 1000 / durationMs,
    medianIntervalMs: [...intervalsMs].sort((a, b) => a - b)[Math.floor(intervalsMs.length / 2)],
    maxIntervalMs: Math.max(...intervalsMs),
    reorderedDeliveries: frames.filter((f, i) => f.index !== sorted[i].index).length,
    fastMotionVerdict: 'inconclusive; inspect per-event gaps, not nominal frame rate',
    errors,
  };
  await writeFile(join(output, 'timeline.json'), JSON.stringify({ stats, events, frames }, null, 2));
  const concat = ['ffconcat version 1.0'];
  sorted.forEach((frame, i) => {
    concat.push(`file '${frame.file}'`, 'option framerate 1000000');
    if (i + 1 < sorted.length) concat.push(`duration ${(timestamps[i + 1] - timestamps[i]).toFixed(6)}`);
  });
  await writeFile(join(output, 'frames.ffconcat'), concat.join('\n') + '\n');
  const encode = spawnSync('ffmpeg', ['-nostdin', '-v', 'warning', '-f', 'concat', '-safe', '0',
    '-i', join(output, 'frames.ffconcat'), '-fps_mode', 'passthrough',
    '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '0', '-pix_fmt', 'yuv444p',
    '-video_track_timescale', '1000000', join(output, 'capture.mp4')], { encoding: 'utf8' });
  await writeFile(join(output, 'ffmpeg.log'), encode.stderr);
  if (encode.status !== 0) throw new Error(`FFmpeg failed: ${encode.stderr}`);
  const probe = spawnSync('ffprobe', ['-v', 'error', '-count_frames', '-show_streams', '-show_format',
    '-show_frames', '-of', 'json', join(output, 'capture.mp4')], { encoding: 'utf8', maxBuffer: 100000000 });
  if (probe.status !== 0) throw new Error(probe.stderr);
  await writeFile(join(output, 'ffprobe.json'), probe.stdout);
  const decoded = JSON.parse(probe.stdout);
  if (Number(decoded.streams[0].nb_read_frames) !== frames.length) throw new Error('Encoded frame count differs from delivered frame count');
  stats.video = { width: decoded.streams[0].width, height: decoded.streams[0].height,
    decodedFrames: Number(decoded.streams[0].nb_read_frames) };
  await writeFile(join(output, 'timeline.json'), JSON.stringify({ stats, events, frames }, null, 2));
  console.log(JSON.stringify(stats, null, 2));
} catch (error) {
  await writeFile(join(output, 'failure.json'), JSON.stringify({ error: String(error), events, frames }, null, 2));
  throw error;
} finally {
  await browser.close();
}
