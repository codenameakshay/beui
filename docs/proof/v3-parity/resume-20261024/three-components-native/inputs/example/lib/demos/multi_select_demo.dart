import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiMultiSelect].
Widget multiSelectDemo(BuildContext context) => const _MultiSelectDemo();

const _teamOptions = <BeuiMultiSelectOption>[
  BeuiMultiSelectOption(
    value: 'design',
    label: 'Design',
    leading: _TeamDot(color: Color(0xFFf43f5e)),
  ),
  BeuiMultiSelectOption(
    value: 'engineering',
    label: 'Engineering',
    leading: _TeamDot(color: Color(0xFF0ea5e9)),
  ),
  BeuiMultiSelectOption(
    value: 'product',
    label: 'Product',
    leading: _TeamDot(color: Color(0xFFf59e0b)),
  ),
  BeuiMultiSelectOption(
    value: 'research',
    label: 'Research',
    leading: _TeamDot(color: Color(0xFF8b5cf6)),
  ),
  BeuiMultiSelectOption(
    value: 'marketing',
    label: 'Marketing',
    leading: _TeamDot(color: Color(0xFF10b981)),
  ),
  BeuiMultiSelectOption(
    value: 'operations',
    label: 'Operations',
    leading: _TeamDot(color: Color(0xFF64748b)),
  ),
];

class _MultiSelectDemo extends StatefulWidget {
  const _MultiSelectDemo();

  @override
  State<_MultiSelectDemo> createState() => _MultiSelectDemoState();
}

class _MultiSelectDemoState extends State<_MultiSelectDemo> {
  List<String> _teams = const ['design', 'engineering'];

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 360,
      child: BeuiMultiSelect(
        items: _teamOptions,
        value: _teams,
        onChanged: (value) => setState(() => _teams = value),
        placeholder: 'Choose teams',
        searchHint: 'Search teams…',
      ),
    ),
  );
}

class _TeamDot extends StatelessWidget {
  const _TeamDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
