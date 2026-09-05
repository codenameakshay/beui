import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduce = false}) {
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
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: body),
  );
}

void main() {
  group('BeuiExpandingArrowButton', () {
    testWidgets('tap fires onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiExpandingArrowButton(
            onPressed: () => taps++,
            child: const Text('Book a demo'),
          ),
        ),
      );
      await tester.tap(find.byType(BeuiExpandingArrowButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('disabled does not fire', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiExpandingArrowButton(
            onPressed: null,
            child: const Text('Book a demo'),
          ),
        ),
      );
      await tester.tap(
        find.byType(BeuiExpandingArrowButton),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(taps, 0);
    });
  });

  group('BeuiHoldActionButton', () {
    testWidgets('completes after hold duration', (tester) async {
      var done = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiHoldActionButton(
            holdDuration: const Duration(milliseconds: 200),
            onHoldComplete: () => done++,
            child: const Text('Hold me'),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(BeuiHoldActionButton));
      final gesture = await tester.startGesture(center);
      // Let the pointer land, then advance past holdDuration.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(done, 1);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('release early cancels', (tester) async {
      var done = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiHoldActionButton(
            holdDuration: const Duration(milliseconds: 800),
            onHoldComplete: () => done++,
            child: const Text('Hold me'),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(BeuiHoldActionButton));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(done, 0);
    });
  });

  group('BeuiSlideActionButton', () {
    testWidgets('dragging the thumb past threshold completes', (tester) async {
      var done = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiSlideActionButton(
            threshold: 0.5,
            resetDelay: const Duration(seconds: 10),
            onComplete: () => done++,
            child: const Text('Slide'),
          ),
        ),
      );
      await tester.pump();
      // Drag from the thumb's own hit region (not the track's centre, which
      // sits well past the thumb's 56px width and never delivered pan
      // events to it).
      final thumb = find.byKey(const ValueKey('beui-slide-action-thumb'));
      await tester.timedDrag(
        thumb,
        const Offset(220, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(done, 1);
    });
  });
}
