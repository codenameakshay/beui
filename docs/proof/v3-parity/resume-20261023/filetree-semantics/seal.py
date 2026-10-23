from pathlib import Path
import hashlib,json
r=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(r/'input-lock.json').write_text(json.dumps({str(p.relative_to(r)):sha(p) for sub in ['source','source-inputs','source-controls-attempt1','candidate-inputs','candidate-build','candidate-build-attempt1','sdk-api'] for p in sorted((r/sub).rglob('*')) if p.is_file()},indent=2))
excluded={'archive-sha256.json','verification-summary.json','verify-export.json'}
(r/'archive-sha256.json').write_text(json.dumps({str(p.relative_to(r)):sha(p) for p in sorted(r.rglob('*')) if p.is_file() and p.name not in excluded},indent=2))
