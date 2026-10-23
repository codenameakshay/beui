#!/usr/bin/env node
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { access, mkdtemp, readFile, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawn } from 'node:child_process';
import { createHash } from 'node:crypto';

const observed = [];
const fixture = `<!doctype html><html><body>
<button style="position:absolute;left:40px;top:40px;width:180px;height:50px">Advance</button>
<input aria-label="Search" style="position:absolute;left:40px;top:120px;width:180px;height:40px">
<output style="position:absolute;left:40px;top:200px">Ready</output>
<div id="pan" style="position:absolute;left:300px;top:240px;width:100px;height:80px;touch-action:none">Pan</div>
<script>
const button = document.querySelector('button');
const input = document.querySelector('input');
const output = document.querySelector('output');
const report = value => { output.textContent = value; fetch('/observed', {method:'POST', body:value}); };
report('motion:' + matchMedia('(prefers-reduced-motion: reduce)').matches);
button.addEventListener('mouseenter', () => report('pointer entered'));
button.addEventListener('click', () => report('advanced'));
input.addEventListener('input', () => report('value:' + input.value));
input.addEventListener('keydown', event => { if (event.key === 'Enter') report('submitted:' + input.value); });
const pan = document.querySelector('#pan');
pan.addEventListener('pointerdown', event => { event.preventDefault(); pan.setPointerCapture(event.pointerId); });
document.addEventListener('contextmenu', event => event.preventDefault());
for (const type of ['pointerdown', 'pointermove', 'pointerup']) {
  document.addEventListener(type, event => {
    if (event.clientX < 300 || event.clientY < 240) return;
    report(JSON.stringify({ type, x: event.clientX, y: event.clientY, button: event.button,
      buttons: event.buttons, trusted: event.isTrusted, time: event.timeStamp }));
  });
}
</script></body></html>`;
const server = createServer(async (request, response) => {
  if (request.url === '/observed' && request.method === 'POST') {
    let body = '';
    for await (const chunk of request) body += chunk;
    observed.push(body);
    response.end('ok');
  } else {
    response.setHeader('content-type', 'text/html');
    response.end(fixture);
  }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const directory = await mkdtemp(join(tmpdir(), 'beui-capture-events-'));
const run = async (config, name, inheritOutput = true) => {
  const configPath = join(directory, `${name}.json`);
  const output = join(directory, `capture-${name}`);
  await writeFile(configPath, JSON.stringify(config));
  const child = spawn(process.execPath, ['tool/parity_capture.mjs', configPath, output], {
    stdio: inheritOutput ? 'inherit' : ['ignore', 'ignore', 'pipe'],
  });
  let stderr = '';
  child.stderr?.on('data', bytes => { stderr += bytes; });
  const exit = await new Promise((resolve, reject) => { child.on('error', reject); child.on('exit', resolve); });
  return { exit, output, stderr };
};
try {
  for (const reducedMotion of ['no-preference', 'reduce']) {
  observed.length = 0;
  const config = {
    url: `http://127.0.0.1:${server.address().port}/`, viewport: { width: 640, height: 480 },
    theme: 'light', reducedMotion, backend: 'screenshots', loadWaitMs: 300, finalHoldMs: 500,
    targets: { button: { role: 'button', name: 'Advance' }, input: { role: 'textbox', name: 'Search' },
      start: { x: 320, y: 260 }, middle: { x: 380, y: 280 }, end: { x: 450, y: 300 }, after: { x: 500, y: 330 } },
    events: [
      { atMs: 200, target: 'button' },
      { atMs: 400, type: 'click', target: 'button' },
      { atMs: 600, type: 'click', target: 'input' },
      { atMs: 800, type: 'text', text: 'hello' },
      { atMs: 1000, type: 'key', key: 'ControlOrMeta+A' },
      { atMs: 1200, type: 'text', text: 'Search phrase' },
      { atMs: 1400, type: 'key', key: 'Enter' },
      { atMs: 1600, type: 'down', target: 'start' },
      { atMs: 2000, target: 'middle' },
      { atMs: 2200, type: 'move', target: 'end' },
      { atMs: 2400, type: 'up' },
      { atMs: 2600, target: 'after' },
    ],
  };
  const { exit, output } = await run(config, reducedMotion);
  assert.equal(exit, 0);
  assert.deepEqual(observed.slice(0, 6), [`motion:${reducedMotion === 'reduce'}`, 'pointer entered', 'advanced', 'value:hello', 'value:Search phrase', 'submitted:Search phrase']);
  const pointerEvents = observed.slice(6).map(value => JSON.parse(value));
  assert.deepEqual(pointerEvents.map(({ time, ...event }) => event), [
    { type: 'pointermove', x: 320, y: 260, button: -1, buttons: 0, trusted: true },
    { type: 'pointerdown', x: 320, y: 260, button: 0, buttons: 1, trusted: true },
    { type: 'pointermove', x: 380, y: 280, button: -1, buttons: 1, trusted: true },
    { type: 'pointermove', x: 450, y: 300, button: -1, buttons: 1, trusted: true },
    { type: 'pointerup', x: 450, y: 300, button: 0, buttons: 0, trusted: true },
    { type: 'pointermove', x: 500, y: 330, button: -1, buttons: 0, trusted: true },
  ]);
  assert.ok(pointerEvents[2].time - pointerEvents[1].time >= 100, 'Chrome observes a held press before the first move');
  const environment = JSON.parse(await readFile(join(output, 'environment.json'), 'utf8'));
  assert.equal(environment.reducedMotion, reducedMotion === 'reduce');
  assert.equal(environment.requestedReducedMotion, reducedMotion);
  const timeline = JSON.parse(await readFile(join(output, 'timeline.json'), 'utf8'));
  assert.deepEqual(timeline.events.map(event => event.type), ['move', 'click', 'click', 'text', 'key', 'text', 'key', 'down', 'move', 'move', 'up', 'move']);
  timeline.events.forEach((event, index) => {
    assert.equal(event.atMs, config.events[index].atMs);
    assert.equal(event.requestedMs, timeline.stats.sequenceStartMs + config.events[index].atMs);
    assert.ok(event.dispatchBeforeMs >= event.requestedMs);
    assert.ok(event.dispatchAfterMs >= event.dispatchBeforeMs);
    assert.equal(event.error, undefined);
  });
  assert.deepEqual(timeline.events[1].pointer, { x: 130, y: 65, width: 180, height: 50 });
  assert.equal(timeline.events[3].pointer, undefined);
  assert.equal(timeline.events[7].button, 'left');
  assert.equal(timeline.events[10].button, 'left');
  assert.deepEqual(timeline.events[10].pointer, { x: 450, y: 300 });
  assert.equal(timeline.stats.backend, 'screenshots');
  assert.equal(timeline.stats.video.decodedFrames, timeline.frames.length);
  assert.ok(timeline.frames.length > 2);
  for (const frame of timeline.frames) {
    assert.ok(frame.file.startsWith('original-frames/'));
    assert.ok(frame.receivedMs >= frame.requestedMs);
    assert.equal(createHash('sha256').update(await readFile(join(output, frame.file))).digest('hex'), frame.sha256);
  }
  await writeFile(join(output, 'observed.json'), JSON.stringify(observed, null, 2));
  console.log(JSON.stringify({ result: 'passed', reducedMotion, observed, preservedCapture: output }));
  }
  const base = { url: `http://127.0.0.1:${server.address().port}/`, viewport: { width: 640, height: 480 },
    theme: 'light', backend: 'screenshots', loadWaitMs: 300, finalHoldMs: 300,
    targets: { start: { x: 320, y: 260 }, end: { x: 450, y: 300 } } };
  observed.length = 0;
  const buttons = await run({ ...base, events: [
    { atMs: 0, target: 'start' },
    { atMs: 100, type: 'down', button: 'right' },
    { atMs: 300, type: 'up', button: 'right', target: 'end' },
    { atMs: 500, type: 'down', button: 'middle' },
    { atMs: 700, target: 'start' },
    { atMs: 900, type: 'up', button: 'middle' },
  ] }, 'buttons');
  assert.equal(buttons.exit, 0);
  assert.deepEqual(observed.filter(value => value.startsWith('{')).map(value => {
    const { type, x, y, button, buttons, trusted } = JSON.parse(value);
    return { type, x, y, button, buttons, trusted };
  }), [
    { type: 'pointermove', x: 320, y: 260, button: -1, buttons: 0, trusted: true },
    { type: 'pointerdown', x: 320, y: 260, button: 2, buttons: 2, trusted: true },
    { type: 'pointermove', x: 450, y: 300, button: -1, buttons: 2, trusted: true },
    { type: 'pointerup', x: 450, y: 300, button: 2, buttons: 0, trusted: true },
    { type: 'pointerdown', x: 450, y: 300, button: 1, buttons: 4, trusted: true },
    { type: 'pointermove', x: 320, y: 260, button: -1, buttons: 4, trusted: true },
    { type: 'pointerup', x: 320, y: 260, button: 1, buttons: 0, trusted: true },
  ]);
  await writeFile(join(buttons.output, 'observed.json'), JSON.stringify(observed, null, 2));
  console.log(JSON.stringify({ result: 'passed', explicitButtons: ['right', 'middle'], preservedCapture: buttons.output }));
  for (const [name, events, error] of [
    ['dangling', [{ atMs: 0, type: 'down' }], /Unreleased/],
    ['unsupported', [{ atMs: 0, type: 'down', button: 'back' }], /Unsupported button/],
    ['unmatched', [{ atMs: 0, type: 'up' }], /does not match/],
  ]) {
    const result = await run({ ...base, chrome: '/missing-chrome', events }, name, false);
    assert.notEqual(result.exit, 0);
    assert.match(result.stderr, error);
    await assert.rejects(access(result.output), { code: 'ENOENT' });
  }
  observed.length = 0;
  const failed = await run({ ...base, events: [
    { atMs: 0, type: 'down', target: 'start' },
    { atMs: 200, type: 'key', key: 'DefinitelyNotAKey' },
    { atMs: 400, type: 'up' },
  ] }, 'cleanup', false);
  assert.notEqual(failed.exit, 0);
  assert.match(failed.stderr, /Unknown key/);
  assert.deepEqual(observed.filter(value => value.startsWith('{')).map(value => {
    const { type, buttons, trusted } = JSON.parse(value);
    return { type, buttons, trusted };
  }), [
    { type: 'pointermove', buttons: 0, trusted: true },
    { type: 'pointerdown', buttons: 1, trusted: true },
    { type: 'pointerup', buttons: 0, trusted: true },
  ]);
  const failure = JSON.parse(await readFile(join(failed.output, 'failure.json'), 'utf8'));
  assert.match(failure.events[1].error, /Unknown key/);
  await writeFile(join(failed.output, 'observed.json'), JSON.stringify(observed, null, 2));
  console.log(JSON.stringify({ result: 'passed', preflightRejectedBeforeOutput: 3,
    cleanupReleasedInChrome: true, preservedFailure: failed.output }));
} finally {
  await new Promise(resolve => server.close(resolve));
}
