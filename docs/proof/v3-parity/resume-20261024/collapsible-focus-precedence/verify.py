#!/usr/bin/env python3
"""Verify archived bytes and native observations without repository or scratch access."""
from pathlib import Path
import hashlib, json, subprocess
from PIL import Image
root = Path(__file__).resolve().parent
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p): return json.loads((root / p).read_text())
manifest = read('manifest.json')
for name, expected in manifest.items():
    p = root / name
    assert p.is_file() and not p.is_symlink(), name
    assert sha(p) == expected, name
for p in root.rglob('*'):
    assert not p.is_symlink(), str(p)
lock = read('build-lock.json')
for group in ['candidate-inputs', 'candidate-build', 'source', 'tests']:
    for name, expected in lock[group].items():
        assert sha(root / name) == expected, name
assert sha(root / lock['production']['path']) == lock['production']['sha256']
bindings = read('source-bindings.json')
assert bindings['pin'] == 'a76e57c9bbc2837e96420b2610e9c82a3271bb05'
assert any(i.get('gitPath') == 'components/motion/collapsible.tsx' for i in bindings['inputs'])
for item in bindings['inputs']:
    assert sha(root / item['file']) == item['sha256'], item
assert '14 -2: Some tests failed' in (root / 'reproduce.log').read_text()
assert '32: All tests passed' in (root / 'widget-exact-final.log').read_text()
assert '32: All tests passed' in (root / 'original16-independent16.log').read_text()
assert 'No issues found' in (root / 'analyze-final.log').read_text()
report = {'manifest_files': len(manifest), 'pngs': 0, 'videos': 0, 'frames_matched': 0, 'native': []}
for p in root.rglob('*.png'):
    with Image.open(p) as im: im.load()
    report['pngs'] += 1
for target in ['source', 'candidate']:
    for pref in ['no-preference', 'reduce']:
        folder = root / 'native' / (target + '-' + pref)
        result = json.loads((folder / 'results.json').read_text())
        assert result['target'] == target and result['reducedMotion'] == pref
        assert len(result['checks']) == 27 and all(c['pass'] for c in result['checks']), folder
        assert not result['errors']
        states = {s['name']: s for s in result['states']}
        assert states['owner-request-inside']['focus']['label'].endswith('Inside')
        assert states['owner-request-close']['focus']['label'].endswith('Outside')
        assert states['owner-request-close']['fixture']['calls'] == []
        assert states['next-tab']['focus']['label'].endswith('Outside')
        assert all(s['fixture']['reduce'] == (pref == 'reduce') for s in result['states'])
        assert all(i['isTrusted'] or (i['type'] == 'click' and i['tag'] == 'FLT-SEMANTICS-PLACEHOLDER') for i in result['inputs'])
        for script in result['scripts']:
            assert sha(root / 'served' / script['sha256']) == script['sha256']
        suffix = 'source.js' if target == 'source' else 'main.dart.js'
        build = root / ('source' if target == 'source' else 'candidate-build') / suffix
        assert any(s['url'].split('?')[0].endswith('/' + suffix) and s['sha256'] == sha(build) for s in result['scripts'])
        for state in result['states']:
            assert sha(folder / state['screenshot']['file']) == state['screenshot']['sha256']
        for frame in result['frames']:
            assert sha(folder / frame['file']) == frame['sha256']
        for video in ['capture.mp4', 'frame-index-replay.mkv']:
            subprocess.run(['ffmpeg', '-v', 'error', '-i', str(folder / video), '-f', 'null', '-'], check=True)
            report['videos'] += 1
        with Image.open(folder / result['frames'][0]['file']) as im: width, height = im.size
        proc = subprocess.Popen(['ffmpeg', '-v', 'error', '-i', str(folder / 'frame-index-replay.mkv'), '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], stdout=subprocess.PIPE)
        for frame in result['frames']:
            actual = proc.stdout.read(width * height * 3)
            with Image.open(folder / frame['file']) as im: expected = im.convert('RGB').tobytes()
            assert actual == expected, frame['file']
            report['frames_matched'] += 1
        assert proc.stdout.read() == b'' and proc.wait() == 0
        report['native'].append({'target': target, 'preference': pref, 'checks': 27, 'frames': len(result['frames'])})
print(json.dumps(report, indent=2))
