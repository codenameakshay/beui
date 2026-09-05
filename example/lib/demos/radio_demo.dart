import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiRadioGroup].
Widget radioDemo(BuildContext context) => const _RadioDemo();

/// Exercises the radio group's gliding selection dot.
class _RadioDemo extends StatefulWidget {
  const _RadioDemo();

  @override
  State<_RadioDemo> createState() => _RadioDemoState();
}

class _RadioDemoState extends State<_RadioDemo> {
  String _plan = 'pro';

  @override
  Widget build(BuildContext context) {
    // Mirrors RadioPreview: the group carries `min-w-48` (192px).
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 192),
      child: BeuiRadioGroup<String>(
        value: _plan,
        onChanged: (v) => setState(() => _plan = v),
        items: const [
          BeuiRadioItem(value: 'starter', label: 'Starter — free'),
          BeuiRadioItem(value: 'pro', label: 'Pro — \$12/mo'),
          BeuiRadioItem(value: 'team', label: 'Team — \$29/mo'),
          BeuiRadioItem(value: 'legacy', label: 'Legacy plan', enabled: false),
        ],
      ),
    );
  }
}
