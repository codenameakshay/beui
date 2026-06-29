import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery demo for [BeuiThemeToggle] / [BeuiThemeSwitcher] — the source
/// theme-toggle preview: a self-contained card whose brightness flips with a
/// full-surface clip-path reveal, in all three variants (rectangle / circle /
/// circle-blur), revealing from the bottom up.
Widget themeToggleDemo(BuildContext context) => const _ThemeToggleDemo();

class _ThemeToggleDemo extends StatelessWidget {
  const _ThemeToggleDemo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: BeuiThemeSwitcher(
        initialBrightness: Brightness.dark,
        builder: (context, brightness) {
          final dark = brightness == Brightness.dark;
          final bg = dark ? const Color(0xFF09090B) : const Color(0xFFFFFFFF);
          final fg = dark ? const Color(0xFFFAFAFA) : const Color(0xFF09090B);
          final muted =
              dark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);
          final border =
              dark ? const Color(0x14FFFFFF) : const Color(0x12000000);
          final chip = dark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5);

          Widget toggle(String label, BeuiThemeRevealVariant v) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: chip,
                      border: Border.all(color: border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(11),
                      child: BeuiThemeToggle(
                        variant: v,
                        start: BeuiThemeRevealStart.bottomUp,
                        size: 20,
                        color: fg,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(label, style: TextStyle(fontSize: 11, color: muted)),
                ],
              );

          return ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 460,
              height: 300,
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: border),
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dark ? 'DARK' : 'LIGHT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Appearance',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap a toggle — the new theme wipes in from the bottom.',
                    style: TextStyle(fontSize: 14, color: muted),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      toggle('Rectangle', BeuiThemeRevealVariant.rectangle),
                      toggle('Circle', BeuiThemeRevealVariant.circle),
                      toggle('Circle blur', BeuiThemeRevealVariant.circleBlur),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
