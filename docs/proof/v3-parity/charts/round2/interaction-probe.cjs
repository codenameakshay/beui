const fs = require('node:fs');
const path = require('node:path');
const puppeteer = require('/tmp/puppeteer-orb/node_modules/puppeteer-core');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
const routes = [
  ['treemap', 592, 'Technology / AAPL', 'Technology / MSFT'],
  ['status-bar', 592, 'API status: inspect period', 'API status: inspect period'],
  ['liquidity-heatmap', 520, '14:00, $250.00: 265 SOL', '14:02, $250.00: 414 SOL'],
  ['order-book', 520, '247.20', '247.16'],
  ['heat-calendar', 592, '0 commits', '3 commits'],
  ['returns-calendar', 592, '2021', '2021'],
  ['price-target-fan', 520, 'High target', 'Mean target'],
];

(async () => {
  const browser = await puppeteer.launch({executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true});
  try {
    for (const phase of ['reference', 'after-round2']) {
      const page = await browser.newPage();
      await page.setViewport({width: 1280, height: 1000, deviceScaleFactor: 1});
      await page.emulateTimezone('Asia/Kolkata');
      await page.evaluateOnNewDocument(() => {
        for (const name of ['setTimeout', 'setInterval']) {
          const original = window[name].bind(window);
          window[name] = (callback, delay, ...args) => original(delay === 950 || delay === 900 ? () => {} : callback, delay === 950 || delay === 900 ? 2147483647 : delay, ...args);
        }
      });
      for (const [slug, width, a, b] of routes) {
        const dir = path.join(__dirname, phase, slug);
        const file = path.join(dir, 'interactions.json');
        if (fs.existsSync(file)) throw Error(`Refusing to overwrite ${file}`);
        await page.goto(phase === 'reference' ? `https://beui.dev/charts/${slug}` : `http://127.0.0.1:8106/?slug=${slug}&theme=dark&previewWidth=${width}`, {waitUntil: 'networkidle0'});
        await page.evaluate(() => {document.documentElement.classList.add('dark'); document.querySelector('flt-semantics-placeholder')?.click(); return document.fonts.ready;});
        await pause(1200);
        const controls = await page.evaluate(({slug, phase, a, b}) => {
          let nodes = [...document.querySelectorAll('main button, main [role="button"], main [role="slider"], main input[type="range"], flt-semantics[role="button"], flt-semantics[role="slider"]')];
          const text = e => e.getAttribute('aria-label') || e.textContent;
          nodes = nodes.filter(e => {const r = e.getBoundingClientRect(); return r.width > 0 && r.height > 0 && r.y > 350 && r.y < 900 && r.x > 280;});
          let selected;
          if (slug === 'status-bar') selected = phase === 'reference' ? nodes.filter(e => text(e).includes(a)).slice(0, 1) : nodes.filter(e => text(e).includes('Aug 21') || text(e).includes('Aug 22')).slice(0, 2);
          else if (slug === 'order-book') selected = nodes.filter(e => text(e).includes(a) || text(e).includes(b)).slice(0, 2);
          else if (slug === 'returns-calendar') selected = nodes.filter(e => text(e).includes('2021')).slice(0, 2);
          else if (slug === 'heat-calendar') selected = nodes.filter(e => /commits/.test(text(e))).slice(0, 2);
          else selected = [nodes.find(e => text(e).toLowerCase().startsWith(a.toLowerCase())), nodes.find(e => text(e).toLowerCase().startsWith(b.toLowerCase()))].filter(Boolean);
          return selected.map((e, i) => {
            e.setAttribute('data-round2-target', String(i));
            const r = e.getBoundingClientRect();
            return {target: i, name: text(e), box: {x: r.x, y: r.y, width: r.width, height: r.height}};
          });
        }, {slug, phase, a, b});
        const events = [];
        async function snapshot(action) {
          await pause(400);
          events.push(await page.evaluate(action => ({action, ms: performance.now(), focus: {tag: document.activeElement?.tagName, label: document.activeElement?.getAttribute('aria-label'), text: document.activeElement?.textContent?.slice(0, 150)}, values: [...document.querySelectorAll('[aria-valuetext]')].map(e => ({label: e.getAttribute('aria-label'), value: e.getAttribute('aria-valuetext')})), tooltips: [...document.querySelectorAll('[role="tooltip"]')].map(e => ({text: e.textContent, box: {x: e.getBoundingClientRect().x, y: e.getBoundingClientRect().y}})), canvasReadout: [...document.querySelectorAll('flt-semantics[aria-live], flt-semantics[role="group"]')].map(e => (e.getAttribute('aria-label') || '') + ' ' + e.textContent).filter(t => /commits|return|Technology|rank|SOL|API status|target/.test(t)).map(t => t.slice(-800))}), action));
        }
        for (const i of [0, 1, 0]) {
          const control = controls[i] || controls[0];
          if (!control) {events.push({action: 'missing target', index: i}); continue;}
          const fraction = controls.length === 1 && i === 1 ? .6 : .2;
          await page.mouse.move(control.box.x + control.box.width * fraction, control.box.y + control.box.height / 2);
          await snapshot(`hover ${i === 1 ? 'B' : 'A'} ${control.name}`);
        }
        await page.screenshot({path: path.join(dir, 'hover-reversal.png')});
        await page.mouse.move(1100, 250);
        await snapshot('pointer exit');
        if (controls[0]) {
          await page.$eval('[data-round2-target="0"]', e => e.focus());
          for (const key of ['ArrowRight', 'Home', 'End', 'Escape']) {
            await page.keyboard.press(key);
            await snapshot(`keyboard ${key}`);
          }
        }
        fs.writeFileSync(file, JSON.stringify({phase, slug, controls, events, limitation: 'Settled behavioral probe, not a cadence or animated character-trajectory recording. Direct focus is not Tab traversal.'}, null, 2));
        console.log(`${phase}/${slug}`);
      }
      await page.close();
    }
  } finally { await browser.close(); }
})().catch(error => {console.error(error); process.exitCode = 1;});
