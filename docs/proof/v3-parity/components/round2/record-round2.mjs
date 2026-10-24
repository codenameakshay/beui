import assert from 'node:assert/strict';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { spawn } from 'node:child_process';
import { join, resolve } from 'node:path';
import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';

const root = import.meta.dirname;
const revision = 'dc564bd78584f6ba9b3825b3b48ceb557f5a5944';
const build = 'example/build/round2-dc564bd7';
const recorder = resolve('tool/parity_capture.mjs');
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const jsHash = sha256(await readFile(join(build, 'main.dart.js')));
const recorderHash = sha256(await readFile(recorder));
const [batch, origin = 'candidate', theme = 'light', reducedMotion = 'no-preference', ...slugs] = process.argv.slice(2);
assert(batch && slugs.length, 'Provide a new batch name, origin, theme, motion preference, and routes');
assert(['reference', 'candidate'].includes(origin));
const inventory = JSON.parse(await readFile(join(root, '../inventory.json')));
const output = join(root, batch);
await mkdir(output, { recursive: true });
const browser = await chromium.launch({ headless: true, executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' });
try {
  for (const slug of slugs) {
    const servedHash = sha256(Buffer.from(await (await fetch('http://127.0.0.1:8110/main.dart.js')).arrayBuffer()));
    assert.equal(servedHash, jsHash, 'Wrong served build before batch');
    const route = inventory.routes.find(route => route.id.endsWith(`/${slug}`));
    assert(route, `Unknown route ${slug}`);
    const id = `${origin}-${theme}-${reducedMotion}-${slug}`;
    const run = join(output, id);
    await mkdir(run);
    const observedDirectory = join(run, 'observed');
    await mkdir(observedDirectory);
    const context = await browser.newContext({ viewport: { width: 1280, height: 1000 }, colorScheme: theme, reducedMotion, locale: 'en-US', timezoneId: 'Asia/Kolkata' });
    const page = await context.newPage();
    page.setDefaultTimeout(8000);
    const url = origin === 'reference' ? route.sourceUrl : `http://127.0.0.1:8110/?slug=${slug}&theme=${theme}&color=Blue&previewWidth=592&captureProbe=1`;
    const observations = [];
    const targets = { outside: { x: 10, y: 10 } };
    const events = [];
    let nextEventAt = 400;
    let held = false;
    const role = (role, name) => page.getByRole(role, { name, exact: typeof name === 'string' }).filter({visible:true}).last();
    const button = name => role('button', name);
    async function observe(label) {
      const index = observations.length;
      const state = await page.evaluate(() => ({
        text: document.body.innerText.slice(-6000),
        focus: { tag: document.activeElement?.tagName, label: document.activeElement?.getAttribute('aria-label'), text: document.activeElement?.textContent?.slice(0,500) },
        probe: globalThis.__beuiCapture ?? null,
        controls: [...document.querySelectorAll('button,input,flt-semantics[role],flt-semantics[aria-label],[role="slider"],[role="tooltip"],[role="dialog"],a')].map(element => ({
          role: element.getAttribute('role'), label: element.getAttribute('aria-label') || element.textContent?.trim(),
          value: element.value ?? element.getAttribute('aria-valuetext'), checked: element.checked ?? element.getAttribute('aria-checked'),
          transform: getComputedStyle(element).transform, rect: element.getBoundingClientRect().toJSON(),
        })).filter(element => element.rect.width > 0 && element.rect.height > 0),
      }));
      const file = `${String(index).padStart(2, '0')}-${label}.png`;
      await page.screenshot({ path: join(observedDirectory, file) });
      observations.push({ label, file, ...state });
      await writeFile(join(run, 'observed.json'), JSON.stringify(observations, null, 2));
    }
    async function action(type, target, payload = {}, label = type, gapAfter = 800) {
      let point;
      let targetName;
      if (target) {
        targetName = `target${Object.keys(targets).length}`;
        const box = typeof target.x === 'number' ? target : await target.boundingBox();
        assert(box && box.width !== 0 && box.height !== 0, `Missing ${label}`);
        point = typeof target.x === 'number' ? target : { x: box.x + box.width / 2, y: box.y + box.height / 2, measuredBox: box };
        targets[targetName] = point;
      }
      const event = { atMs: nextEventAt, type, ...payload, ...(targetName ? { target: targetName } : {}) };
      nextEventAt += gapAfter;
      events.push(event);
      if (point) await page.mouse.move(point.x, point.y);
      if (type === 'click') await page.mouse.click(point.x, point.y);
      if (type === 'down') { await page.mouse.down(); held = true; }
      if (type === 'up') { await page.mouse.up(); held = false; }
      if (type === 'key') await page.keyboard.press(payload.key);
      if (type === 'text') await page.keyboard.insertText(payload.text);
      await page.waitForTimeout(gapAfter < 800 ? 20 : 650);
      await observe(label);
    }
    try {
      await page.goto(url, { waitUntil: 'domcontentloaded' });
      if (origin === 'reference') await role('tab', `${theme === 'light' ? 'Light' : 'Dark'} theme`).click();
      await page.waitForTimeout(3000);
      if (origin === 'candidate') await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
      await page.waitForTimeout(300);
      await page.mouse.move(10, 10);
      await observe('rest');
      if (slug === 'adaptive-stepper') {
        await action('click', button('Increase value'), {}, 'maximum');
        await action('click', button('Decrease value'), {}, 'reverse');
        await action('click', button('Decrease value'), {}, 'one');
        await action('click', button('Decrease value'), {}, 'minimum');
        await action('click', button('Increase value'), {}, 'leave-minimum');
      } else if (slug === 'alert') {
        for (const name of ['Success', 'Warning', 'Error']) await action('click', role(origin === 'reference' ? 'tab' : 'button', name), {}, name.toLowerCase());
        await action('click', button('Dismiss alert'), {}, 'dismissed');
        await action('click', button('Show alert'), {}, 'reopened');
      } else if (slug === 'tooltip') {
        await action('move', button(/Top$/), {}, 'top-hover');
        if (process.env.PARITY_SCENARIO === 'held-mouse') {
          await action('down', button(/Top$/), {}, 'held-mouse-800ms');
          await action('up', null, {}, 'held-mouse-release');
        }
        await action('click', button(/Top$/), {}, 'click-dismissed');
        await action('key', null, { key: 'Tab' }, 'tab-after-click');
        await action('key', null, { key: 'Escape' }, 'escape');
        await action('key', null, { key: 'a' }, 'no-generic-reopen');
        await action('move', targets.outside, {}, 'exit');
        await action('move', button(/Right$/), {}, 'right-hover');
      } else if (slug === 'color-selector') {
        const swatch = name => origin === 'reference' ? role('radio', name).locator('..') : role('radio', name);
        await action('down', swatch('Blue'), {}, 'selected-ring-held');
        await action('up', null, {}, 'selected-ring-released');
        await action('click', swatch('Purple'), {}, 'purple-selected');
        await action('key', null, { key: 'ArrowRight' }, 'keyboard-next');
      } else if (slug === 'breadcrumb') {
        await action('move', button('Show hidden paths'), {}, 'overflow-open');
        const projectsRect = observations.at(-1).controls.find(control => control.label === 'Projects')?.rect;
        assert(projectsRect, 'Observed Projects target in open overflow');
        const projects = { x: projectsRect.x + projectsRect.width / 2, y: projectsRect.y + projectsRect.height / 2, measuredBox: projectsRect };
        await action('down', projects, {}, 'route-held');
        await action('key', null, { key: 'Escape' }, 'escape-held', 100);
        await action('up', null, {}, 'release-hidden-route');
        await action('click', origin === 'reference' ? role('link', 'Workspace') : button('Workspace'), {}, 'parent-navigation');
        await action('click', button('Projects'), {}, 'forward-navigation');
      } else if (slug === 'image-viewer') {
        await action('click', button('Open Sculptural architecture'), {}, 'viewer-open');
        await action('click', button('Zoom in'), {}, 'zoomed');
        await action('down', { x: 640, y: 500 }, {}, 'pan-start');
        await action('move', { x: 790, y: 560 }, {}, 'panned-held');
        await action('up', null, {}, 'pan-release');
        await action('click', button('Zoom out'), {}, 'zoom-reset');
        await action('down', { x: 800, y: 500 }, {}, 'swipe-start');
        await action('move', { x: 600, y: 500 }, {}, 'swiped-held');
        await action('up', null, {}, 'swipe-page');
        await action('key', null, { key: 'ArrowLeft' }, 'keyboard-previous');
        await action('down', button('Zoom in'), {}, 'zoom-held');
        await action('key', null, { key: 'Escape' }, 'escape-held', 100);
        await action('up', null, {}, 'release-hidden-zoom');
      } else if (slug === 'color-picker') {
        await action('click', button(/^#3478f6$/i), {}, 'picker-open');
        const area = origin === 'reference'
          ? role('slider', 'Saturation and brightness').locator('xpath=ancestor::div[contains(@class,"h-40")][1]')
          : page.locator('flt-semantics[aria-label="Saturation and brightness"]').last();
        const box = await area.boundingBox();
        await action('down', { x: box.x + box.width * .65, y: box.y + box.height * .35 }, {}, 'spectrum-held');
        await action('move', { x: box.x + box.width * .8, y: box.y + box.height * .25 }, {}, 'spectrum-drag');
        await action('up', null, {}, 'spectrum-release');
        await action('click', button(origin === 'reference' ? /Format HEX, switch to RGB/ : 'HEX'), {}, 'rgb-channels');
        await action('click', button(origin === 'reference' ? /Format RGB, switch to HSL/ : 'RGB'), {}, 'hsl-channels');
        await action('key', null, { key: 'Escape' }, 'picker-dismissed');
      } else if (slug === 'combobox') {
        await action('click', page.locator('[aria-label="Search workspaces"]').last(), {}, 'options-open');
        await action('key', null, { key: 'ControlOrMeta+A' }, 'query-selected');
        await action('text', null, { text: 'Product' }, 'query-product');
        assert(observations.at(-1).controls.some(control => control.value === 'Product'), 'Native input accepted Product query');
        assert(!observations.at(-1).controls.some(control => control.label === 'Playground\nPlayground\n24 experiments'), 'Unmatched option filtered out');
        await action('key', null, { key: 'ArrowDown' }, 'option-active');
        await action('key', null, { key: 'Enter' }, 'option-selected');
        assert(observations.at(-1).controls.some(control => control.value === 'Product team'), 'Product team is the selected trigger value');
      } else if (slug === 'date-range-picker') {
        await action('click', button(/^Reporting period:/), {}, 'calendar-open');
        await action('key', null, { key: 'ArrowLeft' }, 'previous-day');
        await action('key', null, { key: 'Enter' }, 'range-start');
        await action('key', null, { key: 'ArrowRight' }, 'next-day');
        await action('key', null, { key: 'Enter' }, 'range-end');
        await action('key', null, { key: 'Escape' }, 'calendar-dismissed');
      }
      assert.equal(held, false, 'Balanced planned pointer events');
      const config = {
        url, viewport: { width: 1280, height: 1000 }, theme, reducedMotion,
        reference: origin === 'reference', backend: 'screenshots', loadWaitMs: 3000, finalHoldMs: events.length ? 650 : 1800,
        requireFlutterProbe: origin === 'candidate',
        ...(origin === 'candidate' ? { servedJs: { url: 'http://127.0.0.1:8110/main.dart.js', sha256: jsHash, revision } } : {}),
        targets, events,
        provenance: { revision, jsHash, recorderHash, recorderRevision: '53bfc2c5a79736d9febb5ebe6f5071b1be108eaf', wrapperRevision: '69721029ca661be73dd58ba972d058b84ebe5af6', sourceRevision: inventory.referenceRevision, liveDeploymentRevision: 'unknown', observationRun: 'observed.json and unscaled screenshots replay the same coordinate events separately; video dispatch alone is not an outcome assertion', fastMotionVerdict: 'inconclusive; native60fps unavailable' },
      };
      const configPath = join(run, 'record-config.json');
      await writeFile(configPath, JSON.stringify(config, null, 2));
      const log = [];
      const status = await new Promise(resolve => {
        const child = spawn(process.execPath, [recorder, configPath, join(run, 'recording')], { env: { ...process.env, PARITY_PLAYWRIGHT: '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs' } });
        child.stdout.on('data', data => log.push(String(data)));
        child.stderr.on('data', data => log.push(String(data)));
        child.on('close', resolve);
      });
      await writeFile(join(run, 'recorder.log'), log.join(''));
      assert.equal(status, 0, `Recorder failed for ${id}`);
      console.log(JSON.stringify({ id, revision, jsHash, observations: observations.map(state => state.label), video: join(run, 'recording/capture.mp4') }));
    } catch (error) {
      await writeFile(join(run, 'failure.json'), JSON.stringify({ error: String(error), observations: observations.map(state => state.label), events }, null, 2));
      console.log(JSON.stringify({ id, error: String(error) }));
      if (held) await page.mouse.up().catch(() => {});
    } finally { await context.close(); }
  }
} finally { await browser.close(); }
