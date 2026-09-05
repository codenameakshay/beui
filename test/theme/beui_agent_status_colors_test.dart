import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

// The opaque surfaces agent badges actually sit on.
//
// Light: given directly (already the composited card colors).
const _lightSurfaces = <String, Color>{
  'tool_approval card (muted @0.20 over background)': Color(0xFFFBFBFB),
  'approval_card card (opaque muted)': Color(0xFFF5F5F5),
  'plain background': Color(0xFFFCFCFC),
};

// Dark: the tool_approval card is composited here from its translucent
// ingredients; the other two are the raw opaque tokens.
final _darkSurfaces = <String, Color>{
  'tool_approval card (muted @0.20 over background)': composite(
    const Color(0xFF1C1C1C).withValues(alpha: 0.20),
    const Color(0xFF151515),
  ),
  'approval_card card (opaque muted)': const Color(0xFF1C1C1C),
  'plain background': const Color(0xFF151515),
};

// Tiers covered by the AA gate (neutral is excluded — tested separately).
const _gatedTiers =
    <String, BeuiAgentStatusPalette Function(BeuiAgentStatusColors)>{
      'pending': _pending,
      'running': _running,
      'success': _success,
      'failed': _failed,
      'denied': _denied,
      'destructive': _destructive,
    };

BeuiAgentStatusPalette _pending(BeuiAgentStatusColors c) => c.pending;
BeuiAgentStatusPalette _running(BeuiAgentStatusColors c) => c.running;
BeuiAgentStatusPalette _success(BeuiAgentStatusColors c) => c.success;
BeuiAgentStatusPalette _failed(BeuiAgentStatusColors c) => c.failed;
BeuiAgentStatusPalette _denied(BeuiAgentStatusColors c) => c.denied;
BeuiAgentStatusPalette _destructive(BeuiAgentStatusColors c) => c.destructive;

