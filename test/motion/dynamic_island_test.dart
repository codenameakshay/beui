import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

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
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
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

    // The source's sizer is `w-max`, but it is also a flex item of the shell
    // and the shell's width is driven *from* the sizer's measured width, so
    // the two settle at the content's min-content width. beui.dev renders
    // "INCOMING / CALL" and "Midnight / City" wrapped at the longest word;
    // the port has to size the same way, not at the natural one-line width.
    testWidgets('a view rests at its min-content width, wrapping at the '
        'longest word', (tester) async {
      const label = 'INCOMING CALL';

      await tester.pumpWidget(
        _wrap(
          const BeuiDynamicIsland(
            view: 'call',
            compact: Text('REC'),
            views: [
              BeuiDynamicIslandView(
                id: 'call',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(label, style: TextStyle(fontSize: 10)),
                    ),
                    SizedBox(width: 72, height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The test font is one em per glyph: 'INCOMING' is 80px, the whole
      // label 130px. px-6 (48) + longest word (80) + the 72px trailing block.
      final shell = tester.getSize(find.byType(BeuiDynamicIsland));
      expect(shell.width, moreOrLessEquals(48 + 80 + 72, epsilon: 4));
      expect(
        shell.width,
        lessThan(48 + 130 + 72),
        reason: 'must not rest at the one-line (max-content) width',
      );
      // Two line boxes, not one.
      expect(tester.getSize(find.text(label)).height, greaterThan(15));
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
      expect(maxBlurSigma(tester), greaterThan(0.5));
    });

    testWidgets('reduced motion snaps the size with no blur', (tester) async {
      await tester.pumpWidget(_wrap(_island(null), reduce: true));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(_wrap(_island('timer'), reduce: true));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(maxBlurSigma(tester), lessThan(0.5));
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
