/// Shared scaffolding for the widget tests.
///
/// Every component test pumps the same themed `MaterialApp`; keep that shape
/// here so a theme change lands in one place.
library;

import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A `MaterialApp` carrying the neutral beUI palette, with [child] centred in
/// a `Scaffold`. [reduce] turns on `disableAnimations` for the subtree so a
/// test can assert the reduced-motion path.
Widget beuiTestApp(
  Widget child, {
  bool reduce = false,
  Brightness brightness = Brightness.light,
}) {
  Widget body = Center(child: child);
  if (reduce) {
    final inner = body;
    body = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  final base = brightness == Brightness.dark
      ? ThemeData.dark()
      : ThemeData.light();
  final colors = brightness == Brightness.dark
      ? BeuiColors.dark()
      : BeuiColors.light();
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(base.copyWith(extensions: [colors])),
    home: Scaffold(body: body),
  );
}

/// The largest blur sigma currently applied by any `ImageFiltered` in the
/// tree, or 0 when nothing is blurred.
double maxBlurSigma(WidgetTester tester) => tester
    .widgetList<ImageFiltered>(find.byType(ImageFiltered))
    .map((f) {
      final m = RegExp(r'blur\(([\d.]+)').firstMatch(f.imageFilter.toString());
      return m == null ? 0.0 : double.parse(m.group(1)!);
    })
    .fold<double>(0, math.max);

/// Pumps [count] frames of [frame] each, for surfaces whose tickers never
/// settle and therefore cannot use `pumpAndSettle`.
Future<void> pumpFrames(
  WidgetTester tester,
  int count, {
  Duration frame = const Duration(milliseconds: 20),
}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(frame);
  }
}

/// Source-over composite of [src] onto an opaque [dst].
Color composite(Color src, Color dst) {
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
double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
