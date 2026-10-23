import 'dart:ui' show Tristate;

import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _outcomes = [
  BeuiPredictionMarketCardOutcome(
    id: 'celtics',
    label: 'Celtics',
    probability: .51,
  ),
  BeuiPredictionMarketCardOutcome(
    id: 'lakers',
    label: 'Lakers',
    probability: .49,
  ),
];

Widget _app({
  bool? bookmarked,
  bool defaultBookmarked = false,
  ValueChanged<bool>? onBookmarkChange,
  ValueChanged<BeuiPredictionMarketCardSelection>? onOutcomeClick,
  bool reduce = false,
  bool live = false,
  String status = 'Sunday · 7:30 PM',
  double width = 460,
}) => beuiTestApp(
  BeuiPredictionMarketCard(
    title: 'Boston Celtics vs. Los Angeles Lakers',
    category: 'Basketball',
    status: status,
    live: live,
    volume: r'$2.4M',
    volumeHistory: const [12, 18, 15, 26, 20, 32, 29, 38, 34, 48, 43, 58],
    outcomes: _outcomes,
    bookmarked: bookmarked,
    defaultBookmarked: defaultBookmarked,
    onBookmarkChange: onBookmarkChange,
    onOutcomeClick: onOutcomeClick,
  ),
  reduce: reduce,
  width: width,
);

void main() {
  testWidgets('keyboard visits each payout and CTA only once', (tester) async {
    final selections = <BeuiPredictionMarketCardSelection>[];
    await tester.pumpWidget(_app(onOutcomeClick: selections.add));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.text('Yes'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.text('Yes'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selections.map((s) => (s.outcomeId, s.side)), [
      ('celtics', BeuiPredictionMarketCardSide.yes),
    ]);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.text('Yes'), findsNothing);
    expect(find.text('No'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.text('No'), findsOneWidget);
  });

  testWidgets('renders title, volume and outcomes', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.text('Boston Celtics vs. Los Angeles Lakers'), findsOneWidget);
    expect(find.text(r'$2.4M vol.'), findsOneWidget);
    expect(find.text('Celtics'), findsOneWidget);
    expect(find.text('Lakers'), findsOneWidget);
    expect(find.text('51%'), findsOneWidget);
    expect(find.text('49%'), findsOneWidget);
    expect(find.text('2.0×'), findsNWidgets(2));
    expect(find.text('Yes'), findsNothing);
    expect(find.text('No'), findsNothing);
    expect(find.text('LIVE'), findsNothing);
  });

  testWidgets('uncontrolled bookmark toggles and reports changes', (
    tester,
  ) async {
    final changes = <bool>[];
    await tester.pumpWidget(_app(onBookmarkChange: changes.add));
    await tester.tap(
      find.bySemanticsLabel('Bookmark Boston Celtics vs. Los Angeles Lakers'),
    );
    await tester.pump();
    expect(changes, [true]);
    expect(
      tester
          .getSemantics(
            find.bySemanticsLabel(
              'Bookmark Boston Celtics vs. Los Angeles Lakers',
            ),
          )
          .flagsCollection
          .isToggled,
      Tristate.isTrue,
    );
  });

  testWidgets('controlled bookmark reports change without changing its value', (
    tester,
  ) async {
    bool? next;
    await tester.pumpWidget(
      _app(bookmarked: false, onBookmarkChange: (v) => next = v),
    );
    await tester.tap(
      find.bySemanticsLabel('Bookmark Boston Celtics vs. Los Angeles Lakers'),
    );
    expect(next, isTrue);
    expect(
      tester
          .getSemantics(
            find.bySemanticsLabel(
              'Bookmark Boston Celtics vs. Los Angeles Lakers',
            ),
          )
          .flagsCollection
          .isToggled,
      Tristate.isFalse,
    );
  });

  testWidgets('each outcome CTA buys that outcome, independent of its color', (
    tester,
  ) async {
    final selections = <BeuiPredictionMarketCardSelection>[];
    await tester.pumpWidget(_app(onOutcomeClick: selections.add));
    await tester.tap(find.bySemanticsLabel('Trade Celtics at 51%'));
    await tester.tap(find.bySemanticsLabel('Trade Lakers at 49%'));
    expect(
      selections.map((selection) => (selection.outcomeId, selection.side)),
      [
        ('celtics', BeuiPredictionMarketCardSide.yes),
        ('lakers', BeuiPredictionMarketCardSide.yes),
      ],
    );
  });

  testWidgets('hover rolls percent into Yes on even and No on odd', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final yes = find.bySemanticsLabel('Trade Celtics at 51%');
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(yes));
    await gesture.moveTo(tester.getCenter(yes));
    await tester.pump();
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('No'), findsNothing);
    await gesture.removePointer();
    await tester.pump();

    final no = find.bySemanticsLabel('Trade Lakers at 49%');
    await gesture.addPointer(location: tester.getCenter(no));
    await gesture.moveTo(tester.getCenter(no));
    await tester.pump();
    expect(find.text('No'), findsOneWidget);
  });

  testWidgets('live status uses a rose dot instead of a LIVE badge', (
    tester,
  ) async {
    await tester.pumpWidget(_app(live: true, status: 'Mid 6th'));
    expect(find.text('LIVE'), findsNothing);
    expect(find.text('Mid 6th'), findsOneWidget);
  });

  testWidgets('reduced motion snaps labels without applying press movement', (
    tester,
  ) async {
    await tester.pumpWidget(_app(reduce: true));
    final button = find.text('51%');
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(button));
    await gesture.moveTo(tester.getCenter(button));
    await tester.pump();
    expect(find.text('Yes'), findsOneWidget);
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(_app(width: 420));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiPredictionMarketCard),
      matchesGoldenFile('goldens/beui_prediction_market_card.png'),
    );
  });
}
