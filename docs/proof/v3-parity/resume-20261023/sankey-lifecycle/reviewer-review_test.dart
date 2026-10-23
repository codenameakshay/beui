import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import '/Users/codenameakshay/.t3/worktrees/beui/t3-df4b55e2/lib/src/charts/sankey_chart.dart';
const nodes = [BeuiSankeyNode(id:'a',label:'A'),BeuiSankeyNode(id:'b',label:'B'),BeuiSankeyNode(id:'c',label:'C')];
const links = [BeuiSankeyLink(source:'a',target:'c',value:30),BeuiSankeyLink(source:'b',target:'c',value:70)];
Finder target(String id)=>find.byKey(ValueKey('sankey-target:$id'));
FocusNode focus(WidgetTester t,String id)=>t.widget<FocusableActionDetector>(find.descendant(of:target(id),matching:find.byType(FocusableActionDetector))).focusNode!;
void main(){
 test('100 generated graphs match pinned clean and layout outputs', () {
  final fixtures=jsonDecode(File('/tmp/sankey-independent-review-20261023/source_graph.json').readAsStringSync()) as List;
  for (var i=0;i<fixtures.length;i++) {
   final f=fixtures[i];
   final ns=[for(final n in f['nodes']) BeuiSankeyNode(id:n['id'],label:n['label'])];
   final ls=[for(final l in f['links']) BeuiSankeyLink(id:l['id'],source:l['source'],target:l['target'],value:(l['value'] as num).toDouble())];
   final d=beuiCleanSankey(ns,ls);
   Map<String,dynamic> entry(BeuiSankeyLink l)=>{'id':l.effectiveId,'source':l.source,'target':l.target,'value':l.value};
   expect(d.links.map(entry).toList(), f['cleaned']['links'],reason:'graph $i links');
   expect(d.invalid.length,f['cleaned']['dropped']['invalid'].length);
   expect(d.cycles.map(entry).toList(),f['cleaned']['dropped']['cycle']);
   final layout=beuiLayoutSankey(d,size:const Size(640,320));
   expect(layout.nodes.map((n)=>n.id).toList(),[for(final n in f['layout']['nodes']) n['id']]);
   for(var j=0;j<layout.nodes.length;j++) {
    final n=layout.nodes[j], e=f['layout']['nodes'][j];
    expect(n.rect.top,closeTo(e['y0'],1e-8));expect(n.rect.bottom,closeTo(e['y1'],1e-8));expect(n.rect.left,e['x0']);expect(n.value,e['value']);
   }
   for(var j=0;j<layout.links.length;j++) {
    final l=layout.links[j],e=f['layout']['links'][j];
    expect(l.start.dy,closeTo(e['y0'],1e-8));expect(l.end.dy,closeTo(e['y1'],1e-8));expect(l.width,closeTo(e['width'],1e-8));expect(l.share,e['share']);
   }
  }
 });
 testWidgets('controlled nonnull rejection acceptance and removed active identity', (t) async {
  late BeuiSankeyChartModel model; final changes=<String?>[];
  Widget app(String? id,List<BeuiSankeyLink> edges)=>MaterialApp(home:MediaQuery(data:const MediaQueryData(disableAnimations:true,size:Size(800,600)),child:Scaffold(body:SizedBox(width:640,child:BeuiSankeyChart(nodes:nodes,links:edges,controlled:true,activeId:id,onActiveChange:changes.add,child:Builder(builder:(c){model=BeuiSankeyChart.of(c);return const Column(children:[BeuiSankeyChartPlot(),BeuiSankeyChartTooltip()]);}))))));
  await t.pumpWidget(app('a',links));await t.pumpAndSettle();
  focus(t,'b').requestFocus();await t.pumpAndSettle();
  expect(changes.last,'b');expect(model.active?.node?.id,'a');expect(model.tooltipOpen,true);
  await t.pumpWidget(app('b',links));await t.pumpAndSettle();expect(model.active?.node?.id,'b');
  await t.tapAt(const Offset(799,599));await t.pumpAndSettle();expect(changes.last,null);expect(model.active?.node?.id,'b');expect(model.tooltipOpen,false);
  await t.pumpWidget(app('b',const [BeuiSankeyLink(source:'a',target:'c',value:30)]));await t.pumpAndSettle();expect(model.active,isNull);
 });

 testWidgets('removed cursor must not revive after external blur', (t) async {
  final external=FocusNode();
  Widget app(List<BeuiSankeyLink> edges)=>MaterialApp(home:MediaQuery(data:const MediaQueryData(disableAnimations:true,size:Size(800,600)),child:Scaffold(body:Column(children:[TextButton(focusNode:external,onPressed:(){},child:const Text('Outside')),SizedBox(width:640,child:BeuiSankeyChart(nodes:nodes,links:edges))]))));
  await t.pumpWidget(app(links));await t.pumpAndSettle();
  focus(t,'b').requestFocus();await t.pumpAndSettle();
  external.requestFocus();await t.pumpAndSettle();
  await t.pumpWidget(app(const [BeuiSankeyLink(source:'a',target:'c',value:30)]));await t.pumpAndSettle();
  expect(focus(t,'a').skipTraversal,false);
  await t.pumpWidget(app(links));await t.pumpAndSettle();
  expect(focus(t,'a').skipTraversal,false,reason:'source useRowCursor clears a removed id, so readding B must keep A as tab stop');
  await t.pumpWidget(const SizedBox()); external.dispose();
 });
 testWidgets('all focused nodes removed transfers focus safely', (t) async {
  Widget app(List<BeuiSankeyLink> edges)=>MaterialApp(home:MediaQuery(data:const MediaQueryData(disableAnimations:true,size:Size(800,600)),child:Scaffold(body:SizedBox(width:640,child:BeuiSankeyChart(nodes:nodes,links:edges)))));
  await t.pumpWidget(app(links));await t.pumpAndSettle();
  focus(t,'b').requestFocus();await t.pumpAndSettle();
  await t.pumpWidget(app([]));await t.pumpAndSettle();
  expect(t.takeException(),isNull);
  expect(FocusManager.instance.primaryFocus?.debugLabel,'Sankey plot');
 });
 testWidgets('offscreen chart stays keyboard reachable before entrance', (t) async {
  final before=FocusNode();final after=FocusNode();
  await t.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(child:Column(children:[
    TextButton(focusNode:before,onPressed:(){},child:const Text('Before')),
    const SizedBox(height:800),
    const SizedBox(width:640,child:BeuiSankeyChart(nodes:nodes,links:links)),
    TextButton(focusNode:after,onPressed:(){},child:const Text('After')),
  ])))));
  await t.pumpAndSettle();before.requestFocus();await t.pumpAndSettle();
  debugPrint('before Tab: A.canRequestFocus=${focus(t,"a").canRequestFocus}');
  await t.sendKeyEvent(LogicalKeyboardKey.tab);await t.pumpAndSettle();
  debugPrint('after Tab: After.hasPrimaryFocus=${after.hasPrimaryFocus}');
  expect(focus(t,'a').hasPrimaryFocus,true,reason:'source keeps tabIndex=0 before inView, only disabling pointer events');
  await t.pumpWidget(const SizedBox());before.dispose();after.dispose();
 });
 testWidgets('keyboard End scrolls narrow plot to focused node', (t) async {
  await t.pumpWidget(MaterialApp(home:MediaQuery(data:const MediaQueryData(disableAnimations:true,size:Size(800,600)),child:Scaffold(body:Center(child:SizedBox(width:300,child:BeuiSankeyChart(nodes:nodes,links:links)))))));
  await t.pumpAndSettle();focus(t,'a').requestFocus();await t.pumpAndSettle();
  await t.sendKeyEvent(LogicalKeyboardKey.end);await t.pumpAndSettle();
  expect(focus(t,'c').hasPrimaryFocus,true);
  final viewport=t.getRect(find.byType(SingleChildScrollView));
  final targetCenter=t.getCenter(target('c'));
  expect(viewport.contains(targetCenter),true,reason:'focused C at $targetCenter must be visible in $viewport');
 });
 testWidgets('default format integers and decimals', (t) async {
  late BeuiSankeyChartModel model;
  await t.pumpWidget(MaterialApp(home:BeuiSankeyChart(nodes:nodes,links:links,child:Builder(builder:(c){model=BeuiSankeyChart.of(c);return const SizedBox();}))));
  expect(model.formatValue(30),'30');expect(model.formatValue(1000),'1,000'); expect(model.formatValue(.001),'0');
 });
}
