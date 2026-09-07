// Guards the bug class that made three gallery routes render as a blank pane:
// the explorer lays every demo out inside a SingleChildScrollView, so demos are
// given an UNBOUNDED height. A demo that needs a definite height there —
// `SizedBox.expand`, a `Stack` whose children are all `Positioned`, a bare
// `ListView` — trips an assertion in performLayout and paints NOTHING.
//
// The distinction this test draws:
//   * assertion-class errors ("requires bounded constraints", "forces an
//     infinite", "hasSize") abort layout, so the preview is blank. These FAIL.
//   * a RenderFlex overflow still paints (with the stripe overlay), so it is a
//     cosmetic defect rather than a blank route — but it is still a defect, so
//     it fails too. There are currently none.
//
// visual_harness.dart hands demos a bounded height, which is why these routes
// looked fine there and only broke in the gallery.
import 'package:beui/beui.dart';
import 'package:beui_example/explorer/catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Errors raised while the previous demo is torn down, not by the demo under
/// test. Attributing these to the next slug produces false positives.
bool _isTeardownNoise(Object e) {
  final s = e.toString();
  return s.contains('deactivated widget') ||
      s.contains('Timer is still pending') ||
      s.contains('was used after being disposed');
}

bool _isBlankMaking(Object e) {
  final s = e.toString();
  return s.contains('requires bounded constraints') ||
      s.contains('forces an infinite') ||
      s.contains('hasSize') ||
      s.contains('size.isFinite');
}

void main() {
  testWidgets('no demo goes blank under an unbounded height', (tester) async {
    // 760 stage - 2x32 PreviewSurface padding = 696, the width a demo
    // actually gets in the explorer on a wide screen (1120 content column,
    // minus 40px page padding each side, minus the 240px rail and its 40 gap).
    tester.view.physicalSize = const Size(760, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final blank = <String>[];
    final overflow = <String>[];

    for (final entry in kAllEntries) {
      final builder = entry.builder;

      final colors = BeuiColors.of(BeuiColorTheme.defaultMono, Brightness.dark);
      // `fontFamily: 'Geist'` mirrors explorer_app.dart. Without it the tree
      // renders in the fallback test face, whose wider metrics manufacture
      // overflow that does not exist in the gallery.
      final base = ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'Geist',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: base.copyWith(extensions: [colors]),
          home: Scaffold(
            // The explorer's PreviewSurface, reduced to its constraint shape.
            body: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 360),
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Builder(builder: builder),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      final errs = <Object>[];
      Object? e;
      while ((e = tester.takeException()) != null) {
        errs.add(e!);
      }

      // Drop teardown noise from the PREVIOUS entry: replacing the tree
      // disposes the old demo during this pump, and its disposal error would
      // otherwise be blamed on this slug (bounce-sidebar was blamed this way,
      // yet is clean when pumped on its own).
      errs.removeWhere(_isTeardownNoise);

      if (errs.any(_isBlankMaking)) {
        blank.add(entry.slug);
      } else if (errs.isNotEmpty) {
        overflow.add(entry.slug);
      }
    }

    // An unbounded viewport makes infinite-masonry's fill check schedule a
    // load timer; tear the last tree down and let it fire, or the binding's
    // end-of-test invariant trips on a pending timer.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    while (tester.takeException() != null) {}

    expect(
      blank,
      isEmpty,
      reason:
          'These demos abort layout under an unbounded height, so the gallery '
          'renders an empty pane. Give the subtree a definite height (or '
          'shrinkWrap a root ListView).\n$blank',
    );
    expect(
      overflow,
      isEmpty,
      reason:
          'These demos overflow horizontally at the width the gallery gives '
          'them. They still paint, so the route is not blank, but the content '
          'is clipped.\n$overflow',
    );
  });
}
