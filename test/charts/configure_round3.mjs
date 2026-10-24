import {mkdir, readFile, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve} from 'node:path';
import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';

const [destination, revision, sha256] = process.argv.slice(2);
if (!destination || !revision || !sha256) throw Error('Usage: node test/charts/configure_round3.mjs NEW_DIRECTORY BUILD_REVISION MAIN_JS_SHA256 [ROUTES_COMMA_SEPARATED] [candidate-only]');
const output = resolve(destination);
await mkdir(output);
const recorderSha256 = createHash('sha256').update(await readFile('tool/parity_capture.mjs')).digest('hex');
const dependencyCopies = [
  ['11ee280fc037db9c8139903f2c4588ca5050f45e', '2625a31'],
  ['8ccb169aa6d6786c451456f756af2087d2672c89', 'c580bf2'],
  ['1dde262aa3ab172e4255233a524d712a48952f0a', '1fb1113'],
  ['62d8ab9f783b2150c920874b7f672cfec1daa897', '1efa708'],
  ['a88d982f38da93ccf69c9aa1406f2d6a016ae7d3', '61f44d2'],
  ['d831524e86ecb1703362b1dccd149325f05c50cc', '193a69c'],
  ['d53695ffca9e4c9d1403e75712a9ff8e2ceed8ed', '141bbda'],
  ['7dfd8bd85822de6e7e56660d0d3a8256ceabb75b', '7f1247d5'],
  ['82f12dbe002f3f588c97d7730592d49ae4dc3319', '5170c05d'],
  ['12155d8e1fa7776086e6f1b9334fecbf1ccd414e', 'bb961d33'],
].map(([upstream, local]) => ({upstream, local}));
const routes = {
  'donut-chart': [/^Team/, /^Business/],
  'liquidity-heatmap': [/^14:00, \$250\.00:/, /^14:02, \$250\.00:/],
  'returns-calendar': [/(?:2021 Jan return|Jan 2021)/, /(?:2021 Feb return|Feb 2021)/],
  'heat-calendar': [/(?:commits on .*Jul 6\b|Jul 6.*commits)/, /(?:commits on .*Jul 7\b|Jul 7.*commits)/],
  'status-bar': [/API status: inspect period/, /API status: inspect period/],
  treemap: [/^Technology \/ AAPL/, /^Technology \/ MSFT/],
  'order-book': [/^(?:247\.20$|ask, 247\.20)/, /^(?:247\.05$|ask, 247\.05)/],
  'price-target-fan': [/^High target/, /^Mean target/],
};
const browser = await chromium.launch({executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true});
try {
  for (const reference of [false, true]) {
    if (!reference && process.argv[6] === 'source-only') continue;
    if (reference && process.argv[6] === 'candidate-only') continue;
    for (const [slug, patterns] of Object.entries(routes)) {
      if (process.argv[5] && !process.argv[5].split(',').includes(slug)) continue;
      const page = await browser.newPage({viewport: {width: 1280, height: 1000}, colorScheme: 'dark'});
      const candidateUrl = `http://127.0.0.1:8109/?slug=${slug}&theme=dark&previewWidth=592&captureProbe=1`;
      const url = reference ? `https://beui.dev/charts/${slug}` : candidateUrl;
      await page.goto(url, {waitUntil: 'domcontentloaded'});
      if (reference) await page.getByRole('tab', {name: 'Dark theme', exact: true}).click();
      await page.waitForTimeout(2200);
      await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
      await page.waitForTimeout(150);
      const nodes = await page.evaluate(() => [...document.querySelectorAll('main button, main [role="button"], main [role="slider"], main input[type="range"], flt-semantics[role="button"], flt-semantics[role="slider"], flt-semantics[aria-label]')].map(e => ({name: e.getAttribute('aria-label') || e.textContent, rect: e.getBoundingClientRect().toJSON()})).filter(e => e.rect.x > 280 && e.rect.y > 300 && e.rect.y < 950 && e.rect.width > 0));
      const selected = patterns.map(pattern => nodes
        .filter(node => pattern.test(node.name))
        .sort((a, b) => a.rect.width * a.rect.height - b.rect.width * b.rect.height)[0]);
      if (selected.some(node => !node)) {
        await writeFile(`${output}/${reference ? 'reference' : 'after'}-${slug}-missing.json`, JSON.stringify(nodes, null, 2));
        throw Error(`Missing ${slug} ${reference ? 'reference' : 'candidate'} target`);
      }
      const targets = Object.fromEntries(selected.map((node, index) => [index ? 'B' : 'A', {
        x: node.rect.x + node.rect.width * (slug === 'status-bar' ? (index + .5) / 48 : .5),
        y: node.rect.y + node.rect.height / 2,
      }]));
      if (reference && slug === 'price-target-fan') {
        for (const [name, label] of [['A', 'High'], ['B', 'Mean']]) {
          const dot = await page.locator(`svg [role="button"][aria-label^="${label} target"] circle`).first().boundingBox();
          if (!dot) throw Error(`Missing ${label} target dot`);
          targets[name] = {x: dot.x + dot.width / 2, y: dot.y + dot.height / 2};
        }
      }
      targets.exit = {x: 1120, y: 250};
      const events = [
        {atMs: 300, type: 'move', target: 'A', caption: 'A. Exact datum recorded in provenance.'},
        {atMs: 1100, type: 'move', target: 'B', caption: 'B. Retarget the visible readout.'},
        {atMs: 1220, type: 'move', target: 'A', caption: 'A. Reverse during the source ticker duration.'},
        {atMs: 2100, type: 'move', target: 'exit', caption: 'Pointer exit.'},
        {atMs: 2500, type: 'click', target: 'A', caption: 'Native click establishes focus.'},
        {atMs: 2700, type: 'move', target: 'exit', caption: 'Pointer leaves before keyboard input.'},
        {atMs: 3000, type: 'key', key: slug === 'donut-chart' ? 'ArrowUp' : ['returns-calendar', 'heat-calendar', 'order-book', 'price-target-fan'].includes(slug) ? 'Tab' : 'ArrowRight', caption: 'Actual keyboard input after pointer exit.'},
        {atMs: 3550, type: 'key', key: 'Tab', caption: 'Actual Tab traversal.'},
        {atMs: 3900, type: 'key', key: 'Escape', caption: 'Dismiss.'},
      ];
      if (slug === 'donut-chart') {
        events.splice(7, 0,
          {atMs: 3250, type: 'key', key: 'ArrowDown', caption: 'Native row focus wraps from last to first.'},
          {atMs: 3400, type: 'key', key: 'ArrowDown', caption: 'Native row focus advances to Business.'},
        );
      }
      if (slug === 'price-target-fan') {
        events.push(
          {atMs: 4200, type: 'key', key: 'Enter', caption: 'Native Enter toggles the focused target on after Escape.'},
          {atMs: 4600, type: 'key', key: 'Space', caption: 'Native Space toggles that target off.'},
          {atMs: 5000, type: 'key', key: 'Enter', caption: 'Native Enter restores the focused target.'},
        );
      }
      if (slug === 'status-bar') {
        events.splice(6, 0, {atMs: 2800, type: 'key', key: 'Escape', caption: 'Dismiss while the range retains focus and selection.'});
        events.push(
          {atMs: 4200, type: 'down', target: 'A', caption: 'Hold the actual status range at A.'},
          {atMs: 4500, type: 'move', target: 'B', caption: 'Held pointer crosses to B.'},
          {atMs: 4700, type: 'up', caption: 'Release the actual range.'},
          {atMs: 4900, type: 'move', target: 'exit', caption: 'Focused range after pointer exit.'},
          {atMs: 5200, type: 'key', key: 'Home', caption: 'Native Home restores the first period.'},
          {atMs: 5600, type: 'key', key: 'Escape', caption: 'Dismiss without clearing the native range value.'},
        );
      }
      if (slug === 'order-book') {
        const pause = nodes.find(node => node.name === 'Pause');
        if (!pause) throw Error('Missing order-book Pause control');
        targets.pause = {x: pause.rect.x + pause.rect.width / 2, y: pause.rect.y + pause.rect.height / 2};
        events.unshift({atMs: 50, type: 'click', target: 'pause', caption: 'Pause actual live updates. Tick differs between runs.'});
      }
      for (const [theme, reducedMotion] of [['dark', 'no-preference'], ['light', 'reduce']]) {
        const config = {
          url: reference ? url : candidateUrl.replace('theme=dark', `theme=${theme}`),
          viewport: {width: 1280, height: 1000}, theme, reducedMotion, reference,
          requireFlutterProbe: !reference, backend: 'screenshots', loadWaitMs: 3000,
          ...(reference ? {} : {servedJs: {url: 'http://127.0.0.1:8109/main.dart.js', sha256, revision}}),
          provenance: {slug, revision: reference ? 'live deployment unknown' : revision, pinnedSource: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05', chartRevision: revision, effectiveDependencies: reference ? [] : ['11ee280', '8ccb169', '1dde262aa3ab172e4255233a524d712a48952f0a', '62d8ab9', 'a88d982', 'd831524', 'd53695ffca9e4c9d1403e75712a9ff8e2ceed8ed', '7dfd8bd8', '82f12dbe002f3f588c97d7730592d49ae4dc3319', '12155d8e1fa7776086e6f1b9334fecbf1ccd414e'], recorderRevision: 'd53695ffca9e4c9d1403e75712a9ff8e2ceed8ed', recorderSha256, wrapperRevision: reference ? 'live deployment unknown' : 'd831524', observedProbeTargets: selected, timerOverrides: 'none', keyboardMethod: 'click A, exit, native key, native Tab. No direct focus injection.'},
          targets, events, finalHoldMs: 500,
        };
        const name = `${reference ? 'reference' : 'after'}-${slug}-${theme}-${reducedMotion}`;
        config.provenance.effectiveDependencyCopies = reference ? [] : dependencyCopies;
        await writeFile(`${output}/${name}.json`, JSON.stringify(config, null, 2));
        if (slug === 'price-target-fan') {
          const entrance = {...config, events: [{atMs: 250, type: 'key', key: 'ControlOrMeta+R', caption: 'Actual browser reload. History, fan, now dot, then tail ring.'}], finalHoldMs: 5000};
          await writeFile(`${output}/${reference ? 'reference' : 'after'}-${slug}-entrance-${theme}-${reducedMotion}.json`, JSON.stringify(entrance, null, 2));
        }
        console.log(name, selected.map(node => node.name).join(' | '));
      }
      await page.close();
    }
  }
} finally {await browser.close();}
