import 'dart:convert';
import 'dart:js_interop';
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@JS('globalThis.__fixture')
external set probe(JSAny? value);

void main() => runApp(const Fixture());
class Fixture extends StatefulWidget {
  const Fixture({super.key});
  @override
  State<Fixture> createState() => _FixtureState();
}
class _FixtureState extends State<Fixture> {
  String state = 'initial';
  final selections = <Map<String, Object?>>[];
  final changes = <Map<String, Object?>?>[];
  Map<String, dynamic>? snapshots;
  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/snapshots.json').then((s) => setState(() => snapshots = jsonDecode(s)));
  }
  void change(String next) => setState(() => state = next);
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData(fontFamily: 'Geist', extensions: [BeuiColors.light()]),
    home: Builder(builder: (context) {
      final data = snapshots?[state];
      List<BeuiOrderBookLevel> levels(String side) => [for(final r in data[side]) BeuiOrderBookLevel(price: (r['price'] as num).toDouble(), size: (r['size'] as num).toDouble())];
      probe = {'state':state,'paused':true,'disableAnimations':MediaQuery.disableAnimationsOf(context),'snapshot':data,'selections':selections,'changes':changes}.jsify();
      return CallbackShortcuts(bindings: {
        for(final entry in {LogicalKeyboardKey.keyR:'reorder', LogicalKeyboardKey.keyE:'empty',LogicalKeyboardKey.keyB:'bids',LogicalKeyboardKey.keyA:'asks',LogicalKeyboardKey.keyI:'initial',LogicalKeyboardKey.keyS:'step'}.entries)
          SingleActivator(entry.key): () => change(entry.value),
      }, child: Scaffold(body: Center(child: SizedBox(width:560, child: Column(mainAxisSize:MainAxisSize.min,children:[
        Text('Paused fixture · $state'),
        Wrap(children:[for(final label in ['initial','reorder','empty','bids','asks','step']) TextButton(onPressed:()=>change(label),child:Text(label))]),
        if(data != null) BeuiOrderBook(bids:levels('bids'),asks:levels('asks'),baseSymbol:'BTC',quoteSymbol:'USD',
          onActiveLevelChange:(v)=>setState(()=>changes.add(v == null ? null : {'side':v.side.name,'price':v.price})),
          onLevelSelect:(v,s)=>setState(()=>selections.add({'side':s.name,'price':v.price,'size':v.size,'total':v.total})),
          child:const Column(mainAxisSize:MainAxisSize.min,children:[BeuiOrderBookHeader(),BeuiOrderBookSide(side:BeuiOrderBookSideKind.ask),BeuiOrderBookSpread(),BeuiOrderBookSide(side:BeuiOrderBookSideKind.bid),BeuiOrderBookDepthSummary(),BeuiOrderBookBalance()]),
        ),
      ])))));
    }),
  );
}
