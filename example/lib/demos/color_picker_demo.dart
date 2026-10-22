import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiColorPicker].
Widget colorPickerDemo(BuildContext context) => const _ColorPickerDemo();

class _ColorPickerDemo extends StatefulWidget {
  const _ColorPickerDemo();
  @override
  State<_ColorPickerDemo> createState() => _ColorPickerDemoState();
}

class _ColorPickerDemoState extends State<_ColorPickerDemo> {
  String _color = '#3478f6';
  @override
  Widget build(BuildContext context) {
    const presets = [
      BeuiColorPickerPresetItem('#3478f6', label: 'Blue'),
      BeuiColorPickerPresetItem('#9270e8', label: 'Purple'),
      BeuiColorPickerPresetItem('#e66aa4', label: 'Pink'),
      BeuiColorPickerPresetItem('#e55656', label: 'Red'),
      BeuiColorPickerPresetItem('#ed9141', label: 'Orange'),
      BeuiColorPickerPresetItem('#e5b63c', label: 'Amber'),
      BeuiColorPickerPresetItem('#65a65a', label: 'Green'),
      BeuiColorPickerPresetItem('#169d83', label: 'Teal'),
    ];
    return BeuiColorPicker(
      value: _color,
      onChanged: (value) => setState(() => _color = value),
      trigger: const BeuiColorPickerTrigger(),
      child: BeuiColorPickerContent(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BeuiColorPickerArea(),
            const SizedBox(height: 12),
            const Row(
              children: [
                BeuiColorPickerEyeDropper(),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [BeuiColorPickerHue(), BeuiColorPickerAlpha()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: BeuiColorPickerHex(key: ValueKey(_color))),
                const SizedBox(width: 8),
                const BeuiColorPickerSwatch(),
              ],
            ),
            const SizedBox(height: 12),
            const BeuiColorPickerPresets(items: presets),
          ],
        ),
      ),
    );
  }
}
