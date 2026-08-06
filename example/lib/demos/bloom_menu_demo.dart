import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiBloomMenu] — the "Create" pill blooms into a grid
/// create-menu with a center-out iris reveal.
Widget bloomMenuDemo(BuildContext context) => const _BloomMenuDemo();

class _BloomMenuDemo extends StatelessWidget {
  const _BloomMenuDemo();

  // Source wrapper: `min-h-[420px] w-full items-start justify-center pt-24`.
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 420),
    child: const Padding(
      padding: EdgeInsets.only(top: 96), // pt-24
      child: Align(alignment: Alignment.topCenter, child: BeuiBloomMenu()),
    ),
  );
}
