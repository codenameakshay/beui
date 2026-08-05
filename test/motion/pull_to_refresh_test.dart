import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = child;
  if (reduce) {
    body = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child,
      ),
    );
  }
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(
      body: Center(child: SizedBox(width: 320, height: 400, child: body)),
    ),
  );
}

void main() {
  group('BeuiPullToRefresh', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiPullToRefresh(onRefresh: () {}, child: const Text('Feed body')),
        ),
      );
      await tester.pump();
      expect(find.text('Feed body'), findsOneWidget);
    });

    testWidgets('calls onRefresh when released past threshold', (tester) async {
      var calls = 0;
      final done = Completer<void>();

      await tester.pumpWidget(
        _wrap(
          BeuiPullToRefresh(
            threshold: 76,
            onRefresh: () async {
              calls++;
              await Future<void>.delayed(const Duration(milliseconds: 50));
              done.complete();
            },
            child: const SizedBox(height: 600, child: Text('Pull me')),
          ),
        ),
      );
      await tester.pump();

      final center = tester.getCenter(find.byType(BeuiPullToRefresh));
      // Drag well past threshold (raw distance is resisted; need ~200+ raw).
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(0, 220));
      await tester.pump();
      expect(find.text('Release to refresh'), findsOneWidget);

      await gesture.up();
      await tester.pump(); // start refresh
      expect(calls, 1);
      expect(find.text('Refreshing'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 80));
      await done.future;
      await tester.pump(); // settle after complete
      await tester.pump(const Duration(milliseconds: 400));
      // Back to idle — refresh finished exactly once.
      expect(calls, 1);
      expect(find.text('Refreshing'), findsNothing);
    });

    testWidgets('disabled does not pull', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiPullToRefresh(
            disabled: true,
            onRefresh: () => calls++,
            child: const SizedBox(height: 600, child: Text('Locked')),
          ),
        ),
      );
      await tester.pump();

      final center = tester.getCenter(find.byType(BeuiPullToRefresh));
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(0, 220));
      await tester.pump();
      expect(find.text('Release to refresh'), findsNothing);
      await gesture.up();
      await tester.pump();
      expect(calls, 0);
    });

    testWidgets('reduced motion still renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiPullToRefresh(
            onRefresh: () {},
            child: const Text('Reduced feed'),
          ),
          reduce: true,
        ),
      );
      await tester.pump();
      expect(find.text('Reduced feed'), findsOneWidget);
      expect(find.byType(BeuiPullToRefresh), findsOneWidget);
    });

    testWidgets('external refreshing holds indicator', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiPullToRefresh(
            refreshing: true,
            onRefresh: () {},
            child: const SizedBox(height: 400, child: Text('Busy')),
          ),
        ),
      );
      // Let spring settle toward holdDistance so opacity > 0.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Refreshing'), findsOneWidget);
      expect(find.text('Busy'), findsOneWidget);
    });
  });
}
