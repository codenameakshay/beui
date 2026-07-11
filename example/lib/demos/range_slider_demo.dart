import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery entry for the slider family.
///
/// PRIMARY — the single-thumb [BeuiRangeSlider], a 1:1 port of the source
/// `range-slider.preview`: a ticked slider with a "Drag the handle" caption and
/// a live value readout. Below it, the Flutter-only [BeuiRangeSliderDual]
/// (two thumbs, a band) — clearly labelled as an extension not present in the
/// source.
Widget rangeSliderDemo(BuildContext context) => const _RangeSliderDemo();

class _RangeSliderDemo extends StatefulWidget {
  const _RangeSliderDemo();

  @override
  State<_RangeSliderDemo> createState() => _RangeSliderDemoState();
}

class _RangeSliderDemoState extends State<_RangeSliderDemo> {
  // Primary — single-thumb, source preview parity (value 40, step 5).
  double _value = 40;

  // Flutter-only dual range.
  RangeValues _band = const RangeValues(20, 60);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    Widget caption(String left, String right) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            left,
            style: TextStyle(fontSize: 14, color: colors.mutedForeground),
          ),
          Text(
            right,
            style: TextStyle(
              fontSize: 14,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: colors.foreground,
            ),
          ),
        ],
      ),
    );

    Widget sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          color: colors.mutedForeground,
        ),
      ),
    );

    return SizedBox(
      width: 340,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---- Single-thumb (the source's range-slider) ----
          caption('Drag the handle', '${_value.round()}'),
          BeuiRangeSlider(
            value: _value,
            min: 0,
            max: 100,
            step: 5,
            label: 'Value',
            onChanged: (v) => setState(() => _value = v),
          ),
          const SizedBox(height: 40),
          caption('Volume', '${(_value * 0.6 + 10).round()}'),
          BeuiRangeSlider(
            defaultValue: 30,
            min: 0,
            max: 100,
            step: 10,
            label: 'Volume',
            onChanged: (_) {},
          ),
          const SizedBox(height: 48),

          // ---- Flutter-only dual range ----
          sectionLabel('Dual — Flutter-only extension (not in the source)'),
          caption(
            'Price range',
            '\$${_band.start.round()} – \$${_band.end.round()}',
          ),
          BeuiRangeSliderDual(
            values: _band,
            min: 0,
            max: 100,
            divisions: 20, // step of 5
            label: 'Price range',
            onChanged: (v) => setState(() => _band = v),
          ),
          const SizedBox(height: 40),
          caption('Disabled', '30 – 70'),
          const BeuiRangeSliderDual(
            values: RangeValues(30, 70),
            enabled: false,
            divisions: 20,
            onChanged: null,
          ),
        ],
      ),
    );
  }
}
