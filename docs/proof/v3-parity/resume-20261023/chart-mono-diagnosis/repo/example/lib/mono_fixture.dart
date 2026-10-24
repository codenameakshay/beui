// ignore_for_file: avoid_relative_lib_imports

import 'dart:math' as math;
import 'dart:js_interop';
import 'package:flutter/rendering.dart';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:beui_example/explorer/explorer_app.dart';
import 'package:beui_example/explorer/capture_probe_web.dart';

@JS('globalThis.__readMono')
external set readMono(JSFunction value);
void main() { runApp(Uri.base.queryParameters['chart']?.startsWith('gallery') == true ? const BeuiExplorerApp() : const Fixture()); readMono = (() { return collect().jsify(); }).toJS; }
List<Map<String,Object?>> collect() {
 final result = <Map<String,Object?>>[];
 void visit(Element e) {
  if(e is RenderObjectElement && e.renderObject is RenderParagraph) {
   final p=e.renderObject as RenderParagraph; final s=p.text.style; final pos=p.localToGlobal(Offset.zero);
   final tp=TextPainter(text:p.text,textDirection:p.textDirection,textScaler:p.textScaler)..layout();
   result.add({'text':p.text.toPlainText(),'family':s?.fontFamily,'size':s?.fontSize,'weight':s?.fontWeight?.value,'tracking':s?.letterSpacing,'heightStyle':s?.height,'width':p.size.width,'height':p.size.height,'advance':tp.width,'x':pos.dx,'y':pos.dy,'baseline':p.getDistanceToBaseline(TextBaseline.alphabetic),'scale':p.textScaler.scale(12),'lines':tp.computeLineMetrics().map((l)=>{'width':l.width,'baseline':l.baseline,'ascent':l.ascent,'descent':l.descent}).toList()}); tp.dispose();
  } e.visitChildElements(visit);
 } visit(WidgetsBinding.instance.rootElement!); return result;
}

class Fixture extends StatefulWidget {
  const Fixture({super.key});

  @override
  State<Fixture> createState() => _FixtureState();
}

class _FixtureState extends State<Fixture> {
  final _chart = GlobalKey();
  var _data = 'original';
  final _query = Uri.base.queryParameters;
  final _events = <Map<String, Object?>>[];

