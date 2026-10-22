import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beui/src/motion/timeline.dart';
import '../support.dart';

const _events = [
  BeuiTimelineEvent(
    id: 'beta',
    date: '2025-06-12',
    title: 'Private beta opens',
  ),
  BeuiTimelineEvent(
    id: 'android',
    date: '2025-08-03',
    title: 'Lumen for Android',
  ),
  BeuiTimelineEvent(id: 'offline', date: '2025-10-14', title: 'Offline drafts'),
  BeuiTimelineEvent(
    id: 'signups',
    date: '2025-11-20',
    title: 'Weekly signups double',
  ),
];

Widget _app({
  String? value,
  String? defaultValue,
  ValueChanged<String>? onChanged,
  bool reduce = false,
  double height = 360,
}) => beuiTestApp(
  BeuiTimeline(
    events: _events,
    value: value,
    defaultValue: defaultValue,
    onChanged: onChanged,
    height: height,
  ),
  reduce: reduce,
  width: 800,
);

void main() {
  group('BeuiTimeline selection', () {
    testWidgets('controlled selection reports the requested id', (
      tester,
    ) async {
      String? changed;
      await tester.pumpWidget(
        _app(value: 'beta', onChanged: (id) => changed = id),
      );
      await tester.tap(find.text('Lumen for Android'));
      await tester.pump();
      expect(changed, 'android');
      expect(find.text('Lumen for Android'), findsOneWidget);
    });

    testWidgets(
      'uncontrolled selection starts at defaultValue and changes on tap',
      (tester) async {
        await tester.pumpWidget(_app(defaultValue: 'android'));
        final handle = tester.ensureSemantics();
        expect(
          find.ancestor(
            of: find.text('Lumen for Android'),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.selected == true,
            ),
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Offline drafts'));
        await tester.pump();
        expect(
          find.ancestor(
            of: find.text('Offline drafts'),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.selected == true,
            ),
          ),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets('arrow keys move selection and focus', (tester) async {
      String? changed;
      await tester.pumpWidget(
        _app(defaultValue: 'android', onChanged: (id) => changed = id),
      );
      await tester.tap(find.text('Lumen for Android'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(changed, 'offline');
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(changed, 'signups');
    });

    testWidgets('reduced motion snaps directly to the chosen event', (
      tester,
    ) async {
      String? changed;
      await tester.pumpWidget(
        _app(
          defaultValue: 'beta',
          onChanged: (id) => changed = id,
          reduce: true,
        ),
      );
      await tester.tap(find.text('Private beta opens'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(changed, 'android');
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Aug 3 ’25, Lumen for Android'),
        ),
        isSemantics(isSelected: true),
      );
    });
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(_app(defaultValue: 'offline', height: 360));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiTimeline),
      matchesGoldenFile('goldens/beui_timeline.png'),
    );
  });
}
