import urllib.request,json,pathlib,concurrent.futures
P=pathlib.Path('/tmp/beui-sortable-upstream-20261024/raw')
def fetch(job):
 name,url=job
 try:
  b=urllib.request.urlopen(url).read();(P/name).write_bytes(b);return {'file':name,'url':url,'bytes':len(b)}
 except Exception as e:return {'file':name,'url':url,'error':str(e)}
def run(jobs):
 with concurrent.futures.ThreadPoolExecutor(max_workers=6) as ex:r=list(ex.map(fetch,jobs))
 with (P/'fetch-log.jsonl').open('a') as f:
  for x in r:f.write(json.dumps(x)+'\n')
 print(json.dumps(r,indent=2))
if __name__=='__main__':
 jobs=[]
 for n in [194550,194636,194056,140235,100946,187162,193487]:
  for suf in ['', '/comments','/timeline']:jobs.append((f'issue-{n}'+suf.replace('/','-')+'.json',f'https://api.github.com/repos/flutter/flutter/issues/{n}'+suf))
 for n in [190942,189686,193420]:
  for suf in ['', '/files']:jobs.append((f'pr-{n}'+suf.replace('/','-')+'.json',f'https://api.github.com/repos/flutter/flutter/pulls/{n}'+suf))
 jobs += [('tags.json','https://api.github.com/repos/flutter/flutter/tags?per_page=100'),('releases-api.json','https://api.github.com/repos/flutter/flutter/releases?per_page=15'),('focus-history.json','https://api.github.com/repos/flutter/flutter/commits?path=engine/src/flutter/lib/web_ui/lib/src/engine/platform_dispatcher/view_focus_binding.dart&per_page=30'),('semantics-history.json','https://api.github.com/repos/flutter/flutter/commits?path=engine/src/flutter/lib/web_ui/lib/src/engine/semantics/semantics.dart&per_page=30')]
 run(jobs)
