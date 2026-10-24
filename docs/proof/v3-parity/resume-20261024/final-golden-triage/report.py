import pathlib,json,subprocess,hashlib,shutil,collections
root=pathlib.Path.cwd();p=root/'docs/proof/v3-parity/resume-20261024/final-golden-triage';rows=json.loads((p/'comparison-controls.json').read_text())
notes={
'beui_bump_chart':('5189cd7ef, eaeb9fc98, 059b4dbdb','Grid, labels, rank border and reduced-motion entrance changed; initial capture omits fading paths. Forty timed frames restore paths. Fix the rest-state fixture timing before an intentional reference update.'),
'beui_candlestick-chart':('0444124ce, 2420167cc','Added staggered candle entrance, axes and inspection layout. First-frame capture has no candles; forty timed frames restores all three. Fix rest-state timing before an intentional reference update.'),
'beui_composition_chart':('ce3a48f47, 09cff48a8','Source bar geometry, chart height, legend and percentage layout changed; image dimensions change.'),
'beui_donut-chart':('0444124ce, 97329fccc, 784a2f58d','Ring entrance, gaps, legend tracks and center digits changed. First-frame capture contains only the track; forty timed frames restores colored arcs. Fix rest-state timing first.'),
'beui_funnel_chart':('ca0562e0a, 0219e2845','Stage paths, labels, hover tint and legend geometry changed.'),
'beui_heat_calendar':('ec0513ce8, 4d30d67cf, bf12ab39c','Added/reflowed legend, heading and inspection layout; cells remain present.'),
'beui_liquidity_heatmap':('8eedf6248, ffb962872','Moved price labels to source side and corrected trace/grid geometry.'),
'beui_order_book':('ec0513ce8, 7d5cfaeef','Depth bars, native price buttons and opacity entrance changed. Reduced motion retains nonmovement fades; forty timed frames restores depth fills. Fix rest-state timing first.'),
'beui_price_target_fan':('e8335ba42, f55abfc33, 84e984a3c','Projection, now marker, axes, target labels and controls were deliberately rebuilt.'),
'beui_returns_calendar':('ec0513ce8, bf12ab39c, 28943b965','Cell tint/rounding, header and readout ink/spacing changed.'),
'beui_treemap':('a2c8b3e3d, 28943b965','Cell readouts and legend ink changed; added second text line.'),
'beui_volume-profile':('0444124ce, 31eac9a54, d24249b6c','Added entrance, axes, colored volume geometry and summary. Forty timed frames restores bars. Fix rest-state timing first.'),
'beui_adaptive_stepper':('421e9271e','Rounded pill replaced by the source liquid silhouette and separated side controls.'),
'beui_alert':('7e764e018, 6c86802ae','Tone colors, retained exit layout and close-control margins changed.'),
'beui_approval_card':('a3c2491fa, c729381b2','Badge/counter styling and source example field layout changed.'),
'beui_breadcrumb':('b0a025f76, fee57512d, 8597186fa','Inline/wrapped route layout and typography changed; current final route sits inline.'),
'beui_metallic_button':('ecea1d400','Chrome layers and preview states changed; old broad metallic bands removed.'),
'beui_card_folder':('f0cb706cd, 9d08a1c6f','Card press/privacy rendering and text geometry changed.'),
'beui_card':('b0a025f76','Description line metrics and muted-card border changed; inspected at full image size.'),
'beui_code_block':('4fdec936f','Shared tokenizer now colors assignment punctuation as keyword. The current/author difference is 182 pixels on 3.44.4, plus 6 pre-existing environment pixels; inspected enlarged token crop.'),
'beui_color_picker':('7492c0b3f, cfe381654','Spectrum/trigger morph, field and hue-track geometry changed.'),
'beui_color_selector':('b0a025f76, 93ebe4787','Selected swatch ring changed from the old oversized oval to the source circular ring.'),
'beui_combobox':('81120f68b, 5b749f5a6','Source workspace trigger and editable-input geometry changed; later reopen fix does not account for the historical mismatch.'),
'beui_date_range_picker':('3122ad6b0, 87d8456f3, baf7b62b0','Completed trigger omits repeated year and uses source tabular widths/typography.'),
'beui_digit_swap':('f0cb706cd, 9d08a1c6f','Source digit spacing/width changed; four separated digit cells replace contiguous cells.'),
'beui_expandable_control':('6f97bc3da','Resting foreground intentionally changed to mutedForeground, with foreground reserved for hover.'),
'beui_file_diff':('eca6b142a, 4fdec936f, 4e441e295','Diff token colors, replay/hunk layout and row geometry changed.'),
'beui_file_tree':('6f97bc3da','Selected/emphasized file icon now uses foreground instead of mutedForeground. All 140 changed pixels are localized to that icon; inspected enlarged crop.'),
'beui_image_viewer':('b0a025f76, 1479c7d57','Thumbnail geometry and morph behavior changed; both thumbnails are shorter/narrower.'),
'beui_morphing_search_chips':('aace02b0a','Closed trigger now reserves/displays the searchable chip input layout; width and visible text changed.'),
'beui_morphing_tabs':('f0cb706cd','Source card/tab colors and geometry changed, including outer dark surface.'),
'beui_prediction_market_card':('f0cb706cd','Outcome button colors/layout, sparkline and card geometry changed.'),
'beui_signup_form':('af4522f83, 250a649c0','Typography, fields and confirmation gap changed; fixture output bounds also change. Review intended capture bounds before updating.'),
'beui_sortable_list':('6f97bc3da, 91819aa8e','Handle/undo styles and focus treatment changed; retained rows and undo control shift visually.'),
'beui_tabs':('dfe5bd4e5, aa0a372f6','Underline moved inside the trigger and focus fill was removed; 136 pixels differ on 3.44.4.')}
timing={'beui_bump_chart','beui_candlestick-chart','beui_donut-chart','beui_order_book','beui_volume-profile'}
for i,r in enumerate(rows,1):
 n=pathlib.Path(r['golden']).stem;r['number']=i
 if r['author_vs_current3444']['pixels']==0:
  r['classification']='environment/toolchain drift';r['reason']='Current source and author-commit rendering are pixel-identical on isolated Flutter 3.44.4 / Dart 3.12.2 on this host. Author/current retain '+str(r['author_render_vs_golden']['pixels'])+' differing pixels against the historical reference. 3.47.1 fails. No source/reference edit recommended.';r['causal_commits']=[]
 else:
  assert n in notes,n
  r['classification']='intentional visual change';r['causal_commits']=notes[n][0].split(', ');r['reason']=notes[n][1];r['fixture_timing_repair_required']=n in timing
 r['author_control']='author-'+r['author_commit'][:9] if r['date'].startswith('2026-10') else ('author-lucide131-' if r['date'].startswith('2026-08-18') else 'author-pinned-')+r['author_commit'][:9]
