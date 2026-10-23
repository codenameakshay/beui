from pathlib import Path
import hashlib
import json
import subprocess
from PIL import Image

root = Path(__file__).resolve().parent
manifest = json.loads((root / 'manifest.json').read_text())
for name, expected in manifest.items():
    data = (root / name).read_bytes()
    assert len(data) == expected['bytes'], name
    assert hashlib.sha256(data).hexdigest() == expected['sha256'], name
videos = json.loads((root / 'decoded-videos.json').read_text())
for entry in videos:
    actual = json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-count_frames', '-select_streams', 'v:0',
        '-show_entries', 'stream=width,height,nb_read_frames,r_frame_rate',
        '-of', 'json', str(root / entry['path']),
    ]))['streams'][0]
    assert actual == {k: v for k, v in entry.items() if k != 'path'}, entry['path']
meta = json.loads((root / 'metadata.json').read_text())
horizontal = json.loads((root / 'final-horizontal/results.json').read_text())
comparisons = 0
for preference in ['no-preference', 'reduce']:
    source, after = [next(r for r in horizontal if r['side'] == side and r['reducedMotion'] == preference) for side in ['source', 'after']]
    for row in [source, after]:
        assert not row['errors']
        assert row['events'] and all(e['isTrusted'] for e in row['events'])
        assert any(e['type'] == 'pointerdown' for e in row['events'])
        assert any(e['type'] == 'pointerup' for e in row['events'])
        assert [s['phase'] for s in row['states']] == ['rest', 'freeze', 'drag50']
        assert [s['sha256'] for s in row['scripts']] == [meta[row['side'] + 'JS']]
        assert all(s['reduce'] == (preference == 'reduce') for s in row['states'])
    assert all(s['probe']['disableAnimations'] == (preference == 'reduce') for s in after['states'])
    for a, b in zip(source['states'], after['states']):
        assert len(a['handles']) == len(b['handles']) == 5
        for x, y in zip(a['handles'], b['handles']):
            assert x['label'] == y['label'] and x['rect']['x'] == y['rect']['x']
            comparisons += 1
assert comparisons == 30
scroll = json.loads((root / 'final-scroll/results.json').read_text())
assert len(scroll) == 8
for row in scroll:
    assert not row['errors']
    assert [s['sha256'] for s in row['scripts']] == [meta[row['side'] + 'JS']]
    assert len(row['wheels']) == 3 and all(e['isTrusted'] for e in row['wheels'])
    assert [s['offset'] for s in row['states']] == [0, 26, 52, 104]
    for state in row['states']:
        assert state['reduce'] == (row['reducedMotion'] == 'reduce')
        if row['side'] == 'source':
            assert state['sourceOffset'] == state['offset']
        else:
            assert state['probe']['disableAnimations'] == state['reduce']
pixel_pairs = 0
for theme in ['light', 'dark']:
    for preference in ['no-preference', 'reduce']:
        for offset in [0, 26, 52, 104]:
            a, b = [Image.open(root / f'final-scroll/{side}-{theme}-{preference}-{offset}.png').convert('RGB') for side in ['source', 'after']]
            for y in range(91, 459):
                assert a.getpixel((700, y)) == b.getpixel((700, y)), (theme, preference, offset, y)
            pixel_pairs += 1
print(f'PASS {len(manifest)} hashes, {len(videos)} decoded videos, {comparisons} horizontal boundaries, {pixel_pairs} grid pixel-column pairs')

probes = json.loads((root / 'runtime-baselines/measurements.json').read_text())
for row in probes:
    if row['side'] != 'after': continue
    assert [s['sha256'] for s in row['scripts']] == [meta['probeJS']]
    first = [p for p in row['data']['paragraphs'] if 90 < p['y'] < 140]
    assert len(first) == 3
    normal = next(p for p in first if p['text'] == 'Leo Marsh')
    badge = next(p for p in first if p['text'] == 'Suspended')
    assert abs(normal['baseline'] - badge['baseline']) < 1/64
    assert abs(badge['baseline'] - 124.5) < .05
print('PASS diagnostic runtime baselines within declared tolerances; badge raster residual remains')
