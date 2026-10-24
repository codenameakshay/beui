import pathlib,subprocess,json,re,collections
root=pathlib.Path.cwd(); out=root/'docs/proof/v3-parity/resume-20261024/final-golden-triage'
rows=[]
for line in (root/'docs/proof/v3-parity/resume-20261024/components-integration/failure-identities.txt').read_text().splitlines():
 file,name=line.split(': ',1); text=(root/'test'/file).read_text()
 goldens=re.findall(r"matchesGoldenFile\(\s*['\"]([^'\"]+)",text)
 if len(goldens)>1:
  hints={'chat app shell':'beui_chat_app.png','chat app shell below the sidebar breakpoint':'beui_chat_app_narrow.png','message bubble variants (dark)':'beui_message_bubble_variants_dark.png','message bubble variants (light)':'beui_message_bubble_variants.png','streaming response endings':'beui_streaming_response_endings.png','BeuiMetallicButton rest-state golden':'beui_metallic_button.png'}
  goldens=[g for g in goldens if g.split('/')[-1]==hints.get(name,'')]
 for g in goldens:
  path=str(pathlib.Path('test')/pathlib.Path(file).parent/g)
  h=subprocess.check_output(['git','log','-1','--format=%H|%ad|%s','--date=iso','--',path],text=True).strip().split('|',2)
  rows.append(dict(identity=line,file='test/'+file,golden=path,author_commit=h[0],date=h[1],subject=h[2]))
(out/'history.json').write_text(json.dumps(rows,indent=2))
print(len(rows)); print(collections.Counter((r['author_commit'][:9],r['date'][:10],r['subject']) for r in rows))
