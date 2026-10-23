#!/usr/bin/env python3
"""Read originals only; write JSON to stdout. No Git mutations."""
import pathlib,json,hashlib,sys
r=pathlib.Path(__file__).resolve().parent
repo=pathlib.Path(sys.argv[1]).resolve()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
result={}
for name,d in json.loads((r/'old-archive-audit.json').read_text()).items():
 base=repo/'docs/proof/v3-parity/resume-20261023'/name
 if d['manifest']:assert sha(repo/d['manifest'])==d['manifest_sha256'],name
 for k,v in d['entries'].items():assert sha(base/k)==v,(name,k)
 result[name]={'entries_unchanged':len(d['entries']),'manifest_unchanged':True if d['manifest'] else 'no original manifest; snapshot unchanged'}
for name,d in json.loads((r/'copy-receipt.json').read_text()).items():
 base=pathlib.Path(d['source'])
 if not base.exists():result[name]='original temporary source unavailable';continue
 if d['manifest_sha256']:assert sha(base/'manifest.json')==d['manifest_sha256'],name
 for k,v in d['copied'].items():assert sha(base/k)==v['sha256'],(name,k)
 result[name]={'copied_originals_unchanged':len(d['copied']),'manifest_unchanged':bool(d['manifest_sha256'])}
print(json.dumps(result,indent=2))
