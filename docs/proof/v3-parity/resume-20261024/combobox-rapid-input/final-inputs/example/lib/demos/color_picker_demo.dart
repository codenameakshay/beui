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
  _ColorInputFormat _format = _ColorInputFormat.hex;
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
    final colors = BeuiColors.resolve(context);
    final next = _ColorInputFormat.values[(_format.index + 1) % 3];
    return SizedBox(
      height: 460,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: BeuiColorPicker(
            label: 'Brand color',
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
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            BeuiColorPickerHue(),
                            SizedBox(height: 12),
                            BeuiColorPickerAlpha(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        label:
                            'Format ${_format.name.toUpperCase()}, switch to ${next.name.toUpperCase()}',
                        child: SizedBox(
                          width: 48,
                          height: 36,
                          child: OutlinedButton(
                            onPressed: () => setState(() => _format = next),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              foregroundColor: colors.mutedForeground,
                              side: BorderSide(color: colors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: BeuiActionSwapText(
                              value: _format.name,
                              text: _format.name.toUpperCase(),
                              variant: BeuiActionSwapVariant.roll,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _format == _ColorInputFormat.hex
                            ? const BeuiColorPickerHex()
                            : BeuiColorPickerChannels(
                                format: _format == _ColorInputFormat.rgb
                                    ? BeuiColorFormat.rgb
                                    : BeuiColorFormat.hsl,
                              ),
                      ),
                      if (_format == _ColorInputFormat.hex) ...[
                        const SizedBox(width: 6),
                        const BeuiColorPickerSwatch(size: 36),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 2, right: 2, top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final item in presets)
                          BeuiColorPickerPreset(item: item),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ColorInputFormat { hex, rgb, hsl }
