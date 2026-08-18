import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Source-over composite of [src] onto an opaque [dst].
Color _composite(Color src, Color dst) {
  final a = src.a;
  return Color.from(
    alpha: 1,
    red: src.r * a + dst.r * (1 - a),
    green: src.g * a + dst.g * (1 - a),
    blue: src.b * a + dst.b * (1 - a),
  );
}

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

/// WCAG 2.x relative-contrast ratio between two **opaque** colors.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('BeuiColors.of resolves every theme × brightness', () {
    test('there are exactly 11 color themes (neutral + 10 brand)', () {
      expect(BeuiColorTheme.values.length, 11);
    });

    test('all 11 themes resolve for both light and dark', () {
      for (final theme in BeuiColorTheme.values) {
        for (final brightness in Brightness.values) {
          final colors = BeuiColors.of(theme, brightness);
          expect(colors.colorTheme, theme);
          expect(colors.brightness, brightness);
          // Sanity: a fully-populated palette (opaque surfaces present).
          expect(colors.background.a, 1.0);
          expect(colors.foreground.a, 1.0);
        }
      }
    });

    test('light()/dark() factories are the neutral Mono base', () {
      expect(BeuiColors.light().colorTheme, BeuiColorTheme.defaultMono);
      expect(BeuiColors.light().brightness, Brightness.light);
      expect(BeuiColors.dark().colorTheme, BeuiColorTheme.defaultMono);
      expect(BeuiColors.dark().brightness, Brightness.dark);
    });
  });

  group('known token values match the source palette', () {
    test('dark background is the raw hex #151515 passed straight through', () {
      final dark = BeuiColors.of(BeuiColorTheme.defaultMono, Brightness.dark);
      expect(dark.background, const Color(0xFF151515));
    });

    test('dark card is the raw hex #1c1c1c passed straight through', () {
      final dark = BeuiColors.of(BeuiColorTheme.defaultMono, Brightness.dark);
      expect(dark.card, const Color(0xFF1C1C1C));
    });

    test('colored themes keep the neutral surfaces, override only brand', () {
      final base = BeuiColors.of(BeuiColorTheme.defaultMono, Brightness.dark);
      final violet = BeuiColors.of(BeuiColorTheme.violet, Brightness.dark);
      // Neutral surfaces unchanged...
      expect(violet.background, base.background);
      expect(violet.card, base.card);
      expect(violet.border, base.border);
      // ...brand tokens overridden.
      expect(violet.primary, isNot(base.primary));
      expect(violet.accent, isNot(base.accent));
    });
  });

  group('alpha is preserved through conversion (no dropped / a term)', () {
    test('light border carries its 0.06 alpha (oklch(15% 0 0 / 0.06))', () {
      final light = BeuiColors.of(BeuiColorTheme.defaultMono, Brightness.light);
      expect(light.border.a, lessThan(1.0));
      expect(light.border.a, greaterThan(0.0));
    });

    test('dark border carries its 0.05 alpha (rgb(255 255 255 / 0.05))', () {
      final dark = BeuiColors.of(BeuiColorTheme.defaultMono, Brightness.dark);
      expect(dark.border.a, lessThan(1.0));
      expect(dark.border.a, greaterThan(0.0));
    });

    test('a brand ring tint is translucent (oklch(... / 0.5) light)', () {
      final violet = BeuiColors.of(BeuiColorTheme.violet, Brightness.light);
      expect(violet.ring.a, lessThan(1.0));
    });
  });

  group('focusRing clears WCAG 2.2 SC 1.4.11 (3:1) on every theme', () {
    // The whole reason this role exists: `ring` is a 6-12% hairline that
    // composites to ~1.3:1, so it cannot serve as a focus indicator. These
    // numbers are the gate — if a palette edit drops one below 3:1, fix the
    // palette, not the test.
    test('every theme x brightness composites to at least 3:1', () {
      for (final theme in BeuiColorTheme.values) {
        for (final brightness in Brightness.values) {
          final colors = BeuiColors.of(theme, brightness);
          final ratio = _contrast(
            _composite(colors.focusRing, colors.background),
            colors.background,
          );
          expect(
            ratio,
            greaterThanOrEqualTo(3.0),
            reason:
                '${theme.slug}/${brightness.name} focusRing is '
                '${ratio.toStringAsFixed(2)}:1',
          );
        }
      }
    });

    test('the `ring` token it replaces does NOT clear 3:1 (the bug)', () {
      for (final brightness in Brightness.values) {
        final colors = BeuiColors.of(BeuiColorTheme.defaultMono, brightness);
        final ratio = _contrast(
          _composite(colors.ring, colors.background),
          colors.background,
        );
        expect(ratio, lessThan(2.0));
      }
    });

    test('neutral focusRing is `foreground` at 0.55 light / 0.6 dark', () {
      final light = BeuiColors.light();
      final dark = BeuiColors.dark();
      expect(light.focusRing, const Color(0x8C0B0B0B));
      expect(dark.focusRing, const Color(0x99F2F2F2));
      // Same hue as `foreground`, just alpha-reduced.
      expect(light.focusRing.r, light.foreground.r);
      expect(light.focusRing.g, light.foreground.g);
      expect(light.focusRing.b, light.foreground.b);
      expect(dark.focusRing.r, dark.foreground.r);
      expect(dark.focusRing.g, dark.foreground.g);
      expect(dark.focusRing.b, dark.foreground.b);
    });

    test('branded focusRings are opaque and keep the brand hue', () {
      for (final theme in BeuiColorTheme.values) {
        if (theme == BeuiColorTheme.defaultMono) continue;
        for (final brightness in Brightness.values) {
          final colors = BeuiColors.of(theme, brightness);
          expect(colors.focusRing.a, 1.0, reason: theme.slug);
        }
      }
      // Eight of ten hues are the brand primary verbatim; amber and lime are
      // darkened to 60% oklch lightness because their light hues cannot clear
      // 3:1 at any alpha (2.30:1 and 2.29:1 fully opaque).
      final violet = BeuiColors.of(BeuiColorTheme.violet, Brightness.light);
      expect(violet.focusRing, violet.primary);
      final amber = BeuiColors.of(BeuiColorTheme.amber, Brightness.light);
      expect(amber.focusRing, const Color(0xFFB76C00));
      expect(amber.focusRing, isNot(amber.primary));
      final lime = BeuiColors.of(BeuiColorTheme.lime, Brightness.light);
      expect(lime.focusRing, const Color(0xFF5B9300));
      expect(lime.focusRing, isNot(lime.primary));
    });
  });

  group('picker metadata: name + swatch', () {
    test('every variant exposes a non-empty display name', () {
      for (final theme in BeuiColorTheme.values) {
        expect(BeuiColors.of(theme, Brightness.light).name, isNotEmpty);
      }
      expect(
        BeuiColors.of(BeuiColorTheme.defaultMono, Brightness.light).name,
        'Mono',
      );
    });

    test('swatch is brightness-independent picker metadata', () {
      for (final theme in BeuiColorTheme.values) {
        final light = BeuiColors.of(theme, Brightness.light);
        final dark = BeuiColors.of(theme, Brightness.dark);
        expect(light.swatch, dark.swatch);
      }
    });

    test('swatch is distinct from primary (per source THEME_LIST intent)', () {
      for (final theme in BeuiColorTheme.values) {
        final dark = BeuiColors.of(theme, Brightness.dark);
        // The dark brand primary is a lightened hue, never the swatch.
        expect(
          dark.swatch,
          isNot(dark.primary),
          reason: '${theme.name} dark swatch should differ from primary',
        );

        final light = BeuiColors.of(theme, Brightness.light);
        if (theme == BeuiColorTheme.defaultMono) {
          // Mono picks a mid-gray swatch distinct from its near-black primary.
          expect(light.swatch, isNot(light.primary));
        } else {
          // Colored themes: the swatch IS the light brand primary by design
          // (source THEME_LIST reuses the light hue), so they coincide in light.
          expect(
            light.swatch,
            light.primary,
            reason: '${theme.name} swatch mirrors its light primary',
          );
        }
      }
    });
  });

  group('ThemeExtension contract: copyWith + lerp', () {
    test('copyWith overrides only the named field', () {
      final base = BeuiColors.of(BeuiColorTheme.defaultMono, Brightness.light);
      final modified = base.copyWith(primary: const Color(0xFF123456));
      expect(modified.primary, const Color(0xFF123456));
      expect(modified.background, base.background);
      expect(modified.colorTheme, base.colorTheme);
      expect(modified.brightness, base.brightness);
    });

    test('lerp(other, 0) == this and lerp(other, 1) == other for colors', () {
      final a = BeuiColors.of(BeuiColorTheme.defaultMono, Brightness.light);
      final b = BeuiColors.of(BeuiColorTheme.violet, Brightness.dark);

      final at0 = a.lerp(b, 0.0);
      final at1 = a.lerp(b, 1.0);

      expect(at0.background, a.background);
      expect(at0.primary, a.primary);
      expect(at1.background, b.background);
      expect(at1.primary, b.primary);
    });

    test('lerp interpolates the glass surface too', () {
      final a = BeuiColors.of(BeuiColorTheme.defaultMono, Brightness.light);
      final b = BeuiColors.of(BeuiColorTheme.defaultMono, Brightness.dark);
      final mid = a.lerp(b, 0.5);
      expect(mid.glass.bg, Color.lerp(a.glass.bg, b.glass.bg, 0.5));
    });

    test('lerp with a non-BeuiColors extension returns this unchanged', () {
      final a = BeuiColors.of(BeuiColorTheme.defaultMono, Brightness.light);
      expect(a.lerp(null, 0.5), same(a));
    });
  });

  group('glass surface descriptor (documented blur exception)', () {
    test('blur radii exceed the 10px motion cap by design', () {
      final glass = BeuiColors.of(
        BeuiColorTheme.defaultMono,
        Brightness.dark,
      ).glass;
      expect(glass.blur, 20.0);
      expect(glass.strongBlur, 16.0);
      expect(glass.thinBlur, 12.0);
      expect(glass.blur, greaterThan(10.0));
    });

    test('glass surfaces are translucent on both brightnesses', () {
      final lightGlass = BeuiColors.of(
        BeuiColorTheme.defaultMono,
        Brightness.light,
      ).glass;
      final darkGlass = BeuiColors.of(
        BeuiColorTheme.defaultMono,
        Brightness.dark,
      ).glass;
      expect(lightGlass.bg.a, lessThan(1.0));
      expect(darkGlass.bg.a, lessThan(1.0));
    });
  });

  group('BeuiColors is a value type (load-bearing for AnimatedTheme)', () {
    test('two identically-resolved palettes compare equal', () {
      for (final theme in BeuiColorTheme.values) {
        for (final brightness in Brightness.values) {
          expect(
            BeuiColors.of(theme, brightness),
            BeuiColors.of(theme, brightness),
          );
          expect(
            BeuiColors.of(theme, brightness).hashCode,
            BeuiColors.of(theme, brightness).hashCode,
          );
        }
      }
      expect(BeuiColors.light(), BeuiColors.light());
      expect(BeuiColors.dark(), BeuiColors.dark());
    });

    test('palettes that actually differ compare unequal', () {
      expect(BeuiColors.light(), isNot(BeuiColors.dark()));
      expect(
        BeuiColors.of(BeuiColorTheme.values.first, Brightness.light),
        isNot(BeuiColors.of(BeuiColorTheme.values.last, Brightness.light)),
      );
      expect(
        BeuiColors.light(),
        isNot(BeuiColors.light().copyWith(primary: const Color(0xFF00FF00))),
      );
    });

    test('a ThemeData carrying the extension compares equal', () {
      // This is the property that matters. `ThemeData` compares `extensions` by
      // value, so a `BeuiColors` without `==` makes every rebuild that
      // reconstructs the theme inside `build` look like a theme *change* to
      // `AnimatedTheme`. That kicks off a 200ms theme lerp whose drifting
      // interpolated `ThemeData` then restarts Material's own implicit
      // animations for another ~200ms as they chase it — a constant ~400ms tail
      // of phantom animation on every setState, which reduced motion does not
      // suppress (a color transition is not movement) and which swamps every
      // component animation shorter than it in `pumpAndSettle`.
      ThemeData build() =>
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]);
      expect(build(), build());
    });

    testWidgets('a rebuild does not schedule a phantom theme animation', (
      tester,
    ) async {
      Widget app(int _) => MaterialApp(
        theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        home: const Scaffold(body: SizedBox.shrink()),
      );

      await tester.pumpWidget(app(0));
      await tester.pumpAndSettle();

      // Rebuild with a fresh-but-identical ThemeData. Nothing must start
      // ticking: a single pump has to leave the scheduler idle.
      await tester.pumpWidget(app(1));
      expect(
        tester.binding.transientCallbackCount,
        0,
        reason: 'rebuilding with an equal theme must not animate anything',
      );
    });
  });

  group('BeuiTextTheme exposes family names only (no bundled fonts)', () {
    test('sans is Inter, mono is JetBrains Mono (not Geist Mono)', () {
      const text = BeuiTextTheme();
      expect(text.sansFamily, 'Inter');
      expect(text.monoFamily, 'JetBrains Mono');
    });

    test('mono falls back to the platform monospace family', () {
      const text = BeuiTextTheme();
      expect(text.monoFamilyFallback, contains('monospace'));
    });
  });
}
