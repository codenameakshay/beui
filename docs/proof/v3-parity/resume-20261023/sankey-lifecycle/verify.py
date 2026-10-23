from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parent
manifest = json.loads((root / 'browser-archive.json').read_text())
for entry in manifest:
    data = (root / entry['path']).read_bytes()
    assert len(data) == entry['bytes'], entry['path']
    assert hashlib.sha256(data).hexdigest() == entry['sha256'], entry['path']
results = json.loads((root / 'native-r4/results.json').read_text())
identity = json.loads((root / 'build-identity.json').read_text())
assert len(results) == 12
for result in results:
    assert result['pass'], result
    assert all(s['reduced'] == (result['motion'] == 'reduce') for s in result['states'])
    if result['side'] == 'after':
        assert any(s['sha256'] == identity['candidateMainJsSha256'] for s in result['scripts'])
print(f'Verified {len(manifest)} files and all 12 native scenarios')
