import 'package:flutter/material.dart';

/// A composable modal whose full-size surface unfolds from its exact center
/// toward every edge, then folds back the same way with an inset close control.
///
/// Scaffold — port of the source `beui.dev/r/center-morph-modal` entry;
/// implementation pending. See docs/PORTING_SPEC.md §4.
class BeuiCenterMorphModal extends StatelessWidget {
  const BeuiCenterMorphModal({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('BeuiCenterMorphModal — not yet ported'),
    );
  }
}
