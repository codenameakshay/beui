from pathlib import Path
r=Path('docs/proof/v3-parity/resume-20261023/filetree-semantics');old=r.with_name('filetree-native')
s=(old/'verify.py').read_text()
a=s.index("with tarfile.open");b=s.index("assert json.loads(subprocess",a)
s=s[:a]+'''assert sha(r/'candidate-inputs/lib/src/motion/file_tree.dart')==identity['candidateFileTreeSha256']
assert sha(r/'candidate-inputs/test/motion/file_tree_test.dart')==identity['testSha256']
assert any(x['sha256']==identity['sourceFileTreeSha256'] for x in json.loads((r/'source-input-bindings.json').read_text()))
'''+s[b:]
a=s.index(" expected=sha(");b=s.index(" assert any(x['sha256']==expected",a)
s=s[:a]+''' controls='attempt-controls' in str(p)
 build='source' if d['target']=='source' else ('candidate-build-attempt1' if 'attempt-1' in str(p) else 'candidate-build')
 expected=sha(r/build/('controls' if controls else '')/('source.js' if d['target']=='source' else 'main.dart.js'))
'''+s[b:]
s=s.replace(" assert failures==(['sequence completed'] if 'attempt-1' in str(p) and d['target']=='candidate' else [])", " assert not failures,(p,failures)\n if controls:\n  assert d['states'][-1]['fixture']['controlCalls']==['Inspect','Pin']\n  for state in d['states']:\n   if state['name'].startswith('disabled-'):\n    assert state['focus']['text']=='Disabled'\n    assert state['fixture']['expanded']==['parent','folder']\n    assert state['fixture']['calls']==['leaf']\n    assert len(state['fixture']['expCalls'])==2")
s=s.replace(" assert counts['frame-index-replay.mkv']==len(d['frames'])", " assert counts['frame-index-replay.mkv']==len(d['frames'])\n assert counts['capture.mp4']==len(d['frames'])")
(r/'verify.py').write_text(s)
