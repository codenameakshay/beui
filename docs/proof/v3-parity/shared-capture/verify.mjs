import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { assertMotionEnvironment } from '../../../../tool/parity_capture_config.mjs';

const output = resolve(process.argv[2]);
await mkdir(output);
const save = (name, data) => writeFile(join(output, name), JSON.stringify(data, null, 2));
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const revision = execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
const changedFiles = [
  'example/lib/explorer/widgets.dart', 'example/lib/explorer/capture_probe.dart',
  'example/lib/explorer/capture_probe_stub.dart', 'example/lib/explorer/capture_probe_web.dart',
  'example/lib/visual_harness.dart', 'tool/parity_capture.mjs', 'tool/parity_capture_config.mjs',
];
const inputs = {};
for (const file of changedFiles) inputs[file] = hash(await readFile(file));
await save('build-inputs.json', {
  revision, changedFiles: inputs,
  dirtyFiles: execFileSync('git', ['status', '--short'], { encoding: 'utf8' }),
  flutter: execFileSync('flutter', ['--version'], { encoding: 'utf8' }),
  os: execFileSync('sw_vers', [], { encoding: 'utf8' }),
  referenceRevision: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05',
  liveDeploymentRevision: 'unknown',
});
const { chromium } = await import(pathToFileURL(process.env.PARITY_PLAYWRIGHT));
const browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
const measurements = [];
const configs = [];
try {
  const scenarios = [
    { id: 'reference-light-reduce', reference: true, reducedMotion: 'reduce', theme: 'light' },
    { id: 'reference-light-normal', reference: true, reducedMotion: 'no-preference', theme: 'light' },
    { id: 'gallery-light-reduce', reducedMotion: 'reduce', theme: 'light' },
    { id: 'gallery-light-normal', reducedMotion: 'no-preference', theme: 'light' },
    { id: 'gallery-dark-reduce', reducedMotion: 'reduce', theme: 'dark' },
    { id: 'reference-dark-reduce', reference: true, reducedMotion: 'reduce', theme: 'dark' },
    { id: 'visual-light-reduce', visual: true, reducedMotion: 'reduce', theme: 'light' },
    { id: 'visual-narrow-normal', visual: true, reducedMotion: 'no-preference', theme: 'light', width: 390, measureOnly: true },
    { id: 'visual-default-normal', visual: true, reducedMotion: 'no-preference', theme: 'light', defaultWidth: true, measureOnly: true },
  ];
  for (const scenario of scenarios) {
    const viewport = { width: scenario.width ?? 1280, height: 1000 };
    const url = scenario.reference ? 'https://beui.dev/components/motion/tooltip'
      : `http://127.0.0.1:8111/${scenario.visual ? 'visual/' : ''}?slug=tooltip&theme=${scenario.theme}${scenario.defaultWidth ? '' : '&previewWidth=592'}&captureProbe=1`;
    const javascriptUrl = scenario.reference ? null : `http://127.0.0.1:8111/${scenario.visual ? 'visual/' : ''}main.dart.js`;
    const localHash = javascriptUrl ? hash(await readFile(`example/build/shared-capture-gallery/${scenario.visual ? 'visual/' : ''}main.dart.js`)) : null;
    const context = await browser.newContext({ viewport, deviceScaleFactor: 1, reducedMotion: scenario.reducedMotion, colorScheme: scenario.theme });
    const page = await context.newPage();
    const scripts = [];
    const reads = [];
    page.on('response', response => {
      if (/\.js(?:\?|$)/.test(response.url())) reads.push(response.body().then(bytes => scripts.push({ url: response.url(), sha256: hash(bytes) })).catch(() => {}));
    });
    await page.goto(url, { waitUntil: 'domcontentloaded' });
    if (scenario.reference) await page.getByRole('tab', { name: `${scenario.theme === 'light' ? 'Light' : 'Dark'} theme`, exact: true }).click();
    else await page.waitForFunction(() => !!globalThis.__beuiCapture);
    await page.waitForTimeout(2500);
    await Promise.all(reads);
    if (javascriptUrl) assert.equal(scripts.find(s => s.url === javascriptUrl)?.sha256, localHash, 'served main.dart.js must match the local release before capture');
    const environment = await page.evaluate(() => {
      const stage = document.querySelector('#default-stage');
      const canvas = document.createElement('canvas'), context = canvas.getContext('2d');
      context.fillStyle = getComputedStyle(document.body).backgroundColor;
      context.fillRect(0, 0, 1, 1);
      return {
        reducedMotion: matchMedia('(prefers-reduced-motion: reduce)').matches,
        flutterCapture: globalThis.__beuiCapture ?? null,
        viewport: { width: innerWidth, height: innerHeight }, dpr: devicePixelRatio,
        sourceStage: stage ? { rect: stage.getBoundingClientRect().toJSON(), background: getComputedStyle(stage).backgroundColor } : null,
        bodyRgb: [...context.getImageData(0, 0, 1, 1).data],
      };
    });
    assertMotionEnvironment({ ...scenario, requireFlutterProbe: !scenario.reference }, environment);
    if (!scenario.reference) assert.equal(environment.flutterCapture.constraints.maxWidth, scenario.defaultWidth ? 1184 : scenario.width ? 294 : 592);
    if (scenario.reference) {
      assert.equal(environment.sourceStage.rect.width, 592);
      assert.equal(environment.sourceStage.background, 'rgba(0, 0, 0, 0)');
      assert.deepEqual(environment.bodyRgb, scenario.theme === 'light' ? [252, 252, 252, 255] : [21, 21, 21, 255]);
    }
    const box = scenario.reference ? await page.getByRole('button', { name: 'Top', exact: true }).boundingBox() : {
      x: environment.flutterCapture.rect.x + environment.flutterCapture.rect.width / 2 - 40,
      y: environment.flutterCapture.rect.y, width: 80, height: 40,
    };
    const servedJs = scenario.reference
      ? { ...scripts.find(s => s.url.startsWith('https://beui.dev/_next/')), revision: 'live deployment unknown; local source pinned a76e57c9' }
      : { url: javascriptUrl, sha256: localHash, revision: `${revision} + shared-capture changes; see build-inputs.json` };
    const config = {
      url, viewport, theme: scenario.theme, reducedMotion: scenario.reducedMotion,
      reference: !!scenario.reference, requireFlutterProbe: !scenario.reference,
      backend: 'screenshots', loadWaitMs: 3500, finalHoldMs: 500,
      stageSelector: scenario.reference ? '#default-stage' : undefined,
      servedJs,
      targets: { top: { x: box.x + box.width / 2, y: box.y + box.height / 2 }, outside: { x: 10, y: 10 } },
      events: [{ atMs: 500, type: 'move', target: 'top' }, { atMs: 1300, type: 'move', target: 'outside' }],
      provenance: { revision, buildInputs: '../build-inputs.json', referenceRevision: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05', liveDeploymentRevision: 'unknown', scope: 'Shared capture conditions only. Not a tooltip parity verdict.' },
    };
    measurements.push({ id: scenario.id, url, environment, scripts, servedJs });
    await save('measurements.json', measurements);
    if (!scenario.measureOnly) {
      await save(`${scenario.id}.json`, config);
      configs.push(scenario.id);
    }
    await context.close();
    console.log('Measured', scenario.id);
  }
} finally { await browser.close(); }
for (const id of configs) {
  console.log('Recording', id);
  const log = execFileSync(process.execPath, ['tool/parity_capture.mjs', join(output, `${id}.json`), join(output, id)], { encoding: 'utf8', timeout: 120000 });
  await writeFile(join(output, `${id}.log`), log);
  const environment = JSON.parse(await readFile(join(output, id, 'environment.json')));
  assertMotionEnvironment(JSON.parse(await readFile(join(output, `${id}.json`))), environment);
}
