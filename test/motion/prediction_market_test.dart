import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = SingleChildScrollView(
    child: Center(child: SizedBox(width: 400, child: child)),
  );
  if (reduce) {
    final inner = body;
    body = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: body),
  );
}

const _outcomes = [
  BeuiPredictionMarketOutcome(id: 'yes', label: 'Yes', price: 0.5),
  BeuiPredictionMarketOutcome(id: 'no', label: 'No', price: 0.25),
];

Widget _market({
  bool reduce = false,
  bool authenticated = true,
  VoidCallback? onSignIn,
  void Function(BeuiPredictionMarketOrder, BeuiPredictionMarketQuote)? onTrade,
}) => _wrap(
  BeuiPredictionMarket(
    outcomes: _outcomes,
    balance: 500,
    positions: const {'yes': 24, 'no': 16},
    authenticated: authenticated,
    onSignIn: onSignIn,
    onTrade: onTrade,
  ),
  reduce: reduce,
);

void main() {
  group('BeuiPredictionMarket', () {
    testWidgets('renders modes, outcome prices, amount and footer', (
      tester,
    ) async {
      await tester.pumpWidget(_market());
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Buy'), findsOneWidget);
      expect(find.text('Sell'), findsOneWidget);
      expect(find.text('Yes 50¢'), findsOneWidget);
      expect(find.text('No 25¢'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('To win'), findsOneWidget);
      expect(find.text('Avg. Price 50¢'), findsOneWidget);
      // Empty amount → the stateful button surfaces the error label
      // immediately (source derives state from the live quote).
      expect(find.text('Enter an amount'), findsOneWidget);
    });

    testWidgets('typing an amount rolls digits in and quotes the payout', (
      tester,
    ) async {
      await tester.pumpWidget(_market());
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(EditableText).first, '50');
      await tester.pump(const Duration(milliseconds: 400));
      // Rendered char slots (the hidden input is transparent).
      expect(find.text('5'), findsWidgets);
      // Buy: 50 / 0.5 = 100 shares → payout $100.00 via the ticker.
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.textContaining('100'), findsWidgets);
    });

    testWidgets('quick chips add and Max fills the balance', (tester) async {
      await tester.pumpWidget(_market());
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('+\$10'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('+\$50'));
      await tester.pump(const Duration(milliseconds: 300));
      // 0 + 10 + 50 = 60 → chars 6 and 0 rendered.
      expect(find.text('6'), findsWidgets);

      await tester.tap(find.text('Max'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('5'), findsWidgets); // 500 balance
    });

    testWidgets('sell mode clears the amount and relabels', (tester) async {
      await tester.pumpWidget(_market());
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Sell'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Shares'), findsOneWidget);
      expect(find.text('To receive'), findsOneWidget);
    });

    testWidgets('selecting an outcome updates the average price', (
      tester,
    ) async {
      await tester.pumpWidget(_market());
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('No 25¢'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Avg. Price 25¢'), findsOneWidget);
    });

    testWidgets('invalid submit shakes and surfaces the error state', (
      tester,
    ) async {
      await tester.pumpWidget(_market());
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.byType(BeuiStatefulButton));
      await tester.pump();
      await tester.tap(find.byType(BeuiStatefulButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60)); // mid-shake
      final xs = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(BeuiPredictionMarket),
              matching: find.byType(Transform),
            ),
          )
          .map((t) => t.transform.getTranslation().x.abs())
          .fold<double>(0, math.max);
      expect(xs, greaterThan(0.5));
      await tester.pumpAndSettle();
      expect(find.text('Enter an amount'), findsOneWidget);
    });

    testWidgets('a valid trade goes placing → filled and reports', (
      tester,
    ) async {
      BeuiPredictionMarketOrder? tradedOrder;
      BeuiPredictionMarketQuote? tradedQuote;
      await tester.pumpWidget(
        _market(
          onTrade: (order, quote) {
            tradedOrder = order;
            tradedQuote = quote;
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(EditableText).first, '50');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.byType(BeuiStatefulButton));
      await tester.pump();
      await tester.tap(find.byType(BeuiStatefulButton));
      await tester.pump();
      // The stateful button cascades letters (540ms for 'Trading'); assert
      // once settled but before the 650ms fill timer.
      const afterCascadeSettles = Duration(milliseconds: 600);
      const pastFillTimer = Duration(milliseconds: 100); // fill at 650ms
      const filledCascadeSettles = Duration(milliseconds: 800);
      await tester.pump(afterCascadeSettles);
      expect(find.text('Trading'), findsOneWidget);
      await tester.pump(pastFillTimer);
      await tester.pump(filledCascadeSettles);
      expect(find.text('Trade filled'), findsOneWidget);
      expect(tradedOrder?.amount, '50');
      expect(tradedQuote?.payout, moreOrLessEquals(100, epsilon: 0.01));
      await tester.pumpAndSettle();
    });

    testWidgets('unauthenticated shows Connect and calls onSignIn', (
      tester,
    ) async {
      var signIns = 0;
      await tester.pumpWidget(
        _market(authenticated: false, onSignIn: () => signIns++),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Connect'), findsOneWidget);
      expect(find.text('To win'), findsNothing);
      await tester.tap(find.text('Connect'));
      await tester.pump();
      expect(signIns, 1);
    });

    testWidgets('Connect button is 56px tall (source h-14)', (tester) async {
      await tester.pumpWidget(_market(authenticated: false));
      await tester.pump(const Duration(milliseconds: 400));
      // Source: unauthenticated Connect is `h-14` (56px), not the `lg` 48px.
      expect(tester.getSize(find.byType(BeuiStatefulButton)).height, 56);
    });

    testWidgets('authenticated Trade button stays 48px (source h-12)', (
      tester,
    ) async {
      await tester.pumpWidget(_market());
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.getSize(find.byType(BeuiStatefulButton)).height, 48);
    });

    testWidgets('outcome pill glides to the selected cell', (tester) async {
      await tester.pumpWidget(_market());
      await tester.pumpAndSettle();
      final pill = find.byKey(
        const ValueKey<String>('beui_prediction_market_pill'),
      );
      expect(pill, findsOneWidget);
      // A single fully-rounded pill sits over the selected (first) cell.
      final before = tester.getRect(pill);
      expect(before.height, 56); // h-14
      // Select the second outcome → the shared pill glides right.
      await tester.tap(find.text('No 25¢'));
      // Mid-flight: the spring has not settled to the target yet.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final midway = tester.getRect(pill);
      await tester.pumpAndSettle();
      final after = tester.getRect(pill);
      expect(after.left, greaterThan(before.left)); // moved to cell 2
      expect(midway.left, lessThan(after.left)); // was still travelling
    });

    testWidgets('reduced motion still moves the outcome pill', (tester) async {
      await tester.pumpWidget(_market(reduce: true));
      await tester.pumpAndSettle();
      final pill = find.byKey(
        const ValueKey<String>('beui_prediction_market_pill'),
      );
      final before = tester.getRect(pill);
      await tester.tap(find.text('No 25¢'));
      await tester.pumpAndSettle(); // NoMotion → target, no spring flight
      final after = tester.getRect(pill);
      expect(after.left, greaterThan(before.left));
    });

    testWidgets('reduced motion types without blur', (tester) async {
      await tester.pumpWidget(_market(reduce: true));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(EditableText).first, '7');
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(maxBlurSigma(tester), lessThan(0.5));
      }
    });
  });
}
