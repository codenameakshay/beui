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
//     cosmetic defect at this width, not a blank route. Those are reported
//     below but do not fail, and are listed in `_knownOverflow` so a NEW one
//     stands out.
//
// visual_harness.dart hands demos a bounded height, which is why these routes
// looked fine there and only broke in the gallery.
import 'package:beui/beui.dart';
import 'package:beui_example/explorer/catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Demos that overflow horizontally at the stage width used here. They render;
/// they are not blank. Tracked so a new entry is visible rather than silent.
const _knownOverflow = {'text-animation', 'image-generation', 'loading-states'};

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
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final blank = <String>[];
    final overflow = <String>[];

    for (final entry in kAllEntries) {
      final builder = entry.builder;
      if (builder == null) continue;

      final colors = BeuiColors.of(BeuiColorTheme.defaultMono, Brightness.dark);
      final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
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

    final unexpectedOverflow = overflow
        .where((s) => !_knownOverflow.contains(s))
        .toList();
    // ignore: avoid_print
    print('demos that overflow (render, not blank): $overflow');

    expect(
      blank,
      isEmpty,
      reason:
          'These demos abort layout under an unbounded height, so the gallery '
          'renders an empty pane. Give the subtree a definite height (or '
          'shrinkWrap a root ListView).\n$blank',
    );
    expect(
      unexpectedOverflow,
      isEmpty,
      reason:
          'New horizontal overflow in these demos; add to _knownOverflow only '
          'after confirming it is cosmetic.\n$unexpectedOverflow',
    );
  });
}
