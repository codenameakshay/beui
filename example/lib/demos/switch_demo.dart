import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiSwitch].
Widget switchDemo(BuildContext context) => const _SwitchDemo();

/// Exercises the switch's variants and states (the gallery doubles as visual QA).
class _SwitchDemo extends StatefulWidget {
  const _SwitchDemo();

  @override
  State<_SwitchDemo> createState() => _SwitchDemoState();
}

class _SwitchDemoState extends State<_SwitchDemo> {
  bool _notifications = true;
  bool _off = false;

  @override
  Widget build(BuildContext context) {
    // Mirrors SwitchPreview: `flex flex-col gap-3` (12px) with the three
    // labels the source ships.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BeuiSwitch(
          value: _notifications,
          label: 'Enable notifications',
          onChanged: (v) => setState(() => _notifications = v),
        ),
        const SizedBox(height: 12),
        BeuiSwitch(
          value: _off,
          label: 'Off',
          onChanged: (v) => setState(() => _off = v),
        ),
        const SizedBox(height: 12),
        BeuiSwitch(
          value: true,
          enabled: false,
          label: 'Disabled',
          onChanged: (_) {},
        ),
      ],
    );
  }
}
