import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiPredictionMarket] — the source's
/// `prediction-market.preview.tsx` Yes/No market, controlled at $115.
Widget predictionMarketDemo(BuildContext context) => const _PredictionDemo();

class _PredictionDemo extends StatefulWidget {
  const _PredictionDemo();

  @override
  State<_PredictionDemo> createState() => _PredictionDemoState();
}

class _PredictionDemoState extends State<_PredictionDemo> {
  BeuiPredictionMarketOrder _order = const BeuiPredictionMarketOrder(
    mode: BeuiPredictionMarketMode.buy,
    outcomeId: 'yes',
    amount: '115',
  );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Center(
      child: BeuiPredictionMarket(
        outcomes: const [
          BeuiPredictionMarketOutcome(id: 'yes', label: 'Yes', price: 0.167),
          BeuiPredictionMarketOutcome(id: 'no', label: 'No', price: 0.834),
        ],
        value: _order,
        onValueChange: (next) => setState(() => _order = next),
        balance: 500,
        positions: const {'yes': 125, 'no': 48},
        quickAmounts: const [1, 5, 10, 100],
      ),
    ),
  );
}
