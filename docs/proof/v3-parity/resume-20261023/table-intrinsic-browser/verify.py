from pathlib import Path
import hashlib
import json
import subprocess

root = Path(__file__).resolve().parent
manifest = json.loads((root / 'manifest.json').read_text())
for name, expected in manifest.items():
    data = (root / name).read_bytes()
    assert len(data) == expected['bytes'], name
    assert hashlib.sha256(data).hexdigest() == expected['sha256'], name
videos = json.loads((root / 'decoded-videos.json').read_text())
for entry in videos:
    probe = json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-count_frames', '-select_streams', 'v:0',
        '-show_entries', 'stream=width,height,nb_read_frames,r_frame_rate',
        '-of', 'json', str(root / entry['path']),
    ]))['streams'][0]
    for key in ['width', 'height', 'nb_read_frames', 'r_frame_rate']:
        assert probe[key] == entry[key], (entry['path'], key)
metadata = json.loads((root / 'metadata.json').read_text())
rows = json.loads((root / metadata['finalCapture'] / 'results.json').read_text())
comparisons = 0
for preference in ['no-preference', 'reduce']:
    source = next(r for r in rows if r['side'] == 'source' and r['reducedMotion'] == preference)
    after = next(r for r in rows if r['side'] == 'after' and r['reducedMotion'] == preference)
    for row in [source, after]:
        assert not row['errors']
        assert row['events'] and all(e['isTrusted'] for e in row['events'])
        assert any(e['type'] == 'pointerdown' for e in row['events'])
        assert any(e['type'] == 'pointerup' for e in row['events'])
        assert [s['phase'] for s in row['states']] == ['rest', 'freeze', 'drag50']
        assert all(s['reduce'] == (preference == 'reduce') for s in row['states'])
        expected_js = metadata['sourceJS'] if row['side'] == 'source' else metadata['candidateJS']
        assert [s['sha256'] for s in row['scripts']] == [expected_js]
    assert all(s['probe']['disableAnimations'] == (preference == 'reduce') for s in after['states'])
    for source_state, after_state in zip(source['states'], after['states']):
        assert len(source_state['handles']) == len(after_state['handles']) == 5
        for a, b in zip(source_state['handles'], after_state['handles']):
            assert a['label'] == b['label']
            assert a['rect']['x'] == b['rect']['x'], (preference, source_state['phase'], a, b)
            comparisons += 1
assert comparisons == 30
print(f'PASS {len(manifest)} hashes, {len(videos)} decoded videos, {comparisons} horizontal boundaries')
