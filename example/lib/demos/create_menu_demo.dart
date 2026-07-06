import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiCreateMenu] — tap Create to bloom the grid.
Widget createMenuDemo(BuildContext context) => const _CreateMenuDemo();

class _CreateMenuDemo extends StatefulWidget {
  const _CreateMenuDemo();

  @override
  State<_CreateMenuDemo> createState() => _CreateMenuDemoState();
}

class _CreateMenuDemoState extends State<_CreateMenuDemo> {
  String _last = '—';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BeuiCreateMenu(onSelect: (label) => setState(() => _last = label)),
          const SizedBox(height: 160), // room for the bloom
          Text(
            'Created: $_last',
            style: TextStyle(color: colors.mutedForeground, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
