import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The letter-spacing a `Text` inside [theme] actually ends up laying out with.
Future<double?> _resolvedTracking(WidgetTester tester, ThemeData theme) async {
  double? tracking;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            tracking = DefaultTextStyle.of(context).style.letterSpacing;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return tracking;
}

void main() {
  group('BeuiTextTheme.trackingNormal', () {
    // Material's 2021 typography bakes a non-zero letterSpacing into every
    // body style, which the Tailwind source never applies; trackingNormal
    // neutralises it.
    testWidgets('trackingNormal blocks it at the DefaultTextStyle', (
      tester,
    ) async {
      final tracking = await _resolvedTracking(
        tester,
        BeuiTextTheme.trackingNormal(ThemeData.light()),
      );
      expect(tracking, 0);
    });

    test('covers every style on both text themes', () {
      final flat = BeuiTextTheme.trackingNormal(ThemeData.dark());
      for (final theme in [flat.textTheme, flat.primaryTextTheme]) {
        final styles = <TextStyle?>[
          theme.displayLarge,
          theme.displayMedium,
          theme.displaySmall,
          theme.headlineLarge,
          theme.headlineMedium,
          theme.headlineSmall,
          theme.titleLarge,
          theme.titleMedium,
          theme.titleSmall,
          theme.bodyLarge,
          theme.bodyMedium,
          theme.bodySmall,
          theme.labelLarge,
          theme.labelMedium,
          theme.labelSmall,
        ];
        expect(styles.whereType<TextStyle>(), hasLength(15));
        for (final s in styles.whereType<TextStyle>()) {
          expect(s.letterSpacing, 0);
        }
      }
    });

    // Material styles leave letterSpacing null often enough that the obvious
    // one-liner — base.apply(letterSpacingFactor: 0) — asserts instead.
    test('survives a text theme whose letterSpacing is unset', () {
      final theme = ThemeData.light().copyWith(
        textTheme: const TextTheme(bodyMedium: TextStyle(fontSize: 14)),
      );
      expect(
        BeuiTextTheme.trackingNormal(theme).textTheme.bodyMedium!.letterSpacing,
        0,
      );
    });

    test('leaves everything except letter-spacing alone', () {
      final base = ThemeData.light().copyWith(
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.5,
            letterSpacing: 0.25,
          ),
        ),
      );
      final style = BeuiTextTheme.trackingNormal(base).textTheme.bodyMedium!;
      expect(style.fontSize, 14);
      expect(style.fontWeight, FontWeight.w500);
      expect(style.height, 1.5);
    });
  });
}
