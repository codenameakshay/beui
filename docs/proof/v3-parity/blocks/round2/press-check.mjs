import assert from 'node:assert/strict';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { execFileSync, spawnSync } from 'node:child_process';
import path from 'node:path';

const output = path.join(import.meta.dirname, process.argv[2]);
const expected = process.env.EXPECTED_JS_SHA256;
assert(expected, 'EXPECTED_JS_SHA256 is required');
const servedUrl = 'http://127.0.0.1:8108/main.dart.js';
const actual = createHash('sha256').update(Buffer.from(await (await fetch(servedUrl)).arrayBuffer())).digest('hex');
assert.equal(actual, expected, 'Foreign served build');
await mkdir(output);
const revision = execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
await writeFile(path.join(output, 'served-build.json'), JSON.stringify({ url: servedUrl, expected, actual, revision, checkedAt: new Date().toISOString() }, null, 2));
await writeFile(path.join(output, 'build.diff'), execFileSync('git', ['diff', '--', 'lib', 'example/lib'], { encoding: 'utf8' }));
const tool = '/Users/codenameakshay/.t3/worktrees/beui/t3-f7137276/tool/parity_capture.mjs';
const recorderSha256 = createHash('sha256').update(await readFile(tool)).digest('hex');
const runtime = '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';
const { chromium } = await import(runtime);
const browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
const reducedMotion = process.env.REDUCED || 'no-preference';
const viewport = { width: 1280, height: 1200 };
const reports = [];
try {
  for (const theme of (process.env.THEMES || 'dark').split(',')) {
    for (const candidate of [false, true]) {
      const name = `${candidate ? 'candidate' : 'reference'}-${theme}-${reducedMotion}`;
      const url = candidate ? `http://127.0.0.1:8108/?slug=card-folder&theme=${theme}&previewWidth=592&captureProbe=1` : 'https://beui.dev/components/blocks/card-folder';
      const context = await browser.newContext({ viewport, deviceScaleFactor: 1, colorScheme: theme, reducedMotion });
      const page = await context.newPage();
      page.setDefaultTimeout(10000);
      const report = { name, url, recorderSha256, reducedMotion };
      try {
        await page.goto(url);
        if (!candidate) await page.getByRole('tab', { name: `${theme === 'dark' ? 'Dark' : 'Light'} theme`, exact: true }).click();
        await page.waitForTimeout(3500);
        if (candidate) {
          await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
          await page.waitForTimeout(500);
          report.flutterCapture = await page.evaluate(() => globalThis.__beuiCapture);
          assert.equal(report.flutterCapture.disableAnimations, reducedMotion === 'reduce');
          assert.equal(report.flutterCapture.platformDisableAnimations, reducedMotion === 'reduce');
        }
        assert.equal(await page.evaluate(() => matchMedia('(prefers-reduced-motion: reduce)').matches), reducedMotion === 'reduce');
        const folder = label => page.getByRole('button', { name: `${label} Saurabh Chauhan, card ending in 0806, expires 08/29`, exact: true });
        const privacy = page.getByRole(candidate ? 'switch' : 'button', { name: 'Show card details', exact: true });
        report.folder = await folder('Open').boundingBox();
        const b = report.folder;
        assert(b && b.width === 384, 'Actual source and candidate folder width');
        const targets = { upper: { x: b.x + b.width * .5, y: b.y + b.height * .12 }, held: { x: b.x + b.width * .5 + 2, y: b.y + b.height * .12 + 2 } };
        report.targets = targets;
        report.privacyRest = await privacy.boundingBox();
        await page.screenshot({ path: path.join(output, `${name}-rest.png`) });
        await page.mouse.move(targets.upper.x, targets.upper.y);
        await page.mouse.down();
        await page.waitForTimeout(900);
        await page.mouse.move(targets.held.x, targets.held.y);
        await page.waitForTimeout(600);
        report.privacyHeld = await privacy.boundingBox();
        await page.screenshot({ path: path.join(output, `${name}-held.png`) });
        report.privacyDelta = { x: report.privacyHeld.x - report.privacyRest.x, y: report.privacyHeld.y - report.privacyRest.y };
        if (!candidate || reducedMotion === 'reduce' || process.env.EXPECT_STATIONARY === '1') {
          assert(Math.abs(report.privacyDelta.x) < .01 && Math.abs(report.privacyDelta.y) < .01, 'Front privacy control stays stationary while upper card is held');
        }
        await page.mouse.up();
        await page.waitForTimeout(650);
        assert.equal(await folder('Close').count(), 1, 'Release opens card');
        await page.screenshot({ path: path.join(output, `${name}-released-open.png`) });
        await page.keyboard.press('Enter');
        await page.waitForTimeout(650);
        assert.equal(await folder('Open').count(), 1, 'Enter after pointer release closes card');
        await page.screenshot({ path: path.join(output, `${name}-keyboard-closed.png`) });
        report.pass = true;
        const config = { url, viewport, theme, reducedMotion, reference: !candidate, requireFlutterProbe: candidate,
          servedJs: candidate ? { url: servedUrl, sha256: expected, revision: `${revision}; build.diff records any owned edits` } : undefined,
          backend: 'screenshots', loadWaitMs: 3500, finalHoldMs: 1500, targets,
          events: [{ atMs: 600, type: 'move', target: 'upper' }, { atMs: 900, type: 'down' }, { atMs: 1800, type: 'move', target: 'held' }, { atMs: 2600, type: 'up' }, { atMs: 3500, type: 'key', key: 'Enter' }],
          provenance: { tool, recorderSha256, recorderCommit: 'd53695ffca9e4c9d1403e75712a9ff8e2ceed8ed', source: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05', liveDeploymentRevision: null, wrapper: 'd831524, source background, actual previewWidth592 and effective motion probe. Original 5ec78ac untouched.', assertionScope: 'Assertions are a separate browser run. Actual recorded PNG states need inspection. No interpolation or native cadence claim.' } };
        const configFile = path.join(output, `${name}-config.json`);
        await writeFile(configFile, JSON.stringify(config, null, 2));
        const run = spawnSync(process.execPath, [tool, configFile, path.join(output, name)], { env: { ...process.env, PARITY_PLAYWRIGHT: runtime }, encoding: 'utf8', timeout: 180000 });
        await writeFile(path.join(output, `${name}-capture.log`), `${run.stdout}\n${run.stderr}\nexit=${run.status}\n`);
        assert.equal(run.status, 0, 'Pointer recording completes');
      } catch (error) {
        report.pass = false;
        report.error = String(error.stack || error);
        await page.mouse.up().catch(() => {});
      } finally {
        await writeFile(path.join(output, `${name}-assertions.json`), JSON.stringify(report, null, 2));
        await context.close();
      }
      reports.push(report);
      await writeFile(path.join(output, 'results.json'), JSON.stringify(reports, null, 2));
      console.log(name, report.pass, report.privacyDelta, report.error || '');
    }
  }
} finally { await browser.close(); }
if (reports.some(r => !r.pass)) process.exitCode = 1;
