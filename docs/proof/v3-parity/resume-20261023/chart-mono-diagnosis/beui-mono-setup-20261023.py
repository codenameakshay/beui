import pathlib, shutil, subprocess, hashlib, json
root=pathlib.Path('/Users/codenameakshay/.t3/worktrees/beui/t3-df4b55e2'); out=pathlib.Path('/tmp/beui-mono-research-20261023'); out.mkdir()
subprocess.run(['rsync','-a','--exclude=.git','--exclude=build','--exclude=.dart_tool','--exclude=node_modules','--exclude=docs/proof','--exclude=.fvm',str(root)+'/',str(out/'repo')+'/'],check=True)
fixture=(root/'docs/proof/v3-parity/charts/round4-candle-volume/fixture.dart').read_text().replace("../../../../../example/lib/explorer/", "package:beui_example/explorer/")
fixture=fixture.replace("import 'dart:math' as math;", "import 'dart:math' as math;\nimport 'dart:js_interop';\nimport 'package:flutter/rendering.dart';")
fixture=fixture.replace('void main() => runApp(const Fixture());', '''@JS('globalThis.__readMono')
external set readMono(JSFunction value);
void main() { runApp(const Fixture()); readMono = (() { return collect().jsify(); }).toJS; }
List<Map<String,Object?>> collect() {
 final result = <Map<String,Object?>>[];
 void visit(Element e) {
  if(e is RenderObjectElement && e.renderObject is RenderParagraph) {
   final p=e.renderObject as RenderParagraph; final s=p.text.style; final pos=p.localToGlobal(Offset.zero);
   final tp=TextPainter(text:p.text,textDirection:p.textDirection,textScaler:p.textScaler)..layout();
   result.add({'text':p.text.toPlainText(),'family':s?.fontFamily,'size':s?.fontSize,'weight':s?.fontWeight?.value,'tracking':s?.letterSpacing,'heightStyle':s?.height,'width':p.size.width,'height':p.size.height,'advance':tp.width,'x':pos.dx,'y':pos.dy,'baseline':p.getDistanceToBaseline(TextBaseline.alphabetic),'scale':p.textScaler.scale(12),'lines':tp.computeLineMetrics().map((l)=>{'width':l.width,'baseline':l.baseline,'ascent':l.ascent,'descent':l.descent}).toList()}); tp.dispose();
  } e.visitChildElements(visit);
 } visit(WidgetsBinding.instance.rootElement!); return result;
}''')
fixture=fixture.replace("if (_query['chart'] == 'candle')", "if (_query['chart'] == 'probe')\n                          Column(children: [for(final family in ['Geist Mono','monospace','Geist']) for(final weight in [FontWeight.w400,FontWeight.w500]) for(final text in ['iiiiiiiiii','WWWWWWWWWW','15:55','2,439.17','Vol','+0.04%',r'$65,050','2,371 BTC']) Text(text,style:TextStyle(fontFamily:family,fontSize:12,fontWeight:weight,height:16/12,letterSpacing:0,fontFeatures:const [FontFeature.tabularFigures()]))])\n                        else if (_query['chart'] == 'candle')")
(out/'repo/example/lib/mono_fixture.dart').write_text(fixture)
shutil.copytree('/tmp/beui-round4-candle-volume-source-v2-20261023',out/'source')
files=list((out/'repo/lib').rglob('*.dart'))+list((out/'repo/example/lib').rglob('*.dart'))+list((out/'repo/example/assets/fonts').glob('*'))+[out/'repo/example/pubspec.yaml']
(out/'inputs.json').write_text(json.dumps({'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'sourceHead':subprocess.check_output(['git','rev-parse','HEAD'],cwd='/tmp/beui-charts-reference-20261023',text=True).strip(),'files':{str(p.relative_to(out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}},indent=2))
