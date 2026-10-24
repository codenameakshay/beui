import pathlib,json,hashlib,shutil,os,subprocess
repo=pathlib.Path.cwd();out=repo/'docs/proof/v3-parity/resume-20261023/sortable-dependency';out.mkdir(exist_ok=False)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,d):p.write_text(json.dumps(d,indent=2)+'\n')
roots={'topology':pathlib.Path('/tmp/beui-sortable-topology-20261024'),'upstream':pathlib.Path('/tmp/beui-sortable-upstream-20261024'),'independent-review':pathlib.Path('/tmp/sortable-independent-review-20261024')}
receipt={}; exclusions=[]
for name,src in roots.items():
 sealed={}
 if (src/'manifest.json').exists():
  sealed=json.loads((src/'manifest.json').read_text());sealed=sealed.get('sha256',sealed)
 copied={}
 for p in sorted(src.rglob('*')):
  if not p.is_file():continue
  rel=p.relative_to(src); skip=any(x in rel.parts for x in ['node_modules','.dart_tool','.git','.pub-cache']) or (name=='independent-review' and 'build' in rel.parts)
  if skip and str(rel) not in sealed:
   exclusions.append({'source':str(p),'bytes':p.stat().st_size,'reason':'unsealed dependency/generated cache'});continue
  dst=out/name/rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dst);copied[str(rel)]={'sha256':sha(p),'bytes':p.stat().st_size}
 missing=[k for k,v in sealed.items() if not (out/name/k).is_file() or sha(out/name/k)!=v]
 receipt[name]={'source':str(src),'files':len(copied),'bytes':sum(v['bytes'] for v in copied.values()),'sealed_entries':len(sealed),'sealed_errors':missing,'manifest_sha256':sha(src/'manifest.json') if sealed else None,'copied':copied}
# Exact old inputs sealed by topology, as regular files in a self-contained dependency tree.
deps=json.loads((roots['topology']/'input-hashes.json').read_text());dr={}
for k,v in deps.items():
 src=repo/k; dst=out/'dependencies'/k;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst);assert sha(dst)==v;k2=str(dst.relative_to(out));dr[k2]={'sha256':v,'bytes':dst.stat().st_size}
dump(out/'copy-receipt.json',receipt);dump(out/'excluded-caches.json',exclusions);dump(out/'dependencies.json',dr)
# Read-only full old archive audit including ignored manifest members.
old={}
for name in ['sortable-undo','sortable-focus','sortable-handle-ownership','sortable-ownership-review-r2']:
 root=out.parent/name;m=root/'archive-sha256.json';s=root/'SHA256SUMS'
 if m.exists(): entries=json.loads(m.read_text());manifest=m
 elif s.exists(): entries={line.split(None,1)[1].lstrip('*'):line.split()[0] for line in s.read_text().splitlines() if line.strip()};manifest=s
 else:entries={str(p.relative_to(root)):sha(p) for p in root.rglob('*') if p.is_file()};manifest=None
 paths=[root/k for k in entries];errors=[str(p) for p in paths if not p.is_file() or sha(p)!=entries[str(p.relative_to(root))]]
 allpaths=sorted(set(paths+([manifest] if manifest else [])))
 rels=[str(p.relative_to(repo)) for p in allpaths if p.is_file()]
 ignored=subprocess.run(['git','check-ignore','--no-index','--stdin'],input='\n'.join(rels)+'\n',text=True,capture_output=True).stdout.splitlines()
 old[name]={'manifest':str(manifest.relative_to(repo)) if manifest else None,'manifest_sha256':sha(manifest) if manifest else None,'manifest_entries':len(entries),'manifest_entry_bytes':sum(p.stat().st_size for p in paths if p.is_file()),'ready_files_including_manifest':len(rels),'ready_bytes_including_manifest':sum(p.stat().st_size for p in allpaths if p.is_file()),'errors':errors,'ignored_files':len(ignored),'ignored_bytes':sum((repo/p).stat().st_size for p in ignored),'ignored_paths':ignored,'over_100MB':[{'path':str(p.relative_to(repo)),'bytes':p.stat().st_size} for p in allpaths if p.is_file() and p.stat().st_size>100_000_000],'entries':entries}
 (out/(name+'-ready-to-add.txt')).write_text('\n'.join(rels)+'\n')
dump(out/'old-archive-audit.json',old)
print(json.dumps({k:{a:b for a,b in v.items() if a not in ['entries','ignored_paths']} for k,v in old.items()},indent=2));print('copied',[(k,v['files'],v['bytes'],v['sealed_errors']) for k,v in receipt.items()]);print('excluded',len(exclusions))
