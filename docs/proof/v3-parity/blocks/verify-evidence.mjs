import { readdir, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import path from 'node:path';

const root = import.meta.dirname;
const runs = [];
for (const batch of ['recovered-dark', 'recovered-expanded', 'recovered-focus-ring']) {
  for (const entry of await readdir(path.join(root, batch), { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const directory = path.join(root, batch, entry.name);
    const timeline = JSON.parse(await readFile(path.join(directory, 'timeline.json')));
    for (const frame of timeline.frames) {
      const actual = createHash('sha256').update(await readFile(path.join(directory, frame.file))).digest('hex');
      if (actual !== frame.sha256) throw new Error(`Changed original ${directory}/${frame.file}`);
    }
    const probe = JSON.parse(execFileSync('ffprobe', ['-v', 'error', '-count_frames', '-select_streams', 'v:0', '-show_entries', 'stream=width,height,nb_read_frames:format=duration', '-of', 'json', path.join(directory, 'capture.mp4')], { encoding: 'utf8' }));
    if (Number(probe.streams[0].nb_read_frames) !== timeline.frames.length) throw new Error(`Frame loss ${directory}`);
    runs.push({ path: path.relative(root, directory), originalPngHashesVerified: timeline.frames.length,
      decodedFrames: Number(probe.streams[0].nb_read_frames), width: probe.streams[0].width, height: probe.streams[0].height,
      measuredFps: timeline.stats.measuredFps, maxIntervalMs: timeline.stats.maxIntervalMs,
      events: timeline.events.length, dispatchErrors: timeline.events.filter(event => event.error),
      timingVerdict: 'inconclusive for fast motion; native 60 FPS not established',
    });
  }
}
const hashCheck = execFileSync('shasum', ['-a', '256', '-c', path.join(root, 'before-sha256.txt')], { encoding: 'utf8', cwd: path.resolve(root, '../../../..') });
await writeFile(path.join(root, 'before-hash-verified.log'), hashCheck);
await writeFile(path.join(root, 'verification.json'), JSON.stringify({ checkedAt: new Date().toISOString(), runs,
  originalBeforeHashChecks: hashCheck.split('\n').filter(line => line.endsWith(': OK')).length,
  beforeStatus: 'All frozen manifest entries verified. No baseline wrapper applied.',
}, null, 2));
console.log(JSON.stringify({ runs: runs.length, verifiedOriginalPngs: runs.reduce((sum, run) => sum + run.originalPngHashesVerified, 0), originalBeforeManifest: 'verified' }));
