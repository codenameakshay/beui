from pathlib import Path
import subprocess,os,sys
s=Path('/tmp/beui-gallery-engine-causal-r10');build=sys.argv[1]
for kind in ['initial','full']:
 for i in range(1,4):
  name=f'{build}-{kind}-{i}'
  if (s/name).exists():continue
  p=subprocess.run(['node',str(s/(kind+'.mjs')),name],env={**os.environ,'TMPDIR':str(s/'tmp'),'QUERY':'Product'},stdout=open(s/'logs'/(name+'.log'),'w'),stderr=subprocess.STDOUT)
  print(name,p.returncode,flush=True)
