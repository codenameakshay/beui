import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery demo for [BeuiThemeToggle] / [BeuiThemeSwitcher] — a faithful port of
/// the source `theme-toggle.preview.tsx`: `flex h-full w-full items-center
/// justify-center gap-5` holding one `flex flex-col items-center gap-2` cell per
/// variant (rectangle, circle, circle-blur, blinds), each a
/// `rounded-xl border border-border bg-background p-2.5` button with an
/// `h-5 w-5` icon over an 11px muted label.
///
/// The switcher wraps the whole demo surface, so the reveal spans the full page
/// exactly as the site's view transition does.
Widget themeToggleDemo(BuildContext context) => const _ThemeToggleDemo();

class _ThemeToggleDemo extends StatelessWidget {
  const _ThemeToggleDemo();

  static const _variants = <(BeuiThemeRevealVariant, String)>[
    (BeuiThemeRevealVariant.rectangle, 'Rectangle'),
    (BeuiThemeRevealVariant.circle, 'Circle'),
    (BeuiThemeRevealVariant.circleBlur, 'Circle blur'),
    (BeuiThemeRevealVariant.blinds, 'Blinds'),
  ];

  @override
  Widget build(BuildContext context) {
    final ambient = Theme.of(context).extension<BeuiColors>()!;
    // A definite height, not `SizedBox.expand`: the gallery lays demos out
    // inside a SingleChildScrollView, so an infinite height asserts in
    // performLayout and the preview renders nothing at all.
    return SizedBox(
      width: double.infinity,
      height: 420,
      child: BeuiThemeSwitcher(
        initialBrightness: ambient.brightness,
        builder: (context, brightness) {
          final c = BeuiColors.of(ambient.colorTheme, brightness);
          return ColoredBox(
            color: c.background,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < _variants.length; i++) ...[
                    if (i > 0) const SizedBox(width: 20), // gap-5
                    _ToggleCell(
                      colors: c,
                      variant: _variants[i].$1,
                      label: _variants[i].$2,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One `flex flex-col items-center gap-2` cell: the toggle button and its label.
class _ToggleCell extends StatelessWidget {
  const _ToggleCell({
    required this.colors,
    required this.variant,
    required this.label,
  });

  final BeuiColors colors;
  final BeuiThemeRevealVariant variant;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Container (not DecoratedBox) so the 1px border occupies layout space,
        // like the source's `box-sizing: border-box`: 20 + 2×10 + 2×1 = 42.
        Container(
          decoration: BoxDecoration(
            color: colors.background, // bg-background
            border: Border.all(color: colors.border), // border-border
            borderRadius: BorderRadius.circular(12), // rounded-xl
          ),
          child: Padding(
            padding: const EdgeInsets.all(10), // p-2.5
            child: BeuiThemeToggle(
              variant: variant,
              start: BeuiThemeRevealStart.bottomUp,
              size: 20, // h-5 w-5
              color: colors.foreground,
            ),
          ),
        ),
        const SizedBox(height: 8), // gap-2
        Text(
          label,
          style: TextStyle(fontSize: 11, color: colors.mutedForeground),
        ),
      ],
    );
  }
}
