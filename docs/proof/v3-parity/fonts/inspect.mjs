import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { resolve, join } from 'node:path';

const output = resolve(process.argv[2]);
await mkdir(output);
const { chromium } = await import(pathToFileURL(process.env.PARITY_PLAYWRIGHT));
const browser = await chromium.launch({
  executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  headless: true,
});
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const assets = [
  ['GallerySans', 400, 'Geist-Regular.ttf'],
  ['GallerySans', 500, 'Geist-Medium.ttf'],
  ['GallerySans', 600, 'Geist-SemiBold.ttf'],
  ['GallerySans', 700, 'Geist-Bold.ttf'],
  ['GalleryMono', 400, 'GeistMono-Regular.ttf'],
  ['GalleryMono', 500, 'GeistMono-Medium.ttf'],
];
const result = { capturedAt: new Date().toISOString(), browser: browser.version(), assets: [], pages: [] };
try {
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 });
  for (const [family, weight, file] of assets) {
    const bytes = await readFile(`example/assets/fonts/${file}`);
    result.assets.push({ family, weight, file, bytes: bytes.length, sha256: sha256(bytes) });
    await context.route(`https://beui.dev/__font_proof/${file}`, route => route.fulfill({ body: bytes, contentType: 'font/ttf' }));
  }
  for (const path of ['/components/blocks/command-palette', '/components/agents/code-block', '/charts/order-book']) {
    const page = await context.newPage();
    const pending = [];
    const network = [];
    page.on('response', response => {
      if (!/\.(woff2?|ttf)(\?|$)|\.css(\?|$)/.test(response.url())) return;
      pending.push((async () => {
        try {
          const body = await response.body();
          const name = `${sha256(body)}.${response.url().includes('.css') ? 'css' : response.url().match(/\.(woff2?|ttf)/)[1]}`;
          await writeFile(join(output, name), body);
          network.push({ url: response.url(), status: response.status(), bytes: body.length, sha256: sha256(body), file: name });
        } catch (error) { network.push({ url: response.url(), error: String(error) }); }
      })());
    });
    const response = await page.goto(`https://beui.dev${path}`, { waitUntil: 'networkidle', timeout: 60000 });
    await page.evaluate(() => document.fonts.ready);
    const cdp = await context.newCDPSession(page);
    await cdp.send('DOM.enable');
    await cdp.send('CSS.enable');
    const dom = await cdp.send('DOM.getDocument');
    const samples = await page.evaluate(() => {
      const candidates = [...document.querySelectorAll('h1, h2, button, kbd, code, pre, span.font-mono, p')]
        .filter(el => el.textContent.trim() && el.getBoundingClientRect().width && [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim()));
      return candidates.slice(0, 100).map((el, index) => {
        el.setAttribute('data-font-proof', String(index));
        const s = getComputedStyle(el), r = el.getBoundingClientRect();
        return { index, tag: el.tagName, text: el.textContent.trim().slice(0, 100), className: el.className,
          family: s.fontFamily, size: s.fontSize, weight: s.fontWeight, lineHeight: s.lineHeight,
          tracking: s.letterSpacing, width: r.width, height: r.height };
      });
    });
    for (const sample of samples) {
      const { nodeId } = await cdp.send('DOM.querySelector', { nodeId: dom.root.nodeId, selector: `[data-font-proof="${sample.index}"]` });
      sample.renderedFonts = (await cdp.send('CSS.getPlatformFontsForNode', { nodeId })).fonts;
    }
    const environment = await page.evaluate(() => ({
      body: getComputedStyle(document.body).fontFamily,
      sans: getComputedStyle(document.body).getPropertyValue('--font-sans'),
      mono: getComputedStyle(document.body).getPropertyValue('--font-mono'),
      faces: [...document.fonts].map(f => ({ family: f.family, weight: f.weight, status: f.status })),
      resources: performance.getEntriesByType('resource').filter(r => /woff|ttf/.test(r.name)).map(r => ({ name: r.name, transferSize: r.transferSize, decodedBodySize: r.decodedBodySize })),
    }));
    await page.screenshot({ path: join(output, `${path.split('/').at(-1)}.png`), fullPage: false });
    await page.evaluate(async assets => {
      for (const [family, weight, file] of assets) {
        const face = new FontFace(family, `url(https://beui.dev/__font_proof/${file})`, { weight: String(weight) });
        await face.load(); document.fonts.add(face);
      }
    }, assets);
    const metrics = await page.evaluate(() => {
      const canvas = document.createElement('canvas'), ctx = canvas.getContext('2d');
      const rows = [];
      for (const family of ['Geist', 'GallerySans', 'Geist Mono', 'GalleryMono', 'sans-serif', 'monospace']) {
        for (const weight of [400, 500, 600, 700]) {
          for (const size of [12, 14, 16]) {
            ctx.font = `${weight} ${size}px ${family.includes(' ') ? JSON.stringify(family) : family}`;
            const text = 'Build something great. 0123456789 Wiil', m = ctx.measureText(text);
            rows.push({ family, weight, size, text, width: m.width,
              ascent: m.actualBoundingBoxAscent, descent: m.actualBoundingBoxDescent,
              fontAscent: m.fontBoundingBoxAscent, fontDescent: m.fontBoundingBoxDescent,
              narrow: ctx.measureText('iiiiiiiiii').width, wide: ctx.measureText('WWWWWWWWWW').width,
              asciiWidths: Array.from({ length: 95 }, (_, i) => ctx.measureText(String.fromCharCode(32 + i)).width) });
          }
        }
      }
      return rows;
    });
    await Promise.all(pending);
    result.pages.push({ url: page.url(), status: response.status(), environment, samples, network, metrics });
    await page.close();
    console.log('Inspected', path, samples.length);
  }
  await writeFile(join(output, 'evidence.json'), JSON.stringify(result, null, 2));
} finally { await browser.close(); }
