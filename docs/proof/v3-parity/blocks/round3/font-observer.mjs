import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { writeFile } from 'node:fs/promises';
import { chromium as browserType } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';

export const chromium = {
  async launch(options) {
    const browser = await browserType.launch(options);
    const createContext = browser.newContext.bind(browser);
    browser.newContext = async settings => {
      const context = await createContext(settings);
      const createPage = context.newPage.bind(context);
      const fonts = [];
      const reads = [];
      context.newPage = async () => {
        const page = await createPage();
        page.on('response', response => {
          if (!/\.(ttf|otf)(?:\?|$)/i.test(response.url())) return;
          reads.push(response.body().then(bytes => fonts.push({ url: response.url(), status: response.status(), bytes: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex'), completedAt: new Date().toISOString() })));
        });
        return page;
      };
      const createSession = context.newCDPSession.bind(context);
      context.newCDPSession = async page => {
        const cdp = await createSession(page);
        const send = cdp.send.bind(cdp);
        let inspected = false;
        cdp.send = async (method, parameters) => {
          if (method === 'Page.captureScreenshot' && !inspected) {
            await Promise.all(reads);
            for (const file of ['lucide.ttf', 'GeistMono-Regular.ttf', 'Geist-Regular.ttf']) {
              assert(fonts.some(font => font.url.endsWith(file) && font.status === 200 && font.bytes > 1000), `Font response missing before first capture: ${file}`);
            }
            await writeFile(process.env.FONT_PROOF_FILE, JSON.stringify({ fonts, beforeFirstCaptureAt: new Date().toISOString(), limitation: 'Completed HTTP font responses do not expose CanvasKit internal font registration. Decoded frames must also show the glyphs.' }, null, 2));
            inspected = true;
          }
          return send(method, parameters);
        };
        return cdp;
      };
      return context;
    };
    return browser;
  },
};
