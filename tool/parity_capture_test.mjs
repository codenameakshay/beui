#!/usr/bin/env node
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { mkdtemp, readFile, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawn } from 'node:child_process';

const observed = [];
const fixture = `<!doctype html><html><body>
<button style="position:absolute;left:40px;top:40px;width:180px;height:50px">Advance</button>
<input aria-label="Search" style="position:absolute;left:40px;top:120px;width:180px;height:40px">
<output style="position:absolute;left:40px;top:200px">Ready</output>
<script>
const button = document.querySelector('button');
const input = document.querySelector('input');
const output = document.querySelector('output');
const report = value => { output.textContent = value; fetch('/observed', {method:'POST', body:value}); };
button.addEventListener('mouseenter', () => report('pointer entered'));
button.addEventListener('click', () => report('advanced'));
input.addEventListener('input', () => report('value:' + input.value));
input.addEventListener('keydown', event => { if (event.key === 'Enter') report('submitted:' + input.value); });
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
try {
  const config = {
    url: `http://127.0.0.1:${server.address().port}/`, viewport: { width: 640, height: 480 },
    theme: 'light', backend: 'screenshots', loadWaitMs: 300, finalHoldMs: 500,
    targets: { button: { role: 'button', name: 'Advance' }, input: { role: 'textbox', name: 'Search' } },
    events: [
      { atMs: 200, target: 'button' },
      { atMs: 400, type: 'click', target: 'button' },
      { atMs: 600, type: 'click', target: 'input' },
      { atMs: 800, type: 'text', text: 'hello' },
      { atMs: 1000, type: 'key', key: 'ControlOrMeta+A' },
      { atMs: 1200, type: 'text', text: 'Search phrase' },
      { atMs: 1400, type: 'key', key: 'Enter' },
    ],
  };
  const configPath = join(directory, 'config.json');
  await writeFile(configPath, JSON.stringify(config));
  const output = join(directory, 'capture');
  const child = spawn(process.execPath, ['tool/parity_capture.mjs', configPath, output], { stdio: 'inherit' });
  const exit = await new Promise((resolve, reject) => { child.on('error', reject); child.on('exit', resolve); });
  assert.equal(exit, 0);
  assert.deepEqual(observed, ['pointer entered', 'advanced', 'value:hello', 'value:Search phrase', 'submitted:Search phrase']);
  const timeline = JSON.parse(await readFile(join(output, 'timeline.json'), 'utf8'));
  assert.deepEqual(timeline.events.map(event => event.type), ['move', 'click', 'click', 'text', 'key', 'text', 'key']);
  timeline.events.forEach((event, index) => {
    assert.equal(event.atMs, config.events[index].atMs);
    assert.equal(event.requestedMs, timeline.stats.sequenceStartMs + config.events[index].atMs);
    assert.ok(event.dispatchBeforeMs >= event.requestedMs);
    assert.ok(event.dispatchAfterMs >= event.dispatchBeforeMs);
    assert.equal(event.error, undefined);
  });
  assert.deepEqual(timeline.events[1].pointer, { x: 130, y: 65, width: 180, height: 50 });
  assert.equal(timeline.events[3].pointer, undefined);
  console.log(JSON.stringify({ result: 'passed', observed, preservedCapture: output }));
} finally {
  await new Promise(resolve => server.close(resolve));
}
