import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

class _TestCard implements BeuiCardDealerCard {
  const _TestCard(this.id, this.zone, this.label);

  @override
  final String id;

  @override
  final BeuiCardDealerZone zone;

  @override
  final String label;
}

class _MountProbe extends StatefulWidget {
  const _MountProbe({required this.card, required this.onMount});

  final _TestCard card;
  final VoidCallback onMount;

  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Text(widget.card.id, key: ValueKey('face-${widget.card.id}')),
  );
}

Widget _app(
  List<_TestCard> cards, {
  double width = 400,
  bool reduce = false,
  ValueChanged<String>? onSelect,
  double spread = 46,
  double angle = 0,
  Widget Function(_TestCard)? renderFace,
}) => beuiTestApp(
  SizedBox(
    key: const ValueKey('table-bound'),
    width: width,
    child: BeuiCardDealer<_TestCard>(
      cards: cards,
      renderFace:
          renderFace ??
          (card) =>
              Center(child: Text(card.id, key: ValueKey('face-${card.id}'))),
      renderBack: (card) => Center(child: Text('back-${card.id}')),
      onCardSelect: onSelect,
      spread: spread,
      angle: angle,
      semanticLabel: 'Test card table',
    ),
  ),
  width: width,
  reduce: reduce,
);

Offset _relativeTopLeft(WidgetTester tester, String cardId) =>
    tester.getTopLeft(find.byKey(ValueKey('card-frame-$cardId'))) -
    tester.getTopLeft(find.byKey(const ValueKey('table-bound')));

double _faceAngle(WidgetTester tester, String cardId) {
  final transform = tester.widget<Transform>(
    find.byKey(ValueKey('card-face-turn-$cardId')),
  );
  return math.atan2(
    transform.transform.storage[8],
    transform.transform.storage[0],
  );
}

void _expectArcPosition(
  Offset actual,
  Offset from,
  Offset to,
  double strength,
) {
  final dx = to.dx - from.dx;
  final dy = to.dy - from.dy;
  final distance = math.sqrt(dx * dx + dy * dy);
  final t =
      ((actual.dx - from.dx) * dx + (actual.dy - from.dy) * dy) /
      (distance * distance);
  final dominant = dx.abs() >= dy.abs() ? dx : dy;
  final signedStrength = dominant < 0 ? -strength : strength;
  final expected = Offset(
    from.dx +
        t * dx +
        2 * t * (1 - t) * -dy / distance * signedStrength * distance,
    from.dy +
        t * dy +
        2 * t * (1 - t) * dx / distance * signedStrength * distance,
  );
  expect(actual.dx, closeTo(expected.dx, 0.02));
  expect(actual.dy, closeTo(expected.dy, 0.02));
}

const _threeHandCards = [
  _TestCard('a', BeuiCardDealerZone.hand, 'Ace of spades'),
  _TestCard('b', BeuiCardDealerZone.hand, 'Two of spades'),
  _TestCard('c', BeuiCardDealerZone.hand, 'Three of spades'),
];

