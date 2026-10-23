from pathlib import Path
import hashlib
import json
root = Path(__file__).resolve().parent
entries = json.loads((root / 'archive.json').read_text())
for entry in entries:
    data = (root / entry['path']).read_bytes()
    assert len(data) == entry['bytes']
    assert hashlib.sha256(data).hexdigest() == entry['sha256'], entry['path']
build = json.loads((root / 'build.json').read_text())
rows = json.loads((root / 'native/results.json').read_text())
assert len(rows) == 4
for row in rows:
    assert row['pass'] and row['after'] == ''
    assert build['mainJsSha256'] in row['scripts']
    assert row['probe']['disableAnimations'] == (row['reducedMotion'] == 'reduce')
    assert row['probe']['platformDisableAnimations'] == (row['reducedMotion'] == 'reduce')
print(f'Verified {len(entries)} files and four final native contexts')
