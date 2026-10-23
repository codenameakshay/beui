from pathlib import Path
import hashlib
import json
root = Path(__file__).resolve().parent
entries = json.loads((root / 'manifest.json').read_text())
for entry in entries:
    data = (root / entry['path']).read_bytes()
    assert len(data) == entry['bytes'], entry['path']
    assert hashlib.sha256(data).hexdigest() == entry['sha256'], entry['path']
rows = json.loads((root / 'beui-table-followup-native-r4/results.json').read_text())
assert len(rows) == 4
for row in rows:
    assert len(row['states']) == 6
    assert row['states'][-1]['name'] == 'recovered'
    assert row['scripts'] and row['events']
    assert all(e['isTrusted'] for e in row['events'])
    assert all(s['browserReduce'] == (row['reducedMotion'] == 'reduce') for s in row['states'])
    if row['side'] == 'after':
        assert all(s['probe']['disableAnimations'] == (row['reducedMotion'] == 'reduce') for s in row['states'])
phases = json.loads((root / 'resize-phases.json').read_text())
assert phases[1]['handleX'] - phases[0]['handleX'] == 24
assert phases[2]['handleX'] - phases[1]['handleX'] == 49.546875
assert phases[2]['nameWidth'] == 162
print(f'Verified {len(entries)} files, 24 supplemental native states and separate resize phases.')
