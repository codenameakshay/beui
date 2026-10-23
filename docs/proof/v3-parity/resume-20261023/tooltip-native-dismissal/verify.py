from pathlib import Path
import hashlib
import json
root = Path(__file__).resolve().parent
manifest = json.loads((root / 'archive.json').read_text())
for entry in manifest:
    data = (root / entry['path']).read_bytes()
    assert len(data) == entry['bytes'], entry['path']
    assert hashlib.sha256(data).hexdigest() == entry['sha256'], entry['path']
identity = json.loads((root / 'build-identity.json').read_text())
rows = json.loads((root / 'native-final/results.json').read_text())
assert len(rows) == 4
for row in rows:
    assert row['pass'] and row['after'] == ''
    assert row['probe']['disableAnimations'] == (row['reducedMotion'] == 'reduce')
    assert row['probe']['platformDisableAnimations'] == (row['reducedMotion'] == 'reduce')
    assert identity['scripts']['gallery'] in row['scripts']
rows = json.loads((root / 'sankey-pointer-final/results.json').read_text())
assert len(rows) == 12 and all(row['pass'] for row in rows)
for row in rows:
    if row['side'] == 'after':
        assert any(s['sha256'] == identity['scripts']['sankey'] for s in row['scripts'])
for name in ['burst2', 'burst3']:
    rows = json.loads((root / f'bump-after-{name}/states.json').read_text())
    assert rows[-1]['event'] == 'legend-tab'
    assert rows[-1]['active'] != 'Highlight Studio'
print(f'Verified {len(manifest)} files, four native dismissal cases, 12 Sankey cases and two retained Bump failures')
