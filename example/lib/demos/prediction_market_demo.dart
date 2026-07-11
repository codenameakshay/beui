import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiPredictionMarket] — the source's Up/Down demo.
Widget predictionMarketDemo(BuildContext context) =>
    const SingleChildScrollView(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: BeuiPredictionMarket()),
    );
