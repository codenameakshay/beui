import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Preview for the order book.
Widget orderBookDemo(BuildContext context) => const _OrderBookDemo();

class _OrderBookDemo extends StatelessWidget {
  const _OrderBookDemo();

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 672),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: BeuiOrderBook(
          bids: [
            BeuiOrderBookLevel(price: 245.70, size: 194),
            BeuiOrderBookLevel(price: 245.55, size: 543),
            BeuiOrderBookLevel(price: 245.40, size: 314),
            BeuiOrderBookLevel(price: 245.25, size: 592),
            BeuiOrderBookLevel(price: 245.10, size: 715),
            BeuiOrderBookLevel(price: 244.95, size: 744),
            BeuiOrderBookLevel(price: 244.80, size: 789),
            BeuiOrderBookLevel(price: 244.65, size: 735),
            BeuiOrderBookLevel(price: 244.50, size: 1100),
          ],
          asks: [
            BeuiOrderBookLevel(price: 246.00, size: 284),
            BeuiOrderBookLevel(price: 246.15, size: 574),
            BeuiOrderBookLevel(price: 246.30, size: 363),
            BeuiOrderBookLevel(price: 246.45, size: 278),
            BeuiOrderBookLevel(price: 246.60, size: 1800),
            BeuiOrderBookLevel(price: 246.75, size: 2200),
            BeuiOrderBookLevel(price: 246.90, size: 1100),
            BeuiOrderBookLevel(price: 247.05, size: 1200),
            BeuiOrderBookLevel(price: 247.20, size: 782),
          ],
          baseSymbol: 'SOL',
          quoteSymbol: 'USD',
          label: 'Simulated SOL / USD order book',
          child: Column(
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
  );
}
