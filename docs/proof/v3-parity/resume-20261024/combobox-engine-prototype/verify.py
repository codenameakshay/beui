from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parent
manifest=json.loads((root/'SHA256SUMS.json').read_text())
for name,expected in manifest.items():
    assert hashlib.sha256((root/name).read_bytes()).hexdigest()==expected,name
r=json.loads((root/'results.json').read_text())
assert '+16 -6:' in r['prototype-expanded']['result'][0]
assert '+14 -8:' in r['baseline-expanded']['result'][0]
assert '+22:' in r['narrow-text-field']['result'][0]
assert not r['narrow-text-field']['failures']
for name in ['prototype-expanded','baseline-expanded']:
    traces=json.loads((root/f'{name}-trace.json').read_text())
    assert len(traces)==22
    assert all(len(t['trace']) <= 200 for t in traces)
failures='\n'.join(r['prototype-expanded']['failures'])
for name in ['preclient','backward','delta','composition']:
    assert f'prototype lifecycle {name} [E]' in failures
assert failures.count('emptyUpdate=true')==2
assert 'emptyUpdate=false' not in failures
assert not json.loads((root/'process-cleanup.json').read_text())['remaining_owned_runners']
print(f'Verified {len(manifest)} artifact hashes; candidate 16/6, baseline 14/8, narrow 22/0. Synthetic evidence only.')
