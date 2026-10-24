const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const root = __dirname;
for (const phase of ['reference', 'after']) {
  for (const name of ['voice-orb-dark-1440', 'voice-orb-dark-1440-reduced']) {
    const dir = path.join(root, phase, name);
    const facts = JSON.parse(fs.readFileSync(path.join(dir, 'capture.json')));
    const rect = phase === 'reference'
      ? facts.facts.slots.find(x => x.slot === 'voice-orb').rect
      : { x: 576, y: 356, width: 288, height: 288 };
    const output = path.join(dir, 'widget-frames');
    fs.mkdirSync(output, { recursive: true });
    execFileSync('ffmpeg', [
      '-hide_banner', '-loglevel', 'error', '-n',
      '-framerate', '10', '-i', path.join(dir, 'frames/frame_%03d.png'),
      '-vf', `crop=${rect.width}:${rect.height}:${rect.x}:${rect.y}`,
      '-start_number', '0', path.join(output, 'frame_%03d.png'),
    ]);
    fs.writeFileSync(path.join(dir, 'crop.json'), JSON.stringify({ rect, input: 'Unmodified full viewport PNG sequence', method: 'Integer crop only. No scaling, alignment correction, recoloring, or time resampling.' }, null, 2));
  }
}
