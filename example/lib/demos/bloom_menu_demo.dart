import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiBloomMenu] — the "Create" pill blooms into a grid
/// create-menu with a center-out iris reveal.
Widget bloomMenuDemo(BuildContext context) => const _BloomMenuDemo();

class _BloomMenuDemo extends StatefulWidget {
  const _BloomMenuDemo();

  @override
  State<_BloomMenuDemo> createState() => _BloomMenuDemoState();
}

class _BloomMenuDemoState extends State<_BloomMenuDemo> {
  String? _last;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 120),
          BeuiBloomMenu(onSelect: (label) => setState(() => _last = label)),
          const SizedBox(height: 160),
          Text(
            _last == null ? 'Pick an item…' : 'Created: $_last',
            style: TextStyle(fontSize: 13, color: colors.mutedForeground),
          ),
        ],
      ),
    );
  }
}