(p/'classification.json').write_text(json.dumps(rows,indent=2))
lines=['# Per-golden classification checkpoint','','All 56 original failure identities are mapped below. Classes identify the supported cause of the mismatch, not release acceptance. Intentional changes may still include environmental pixels. No reference was regenerated.','','| # | Test identity / golden | Classification | Author control | Evidence and recommendation |','| --- | --- | --- | --- | --- |']
for r in rows:
 lines.append(f"| {r['number']} | {r['identity']}<br>`{r['golden']}` | {r['classification']} | `{r['author_commit'][:9]}`; [log]({r['author_control']}-1.log) | {r['reason']} Commits: {', '.join(r['causal_commits']) or 'none required'}. |")
(p/'CLASSIFICATION.md').write_text('\n'.join(lines)+'\n')
for f in pathlib.Path('/tmp/beui-final-golden-triage').glob('*.py'):shutil.copy2(f,p/f.name)
# Record evidence provenance without adding mutable cache/build inputs.
manifest={'os':subprocess.check_output(['sw_vers'],text=True),'arch':subprocess.check_output(['uname','-m'],text=True).strip(),'final_observed_head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'goldens_unchanged':{},'fonts':{}}
inputs=json.loads((p/'current-inputs.json').read_text())['files']
for r in rows:
 h=hashlib.sha256((root/r['golden']).read_bytes()).hexdigest();manifest['goldens_unchanged'][r['golden']]={'sha256':h,'matches_snapshot':h==inputs[r['golden']]}
for sdk in ['3.44.4','3.47.1']:
 f=pathlib.Path('/tmp/beui-final-golden-triage')/('sdk-'+sdk)/'packages/flutter_tools/static/Ahem.ttf';manifest['fonts'][sdk]={'path':str(f),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}
(p/'provenance.json').write_text(json.dumps(manifest,indent=2))
print(collections.Counter(r['classification'] for r in rows))
