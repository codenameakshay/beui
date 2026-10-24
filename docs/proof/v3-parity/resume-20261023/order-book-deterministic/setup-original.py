from pathlib import Path
import shutil,json,hashlib,subprocess
root=Path.cwd(); out=root/'docs/proof/v3-parity/resume-20261023/order-book-deterministic'; tmp=Path('/tmp/beui-order-book-deterministic-20261023'); tmp.mkdir(exist_ok=False)
for name in ['lib','assets']:
 if (root/name).exists(): shutil.copytree(root/name,tmp/'candidate'/name)
for name in ['pubspec.yaml','pubspec.lock']: shutil.copy2(root/name,tmp/'candidate'/name)
shutil.copytree(root/'example',tmp/'candidate/example',ignore=shutil.ignore_patterns('build','.dart_tool','.git','ios','android','macos','linux','windows'))
bids=[{'price':99,'size':2},{'price':98,'size':3},{'price':97,'size':5}]; asks=[{'price':101,'size':4},{'price':102,'size':6}]
states={'initial':{'bids':bids,'asks':asks},'reorder':{'bids':bids[::-1],'asks':asks[::-1]},'empty':{'bids':[],'asks':[]},'bids':{'bids':bids,'asks':[]},'asks':{'bids':[],'asks':asks},'step':{'bids':[dict(x,size=x['size']+1) for x in bids],'asks':[dict(x,size=x['size']+1) for x in asks]}}
(out/'snapshots.json').write_text(json.dumps(states,indent=2)+'\n')
manifest={str(p.relative_to(tmp/'candidate')):hashlib.sha256(p.read_bytes()).hexdigest() for p in (tmp/'candidate').rglob('*') if p.is_file()}
(out/'candidate-inputs.json').write_text(json.dumps({'head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'files':manifest},indent=2))
