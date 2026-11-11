import 'package:beui_example/explorer/catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support.dart';

const _suits = ['spades', 'hearts', 'clubs', 'diamonds'];
const _ranks = [
  'Ace',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  'Jack',
  'Queen',
  'King',
];

int _handCount(WidgetTester tester) => [
  for (final suit in _suits)
    for (final rank in _ranks)
      tester
          .widgetList<Semantics>(find.bySemanticsLabel('$rank of $suit'))
          .length,
].fold(0, (count, matches) => count + matches);

void main() {
  testWidgets('seeded cards and controls follow the source preview', (
    tester,
  ) async {
    final entry = kBlocks.singleWhere((entry) => entry.slug == 'card-dealer');
    expect(entry.title, 'Card Dealer');
    expect(entry.section, ExploreSection.blocks);
    await tester.pumpWidget(
      beuiTestApp(Builder(builder: entry.builder), width: 600),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    const firstHand = [
      '9 of spades',
      '4 of diamonds',
      'Ace of spades',
      '7 of diamonds',
      '7 of clubs',
    ];
    for (final label in firstHand) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    expect(_handCount(tester), 5);

    await tester.tap(find.text('Deal'));
    await tester.pumpAndSettle();
    expect(_handCount(tester), 6);
    expect(find.bySemanticsLabel('Deal 3'), findsOneWidget);
    await tester.tap(find.text('Deal 3'));
    await tester.pumpAndSettle();
    expect(_handCount(tester), 9);
    expect(find.bySemanticsLabel('Sort'), findsOneWidget);
    await tester.tap(find.text('Sort'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.bySemanticsLabel('Ace of spades')).dx,
      lessThan(tester.getTopLeft(find.bySemanticsLabel('4 of diamonds')).dx),
    );
    await tester.tap(find.text('Shuffle'));
    await tester.pumpAndSettle();
    expect(_handCount(tester), 9);

    await tester.tap(find.bySemanticsLabel('Ace of spades'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Ace of spades'), findsNothing);
    expect(_handCount(tester), 8);

    await tester.tap(find.text('Collect'));
    await tester.pumpAndSettle();
    expect(_handCount(tester), 0);
    for (final label in firstHand) {
      expect(find.bySemanticsLabel(label), findsNothing, reason: label);
    }
  });
}
