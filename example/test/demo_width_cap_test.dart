// Guards a layout bug that has bitten this gallery repeatedly: a max-width cap
// written as a bare `ConstrainedBox(maxWidth: N)` or `SizedBox(width: N)` only
// holds under LOOSE incoming constraints. Both lay the child out with
// `additionalConstraints.enforce(incoming)`, so a parent that hands down a
// TIGHT width discards the cap and the demo renders full-bleed — silently
// wider than the beui.dev preview it mirrors.
//
// The fix is always the same: wrap in `Align`/`Center`, which loosens, and is
// a no-op when the parent is already loose.
//
// Today both real render paths (the explorer's PreviewSurface and
// visual_harness.dart) hand down loose width, so a defeat here is latent
// rather than live — but it becomes live the moment a stage stops centring.
import 'package:beui/beui.dart';
import 'package:beui_example/explorer/catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Width of the visual-pass preview band, and of the explorer's stage.
const double _kStage = 824;

/// Real Tailwind `max-w-*` caps in this gallery start at 320 (`max-w-xs`).
/// Below that the RenderConstrainedBox hits are framework internals — Icon's
/// SizedBox, `SizedBox.shrink` placeholders — which "defeat" harmlessly.
const double _kMinRealCap = 240;

/// Every finite width cap in the tree, paired with its laid-out width.
List<({double cap, double actual})> _caps(RenderObject root) {
  final out = <({double cap, double actual})>[];
  void walk(RenderObject node) {
    if (node is RenderConstrainedBox) {
      final cap = node.additionalConstraints.maxWidth;
      if (cap.isFinite && cap >= _kMinRealCap && node.hasSize) {
        out.add((cap: cap, actual: node.size.width));
      }
    }
    node.visitChildren(walk);
  }

  walk(root);
  return out;
}

Widget _wrap(Widget child) {
  final colors = BeuiColors.of(BeuiColorTheme.defaultMono, Brightness.dark);
  // `fontFamily: 'Geist'` mirrors explorer_app.dart and visual_harness.dart.
  // flutter_test_config.dart registers the real face; without asking for it
  // here the tree renders in the much wider fallback test font, which
  // manufactures RenderFlex overflow that does not exist in the gallery.
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: 'Geist',
  );
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: base.copyWith(
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      extensions: [colors],
      colorScheme: base.colorScheme.copyWith(
        surface: colors.background,
        primary: colors.primary,
        onPrimary: colors.primaryForeground,
        secondary: colors.secondary,
        onSurface: colors.foreground,
        outline: colors.border,
        error: colors.destructive,
      ),
      splashFactory: NoSplash.splashFactory,
    ),
    home: Scaffold(backgroundColor: colors.background, body: child),
  );
}

void main() {
  testWidgets('no demo width cap is defeated by a tight-width parent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(_kStage, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final defeated = <String>[];

    for (final entry in kAllEntries) {
      final builder = entry.builder;
      if (builder == null) continue;

      await tester.pumpWidget(
        _wrap(
          Align(
            alignment: Alignment.topCenter,
            // A tight width — the constraint shape that discards the cap.
            child: SizedBox(
              width: _kStage,
              child: Builder(builder: builder),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      // Demos may throw while pumping in isolation; that is a separate
      // concern from this assertion, so drain rather than fail here.
      while (tester.takeException() != null) {}

      for (final hit in _caps(tester.renderObject(find.byType(Scaffold)))) {
        // The SizedBox above is itself a cap at exactly _kStage; skip it.
        if (hit.cap == _kStage) continue;
        if (hit.actual > hit.cap + 0.5) {
          defeated.add(
            '${entry.slug}: cap=${hit.cap.toStringAsFixed(0)} '
            'rendered=${hit.actual.toStringAsFixed(1)}',
          );
        }
      }
    }

    // With real Geist metrics the masonry demo fits fewer items per column, so
    // its fill check schedules a load timer. Tear the last tree down and let it
    // fire, or the binding's end-of-test invariant trips on a pending timer.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    while (tester.takeException() != null) {}

    expect(
      defeated,
      isEmpty,
      reason:
          'These demos lose their max-width cap under a tight-width parent.\n'
          'Wrap the capped subtree in Align(alignment: Alignment.center, ...) '
          'or Center — it loosens the constraints and is a no-op when the '
          'parent is already loose.\n${defeated.join("\n")}',
    );
  });
}
