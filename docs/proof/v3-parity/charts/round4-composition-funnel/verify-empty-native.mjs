import assert from 'node:assert/strict';
import {mkdir, readFile, writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {chromium} from '/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs';

const root = 'docs/proof/v3-parity/charts/round4-composition-funnel';
const output = `${root}/${process.argv[2] ?? 'empty-native'}`;
await mkdir(output);
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const expected = {
  source: hash(await readFile(`${root}/empty-source-build/empty.js`)),
  candidate: hash(await readFile(`${process.argv[3] ?? '/tmp/beui-round4-empty-fixture-20261023'}/main.dart.js`)),
};
const browser = await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const rows = [];
try {
  for (const [dataCase, height] of [['composition',256],['funnel',148],['invalid',148]]) {
    const pair = {};
    for (const kind of ['source','candidate']) {
      const page = await browser.newPage({viewport:{width:1000,height:800},reducedMotion:'reduce'});
      const scripts = [];
      const pending = [];
      page.on('response',response => {
        if (response.url().endsWith(kind === 'source' ? '/empty.js' : '/main.dart.js')) pending.push(response.body().then(bytes => scripts.push({url:response.url(),sha256:hash(bytes)})));
      });
      const url = `http://127.0.0.1:18116/empty-${kind}/?case=${dataCase}`;
      await page.goto(url);
      if (kind === 'candidate') await page.waitForFunction(() => globalThis.__beuiCapture?.rect);
      await page.evaluate(() => document.fonts.ready);
      await page.waitForTimeout(500);
      const motion = await page.evaluate(() => ({browser:matchMedia('(prefers-reduced-motion: reduce)').matches,flutter:globalThis.__beuiCapture ?? null}));
      const rect = kind === 'source' ? await page.locator('section').boundingBox() : motion.flutter.rect;
      assert.equal(rect.height,height,`${kind}/${dataCase}`);
      assert.equal(rect.width,752,`${kind}/${dataCase}`);
      assert.equal(motion.browser,true);
      if (kind === 'candidate') {
        assert.equal(motion.flutter.disableAnimations,true);
        assert.equal(motion.flutter.platformDisableAnimations,true);
        assert.equal(motion.flutter.motionOverride,null);
      }
      const file = `${dataCase}-${kind}`;
      await page.screenshot({path:`${output}/${file}-native.png`});
      const crop = spawnSync('ffmpeg',['-v','error','-i',`${output}/${file}-native.png`,'-vf',`crop=752:${height}:${Math.floor(rect.x)}:${Math.floor(rect.y)}`,'-frames:v','1',`${output}/${file}-plot.png`],{encoding:'utf8'});
      assert.equal(crop.status,0,crop.stderr);
      const pixels = spawnSync('ffmpeg',['-v','error','-i',`${output}/${file}-plot.png`,'-f','rawvideo','-pix_fmt','rgb24','pipe:1'],{maxBuffer:10_000_000});
      assert.equal(pixels.status,0);
      await Promise.all(pending);
      assert(scripts.some(script => script.sha256 === expected[kind]));
      pair[kind] = {file,rect,motion,scripts,pixels:pixels.stdout};
      await page.close();
    }
    let changed = 0;
    let absolute = 0;
    for (let i=0;i<pair.source.pixels.length;i+=3) {
      let delta = 0;
      for (let channel=0;channel<3;channel++) {
        const difference = Math.abs(pair.source.pixels[i+channel]-pair.candidate.pixels[i+channel]);
        absolute += difference;
        delta = Math.max(delta,difference);
      }
      if (delta>0) changed++;
    }
    rows.push({dataCase,height,source:{...pair.source,pixels:undefined},candidate:{...pair.candidate,pixels:undefined},changedPixels:changed,meanAbsoluteChannelError:absolute/pair.source.pixels.length});
  }
  await writeFile(`${output}/states.json`,JSON.stringify({revision:process.argv[4] ?? '9b4aee3cce5adbbdac286eecda465f0409f74e3d',pinnedSource:'a76e57c9bbc2837e96420b2610e9c82a3271bb05',expected,fixtureSha256:hash(await readFile(`${root}/empty_fixture.dart`)),rows},null,2),{flag:'wx'});
  console.log(JSON.stringify(rows.map(({dataCase,height,changedPixels,meanAbsoluteChannelError})=>({dataCase,height,changedPixels,meanAbsoluteChannelError})),null,2));
} finally {await browser.close();}