void main() {
  testWidgets('lays out the centered fan with source size and spread bounds', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_threeHandCards));

    expect(_relativeTopLeft(tester, 'a').dx, closeTo(112, 0.01));
    expect(_relativeTopLeft(tester, 'b').dx, closeTo(158, 0.01));
    expect(_relativeTopLeft(tester, 'c').dx, closeTo(204, 0.01));
    expect(_relativeTopLeft(tester, 'a').dy, closeTo(186.2, 0.01));
    expect(
      tester.getSize(find.byKey(const ValueKey('card-frame-b'))),
      const Size(84, 120),
    );

    await tester.pumpWidget(_app(_threeHandCards, width: 120));
    expect(_relativeTopLeft(tester, 'a').dx, closeTo(16, 0.01));
    expect(_relativeTopLeft(tester, 'b').dx, closeTo(18, 0.01));
    expect(_relativeTopLeft(tester, 'c').dx, closeTo(20, 0.01));
  });

  testWidgets(
    'keeps card faces mounted and selects only accessible hand cards',
    (tester) async {
      final selected = <String>[];
      final cards = [
        const _TestCard('deck', BeuiCardDealerZone.deck, 'Deck card'),
        const _TestCard('hand', BeuiCardDealerZone.hand, 'Ace of spades'),
        const _TestCard('pile', BeuiCardDealerZone.pile, 'Played card'),
      ];
      await tester.pumpWidget(_app(cards, onSelect: selected.add));

      expect(find.byKey(const ValueKey('face-deck')), findsOneWidget);
      expect(find.byKey(const ValueKey('face-hand')), findsOneWidget);
      expect(find.byKey(const ValueKey('face-pile')), findsOneWidget);
      expect(find.bySemanticsLabel('Ace of spades'), findsOneWidget);
      expect(find.bySemanticsLabel('Deck card'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Ace of spades'));
      expect(selected, ['hand']);
      expect(find.bySemanticsLabel('Ace of spades'), findsOneWidget);
    },
  );

  testWidgets('hand card buttons activate from keyboard focus', (tester) async {
    final selected = <String>[];
    await tester.pumpWidget(_app(_threeHandCards, onSelect: selected.add));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(_relativeTopLeft(tester, 'a').dy, closeTo(168.2, 0.01));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(selected, ['a']);
  });

  testWidgets(
    'zone changes arc and flip in flight, then land at the new pose',
    (tester) async {
      const deck = [
        _TestCard('moving', BeuiCardDealerZone.deck, 'Moving card'),
      ];
      const hand = [
        _TestCard('moving', BeuiCardDealerZone.hand, 'Moving card'),
      ];
      var faceMounts = 0;
      Widget face(_TestCard card) =>
          _MountProbe(card: card, onMount: () => faceMounts++);
      await tester.pumpWidget(_app(deck, renderFace: face));
      final frame = find.byKey(const ValueKey('card-frame-moving'));
      final origin =
          tester.getTopLeft(frame) -
          tester.getTopLeft(find.byKey(const ValueKey('table-bound')));
      expect(origin, const Offset(16, 16));

      await tester.pumpWidget(_app(hand, renderFace: face));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final current =
          tester.getTopLeft(frame) -
          tester.getTopLeft(find.byKey(const ValueKey('table-bound')));
      _expectArcPosition(
        current,
        const Offset(16, 16),
        const Offset(158, 184),
        -0.35,
      );
      // Pinned motion-dom 12.43 spring and arc sampled at 120 ms.
      expect(current.dx, closeTo(91.99815263759902, 0.15));
      expect(current.dy, closeTo(51.83245105368256, 0.15));
      expect(find.byKey(const ValueKey('face-moving')), findsOneWidget);
      expect(faceMounts, 1);

      await tester.pumpAndSettle();
      final landed =
          tester.getTopLeft(frame) -
          tester.getTopLeft(find.byKey(const ValueKey('table-bound')));
      expect(landed.dx, closeTo(158, 0.01));
      expect(landed.dy, closeTo(184, 0.01));
    },
  );

  testWidgets('hand reorder hops cards into their new fan slots', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_threeHandCards));
    final initial = _relativeTopLeft(tester, 'a');
    await tester.pumpWidget(_app(_threeHandCards.reversed.toList()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final inFlight = _relativeTopLeft(tester, 'a');
    expect(inFlight.dx, greaterThan(initial.dx));
    expect(inFlight.dx, lessThan(204));
    _expectArcPosition(inFlight, initial, const Offset(204, 186.2), -0.3);
    // Pinned motion-dom 12.43 HOP spring and arc sampled at 100 ms.
    expect(inFlight.dx, closeTo(150.7330909004355, 0.15));
    expect(inFlight.dy, closeTo(172.74439979039997, 0.15));

    await tester.pumpAndSettle();
    final landed = _relativeTopLeft(tester, 'a');
    expect(landed.dx, closeTo(204, 0.01));
    expect(landed.dy, closeTo(186.2, 0.01));
  });

  testWidgets(
    'an unrelated rebuild keeps the active flight path and controller',
    (tester) async {
      const deck = [
        _TestCard('moving', BeuiCardDealerZone.deck, 'Moving card'),
      ];
      const hand = [
        _TestCard('moving', BeuiCardDealerZone.hand, 'Moving card'),
      ];
      await tester.pumpWidget(_app(deck));
      await tester.pumpWidget(_app(hand));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpWidget(_app(hand));
      await tester.pump(const Duration(milliseconds: 100));

      _expectArcPosition(
        _relativeTopLeft(tester, 'moving'),
        const Offset(16, 16),
        const Offset(158, 184),
        -0.35,
      );
    },
  );

  testWidgets('reduced motion snaps a controlled zone update to its target', (
    tester,
  ) async {
    const deck = [_TestCard('moving', BeuiCardDealerZone.deck, 'Moving card')];
    const hand = [_TestCard('moving', BeuiCardDealerZone.hand, 'Moving card')];
    await tester.pumpWidget(_app(deck, reduce: true));
    await tester.pumpWidget(_app(hand, reduce: true));
    await tester.pump();

    final landed = _relativeTopLeft(tester, 'moving');
    expect(landed.dx, closeTo(158, 0.01));
    expect(landed.dy, closeTo(184, 0.01));
    expect(_faceAngle(tester, 'moving'), closeTo(0, 0.01));
  });

  testWidgets('hover lifts one hand card and pushes its neighbors', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_threeHandCards, onSelect: (_) {}));
    final beforeCenter = _relativeTopLeft(tester, 'b');
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      pointer.hover(
        tester.getTopLeft(find.byKey(const ValueKey('card-frame-b'))) +
            const Offset(10, 60),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    _expectArcPosition(
      _relativeTopLeft(tester, 'b'),
      beforeCenter,
      const Offset(158, 166),
      0,
    );
    await tester.pumpAndSettle();

    expect(_relativeTopLeft(tester, 'b').dy, lessThan(beforeCenter.dy));
    expect(_relativeTopLeft(tester, 'a').dx, lessThan(112));
    expect(_relativeTopLeft(tester, 'c').dx, greaterThan(204));
  });

  testWidgets('a staggered frame still starts its face turn immediately', (
    tester,
  ) async {
    const deck = [
      _TestCard('a', BeuiCardDealerZone.deck, 'Card A'),
      _TestCard('b', BeuiCardDealerZone.deck, 'Card B'),
    ];
    const hand = [
      _TestCard('a', BeuiCardDealerZone.hand, 'Card A'),
      _TestCard('b', BeuiCardDealerZone.hand, 'Card B'),
    ];
    await tester.pumpWidget(_app(deck));
    await tester.pumpWidget(_app(hand));
    await tester.pump(const Duration(milliseconds: 16));

    expect(_relativeTopLeft(tester, 'b').dx, closeTo(15.4, 0.01));
    expect(_relativeTopLeft(tester, 'b').dy, closeTo(15.4, 0.01));
    expect(_faceAngle(tester, 'b'), lessThan(math.pi));
    expect(_faceAngle(tester, 'b'), greaterThan(0));
  });

  testWidgets(
    'an interrupted flight and face turn continue from painted values',
    (tester) async {
      const deck = [
        _TestCard('moving', BeuiCardDealerZone.deck, 'Moving card'),
      ];
      const hand = [
        _TestCard('moving', BeuiCardDealerZone.hand, 'Moving card'),
      ];
      await tester.pumpWidget(_app(deck));
      await tester.pumpWidget(_app(hand));
      await tester.pump(const Duration(milliseconds: 80));
      final interruptedPosition = _relativeTopLeft(tester, 'moving');
      final interruptedAngle = _faceAngle(tester, 'moving');
      expect(interruptedPosition, isNot(const Offset(16, 16)));
      expect(interruptedAngle, inInclusiveRange(0, math.pi));

      await tester.pumpWidget(_app(deck));
      expect(_relativeTopLeft(tester, 'moving'), interruptedPosition);
      expect(_faceAngle(tester, 'moving'), closeTo(interruptedAngle, 0.01));
      await tester.pumpAndSettle();

      expect(_relativeTopLeft(tester, 'moving'), const Offset(16, 16));
      expect(_faceAngle(tester, 'moving'), closeTo(math.pi, 0.01));
    },
  );

  testWidgets('a newer move cancels an older delayed endpoint', (tester) async {
    const deck = [
      _TestCard('a', BeuiCardDealerZone.deck, 'Card A'),
      _TestCard('b', BeuiCardDealerZone.deck, 'Card B'),
    ];
    const hand = [
      _TestCard('a', BeuiCardDealerZone.hand, 'Card A'),
      _TestCard('b', BeuiCardDealerZone.hand, 'Card B'),
    ];
    const pile = [
      _TestCard('b', BeuiCardDealerZone.pile, 'Card B'),
      _TestCard('a', BeuiCardDealerZone.hand, 'Card A'),
    ];
    await tester.pumpWidget(_app(deck));
    await tester.pumpWidget(_app(hand));
    await tester.pump(const Duration(milliseconds: 16));
    final beforeSupersession = _relativeTopLeft(tester, 'b');
    expect(beforeSupersession.dx, closeTo(15.4, 0.01));

    await tester.pumpWidget(_app(pile));
    await tester.pump(const Duration(milliseconds: 100));
    final current = _relativeTopLeft(tester, 'b');
    expect(current.dx, greaterThan(beforeSupersession.dx));
    expect(current.dx, lessThan(316));
    await tester.pumpAndSettle();
    final center =
        tester.getCenter(find.byKey(const ValueKey('card-frame-b'))) -
        tester.getTopLeft(find.byKey(const ValueKey('table-bound')));
    expect(center, const Offset(342, 76));
  });

  testWidgets(
    'resizing snaps the frame but leaves the face transition running',
    (tester) async {
      const deck = [
        _TestCard('moving', BeuiCardDealerZone.deck, 'Moving card'),
      ];
      const hand = [
        _TestCard('moving', BeuiCardDealerZone.hand, 'Moving card'),
      ];
      await tester.pumpWidget(_app(deck));
      await tester.pumpWidget(_app(hand));
      await tester.pump(const Duration(milliseconds: 80));
      final faceBeforeResize = _faceAngle(tester, 'moving');

      await tester.pumpWidget(_app(hand, width: 120));

      expect(_relativeTopLeft(tester, 'moving').dx, closeTo(18, 0.01));
      expect(_faceAngle(tester, 'moving'), closeTo(faceBeforeResize, 0.01));
      expect(_faceAngle(tester, 'moving'), greaterThan(0));
    },
  );

  testWidgets(
    'the fan keeps source spacing when its bounds are narrower than a card',
    (tester) async {
      await tester.pumpWidget(_app(_threeHandCards, width: 84));

      expect(_relativeTopLeft(tester, 'a').dx, closeTo(16, 0.01));
      expect(_relativeTopLeft(tester, 'b').dx, closeTo(0, 0.01));
      expect(_relativeTopLeft(tester, 'c').dx, closeTo(-16, 0.01));
    },
  );

  testWidgets('custom card backs keep their own front-facing orientation', (
    tester,
  ) async {
    const deck = [_TestCard('custom', BeuiCardDealerZone.deck, 'Custom card')];
    await tester.pumpWidget(
      beuiTestApp(
        SizedBox(
          width: 400,
          child: BeuiCardDealer<_TestCard>(
            cards: deck,
            renderFace: (_) => const Text('face'),
            renderBack: (_) => const Text('asymmetric back'),
          ),
        ),
      ),
    );

    final orientation = tester.widget<Transform>(
      find.byKey(const ValueKey('card-back-orientation-custom')),
    );
    expect(orientation.transform.storage[0], closeTo(-1, 0.01));
  });

  testWidgets('disposing the table cancels motion tickers', (tester) async {
    const deck = [_TestCard('moving', BeuiCardDealerZone.deck, 'Moving card')];
    const hand = [_TestCard('moving', BeuiCardDealerZone.hand, 'Moving card')];
    await tester.pumpWidget(_app(deck));
    await tester.pumpWidget(_app(hand));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
  });
}
