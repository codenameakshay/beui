import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiDateRangePicker].
Widget dateRangePickerDemo(BuildContext context) =>
    const _DateRangePickerDemo();

class _DateRangePickerDemo extends StatefulWidget {
  const _DateRangePickerDemo();

  @override
  State<_DateRangePickerDemo> createState() => _DateRangePickerDemoState();
}

class _DateRangePickerDemoState extends State<_DateRangePickerDemo> {
  late final String _today = _iso(DateTime.now());
  late final String _weekStart = _iso(
    DateTime.now().subtract(const Duration(days: 6)),
  );
  BeuiDateRange? _range;

  @override
  void initState() {
    super.initState();
    _range = BeuiDateRange(from: _weekStart, to: _today);
  }

  @override
  Widget build(BuildContext context) => BeuiDateRangePickerDropdown(
    value: _range,
    onChanged: (value) => setState(() => _range = value),
    defaultMonth: _today,
    max: _today,
    label: 'Reporting period',
  );

  String _iso(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
