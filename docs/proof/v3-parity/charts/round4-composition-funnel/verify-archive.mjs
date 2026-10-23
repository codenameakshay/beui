import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readdir, readFile, writeFile} from 'node:fs/promises';
import {dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';

const root = process.env.CHART_ARCHIVE_ROOT ?? dirname(fileURLToPath(import.meta.url));
const seal = 'ARCHIVE.json';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
async function collect(directory, prefix = '') {
  const files = [];
  for (const entry of await readdir(directory, {withFileTypes: true})) {
    const path = join(prefix, entry.name);
    if (entry.isDirectory()) files.push(...await collect(join(directory, entry.name), path));
    else {
      assert(entry.isFile());
      if (path !== seal) files.push(path);
    }
  }
  return files.sort();
}
const files = [];
for (const path of await collect(root)) {
  const bytes = await readFile(join(root, path));
  files.push({path, bytes: bytes.length, sha256: hash(bytes)});
}
const byPath = new Map(files.map(file => [file.path, file]));
let recordings = 0;
let originalFrames = 0;
for (const file of files.filter(file => file.path.endsWith('/timeline.json'))) {
  const directory = dirname(file.path);
  const timeline = JSON.parse(await readFile(join(root, file.path)));
  for (const frame of timeline.frames) {
    assert.equal(byPath.get(join(directory, frame.file))?.sha256, frame.sha256, `${directory}/${frame.file}`);
    originalFrames++;
  }
  const result = spawnSync('ffprobe', ['-v', 'error', '-count_frames', '-select_streams', 'v:0', '-show_entries', 'stream=nb_read_frames', '-of', 'json', join(root, directory, 'capture.mp4')], {encoding: 'utf8'});
  assert.equal(result.status, 0, directory);
  assert.equal(Number(JSON.parse(result.stdout).streams[0].nb_read_frames), timeline.frames.length, directory);
  const config = JSON.parse(await readFile(join(root, directory, 'config.json')));
  const scripts = JSON.parse(await readFile(join(root, directory, 'scripts.json')));
  assert(scripts.some(script => script.url === config.servedJs.url && script.sha256 === config.servedJs.sha256), directory);
  const environment = JSON.parse(await readFile(join(root, directory, 'environment.json')));
  assert.equal(environment.reducedMotion, config.reducedMotion === 'reduce', directory);
  if (config.requireFlutterProbe) {
    assert.equal(environment.flutterCapture.disableAnimations, config.reducedMotion === 'reduce', directory);
    assert.equal(environment.flutterCapture.platformDisableAnimations, config.reducedMotion === 'reduce', directory);
    assert.equal(environment.flutterCapture.motionOverride, null, directory);
  }
  recordings++;
}
const archive = {files, counts: {files: files.length, bytes: files.reduce((sum, file) => sum + file.bytes, 0), pngs: files.filter(file => file.path.endsWith('.png')).length, videos: files.filter(file => file.path.endsWith('.mp4')).length, recordings, originalFrames}};
if (process.argv.includes('--seal')) await writeFile(join(root, seal), JSON.stringify(archive, null, 2), {flag: 'wx'});
else assert.deepEqual(archive, JSON.parse(await readFile(join(root, seal))));
console.log(JSON.stringify({verified: true, ...archive.counts}, null, 2));
