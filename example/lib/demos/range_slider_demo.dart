import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery entry for the slider family — one band per component on the source's
/// `motion/range-slider` page, in the order that page ships them:
/// [BeuiRangeSlider], [BeuiFluidSlider], [BeuiWaveSlider], [BeuiBubbleSlider]
/// and [BeuiRulerSlider]. Each band is a 1:1 port of that component's usage
/// snippet — same seed value, same caption strings, same widths and gaps — so
/// the route doubles as visual QA against beui.dev.
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

  static const double _sm = 384; // max-w-sm
  static const double _md = 448; // max-w-md
  static const double _bandGap = 64; // separation between page bands

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    // `flex items-center justify-between text-sm text-muted-foreground`
    // with a `tabular-nums text-foreground` value on the right.
    Widget valueRow(String left, String right) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          left,
          style: TextStyle(
            fontSize: 14,
            height: 20 / 14,
            color: colors.mutedForeground,
          ),
        ),
        Text(
          right,
          style: TextStyle(
            fontSize: 14,
            height: 20 / 14,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: colors.foreground,
          ),
        ),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Range Slider — `max-w-sm flex-col gap-3` ──────────────────────
        SizedBox(
          width: _sm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              valueRow('Drag the handle', '${_value.round()}'),
              const SizedBox(height: 12), // gap-3
              BeuiRangeSlider(
                value: _value,
                min: 0,
                max: 100,
                step: 5,
                label: 'Value',
                onChanged: (v) => setState(() => _value = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: _bandGap),

        // ── Fluid Slider — `max-w-sm` ────────────────────────────────────
        SizedBox(
          width: _sm,
          child: BeuiFluidSlider(
            value: _brightness,
            labelText: 'Brightness',
            label: 'Brightness',
            onChanged: (v) => setState(() => _brightness = v),
          ),
        ),
        const SizedBox(height: _bandGap),

        // ── Wave Slider — `max-w-md flex-col gap-2` ──────────────────────
        SizedBox(
          width: _md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              valueRow('Gain', '${_gain.round()}'),
              const SizedBox(height: 8), // gap-2
              BeuiWaveSlider(
                value: _gain,
                label: 'Gain',
                onChanged: (v) => setState(() => _gain = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: _bandGap),

        // ── Bubble Slider — `max-w-sm flex-col gap-1` ────────────────────
        SizedBox(
          width: _sm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Drag fast and the bubble leans',
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 4), // gap-1
              BeuiBubbleSlider(
                value: _bubble,
                label: 'Value',
                onChanged: (v) => setState(() => _bubble = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: _bandGap),

        // ── Ruler Slider — `max-w-sm` ────────────────────────────────────
        SizedBox(
          width: _sm,
          child: BeuiRulerSlider(
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
        ),
      ],
    );
  }
}
