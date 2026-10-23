const { chromium } = require(process.env.PLAYWRIGHT_MODULE || '/tmp/beui-agents-capture/node_modules/playwright');
const fs = require('node:fs/promises');
const path = require('node:path');

const phase = process.argv[2] || 'after';

async function captureLocalTheme(page, dir, record) {
  await record('local-only idle, no source equivalent');
  await page.screenshot({ path: path.join(dir, 'idle.png') });
  const edit = page.getByRole('button', { name: /^Edit(?: Edit)?$/ });
  await edit.hover();
  await page.waitForTimeout(350);
  await record('hover Edit');
  await edit.click();
  await page.waitForTimeout(400);
  if (!(await page.locator('body').ariaSnapshot()).includes('Full proposal')) {
    throw new Error('Theme proposal did not expand.');
  }
  await record('expanded proposal');
  await page.screenshot({ path: path.join(dir, 'expanded.png') });
  const input = page.locator('input, textarea').filter({ visible: true }).first();
  await input.click();
  await page.keyboard.press('ControlOrMeta+A');
  await page.keyboard.insertText('Shared layout proof');
  if (await input.inputValue() !== 'Shared layout proof') {
    throw new Error('Theme editor did not accept the replacement text.');
  }
  await record('editor replaced with Shared layout proof');
  await page.screenshot({ path: path.join(dir, 'edited.png') });
  await edit.click();
  await page.waitForTimeout(400);
  await record('collapsed proposal');
  await page.mouse.move(5, 5);
  await page.keyboard.press('Tab');
  await page.waitForTimeout(300);
  await page.getByRole('button', { name: /^Approve(?: Approve)?$/ }).click();
  await page.waitForTimeout(500);
  if (!(await page.locator('body').ariaSnapshot()).includes('Approved')) {
    throw new Error('Theme approve did not reach Approved.');
  }
  await record('Approved');
  await page.screenshot({ path: path.join(dir, 'approved.png') });
  for (const [action, outcome] of [['Reject', 'Rejected'], ['Request changes', 'Changes requested']]) {
    await page.reload({ waitUntil: 'networkidle' });
    await page.waitForTimeout(1200);
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    await page.waitForTimeout(500);
    await page.getByRole('button', { name: new RegExp(`^${action}(?: ${action})?$`) }).click();
    await page.waitForTimeout(500);
    if (!(await page.locator('body').ariaSnapshot()).includes(outcome)) {
      throw new Error(`Theme ${action} did not reach ${outcome}.`);
    }
    await record(outcome);
    await page.screenshot({ path: path.join(dir, `${action.toLowerCase().replaceAll(' ', '-')}.png`) });
  }
}

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  for (const slug of process.argv.includes('--theme') ? ['agent-theme'] : ['prompt-input', 'message', 'message-scroller', 'chat-app']) {
    const dir = path.join(__dirname, 'flows', phase, slug);
    await fs.mkdir(dir, { recursive: true });
    const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, deviceScaleFactor: 1, colorScheme: 'dark', recordVideo: { dir, size: { width: 1440, height: 1000 } } });
    const page = await context.newPage();
    const events = [];
    const record = async event => events.push({ event, at: Date.now(), monotonicMs: await page.evaluate(() => performance.now()), text: await page.locator('body').innerText(), accessibility: await page.locator('body').ariaSnapshot() });
    try {
      await page.goto(phase === 'reference' ? `https://beui.dev/components/agents/${slug}` : `http://localhost:8104/agents-${phase}/?slug=${slug}&theme=dark`, { waitUntil: 'networkidle', timeout: 60000 });
      if (phase !== 'reference') {
        await page.waitForSelector('flutter-view');
        await page.waitForTimeout(1200);
        await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
      }
      await page.waitForTimeout(600);
      if (slug === 'agent-theme') {
        await captureLocalTheme(page, dir, record);
        console.log(`${phase} ${slug} local-only expand, edit, collapse, approve, reject, and request changes captured`);
      } else {
      const field = page.locator('textarea, input:not([type=hidden])').filter({ visible: true }).first();
      await field.waitFor({ state: 'visible', timeout: 10000 });
      await record('idle');
      await field.hover();
      await page.waitForTimeout(350);
      await record('hover-enter');
      const box = await field.boundingBox();
      await page.mouse.move(box.x + box.width - 8, box.y + 8);
      await record('hover-move');
      await page.mouse.move(5, 5);
      await record('hover-leave');
      await field.click();
      await page.keyboard.press('ControlOrMeta+A');
      await page.keyboard.insertText('Review the release plan.');
      await page.keyboard.press('Enter');
      await page.waitForTimeout(200);
      await record('submitted-200ms');
      if (!(await page.locator('body').innerText()).includes('Review the release plan.')) {
        throw new Error('The submitted prompt did not enter the transcript. This is not a successful flow capture.');
      }
      await page.screenshot({ path: path.join(dir, 'pending.png') });
      await page.waitForTimeout(1100);
      await record('streaming-or-complete-1300ms');
      await page.keyboard.press('Tab');
      await page.waitForTimeout(500);
      await page.screenshot({ path: path.join(dir, 'focus.png') });
      await page.waitForTimeout(2000);
      await record('complete');
      await page.screenshot({ path: path.join(dir, 'complete.png') });
      await field.click();
      await page.keyboard.press('ControlOrMeta+A');
      await page.keyboard.insertText('Stop this reply.');
      await page.keyboard.press('Enter');
      await page.waitForTimeout(120);
      const stop = page.getByRole('button', { name: /stop/i }).first();
      await stop.click({ timeout: 2000 });
      await page.waitForTimeout(300);
      await record('stopped-while-pending');
      await page.screenshot({ path: path.join(dir, 'stopped.png') });
      console.log(`${phase} ${slug} submit, completion, and stop captured`);
      }
    } catch (error) {
      events.push({ error: String(error) });
      console.log(`${phase} ${slug} blocked: ${error.message.split('\n')[0]}`);
    }
    await fs.writeFile(path.join(dir, 'events.json'), JSON.stringify(events, null, 2));
    const video = page.video();
    await context.close();
    await video.saveAs(path.join(dir, 'recording.webm'));
    const original = await video.path();
    if (original !== path.join(dir, 'recording.webm')) await fs.unlink(original);
  }
  await browser.close();
})().catch(error => { console.error(error); process.exitCode = 1; });