  void _recordFocus() {
    final primary = FocusManager.instance.primaryFocus;
    _events.add({
      'event': 'focus-change',
      'primary': primary.toString(),
      'widget': primary?.context?.widget.toStringShort(),
      'primaryFocus': switch (primary?.context?.widget) {
        final Focus focus => {
          'canRequestFocus': focus.canRequestFocus,
          'skipTraversal': focus.skipTraversal,
          'includeSemantics': focus.includeSemantics,
          'autofocus': focus.autofocus,
          'child': focus.child is CallbackShortcuts
              ? 'CallbackShortcuts'
              : focus.child is Semantics
              ? 'Semantics'
              : focus.child is Center
              ? 'Center'
              : focus.child is Listener
              ? 'Listener'
              : 'other',
        },
        _ => null,
      },
      'ancestors': primary?.ancestors.map((n) => n.toString()).toList(),
      'focus': _focusNodes(),
    });
  }

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_recordFocus);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_recordFocus);
    super.dispose();
  }

  List<Map<String, Object?>> _focusNodes() {
    final result = <Map<String, Object?>>[];
    void visit(Element element) {
      final widget = element.widget;
      if (widget is FocusableActionDetector) {
        result.add({
          'focus': widget.focusNode?.hasFocus,
          'primary': widget.focusNode?.hasPrimaryFocus,
        });
      }
      element.visitChildElements(visit);
    }

    final element = _chart.currentContext;
    if (element is Element) visit(element);
    return result;
  }

  List<BeuiCandle> get candles {
    var close = 2380.0;
    return [
      for (var i = 0; i < 48; i++)
        (() {
          final open = close;
          close =
              open * (1 + math.sin(i * .7) * .004 + math.cos(i * .23) * .003);
          final reach =
              (close - open).abs() * .6 + 1.5 + math.sin(i * 1.9).abs() * 3;
          return BeuiCandle(
            id: '$i',
            time: '${12 + i ~/ 12}:${(i % 12 * 5).toString().padLeft(2, '0')}',
            open: open,
            close: close,
            high: math.max(open, close) + reach * math.cos(i * 1.3).abs(),
            low: math.min(open, close) - reach * math.sin(i * .9).abs(),
            volume: 120 + math.sin(i * .6).abs() * 420,
          );
        })(),
    ];
  }

  static const volumes = [
    18,
    27,
    36,
    52,
    70,
    96,
    135,
    172,
    205,
    241,
    278,
    225,
    192,
    146,
    108,
    79,
    56,
    42,
    31,
    22,
    16,
    11,
    8,
    5,
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = _query['theme'] == 'light'
        ? Brightness.light
        : Brightness.dark;
    return MaterialApp(
      theme: beuiGalleryTheme(BeuiColorTheme.defaultMono, brightness),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final box =
                  _chart.currentContext?.findRenderObject() as RenderBox?;
              publishCaptureProbe({
                'disableAnimations': MediaQuery.disableAnimationsOf(context),
                'platformDisableAnimations': View.of(
                  context,
                ).platformDispatcher.accessibilityFeatures.disableAnimations,
                'data': _data,
                'focusNodes': _focusNodes(),
                'events': _events,
                'rect': box == null
                    ? null
                    : {
                        'x': box.localToGlobal(Offset.zero).dx,
                        'y': box.localToGlobal(Offset.zero).dy,
                        'width': box.size.width,
                        'height': box.size.height,
                      },
              });
            });
            final candleData = _data == 'empty' ? <BeuiCandle>[] : candles;
            final volumeData = _data == 'empty'
                ? <BeuiVolumeProfileBin>[]
                : [
                    for (var i = 0; i < volumes.length; i++)
                      BeuiVolumeProfileBin.range(
                        id: _data == 'replaced'
                            ? 'new-$i'
                            : 'price-${64000 + i * 100}',
                        priceLow: 64000 + i * 100,
                        priceHigh: 64100 + i * 100,
                        volume: volumes[i].toDouble(),
                      ),
                  ];
            return Listener(
              onPointerDown: (_) =>
                  _events.add({'event': 'down', 'focus': _focusNodes()}),
              onPointerUp: (_) =>
                  _events.add({'event': 'up', 'focus': _focusNodes()}),
              child: Focus(
                autofocus: true,
                onKeyEvent: (_, event) {
                  setState(
                    () => _events.add({
                      'event': 'unhandled-key',
                      'key': event.logicalKey.keyLabel,
                      'focus': _focusNodes(),
                    }),
                  );
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  final next = switch (event.logicalKey) {
                    LogicalKeyboardKey.keyR => 'replaced',
                    LogicalKeyboardKey.keyE => 'empty',
                    LogicalKeyboardKey.keyI => 'original',
                    _ => null,
                  };
                  if (next == null) return KeyEventResult.ignored;
                  setState(() => _data = next);
                  return KeyEventResult.handled;
                },
                child: Center(
                  child: SizedBox(
                    width: double.parse(_query['width'] ?? '576'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('R replaces IDs. E empties. I restores.'),
                        const SizedBox(height: 24),
                        if (_query['chart'] == 'probe')
                          Column(children: [for(final family in ['Geist Mono','monospace','Geist']) for(final weight in [FontWeight.w400,FontWeight.w500]) for(final text in ['iiiiiiiiii','WWWWWWWWWW','15:55','2,360.34','Vol','+0.34%',r'$65,050','2,271 BTC']) Text(text,style:TextStyle(fontFamily:family,fontSize:12,fontWeight:weight,height:16/12,letterSpacing:0,fontFeatures:const [FontFeature.tabularFigures()]))])
                        else if (_query['chart'] == 'candle')
                          BeuiCandlestickChart(
                            key: _chart,
                            candles: candleData,
                            lastPrice: candleData.isEmpty
                                ? null
                                : candleData.last.close,
                            formatPrice: (v) => beuiChartFormatNumber(
                              v,
                              maximumFractionDigits: 2,
                            ),
                          )
                        else
                          BeuiVolumeProfile(
                            key: _chart,
                            data: volumeData,
                            unit: 'BTC',
                            label: 'BTC volume profile',
                            formatPrice: (v) => '\$${beuiChartFormatNumber(v)}',
                            formatVolume: (v) => beuiChartFormatNumber(v),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
