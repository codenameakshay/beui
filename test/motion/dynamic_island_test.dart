import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = Align(alignment: Alignment.topCenter, child: child);
  if (reduce) {
    final inner = body;
    body = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: body),
  );
}

BeuiDynamicIsland _island(String? view, {bool compactDot = true}) =>
    BeuiDynamicIsland(
      view: view,
      compact: compactDot ? const Text('REC') : null,
      views: const [
        BeuiDynamicIslandView(
          id: 'timer',
          child: SizedBox(
            width: 220,
            height: 64,
            child: Center(child: Text('Timer running')),
          ),
        ),
        BeuiDynamicIslandView(
          id: 'call',
          child: SizedBox(
            width: 260,
            height: 48,
            child: Center(child: Text('Incoming call')),
          ),
        ),
      ],
    );

double _maxBlurSigma(WidgetTester tester) => tester
    .widgetList<ImageFiltered>(find.byType(ImageFiltered))
    .map((f) {
      final m = RegExp(r'blur\(([\d.]+)').firstMatch(f.imageFilter.toString());
      return m == null ? 0.0 : double.parse(m.group(1)!);
    })
    .fold<double>(0, math.max);

void main() {
  group('BeuiDynamicIsland', () {
    testWidgets('renders the compact pill at ~126x37', (tester) async {
      await tester.pumpWidget(_wrap(_island(null)));
      await tester.pumpAndSettle();
      expect(find.text('REC'), findsOneWidget);
      final size = tester.getSize(find.byType(BeuiDynamicIsland));
      expect(size.width, moreOrLessEquals(126, epsilon: 2));
      expect(size.height, moreOrLessEquals(37, epsilon: 2));
    });

    testWidgets('expanding springs the shell to the view size', (tester) async {
      await tester.pumpWidget(_wrap(_island(null)));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_wrap(_island('timer')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 120)); // mid-spring
      final mid = tester.getSize(find.byType(BeuiDynamicIsland));
      expect(mid.width, greaterThan(126));
      expect(mid.width, lessThan(264), reason: 'still springing');

      await tester.pumpAndSettle();
      final settled = tester.getSize(find.byType(BeuiDynamicIsland));
      expect(settled.width, moreOrLessEquals(220 + 48, epsilon: 2));
      expect(settled.height, moreOrLessEquals(64 + 32, epsilon: 2));
      expect(find.text('Timer running'), findsOneWidget);
      expect(find.text('REC'), findsNothing);
    });

    testWidgets('switching views swaps content and resizes', (tester) async {
      await tester.pumpWidget(_wrap(_island('timer')));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_wrap(_island('call')));
      await tester.pumpAndSettle();
      expect(find.text('Incoming call'), findsOneWidget);
      expect(find.text('Timer running'), findsNothing);
      final size = tester.getSize(find.byType(BeuiDynamicIsland));
      expect(size.width, moreOrLessEquals(260 + 48, epsilon: 2));
      expect(size.height, moreOrLessEquals(48 + 32, epsilon: 2));
    });

    testWidgets('collapsing returns to the pill and compact content', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_island('timer')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_wrap(_island(null)));
      await tester.pumpAndSettle();
      expect(find.text('REC'), findsOneWidget);
      expect(find.text('Timer running'), findsNothing);
      final size = tester.getSize(find.byType(BeuiDynamicIsland));
      expect(size.width, moreOrLessEquals(126, epsilon: 2));
      expect(size.height, moreOrLessEquals(37, epsilon: 2));
    });

    testWidgets('shell radius stays constant at 32', (tester) async {
      await tester.pumpWidget(_wrap(_island('timer')));
      await tester.pump(const Duration(milliseconds: 100));
      final boxes = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(BeuiDynamicIsland),
          matching: find.byType(Container),
        ),
      );
      final radii = boxes
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.borderRadius)
          .whereType<BorderRadius>()
          .map((r) => r.topLeft.x);
      expect(radii, contains(32.0));
    });

    testWidgets('content enters with blur under normal motion', (tester) async {
      await tester.pumpWidget(_wrap(_island(null)));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_wrap(_island('timer')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40)); // mid-enter
      expect(_maxBlurSigma(tester), greaterThan(0.5));
    });

    testWidgets('reduced motion snaps the size with no blur', (tester) async {
      await tester.pumpWidget(_wrap(_island(null), reduce: true));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(_wrap(_island('timer'), reduce: true));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(_maxBlurSigma(tester), lessThan(0.5));
      }
      final size = tester.getSize(find.byType(BeuiDynamicIsland));
      expect(size.width, moreOrLessEquals(220 + 48, epsilon: 2));
    });

    testWidgets('announces as a polite live region', (tester) async {
      await tester.pumpWidget(_wrap(_island(null)));
      await tester.pumpAndSettle();
      final live = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.liveRegion ?? false),
      );
      expect(live, findsAtLeastNWidgets(1));
    });
  });
}
