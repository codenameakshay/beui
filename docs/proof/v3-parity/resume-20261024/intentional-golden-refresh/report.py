import pathlib,json,hashlib,subprocess,collections
from run import ROOT,OUT,WORK,rows
notes={
1:'Both ranking series have visible nodes and end labels; the dimmed Studio path is present. Canvas has a null middle rank, so no invented connecting path. Dotted grid and rank rings match the intended change.',
2:'Three candle bodies, three wicks and three volume bars are visible. New right-hand labels and green/pink palette fit the 640x420 capture.',
3:'Two stacked bars, endpoint labels and two legend entries fit the intentionally taller 640x520 capture. The empty third period remains empty.',
4:'All three colored arcs, ring gaps, total readout and three legend tracks are visible within the intentionally taller 640x256 boundary.',
5:'Three shaped stages, inset readout pills, horizontal legend and bottom summary remain visible. Stage and legend geometry matches the causal change.',
6:'All calendar cells remain visible; heading and expanded legend fit without clipping.',
7:'Four data cells, descending trace, right-hand price labels and color scale remain visible.',
8:'Both ask fills and all three bid fills are visible, with full row height, balance bar and depth summary.',
9:'Historical trace joins the now marker and three dashed target projections. Axis and target labels fit.',
10:'Both year rows and all month cells fit, with revised tint and readout ink.',
11:'Three rectangles now show two readout lines; legend ink is muted. All rectangles and legend fit.',
12:'All four colored volume bars, left price labels, POC badge and three summary columns are present in the 640x420 capture.',
13:'Liquid center silhouette and separated diamond-like side controls are intentional; all three controls fit.',
15:'Info tint and close-control position change; title and body remain fully inside the alert.',
16:'Pending/expandable/rejected cards remain present. Badge outlines and expanded field layout match the intended changes; historical environment residual is included in this intentional refresh.',
18:'Final route now sits inline with the breadcrumb controls; nothing is clipped.',
19:'Resting metallic button has the revised thin chrome outline and shadow; broad old bands are gone. Only BeuiMetallicButton was selected.',
20:'Folder mask and card geometry remain complete; privacy text and lower card position reflect the intended update.',
21:'Full-height card and compact muted card remain complete. Description metrics and compact-card border match the declared change.',
24:'Assignment punctuation uses keyword ink; line numbers, highlight and all fixture rows remain. Horizontal code viewport clipping already existed in the old reference. Historical environment residual is included.',
25:'Spectrum shading, rounded field and hue/alpha tracks change; all handles remain within the control.',
26:'Selected blue swatch has a centered circular ring; red swatch and label remain intact.',
27:'Closed workspace trigger is complete with source input geometry; no reopen-state claim is made.',
33:'Selected date range and controls fit the existing full-height card. Trigger text spacing reflects omitted repeated year.',
34:'Four separated digit groups fit without cropping.',
35:'Both expanded and collapsed resting labels use muted foreground; outlines remain complete.',
37:'Diff rows, token ink and replay/footer control match the intentional layout. Horizontal code viewport remains intentional. Historical environment residual is included.',
38:'Selected file icon uses foreground ink; tree indentation and rows remain unchanged in structure.',
39:'Both thumbnails retain complete rounded edges, with intentionally smaller geometry.',
42:'Closed trigger now includes the input alongside the existing chip; complete pill boundary is visible.',
43:'Dark outer tab surface and light content geometry match intended colors; tab labels and content remain inside.',
45:'Green/red outcome buttons and green sparkline appear in the complete card. Source card layout is retained.',
48:'Both old and new images are 480x1000. The new card spans approximately y=161..839, compared with y=217..783 before. Title, four fields, terms and submit fit. No capture-bound correction or test edit is necessary; the triage phrase about changed output bounds referred to content geometry, not PNG dimensions.',
49:'Three rows and undo control remain intact with revised handles, ink and spacing.',
51:'All three tab variants fit; the bottom underline is now inside the trigger, with revised focus fill.'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def events(p):
 return [json.loads(l) for l in p.read_text().splitlines() if l.startswith('{')]
manifest=json.loads((OUT/'manifest.json').read_text())
for r in manifest:
 if r['number'] in notes:
  r['visual_review']=notes[r['number']];r['original_resolution_reviewed']=True;r['contact_sheet_reviewed']=True
  r['causal_commit_full_hashes']=[subprocess.check_output(['git','rev-parse',c],cwd=ROOT,text=True).strip() for c in r['causal_commits']]
 r['comparison_exit']=json.loads((OUT/f'classification-{r["number"]:02}.command.json').read_text())['exit']
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
files=[f'test/charts/{n}_test.dart' for n in ['bump_chart','candlestick_chart','donut_chart','order_book','volume_profile']]
changed={p:sha(ROOT/p) for p in files+[r['golden'] for r in manifest if r['classification']=='intentional visual change']}
(OUT/'changed-paths-sha256.json').write_text(json.dumps(changed,indent=2))
patch=subprocess.check_output(['git','diff','--',*files],cwd=ROOT,text=True);(OUT/'fixture.patch').write_text(patch)
# Reconstruct the red check from the final tests by deleting only the added frame progression.
import difflib
red=[]
for p in files:
 final=(ROOT/p).read_text();without=''.join(line for line in final.splitlines(True) if 'await pumpFrames(tester,' not in line)
 red.extend(difflib.unified_diff(final.splitlines(True),without.splitlines(True),fromfile='a/'+p,tofile='b/'+p))
(OUT/'reproduce-red.patch').write_text(''.join(red))
env=json.loads((OUT/'environment.json').read_text())
assert [p for p,h in env['all_original_goldens'].items() if sha(ROOT/p)!=h]==[p for p,h in env['all_original_goldens'].items() if p in changed and p.endswith('.png')]
summary={}
for label in ['root-suite','example-suite']:
 p=OUT/f'{label}.jsonl'
 if not p.exists() or not (OUT/f'{label}.command.json').exists():continue
 ee=events(p);tests={e['test']['id']:e['test']['name'] for e in ee if e['type']=='testStart'}
 done=[e for e in ee if e['type']=='testDone' and not e.get('hidden')]
 summary[label]={'exit':json.loads((OUT/f'{label}.command.json').read_text())['exit'],'results':dict(collections.Counter('skipped' if e.get('skipped') else e['result'] for e in done)),'failures':[tests.get(e['testID']) for e in done if e['result']!='success' and not e.get('skipped')]}
(OUT/'suite-summary.json').write_text(json.dumps(summary,indent=2))
lines=['# Intentional golden refresh', '', 'Updated exactly 35 allowlisted PNGs and five chart fixture files on isolated Flutter 3.47.1. All 35 pass without update mode. Across the 56 classified identities, 35 pass and the expected 21 environment/toolchain cases fail. All 21 references remain byte-identical. All 41 non-allowlisted golden files are unchanged. No additional unlisted golden was updated or selected by the focused update/verify runs; the BeuiButton sibling was excluded.', '', 'The classification run executes 57 comparisons covering 56 unique identities: the plain-name selector for `chat app shell` also selects the already-listed `chat app shell below the sidebar breakpoint`; that second identity runs again in its dedicated command. This is one duplicate listed failure, not an additional unlisted failure. Each of the 35 update and 35 verify invocations selected exactly one test.', '', '## Capture repair and red proof', '', 'The new content assertions failed in all five original chart captures because entrance opacity was zero. `red-content.jsonl` retains the failures; `reproduce-red.patch` removes only the frame progression from the final tests. Final fixtures use ten sequential 100 ms frames for reduced-motion BumpChart and OrderBook, and twenty for CandlestickChart, DonutChart and VolumeProfile. These cover fades, stagger timers and spring progression without relying on a single large pump. Motion preferences were preserved.', '', 'Assertions require two ranking path painters and visible entrance opacity; nine painted candle shapes with full opacity; three painted donut arcs with full ancestor opacity; five nonzero colored depth fills of the expected height; and four nonzero volume fills of meaningful dimensions and final opacity. No missing first frame was adopted. All five resulting PNGs are pixel-identical to the prior forty-frame control (`chart-rest-state-control.json`).', '', 'All 35 new original-resolution PNGs and all seven before/after contact sheets were inspected. No new clipping or incomplete chart content was found. SignupForm needs no fixture edit: the same 480x1000 capture contains its taller intended card, all four fields, terms and submit.', '', '## Environment and provenance', '', 'Execution used `/tmp/beui-intentional-refresh` and `/tmp/beui-final-golden-triage/sdk-3.47.1`, leaving shared SDKs and dependency files untouched. Source snapshot HEAD is `'+env['head']+'`; `environment.json` records every source/test input hash, all 76 original golden hashes, full Flutter/engine/Dart version output, OS/kernel and SDK font hashes. The 40 changed-file SHA-256 hashes are in `changed-paths-sha256.json`. Per-image dimensions, old/new SHA-256, author commit, full causal commit hashes, individual reasons and visual review are in `manifest.json`.', '', 'Flutter 3.47.1 / Dart 3.13.1 runs on macOS 27.0.1 build 26A434 arm64. The selected root golden fixtures do not load production fonts; Ahem and missing icon glyph boxes remain the existing test rendering contract. No font substitution was introduced. Retained dependency tree, pubspec/lock and package config record the offline resolution. The earlier triage proved the 32 October author controls on this SDK; the three older intentional cases retain disclosed environment residuals. Exact historical author OS/dependencies remain unknown.', '', '## Gates', '', '- Focused update: 35/35 passed, one allowlisted test per command.', '- Focused no-update verification: 35/35 passed.', '- Classification: 35 intentional passes; 21 expected drift failures, unchanged references.', '- Changed-test analyzer: passed with no issues.', '- Changed-test formatter: passed, zero changes.', '- Root suite with `BEUI_SKIP_GOLDENS=1`: '+('pending' if 'root-suite' not in summary else str(summary['root-suite']['results']) + ', exit ' + str(summary['root-suite']['exit']))+'.', '- Example suite: '+('pending' if 'example-suite' not in summary else str(summary['example-suite']['results']) + ', exit ' + str(summary['example-suite']['exit']))+'.', '', 'The existing skip comparator was used only for the requested root suite. It was unset for update, focused verification and classification. No comparator or tolerance was edited. Full suite results prove this isolated source snapshot, not hosted CI, native engine behavior or release readiness.', '', 'The first root attempt omitted three proof JSON fixtures from the isolated copy and ended with 2728 passes plus three PathNotFound errors. Raw output is retained as `root-suite-missing-fixtures.*`. After copying those unchanged required inputs, the corrected complete root suite was run once. The example suite ran once. No product or test code changed to resolve that setup error.', '', '## Individual update reasons', '']
for r in manifest:
 if r['number'] not in notes:continue
 lines += [f"### {r['number']:02}. {pathlib.Path(r['golden']).name}",'',f"Path: `{r['golden']}`. Causal commits: {', '.join('`'+c+'`' for c in r['causal_commits'])}.",'',r['reason'],'',notes[r['number']],'',f"Dimensions: {r['before_dimensions']} to {r['after_dimensions']}. Full hashes are in manifest.json.",'']
lines+=['Original triage, archived failures, production code, all other tests and parent engine/CI work were left untouched. No child agents, commits, pushes or merges were made.']
(OUT/'REPORT.md').write_text('\n'.join(lines)+'\n')
print(json.dumps(summary,indent=2))
