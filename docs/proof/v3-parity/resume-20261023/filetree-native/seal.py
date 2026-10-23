from pathlib import Path
import hashlib,json
r=Path('docs/proof/v3-parity/resume-20261023/filetree-native');sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inputs={str(p.relative_to(r)):sha(p) for sub in ['source','source-inputs','candidate-inputs','candidate-build','candidate-build-attempt1'] for p in (r/sub).rglob('*') if p.is_file()}
(r/'input-lock.json').write_text(json.dumps(inputs,indent=2))
excluded={'archive-sha256.json','verification-summary.json','verify-export.json'}
(r/'archive-sha256.json').write_text(json.dumps({str(p.relative_to(r)):sha(p) for p in sorted(r.rglob('*')) if p.is_file() and p.name not in excluded},indent=2))
