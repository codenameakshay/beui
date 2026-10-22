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
      await tester.tap(find.bySemanticsLabel(RegExp('bid, 98.00')));
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

  testWidgets('reduced-motion bars render and rest state matches golden', (
    tester,
  ) async {
    await tester.pumpWidget(_surface(reduce: true));
    await tester.pump();
    expect(find.byType(BeuiOrderBookBalance), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/beui_order_book.png'),
    );
  });

  testWidgets('keyboard Home and Escape inspect and clear levels', (
    tester,
  ) async {
    await tester.pumpWidget(_surface());
    await tester.tap(find.bySemanticsLabel(RegExp('bid, 98.00')));
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(find.textContaining('Avg 99.00'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Hover a level to inspect depth'), findsOneWidget);
  });
}
