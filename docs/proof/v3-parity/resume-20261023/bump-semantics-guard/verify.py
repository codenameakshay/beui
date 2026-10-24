from pathlib import Path
import hashlib
import json
root = Path(__file__).resolve().parent
manifest = json.loads((root / 'manifest.json').read_text())
for entry in manifest:
    data = (root / entry['path']).read_bytes()
    assert len(data) == entry['bytes'], entry['path']
    assert hashlib.sha256(data).hexdigest() == entry['sha256'], entry['path']
final_runs = sorted(root.glob('beui-focus-research-after-r5-*/states.json'))
assert len(final_runs) == 8
assert sum(len(json.loads(p.read_text())) for p in final_runs) == 148
moves = []
for path in root.glob('beui-focus-research-after-r5-*/trace.json'):
    for row in json.loads(path.read_text()):
        moves.extend(e for e in row if e['type'] == 'production-active-move')
assert len(moves) == 3
assert all(e['retained'] and e['exactOrder'] for e in moves)
results = json.loads((root / 'beui-semantics-guard-contract-all-final/results.json').read_text())['results']
for name in ['chromium', 'webkit']:
    result = next(r for r in results if r['name'] == name)
    assert result['cases'] == 240 and result['errors'] == []
assert next(r for r in results if r['name'] == 'firefox').get('unavailable')
print(f'Verified {len(manifest)} files, 148 final states, 3 preserved reorder events; Firefox unavailable.')
