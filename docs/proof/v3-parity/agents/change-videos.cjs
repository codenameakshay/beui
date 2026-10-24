const { chromium } = require(process.env.PLAYWRIGHT_MODULE || '/tmp/beui-agents-capture/node_modules/playwright');
const fs = require('node:fs/promises');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const inventory = require('./route-inventory.json');

const changes = {
  'voice-orb': 'One source orb replaces two. Responsive 256/288px size. Error fallback stays stationary.',
  'prompt-input': 'Removed three unsourced attachments. Restored the source 900ms submit completion.',
  message: 'Response actions hidden by default. Separate pending row, then answer mounts at 420ms.',
  'message-bubble': 'Shared chat defaults repaired. Extra specimen composition still differs from source examples.',
  'message-scroller': 'Shared pending and answer timing repaired. Unread and scroll recovery remain unverified.',
  'streaming-response': 'Terminal live-region flush moves after build. Extra outcome chips still differ from source.',
  'image-generation': 'Removed extra cards, progress and cancel. Restored source artwork aspect and compact layout.',
  'file-diff': 'No owned repair. Final row still uses 40/41 instead of source 20/21.',
  'approval-card': 'No owned repair. First question option descriptions and canonical example composition still differ.',
};

(async () => {
  const root = __dirname;
  const directory = path.join(root, 'change-videos');
  await fs.mkdir(directory, { recursive: false });
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const page = await browser.newPage({ viewport: { width: 1440, height: 112 }, deviceScaleFactor: 1 });
  const manifest = [];
  for (const route of inventory.routes.filter(route => route.sourceUrl)) {
    const text = changes[route.slug] || 'No owned repair. Existing demo and state differences remain listed in GAPS.md.';
    const inputs = ['before', 'final'].map(phase => path.join(root, phase, `${route.slug}-dark-1440/recording.webm`));
    const captions = [];
    for (const phase of ['before', 'final']) {
      const caption = path.join(directory, `${route.slug}-${phase}.png`);
      const label = phase === 'before' ? 'BEFORE. Pristine baseline 5ec78ac.' : 'AFTER. Implementation 56f83f4.';
      await page.setContent(`<style>body{margin:0;background:#151515;color:#eee;font:19px Arial}h1{margin:12px 20px 8px;font-size:23px}p{margin:5px 20px;font-size:18px}small{color:#bbb}</style><h1>${route.id}. ${label}</h1><p>${text}</p><p><small>Original browser recording. Unsynchronized timing and 25 FPS. Exact visual and motion parity remain unverified.</small></p>`);
      await page.screenshot({ path: caption });
      captions.push(caption);
    }
    const output = path.join(directory, `${route.slug}-before-after.mp4`);
    execFileSync('ffmpeg', ['-nostdin', '-v', 'error', '-i', inputs[0], '-i', captions[0], '-i', inputs[1], '-i', captions[1], '-filter_complex', '[0:v]pad=1440:1112:0:112[b];[b][1:v]overlay=0:0[bcap];[2:v]pad=1440:1112:0:112[a];[a][3:v]overlay=0:0[acap];[bcap][acap]concat=n=2:v=1:a=0[out]', '-map', '[out]', '-fps_mode', 'passthrough', '-c:v', 'libx264', '-crf', '18', '-preset', 'fast', '-pix_fmt', 'yuv420p', output]);
    manifest.push({ route: route.id, change: text, before: path.relative(root, inputs[0]), after: path.relative(root, inputs[1]), video: path.relative(root, output), captions: captions.map(file => path.relative(root, file)), limitations: 'Annotation and concatenation only. Original dimensions preserved below added header. No interpolation. Not synchronized comparison proof.' });
    console.log(route.slug, 'labeled before/after video encoded');
  }
  await fs.writeFile(path.join(root, 'change-manifest.json'), JSON.stringify(manifest, null, 2));
  const rows = manifest.map(item => `| ${item.route} | ${item.change} | [Before and after](${item.video}) | [New-badged route video](${item.after}) |`);
  await fs.writeFile(path.join(root, 'CHANGE_MANIFEST.md'), `# Agent change videos\n\nAll 19 routes carry a new badge in the parent audit. This index covers those routes, not only newly added files. Only Voice Orb is a newly added widget file in the branch diff. Each source-backed route has a labeled derivative of its pristine before and final after videos. The source videos remain separate in [recordings.md](recordings.md). Full state gaps remain in [GAPS.md](GAPS.md).\n\nThe annotations describe implemented changes or explicitly state that no owned repair exists. They do not imply the displayed idle recording exercises a repaired transition. Native recordings are 25 FPS and unsynchronized. The derived videos preserve input frames without interpolation and add a 112px text header. They do not certify parity.\n\n| Route | Change text | Labeled video | Per-new-badged route video |\n|---|---|---|---|\n${rows.join('\n')}\n| agents/agent-theme | Local-only. No source equivalent. Expand, edit, collapse, approve, reject, and request changes. | [Functional video](flows/final/agent-theme/recording.webm) | [Local-only new-badged route](flows/final/agent-theme/recording.webm) |\n\nThe agent-theme functional event assertions are in [events.json](flows/final/agent-theme/events.json). Reload separates the three decision outcomes. The editor intentionally belongs to the expanded consumer composition and does not persist its local input after collapse. No source-parity verdict is possible.\n`);
  await browser.close();
})().catch(error => { console.error(error); process.exitCode = 1; });
