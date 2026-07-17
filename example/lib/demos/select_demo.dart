import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiSelect] and [BeuiMorphSelect] — the accordion
/// dropdown and the shared-layout morph variants.
Widget selectDemo(BuildContext context) => const _SelectDemo();

const _fruits = <BeuiSelectOption>[
  BeuiSelectOption(value: 'apple', label: 'Apple'),
  BeuiSelectOption(value: 'banana', label: 'Banana'),
  BeuiSelectOption(value: 'blueberry', label: 'Blueberry'),
  BeuiSelectOption(value: 'grapes', label: 'Grapes'),
  BeuiSelectOption(value: 'pineapple', label: 'Pineapple', enabled: false),
];

class _SelectDemo extends StatefulWidget {
  const _SelectDemo();

  @override
  State<_SelectDemo> createState() => _SelectDemoState();
}

class _SelectDemoState extends State<_SelectDemo> {
  String? _default;
  String? _morph = 'banana';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: colors.mutedForeground,
        ),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label('Default — accordion dropdown'),
          SizedBox(
            width: 220,
            child: BeuiSelect(
              options: _fruits,
              placeholder: 'Pick a fruit',
              onChanged: (v) => setState(() => _default = v),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _default == null ? 'Nothing selected' : 'Selected: $_default',
            style: TextStyle(fontSize: 13, color: colors.mutedForeground),
          ),
          const SizedBox(height: 48),
          label('Morph — trigger grows into the panel'),
          SizedBox(
            width: 220,
            child: BeuiMorphSelect(
              options: _fruits,
              defaultValue: 'banana',
              placeholder: 'Pick a fruit',
              onChanged: (v) => setState(() => _morph = v),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Selected: $_morph',
            style: TextStyle(fontSize: 13, color: colors.mutedForeground),
          ),
          const SizedBox(height: 48),
          label('Disabled'),
          const SizedBox(
            width: 220,
            child: BeuiSelect(
              options: _fruits,
              enabled: false,
              placeholder: 'Unavailable',
            ),
          ),
        ],
      ),
    );
  }
}
