import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiCheckbox].
Widget checkboxDemo(BuildContext context) => const _CheckboxDemo();

/// Exercises the checkbox's states, including indeterminate and disabled.
class _CheckboxDemo extends StatefulWidget {
  const _CheckboxDemo();

  @override
  State<_CheckboxDemo> createState() => _CheckboxDemoState();
}

class _CheckboxDemoState extends State<_CheckboxDemo> {
  bool _terms = true;
  bool _updates = false;

  @override
  Widget build(BuildContext context) {
    // Mirrors CheckboxPreview: `flex flex-col gap-3` (12px).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BeuiCheckbox(
          value: _terms,
          label: 'Accept terms and conditions',
          onChanged: (v) => setState(() => _terms = v),
        ),
        const SizedBox(height: 12),
        BeuiCheckbox(
          value: _updates,
          label: 'Email me product updates',
          onChanged: (v) => setState(() => _updates = v),
        ),
        const SizedBox(height: 12),
        BeuiCheckbox(
          value: true,
          indeterminate: true,
          label: 'Select all (partial)',
          onChanged: (_) {},
        ),
        const SizedBox(height: 12),
        BeuiCheckbox(
          value: true,
          enabled: false,
          label: 'Disabled',
          onChanged: (_) {},
        ),
      ],
    );
  }
}
