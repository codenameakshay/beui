import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readdir, readFile, writeFile} from 'node:fs/promises';
import {dirname, join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';

const root = resolve(process.env.CHART_ARCHIVE_ROOT ?? join(dirname(fileURLToPath(import.meta.url)), '../../docs/proof/v3-parity/charts/round3'));
const sealName = 'ARCHIVE-v11.json';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
async function filesAt(directory, prefix = '') {
  const files = [];
  for (const entry of await readdir(directory, {withFileTypes: true})) {
    const name = join(prefix, entry.name);
    if (entry.isDirectory()) files.push(...await filesAt(join(directory, entry.name), name));
    else {
      assert(entry.isFile(), `Unexpected non-file ${name}`);
      if (name !== sealName) files.push(name);
    }
  }
  return files.sort();
}

const names = await filesAt(root);
const files = [];
for (const path of names) {
  const bytes = await readFile(join(root, path));
  files.push({path, bytes: bytes.length, sha256: hash(bytes)});
}
const counts = {
  files: files.length,
  bytes: files.reduce((sum, file) => sum + file.bytes, 0),
  pngs: files.filter(file => file.path.endsWith('.png')).length,
  videos: files.filter(file => file.path.endsWith('.mp4')).length,
};

let timelines = 0;
let originalFrames = 0;
const filesByPath = new Map(files.map(file => [file.path, file]));
for (const file of files.filter(file => file.path.endsWith('/timeline.json'))) {
  const directory = dirname(file.path);
  const timeline = JSON.parse(await readFile(join(root, file.path)));
  for (const frame of timeline.frames) {
    const recorded = filesByPath.get(join(directory, frame.file));
    assert(recorded, `Missing original ${directory}/${frame.file}`);
    assert.equal(recorded.sha256, frame.sha256, `${directory}/${frame.file}`);
    originalFrames++;
  }
  const video = join(root, directory, 'capture.mp4');
  const probe = spawnSync('ffprobe', ['-v', 'error', '-count_frames', '-select_streams', 'v:0', '-show_entries', 'stream=nb_read_frames', '-of', 'json', video], {encoding: 'utf8'});
  assert.equal(probe.status, 0, `${video}: ${probe.stderr}`);
  assert.equal(Number(JSON.parse(probe.stdout).streams[0].nb_read_frames), timeline.frames.length, directory);
  const config = JSON.parse(await readFile(join(root, directory, 'config.json')));
  if (config.servedJs) {
    const scripts = JSON.parse(await readFile(join(root, directory, 'scripts.json')));
    assert(scripts.some(script => script.url === config.servedJs.url && script.sha256 === config.servedJs.sha256), directory);
    if (config.requireFlutterProbe) {
      const environment = JSON.parse(await readFile(join(root, directory, 'environment.json')));
      assert.equal(environment.flutterCapture.disableAnimations, config.reducedMotion === 'reduce', directory);
      assert.equal(environment.reducedMotion, config.reducedMotion === 'reduce', directory);
    }
  }
  timelines++;
}
assert.equal(timelines, counts.videos);
assert.equal(originalFrames, counts.pngs);
const archive = {version: 1, chartRevision: '4118dffac7ecd680e8dae48cd0463c59b82144db', counts, timelines, originalFrames, files};
if (process.argv.includes('--seal')) {
  await writeFile(join(root, sealName), JSON.stringify(archive, null, 2), {flag: 'wx'});
} else {
  const expected = JSON.parse(await readFile(join(root, sealName)));
  assert.deepEqual(archive, expected);
}
console.log(JSON.stringify({verified: true, ...counts, timelines, originalFrames}, null, 2));
