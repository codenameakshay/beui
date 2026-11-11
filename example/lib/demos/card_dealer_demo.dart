import 'dart:async';
import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for the source's seeded 52-card Card Dealer preview.
Widget cardDealerDemo(BuildContext context) => const _CardDealerDemo();

const _suits = <(String, String, bool)>[
  ('spades', '♠', false),
  ('hearts', '♥', true),
  ('clubs', '♣', false),
  ('diamonds', '♦', true),
];
const _ranks = <String>[
  'A',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  'J',
  'Q',
  'K',
];
const _rankNames = <String, String>{
  'A': 'Ace',
  'J': 'Jack',
  'Q': 'Queen',
  'K': 'King',
};
const _handLimit = 13;

class _PlayingCard implements BeuiCardDealerCard {
  const _PlayingCard({
    required this.rank,
    required this.suit,
    required this.zone,
  });

  final int rank;
  final int suit;

  @override
  final BeuiCardDealerZone zone;

  @override
  String get id => '${_ranks[rank]}-${_suits[suit].$1}';

  @override
  String get label =>
      '${_rankNames[_ranks[rank]] ?? _ranks[rank]} of ${_suits[suit].$1}';

  _PlayingCard inZone(BeuiCardDealerZone next) =>
      _PlayingCard(rank: rank, suit: suit, zone: next);
}

List<T> _shuffle<T>(List<T> items, int seed) {
  final output = [...items];
  var state = seed.toDouble();
  for (var i = output.length - 1; i > 0; i--) {
    // Keep JavaScript Number arithmetic. Dart's integer multiplication would
    // produce a different seeded order for this source preview.
    state = (state * 1103515245 + 12345) % 2147483648;
    final j = (state % (i + 1)).toInt();
    final card = output[i];
    output[i] = output[j];
    output[j] = card;
  }
  return output;
}

List<_PlayingCard> _createDeck() => _shuffle([
  for (var suit = 0; suit < _suits.length; suit++)
    for (var rank = 0; rank < _ranks.length; rank++)
      _PlayingCard(rank: rank, suit: suit, zone: BeuiCardDealerZone.deck),
], 7);

List<_PlayingCard> _moveTo(
  List<_PlayingCard> cards,
  List<String> ids,
  BeuiCardDealerZone zone,
) {
  final moving = ids.toSet();
  final picked = [
    for (final id in ids)
      for (final card in cards)
        if (card.id == id) card.inZone(zone),
  ];
  return [...cards.where((card) => !moving.contains(card.id)), ...picked];
}

class _CardDealerDemo extends StatefulWidget {
  const _CardDealerDemo();

  @override
  State<_CardDealerDemo> createState() => _CardDealerDemoState();
}

class _CardDealerDemoState extends State<_CardDealerDemo> {
  late List<_PlayingCard> _cards = _createDeck();
  Timer? _initialDeal;

  List<_PlayingCard> get _deck =>
      _cards.where((card) => card.zone == BeuiCardDealerZone.deck).toList();
  List<_PlayingCard> get _hand =>
      _cards.where((card) => card.zone == BeuiCardDealerZone.hand).toList();

  @override
  void initState() {
    super.initState();
    _initialDeal = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        final top = _deck.reversed.take(5).map((card) => card.id).toList();
        _cards = _moveTo(_cards, top, BeuiCardDealerZone.hand);
      });
    });
  }

  @override
  void dispose() {
    _initialDeal?.cancel();
    super.dispose();
  }

  void _deal(int count) {
    setState(() {
      final room = math.max(0, _handLimit - _hand.length);
      final amount = math.min(count, room);
      final top = _deck.reversed.take(amount).map((card) => card.id).toList();
      if (top.isNotEmpty) {
        _cards = _moveTo(_cards, top, BeuiCardDealerZone.hand);
      }
    });
  }

  void _sort() {
    setState(() {
      final ids = [..._hand]
        ..sort((a, b) {
          final suitOrder = a.suit.compareTo(b.suit);
          return suitOrder == 0 ? a.rank.compareTo(b.rank) : suitOrder;
        });
      _cards = _moveTo(
        _cards,
        ids.map((card) => card.id).toList(),
        BeuiCardDealerZone.hand,
      );
    });
  }

  void _shuffleHand() {
    setState(() {
      final ids = _shuffle(
        _hand.map((card) => card.id).toList(),
        DateTime.now().millisecondsSinceEpoch % 2147483647,
      );
      _cards = _moveTo(_cards, ids, BeuiCardDealerZone.hand);
    });
  }

  void _collect() {
    setState(() {
      final ids = _shuffle(
        _cards
            .where((card) => card.zone != BeuiCardDealerZone.deck)
            .map((card) => card.id)
            .toList(),
        DateTime.now().millisecondsSinceEpoch % 2147483647,
      );
      _cards = _moveTo(_cards, ids, BeuiCardDealerZone.deck);
    });
  }

  @override
  Widget build(BuildContext context) {
    final deck = _deck;
    final hand = _hand;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 576),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiCardDealer<_PlayingCard>(
                cards: _cards,
                renderFace: (card) => _CardFace(card: card),
                renderBack: (_) => const _CardBack(),
                onCardSelect: (id) => setState(() {
                  _cards = _moveTo(_cards, [id], BeuiCardDealerZone.pile);
                }),
                semanticLabel:
                    'Card table. Select a card in your hand to play it.',
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: deck.isEmpty || hand.length >= _handLimit
                        ? null
                        : () => _deal(1),
                    child: const Text('Deal'),
                  ),
                  FilledButton(
                    onPressed: deck.isEmpty || hand.length >= _handLimit
                        ? null
                        : () => _deal(3),
                    child: const Text('Deal 3'),
                  ),
                  OutlinedButton(
                    onPressed: hand.length < 2 ? null : _sort,
                    child: const Text('Sort'),
                  ),
                  OutlinedButton(
                    onPressed: hand.length < 2 ? null : _shuffleHand,
                    child: const Text('Shuffle'),
                  ),
                  OutlinedButton(
                    onPressed: deck.length == _cards.length ? null : _collect,
                    child: const Text('Collect'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.card});

  final _PlayingCard card;

  @override
  Widget build(BuildContext context) {
    final suit = _suits[card.suit];
    final rank = _ranks[card.rank];
    final color = suit.$3 ? const Color(0xFFF43F5E) : const Color(0xFF171717);
    final pip = TextStyle(
      fontSize: 14,
      height: 1,
      fontWeight: FontWeight.w600,
      color: color,
    );
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rank, style: pip),
                Text(suit.$2, style: pip.copyWith(fontSize: 12)),
              ],
            ),
          ),
          Text(
            suit.$2,
            style: TextStyle(fontSize: 30, height: 1, color: color),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Transform.rotate(
              angle: math.pi,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rank, style: pip),
                  Text(suit.$2, style: pip.copyWith(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: const Color(0xFF262626),
      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: _DemoCardBackStripePainter(
          Colors.white.withValues(alpha: 0.12),
        ),
      ),
    ),
  );
}

class _DemoCardBackStripePainter extends CustomPainter {
  const _DemoCardBackStripePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var x = -size.height; x < size.width; x += 10) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint..strokeWidth = 5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DemoCardBackStripePainter oldDelegate) =>
      oldDelegate.color != color;
}
