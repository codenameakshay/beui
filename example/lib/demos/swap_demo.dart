import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiMultiChainSwap] — the source's demo chains/tokens.
Widget swapDemo(BuildContext context) => const SingleChildScrollView(
  padding: EdgeInsets.symmetric(vertical: 24),
  child: Center(child: BeuiMultiChainSwap()),
);
