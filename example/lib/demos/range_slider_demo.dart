import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery entry for the slider family — one section per component on the
/// source's `motion/range-slider` page, in the order that page ships them:
/// [BeuiRangeSlider], [BeuiFluidSlider], [BeuiWaveSlider], [BeuiBubbleSlider]
/// and [BeuiRulerSlider]. Each section mirrors that component's own preview
/// (same seed value, same caption, same props), so the route doubles as visual
/// QA against beui.dev.
Widget rangeSliderDemo(BuildContext context) => const _RangeSliderDemo();

class _RangeSliderDemo extends StatefulWidget {
  const _RangeSliderDemo();

  @override
  State<_RangeSliderDemo> createState() => _RangeSliderDemoState();
}

class _RangeSliderDemoState extends State<_RangeSliderDemo> {
  // Each preview's own seed value, from the source's usage snippets.
  double _value = 40; // range-slider
  double _brightness = 35; // range-slider-fluid
  double _gain = 45; // range-slider-wave
  double _bubble = 28; // range-slider-bubble
  double _weight = 72.5; // range-slider-ruler

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
          // ---- Range Slider ----
          sectionLabel('Range slider'),
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

          // ---- Fluid Slider ----
          sectionLabel('Fluid — no thumb, the label inverts under the fill'),
          BeuiFluidSlider(
            value: _brightness,
            labelText: 'Brightness',
            label: 'Brightness',
            onChanged: (v) => setState(() => _brightness = v),
          ),
          const SizedBox(height: 16),
          const BeuiFluidSlider(
            defaultValue: 60,
            labelText: 'Disabled',
            label: 'Disabled',
            enabled: false,
          ),
          const SizedBox(height: 48),

          // ---- Wave Slider ----
          sectionLabel('Wave — a crest travels with the value'),
          caption('Gain', '${_gain.round()}'),
          BeuiWaveSlider(
            value: _gain,
            label: 'Gain',
            onChanged: (v) => setState(() => _gain = v),
          ),
          const SizedBox(height: 48),

          // ---- Bubble Slider ----
          sectionLabel('Bubble — leans and squashes with drag speed'),
          caption('Drag fast and the bubble leans', '${_bubble.round()}'),
          BeuiBubbleSlider(
            value: _bubble,
            label: 'Value',
            onChanged: (v) => setState(() => _bubble = v),
          ),
          const SizedBox(height: 32),

          // ---- Ruler Slider ----
          sectionLabel('Ruler — the scale scrolls under a fixed needle'),
          BeuiRulerSlider(
            value: _weight,
            min: 40,
            max: 120,
            step: 0.5,
            gap: 12,
            majorEvery: 10,
            unit: 'kg',
            label: 'Weight',
            onChanged: (v) => setState(() => _weight = v),
          ),
        ],
      ),
    );
  }
}
