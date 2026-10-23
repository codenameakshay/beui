const fs = require('node:fs');
const path = require('node:path');
const puppeteer = require('/tmp/puppeteer-orb/node_modules/puppeteer-core');

const phase = process.argv[2];
if (!['reference', 'before-round2', 'after-round2'].includes(phase)) throw Error('Explicit phase required');
const output = path.join(__dirname, phase + (process.argv[3] ? `-${process.argv[3]}` : ''));
if (fs.existsSync(output)) throw Error(`Refusing to overwrite ${output}`);
fs.mkdirSync(output);
const routes = [
  ['treemap', 592], ['candlestick-chart', 592], ['donut-chart', 576],
  ['volume-profile', 576], ['status-bar', 592], ['composition-chart', 592],
  ['funnel-chart', 592], ['liquidity-heatmap', 520], ['bump-chart', 592],
  ['order-book', 520], ['heat-calendar', 592], ['returns-calendar', 592],
  ['price-target-fan', 520],
];
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));

(async () => {
  const browser = await puppeteer.launch({executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true});
  try {
    const page = await browser.newPage();
    await page.setViewport({width: 1280, height: 1000, deviceScaleFactor: 1});
    await page.emulateTimezone('Asia/Kolkata');
    await page.evaluateOnNewDocument(() => {
      window.__captureTimers = [];
      for (const name of ['setInterval', 'setTimeout']) {
        const original = window[name].bind(window);
        window[name] = (callback, delay, ...args) => {
          if (delay === 900 || delay === 950) {
            window.__captureTimers.push({name, delay});
            return original(() => {}, 2147483647);
          }
          return original(callback, delay, ...args);
        };
      }
    });
    if (phase === 'before-round2') {
      const build = '/tmp/beui-charts-round2-before-20261023/example/build/web';
      await page.setRequestInterception(true);
      page.on('request', async request => {
        const url = new URL(request.url());
        if (url.origin !== 'http://127.0.0.1:8106') return request.continue();
        const file = path.join(build, decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname));
        if (!fs.existsSync(file) || !fs.statSync(file).isFile()) return request.continue();
        const types = {'.html': 'text/html', '.js': 'application/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.ttf': 'font/ttf', '.otf': 'font/otf', '.png': 'image/png'};
        return request.respond({status: 200, contentType: types[path.extname(file)] || 'application/octet-stream', body: fs.readFileSync(file)});
      });
    }
    for (const [slug, width] of routes) {
      if (process.argv[4] && process.argv[4] !== slug) continue;
      const dir = path.join(output, slug);
      fs.mkdirSync(dir);
      const url = phase === 'reference' ? `https://beui.dev/charts/${slug}` : `http://127.0.0.1:8106/?slug=${slug}&theme=dark&previewWidth=${width}`;
      const errors = [];
      const onError = error => errors.push(String(error));
      page.on('pageerror', onError);
      await page.goto(url, {waitUntil: 'networkidle0'});
      await page.evaluate(() => {
        document.documentElement.classList.add('dark');
        document.querySelector('flt-semantics-placeholder')?.click();
        return document.fonts.ready;
      });
      await pause(1400);
      const inventory = await page.evaluate(() => {
        const box = e => {const r = e.getBoundingClientRect(); return {x: r.x, y: r.y, width: r.width, height: r.height};};
        const all = [...document.querySelectorAll('main svg, main [data-slot], main button[aria-label], main [role="button"][aria-label], input[type="range"], flt-semantics[aria-label], flt-semantics[role="button"]')];
        return {
          url: location.href, viewport: [innerWidth, innerHeight], dpr: devicePixelRatio,
          browserZoom: visualViewport.scale, scroll: [scrollX, scrollY], locale: navigator.language,
          timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
          reducedMotion: matchMedia('(prefers-reduced-motion: reduce)').matches,
          timersSuppressed: window.__captureTimers, fonts: document.fonts.status,
          nodes: all.map(e => ({tag: e.tagName, role: e.getAttribute('role'), label: e.getAttribute('aria-label'), slot: e.getAttribute('data-slot'), text: e.textContent.slice(0, 300), box: box(e)})).filter(n => n.box.width > 0 && n.box.height > 0 && n.box.y > 275 && n.box.x > 270),
        };
      });
      await page.screenshot({path: path.join(dir, 'rest.png')});
      inventory.errors = errors;
      inventory.browser = await browser.version();
      inventory.phase = phase;
      inventory.revision = phase === 'reference' ? 'live deployment unknown' : phase === 'before-round2' ? 'b3308ad' : 'working tree, see implementation diff';
      fs.writeFileSync(path.join(dir, 'render.json'), JSON.stringify(inventory, null, 2));
      console.log(`${phase}/${slug}`);
      page.off('pageerror', onError);
    }
  } finally { await browser.close(); }
})().catch(error => {console.error(error); process.exitCode = 1;});
