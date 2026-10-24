import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiArcPicker].
Widget arcPickerDemo(BuildContext context) => const _ArcPickerDemo();

const _times = <BeuiArcPickerOption>[
  BeuiArcPickerOption(value: 'first-light', label: 'First light'),
  BeuiArcPickerOption(value: 'dawn', label: 'Dawn'),
  BeuiArcPickerOption(value: 'daybreak', label: 'Daybreak'),
  BeuiArcPickerOption(value: 'sunrise', label: 'Sunrise'),
  BeuiArcPickerOption(value: 'early-morning', label: 'Early morning'),
  BeuiArcPickerOption(value: 'morning', label: 'Morning'),
  BeuiArcPickerOption(value: 'late-morning', label: 'Late morning'),
  BeuiArcPickerOption(value: 'midday', label: 'Midday'),
  BeuiArcPickerOption(value: 'noon', label: 'Noon'),
  BeuiArcPickerOption(value: 'afternoon', label: 'Afternoon'),
  BeuiArcPickerOption(value: 'golden-hour', label: 'Golden hour'),
  BeuiArcPickerOption(value: 'sunset', label: 'Sunset'),
  BeuiArcPickerOption(value: 'blue-hour', label: 'Blue hour'),
  BeuiArcPickerOption(value: 'dusk', label: 'Dusk'),
  BeuiArcPickerOption(value: 'twilight', label: 'Twilight'),
  BeuiArcPickerOption(value: 'evening', label: 'Evening'),
  BeuiArcPickerOption(value: 'nightfall', label: 'Nightfall'),
  BeuiArcPickerOption(value: 'night', label: 'Night'),
  BeuiArcPickerOption(value: 'late-night', label: 'Late night'),
  BeuiArcPickerOption(value: 'midnight', label: 'Midnight'),
  BeuiArcPickerOption(value: 'deep-night', label: 'Deep night'),
  BeuiArcPickerOption(value: 'starlight', label: 'Starlight'),
];

class _ArcPickerDemo extends StatefulWidget {
  const _ArcPickerDemo();

  @override
  State<_ArcPickerDemo> createState() => _ArcPickerDemoState();
}

class _ArcPickerDemoState extends State<_ArcPickerDemo> {
  String _value = 'golden-hour';
  BeuiArcPickerSide _side = BeuiArcPickerSide.right;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        children: [
          for (final side in BeuiArcPickerSide.values)
            ChoiceChip(
              label: Text(side.name),
              selected: _side == side,
              onSelected: (_) => setState(() => _side = side),
            ),
        ],
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 420,
        child: BeuiArcPicker(
          options: _times,
          value: _value,
          onChanged: (value) => setState(() => _value = value),
          semanticLabel: 'Time of day',
          side: _side,
          radius: 260,
          visibleCount: 9,
          itemHeight: 48,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Drag ${_side == BeuiArcPickerSide.top || _side == BeuiArcPickerSide.bottom ? 'horizontally' : 'vertically'}, scroll, or use arrow keys.',
        textAlign: TextAlign.center,
        style: TextStyle(color: BeuiColors.resolve(context).mutedForeground),
      ),
    ],
  );
}