void main() {
  group('BeuiAgentStatusColors.of resolves by brightness', () {
    test('light', () {
      expect(
        BeuiAgentStatusColors.of(Brightness.light),
        BeuiAgentStatusColors.light,
      );
    });

    test('dark', () {
      expect(
        BeuiAgentStatusColors.of(Brightness.dark),
        BeuiAgentStatusColors.dark,
      );
    });
  });

  group('palette() maps every BeuiAgentStatus to its named tier', () {
    test('light', () {
      const colors = BeuiAgentStatusColors.light;
      final expectedByStatus = <BeuiAgentStatus, BeuiAgentStatusPalette>{
        BeuiAgentStatus.pending: colors.pending,
        BeuiAgentStatus.running: colors.running,
        BeuiAgentStatus.success: colors.success,
        BeuiAgentStatus.failed: colors.failed,
        BeuiAgentStatus.denied: colors.denied,
        BeuiAgentStatus.neutral: colors.neutral,
        BeuiAgentStatus.destructive: colors.destructive,
      };
      for (final status in BeuiAgentStatus.values) {
        final result = colors.palette(status);
        expect(result, isNotNull, reason: status.name);
        expect(result, expectedByStatus[status], reason: status.name);
      }
    });

    test('dark', () {
      const colors = BeuiAgentStatusColors.dark;
      final expectedByStatus = <BeuiAgentStatus, BeuiAgentStatusPalette>{
        BeuiAgentStatus.pending: colors.pending,
        BeuiAgentStatus.running: colors.running,
        BeuiAgentStatus.success: colors.success,
        BeuiAgentStatus.failed: colors.failed,
        BeuiAgentStatus.denied: colors.denied,
        BeuiAgentStatus.neutral: colors.neutral,
        BeuiAgentStatus.destructive: colors.destructive,
      };
      for (final status in BeuiAgentStatus.values) {
        final result = colors.palette(status);
        expect(result, isNotNull, reason: status.name);
        expect(result, expectedByStatus[status], reason: status.name);
      }
    });
  });

  group('badge foreground clears WCAG AA (4.5:1) on every card surface', () {
    test('light', () {
      const colors = BeuiAgentStatusColors.light;
      for (final tierEntry in _gatedTiers.entries) {
        final palette = tierEntry.value(colors);
        for (final surfaceEntry in _lightSurfaces.entries) {
          final compositedBadgeBg = composite(
            palette.background,
            surfaceEntry.value,
          );
          final ratio = contrastRatio(palette.foreground, compositedBadgeBg);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                'light ${tierEntry.key} on ${surfaceEntry.key} is '
                '${ratio.toStringAsFixed(2)}:1',
          );
        }
      }
    });

    test('dark', () {
      const colors = BeuiAgentStatusColors.dark;
      for (final tierEntry in _gatedTiers.entries) {
        final palette = tierEntry.value(colors);
        for (final surfaceEntry in _darkSurfaces.entries) {
          final compositedBadgeBg = composite(
            palette.background,
            surfaceEntry.value,
          );
          final ratio = contrastRatio(palette.foreground, compositedBadgeBg);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                'dark ${tierEntry.key} on ${surfaceEntry.key} is '
                '${ratio.toStringAsFixed(2)}:1',
          );
        }
      }
    });
  });

  group('neutral foreground clears 4.5:1 on plain background', () {
    test('light', () {
      const colors = BeuiAgentStatusColors.light;
      final ratio = contrastRatio(
        colors.neutral.foreground,
        _lightSurfaces['plain background']!,
      );
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('dark', () {
      const colors = BeuiAgentStatusColors.dark;
      final ratio = contrastRatio(
        colors.neutral.foreground,
        _darkSurfaces['plain background']!,
      );
      expect(ratio, greaterThanOrEqualTo(4.5));
    });
  });

  group('destructive.border clears 3:1 as a standalone UI edge', () {
    test('light', () {
      const colors = BeuiAgentStatusColors.light;
      final card = _lightSurfaces['approval_card card (opaque muted)']!;
      final compositedEdge = composite(colors.destructive.border, card);
      final ratio = contrastRatio(compositedEdge, card);
      expect(ratio, greaterThanOrEqualTo(3.0));
    });

    test('dark', () {
      const colors = BeuiAgentStatusColors.dark;
      final card = _darkSurfaces['approval_card card (opaque muted)']!;
      final compositedEdge = composite(colors.destructive.border, card);
      final ratio = contrastRatio(compositedEdge, card);
      expect(ratio, greaterThanOrEqualTo(3.0));
    });
  });

  group('destructive is visually distinct from failed', () {
    test('light', () {
      const colors = BeuiAgentStatusColors.light;
      expect(colors.destructive.foreground, isNot(colors.failed.foreground));
      expect(colors.destructive.border.a, greaterThan(colors.failed.border.a));
    });

    test('dark', () {
      const colors = BeuiAgentStatusColors.dark;
      expect(colors.destructive.foreground, isNot(colors.failed.foreground));
      expect(colors.destructive.border.a, greaterThan(colors.failed.border.a));
    });
  });

  group('denied defaults equal failed', () {
    test('light', () {
      const colors = BeuiAgentStatusColors.light;
      expect(colors.denied, colors.failed);
      expect(colors.denied.foreground, colors.failed.foreground);
      expect(colors.denied.background, colors.failed.background);
      expect(colors.denied.border, colors.failed.border);
      expect(colors.denied.solid, colors.failed.solid);
      expect(colors.denied.onSolid, colors.failed.onSolid);
    });

    test('dark', () {
      const colors = BeuiAgentStatusColors.dark;
      expect(colors.denied, colors.failed);
      expect(colors.denied.foreground, colors.failed.foreground);
      expect(colors.denied.background, colors.failed.background);
      expect(colors.denied.border, colors.failed.border);
      expect(colors.denied.solid, colors.failed.solid);
      expect(colors.denied.onSolid, colors.failed.onSolid);
    });
  });

  group('copyWith round-trips', () {
    test('overriding one tier leaves the other six identical', () {
      const base = BeuiAgentStatusColors.light;
      final modified = base.copyWith(
        pending: base.pending.copyWith(foreground: const Color(0xFF123456)),
      );
      expect(modified.pending, isNot(base.pending));
      expect(modified.running, base.running);
      expect(modified.success, base.success);
      expect(modified.failed, base.failed);
      expect(modified.denied, base.denied);
      expect(modified.neutral, base.neutral);
      expect(modified.destructive, base.destructive);
    });

    test('copyWith() with no args returns an equal value', () {
      const base = BeuiAgentStatusColors.light;
      expect(base.copyWith(), base);
    });
  });

  group('value equality is load-bearing', () {
    test('two const BeuiAgentStatusColors.light references are ==', () {
      const a = BeuiAgentStatusColors.light;
      const b = BeuiAgentStatusColors.light;
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('BeuiAgentStatusPalette.lerp(a, a, 0.5) == a', () {
      const a = BeuiAgentStatusColors.light;
      expect(BeuiAgentStatusPalette.lerp(a.pending, a.pending, 0.5), a.pending);
    });
  });

  group('BeuiAgentTheme wiring', () {
    test('statusColorsFor resolves the right brightness', () {
      expect(
        BeuiAgentTheme.standard.statusColorsFor(Brightness.light),
        BeuiAgentStatusColors.light,
      );
    });

    test(
      'statusPalette is shorthand for statusColorsFor(...).palette(...)',
      () {
        expect(
          BeuiAgentTheme.standard.statusPalette(
            BeuiAgentStatus.pending,
            Brightness.dark,
          ),
          BeuiAgentStatusColors.dark.pending,
        );
      },
    );
  });
}
