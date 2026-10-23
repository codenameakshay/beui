import assert from 'node:assert/strict';
import { writeFile } from 'node:fs/promises';
import { chromium } from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';

const browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 }, deviceScaleFactor: 1 });
  await page.goto('http://127.0.0.1:18117/components/agents/approval-card', { waitUntil: 'networkidle' });
  await page.getByRole('tab', { name: 'Dark theme', exact: true }).click();
  await page.waitForTimeout(1000);
  const stage = page.getByRole('button', { name: 'Replay', exact: true }).nth(1).locator('..');
  const inspect = () => stage.evaluate(root => [...root.querySelectorAll('span,h3,p')].map(e => {
    const s = getComputedStyle(e);
    return { text: e.textContent, className: e.className, font: s.font, lineHeight: s.lineHeight, padding: s.padding, border: s.borderWidth, bounds: e.getBoundingClientRect().toJSON() };
  }));
  const pending = await inspect();
  await page.getByRole('button', { name: 'Approve', exact: true }).click();
  await page.getByText('Publishing was approved.', { exact: true }).waitFor();
  await page.waitForTimeout(350);
  const approved = await inspect();
  const badge = approved.find(e => e.text === 'Approved');
  assert.equal(badge.bounds.height, 22);
  assert.equal(badge.lineHeight, '16px');
  await writeFile(process.argv[2], JSON.stringify({ sourceRevision: 'a76e57c9bbc2837e96420b2610e9c82a3271bb05', liveRevision: 'unknown', pending, approved }, null, 2), { flag: 'wx' });
  console.log(JSON.stringify(badge));
} finally { await browser.close(); }
