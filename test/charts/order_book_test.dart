import 'dart:ui' show PointerDeviceKind;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _bids = [
  BeuiOrderBookLevel(price: 99, size: 2),
  BeuiOrderBookLevel(price: 98, size: 3),
  BeuiOrderBookLevel(price: 97, size: 5),
];
const _asks = [
  BeuiOrderBookLevel(price: 101, size: 4),
  BeuiOrderBookLevel(price: 102, size: 6),
];

Widget _surface({
  BeuiOrderBookActiveLevel? active,
  BeuiOrderBookActiveLevel? defaultActive,
  ValueChanged<BeuiOrderBookActiveLevel?>? onChange,
  bool reduce = false,
  void Function(BeuiOrderBookDepthLevel, BeuiOrderBookSideKind)? onSelect,
}) => beuiTestApp(
  SizedBox(
    width: 640,
    height: 420,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BeuiOrderBook(
          bids: _bids,
          asks: _asks,
          baseSymbol: 'BTC',
          quoteSymbol: 'USD',
          activeLevel: active,
          defaultActiveLevel: defaultActive,
          onActiveLevelChange: onChange,
          onLevelSelect: onSelect,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiOrderBookHeader(),
              BeuiOrderBookSide(side: BeuiOrderBookSideKind.ask),
              BeuiOrderBookSpread(),
              BeuiOrderBookSide(side: BeuiOrderBookSideKind.bid),
              BeuiOrderBookDepthSummary(),
              BeuiOrderBookBalance(),
            ],
          ),
        ),
      ),
    ),
  ),
  reduce: reduce,
);

void main() {
  testWidgets(
    'shows sorted order tables, midpoint spread and live depth summary',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _surface(
          defaultActive: const BeuiOrderBookActiveLevel(
            side: BeuiOrderBookSideKind.bid,
            price: 98,
          ),
        ),
      );
      final priceTicker = tester.widget<BeuiChartTicker>(
        find.byType(BeuiChartTicker),
      );
      expect(priceTicker.value, 100);
      expect(priceTicker.format(priceTicker.value), '100.00');
      expect(find.textContaining('Spread 2.00'), findsOneWidget);
      expect(find.textContaining('Avg 98.40'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('bid, 98.00'))),
        isNotNull,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'uncontrolled inspection notifies, controlled value remains owner-driven',
    (tester) async {
      final changes = <BeuiOrderBookActiveLevel?>[];
      await tester.pumpWidget(_surface(onChange: changes.add));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(tester.getCenter(find.text('98.00')));
      await tester.pump();
      expect(
        changes,
        contains(
          const BeuiOrderBookActiveLevel(
            side: BeuiOrderBookSideKind.bid,
            price: 98,
          ),
        ),
      );
      await tester.pumpWidget(
        _surface(
          active: const BeuiOrderBookActiveLevel(
            side: BeuiOrderBookSideKind.ask,
            price: 102,
          ),
          onChange: changes.add,
        ),
      );
      expect(find.textContaining('Avg 101.60'), findsOneWidget);
      await mouse.removePointer();
    },
  );

  testWidgets('hover highlights the price and cumulative depth range', (
    tester,
  ) async {
    await tester.pumpWidget(_surface());
    expect(find.text('Hover a level to inspect depth'), findsOneWidget);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.text('98.00')));
    await tester.pump();

    expect(find.textContaining('Avg 98.40'), findsOneWidget);
    expect(find.text('5 BTC · 492.00 USD'), findsOneWidget);
    await gesture.removePointer();
  });

  testWidgets('rest depth bars fill the row height', (tester) async {
    await tester.pumpWidget(_surface(reduce: true));
    await tester.pump();
    final bar = tester.getSize(
      find.byKey(const ValueKey('beui-order-bar-ask-102.0')),
    );
    expect(bar.height, 30);
    expect(bar.width, greaterThan(80));
  });

  testWidgets('reduced-motion bars render and rest state matches golden', (
    tester,
  ) async {
    await tester.pumpWidget(_surface(reduce: true));
    await tester.pump();
    expect(find.byType(BeuiOrderBookBalance), findsOneWidget);
    await pumpFrames(tester, 10, frame: const Duration(milliseconds: 100));
    for (final entry in {
      'ask': [102.0, 101.0],
      'bid': [99.0, 98.0, 97.0],
    }.entries) {
      for (final price in entry.value) {
        final bar = find.byKey(ValueKey('beui-order-bar-${entry.key}-$price'));
        expect(tester.getSize(bar).width, greaterThan(80));
        expect(tester.getSize(bar).height, 30);
        expect(tester.widget<ColoredBox>(bar).color.a, greaterThan(0));
        expect(
          tester
              .widget<Opacity>(
                find.ancestor(of: bar, matching: find.byType(Opacity)).first,
              )
              .opacity,
          1,
          reason: 'All five cumulative depth fills must be visible.',
        );
      }
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/beui_order_book.png'),
    );
  });

  testWidgets('native price buttons inspect on Tab and ignore chart arrows', (
    tester,
  ) async {
    await tester.pumpWidget(_surface(onSelect: (_, _) {}));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.textContaining('Avg 101.60'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.textContaining('Avg 101.60'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.textContaining('Avg 101.00'), findsOneWidget);
  });
}
