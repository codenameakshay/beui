import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('beuiChartColor source outcomes', () {
    final colors = BeuiColors.light().copyWith(
      mutedForeground: const Color(0xFF010101),
      foreground: const Color(0xFF020202),
      background: const Color(0xFF030303),
      muted: const Color(0xFF040404),
      border: const Color(0xFF050505),
      primary: const Color(0xFF060606),
      accent: const Color(0xFF070707),
      success: const Color(0xFF080808),
      warning: const Color(0xFF090909),
      destructive: const Color(0xFF0A0A0A),
    );

    const cssCases = <String, Color>{
      '#abc': Color(0xFFAABBCC),
      '#abcd': Color(0xDDAABBCC),
      '#112233': Color(0xFF112233),
      '#11223344': Color(0x44112233),
      '#ff000080': Color(0x80FF0000),
      '#00ff0000': Color(0x0000FF00),
      // Preserve the original helper's bare hexadecimal forms. Bare 8-digit
      // values are Flutter ARGB; CSS-prefixed 8-digit values are CSS RGBA.
      'abc': Color(0xFFAABBCC),
      '112233': Color(0xFF112233),
      '80ff0000': Color(0x80FF0000),
      'rgb(17, 34, 51)': Color(0xFF112233),
      'rgba(17, 34, 51, 0.5)': Color(0x80112233),
      'rgb(100% 0% 50% / 25%)': Color(0x40FF0080),
      'hsl(210 100% 50% / 50%)': Color(0x800080FF),
      'hsl(0.5turn 100% 50% / 25%)': Color(0x4000FFFF),
      'hsl(200grad, 100%, 50%)': Color(0xFF00FFFF),
      'rebeccapurple': Color(0xFF663399),
      'peachpuff': Color(0xFFFFDAB9),
      'transparent': Color(0x00000000),
    };
    for (final entry in cssCases.entries) {
      test('parses CSS ${entry.key}', () {
        expect(beuiChartColor(entry.key, colors), entry.value);
      });
    }

    test('preserves all ten chart theme token aliases', () {
      const cases = <String, Color>{
        'var(--muted-foreground)': Color(0xFF010101),
        'var(--foreground)': Color(0xFF020202),
        'var(--background)': Color(0xFF030303),
        'var(--muted)': Color(0xFF040404),
        'var(--border)': Color(0xFF050505),
        'var(--primary)': Color(0xFF060606),
        'var(--accent)': Color(0xFF070707),
        'var(--success)': Color(0xFF080808),
        'var(--warning)': Color(0xFF090909),
        'var(--destructive)': Color(0xFF0A0A0A),
      };

      for (final entry in cases.entries) {
        expect(
          beuiChartColor(entry.key, colors),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test(
      'uses explicit and primary fallbacks for missing or invalid colors',
      () {
        const explicitFallback = Color(0xFFABCDEF);
        expect(beuiChartColor(null, colors), const Color(0xFF060606));
        expect(beuiChartColor('', colors), const Color(0xFF060606));
        expect(
          beuiChartColor(null, colors, fallback: explicitFallback),
          explicitFallback,
        );
        expect(
          beuiChartColor('', colors, fallback: explicitFallback),
          explicitFallback,
        );
        expect(
          beuiChartColor('not-a-css-color', colors),
          const Color(0xFF060606),
        );
        expect(
          beuiChartColor('var(--unknown)', colors, fallback: explicitFallback),
          explicitFallback,
        );
        expect(
          beuiChartColor('nope', colors, fallback: explicitFallback),
          explicitFallback,
        );
        expect(beuiChartColor('currentColor', colors), colors.foreground);
      },
    );

    const hugeDecimal =
        '9999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999'
        '9999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999'
        '9999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999'
        '9999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999';
    test('unsupported browser CSS expressions retain both fallbacks', () {
      const fallback = Color(0xFFABCDEF);
      for (final input in [
        'oklch(70% 0.18 155)',
        'oklch(from var(--success) min(l, 0.5) c h)',
        'color-mix(in srgb, var(--success) 22%, transparent)',
        'color(display-p3 1 0 0)',
        'var(--unknown, #ff0000)',
      ]) {
        expect(
          beuiChartColor(input, colors, fallback: fallback),
          fallback,
          reason: input,
        );
        expect(beuiChartColor(input, colors), colors.primary, reason: input);
      }
    });
    for (final entry in {
      'RGB': 'rgb($hugeDecimal 0 0)',
      'RGB percent': 'rgb($hugeDecimal% 0% 0%)',
      'HSL degrees': 'hsl($hugeDecimal 100% 50%)',
      'HSL turns': 'hsl(${hugeDecimal}turn 100% 50%)',
    }.entries) {
      test('non-finite decimal components in ${entry.key} use fallback', () {
        const fallback = Color(0xFFABCDEF);
        final input = entry.value;
        expect(beuiChartColor(input, colors, fallback: fallback), fallback);
        expect(beuiChartColor(input, colors), colors.primary);
      });
    }
    test(
      'finite decimal overflow clamps channels and rejects invalid hues',
      () {
        final finiteDecimal = hugeDecimal.substring(0, 308);
        expect(double.parse(finiteDecimal).isFinite, isTrue);
        expect(
          beuiChartColor('rgb($finiteDecimal% 0% 0%)', colors),
          const Color(0xFFFF0000),
        );
        expect(
          beuiChartColor(
            'hsl(${finiteDecimal}turn 100% 50%)',
            colors,
            fallback: const Color(0xFFABCDEF),
          ),
          const Color(0xFFABCDEF),
        );
      },
    );
  });

  group('beuiChartFormatNumber source outcomes', () {
    final fractionalCases = <num, String>{
      1234.5: '1,234.5',
      12: '12',
      1.005: '1.01',
    };
    for (final entry in fractionalCases.entries) {
      test('formats ${entry.key} with at most two fraction digits', () {
        expect(
          beuiChartFormatNumber(entry.key, maximumFractionDigits: 2),
          entry.value,
        );
      });
    }
    const compactCases = <num, String>{1000: '1K', 1200: '1.2K', 1000000: '1M'};
    for (final entry in compactCases.entries) {
      test('formats ${entry.key} in compact notation', () {
        expect(beuiChartFormatNumber(entry.key, compact: true), entry.value);
      });
    }

    test('minimum precision remains available for fixed-decimal callers', () {
      expect(
        beuiChartFormatNumber(
          100,
          maximumFractionDigits: 2,
          minimumFractionDigits: 2,
        ),
        '100.00',
      );
    });

    test('rounding handles carry, negative values, and zero', () {
      expect(beuiChartFormatNumber(9.999, maximumFractionDigits: 2), '10');
      expect(beuiChartFormatNumber(-1.005, maximumFractionDigits: 2), '-1.01');
      expect(beuiChartFormatNumber(-0.004, maximumFractionDigits: 2), '-0');
      expect(
        beuiChartFormatNumber(1e21, maximumFractionDigits: 2),
        '1,000,000,000,000,000,000,000',
      );
      expect(beuiChartFormatNumber(1e-8, maximumFractionDigits: 2), '0');
      expect(beuiChartFormatNumber(-1e-8, maximumFractionDigits: 2), '-0');
    });

    test(
      'compact formatting trims fractions and promotes rounded thresholds',
      () {
        expect(beuiChartFormatNumber(999.9, compact: true), '999.9');
        expect(beuiChartFormatNumber(999.95, compact: true), '1K');
        expect(beuiChartFormatNumber(-1200, compact: true), '-1.2K');
        expect(
          beuiChartFormatNumber(1200, compact: true, maximumFractionDigits: 0),
          '1.2K',
        );
        expect(beuiChartFormatNumber(999950, compact: true), '1M');
        expect(beuiChartFormatNumber(1e12, compact: true), '1T');
        expect(beuiChartFormatNumber(1e21, compact: true), '1,000,000,000T');
      },
    );

    test('formats non-finite values as en-US Intl does', () {
      expect(beuiChartFormatNumber(double.nan), 'NaN');
      expect(beuiChartFormatNumber(double.infinity), '∞');
      expect(beuiChartFormatNumber(double.negativeInfinity), '-∞');
      expect(beuiChartFormatNumber(double.infinity, compact: true), '∞');
    });
  });
}
