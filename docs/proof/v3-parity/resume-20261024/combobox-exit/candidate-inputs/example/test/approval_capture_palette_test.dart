import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/demos/agents_capture.dart';

List<int> _tokens(BeuiColors c) => [
  c.background,
  c.foreground,
  c.card,
  c.cardForeground,
  c.popover,
  c.popoverForeground,
  c.primary,
  c.primaryForeground,
  c.secondary,
  c.secondaryForeground,
  c.muted,
  c.mutedForeground,
  c.accent,
  c.accentForeground,
  c.destructive,
  c.border,
  c.input,
  c.ring,
].map((c) => c.toARGB32()).toList();

void main() {
  test('capture source-default palette resolves all public default tokens', () {
    for (final brightness in Brightness.values) {
      final theme = agentsCaptureTheme(
        brightness,
        palette: 'source-default-a76e57c9',
      );
      final colors = theme.extension<BeuiColors>()!;
      expect(
        _tokens(colors),
        brightness == Brightness.dark
            ? [
                0xFF151515,
                0xFFF2F2F2,
                0xFF1C1C1C,
                0xFFF2F2F2,
                0xFF1C1C1C,
                0xFFF2F2F2,
                0xFF0285F7,
                0xFFFFFFFF,
                0xFF1C1C1C,
                0xFFF2F2F2,
                0xFF1C1C1C,
                0xFF868686,
                0xFF00DFE1,
                0xFF151515,
                0xFFEE343B,
                0x0DFFFFFF,
                0x0DFFFFFF,
                0x1AFFFFFF,
              ]
            : [
                0xFFFCFCFC,
                0xFF0B0B0B,
                0xFFF5F5F5,
                0xFF0B0B0B,
                0xFFF5F5F5,
                0xFF0B0B0B,
                0xFF0285F7,
                0xFFFFFFFF,
                0xFFF5F5F5,
                0xFF0B0B0B,
                0xFFF5F5F5,
                0xFF636363,
                0xFF00C5C7,
                0xFF0B0B0B,
                0xFFEE343B,
                0x0F0B0B0B,
                0x0F0B0B0B,
                0x1F0B0B0B,
              ],
      );
      expect(theme.colorScheme.primary.toARGB32(), 0xFF0285F7);
      expect(theme.colorScheme.onPrimary.toARGB32(), 0xFFFFFFFF);
    }
  });

  test(
    'capture palette remains opt-in and does not mutate public palettes',
    () {
      for (final brightness in Brightness.values) {
        final defaultTheme = agentsCaptureTheme(brightness);
        agentsCaptureTheme(brightness, palette: 'source-default-a76e57c9');
        final unknownTheme = agentsCaptureTheme(brightness, palette: 'blue');
        final expected = brightness == Brightness.dark
            ? 0xFFF2F2F2
            : 0xFF0B0B0B;
        expect(
          defaultTheme.extension<BeuiColors>()!.primary.toARGB32(),
          expected,
        );
        expect(
          unknownTheme.extension<BeuiColors>()!.primary.toARGB32(),
          expected,
        );
        expect(
          BeuiColors.of(
            BeuiColorTheme.defaultMono,
            brightness,
          ).primary.toARGB32(),
          expected,
        );
      }
    },
  );
}
