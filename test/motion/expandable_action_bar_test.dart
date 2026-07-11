import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
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
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: body),
  );
}

List<BeuiExpandableActionBarItem> _items({
  List<String>? tapped,
  bool disableSecond = false,
}) => [
  BeuiExpandableActionBarItem(
    id: 'inbox',
    label: 'Inbox',
    icon: LucideIcons.inbox,
    badge: const Text('3'),
    onPressed: () => tapped?.add('inbox'),
  ),
  BeuiExpandableActionBarItem(
    id: 'send',
    label: 'Send',
    icon: LucideIcons.send,
    disabled: disableSecond,
    onPressed: () => tapped?.add('send'),
  ),
  BeuiExpandableActionBarItem(
    id: 'archive',
    label: 'Archive',
    icon: LucideIcons.archive,
    active: true,
    onPressed: () => tapped?.add('archive'),
  ),
];

double _maxBlurSigma(WidgetTester tester) => tester
    .widgetList<ImageFiltered>(find.byType(ImageFiltered))
    .map((f) {
      final m = RegExp(r'blur\(([\d.]+)').firstMatch(f.imageFilter.toString());
      return m == null ? 0.0 : double.parse(m.group(1)!);
    })
    .fold<double>(0, math.max);

Future<TestGesture> _mouse(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await tester.pump();
  return gesture;
}

void main() {
  group('BeuiExpandableActionBar', () {
    testWidgets('collapsed rail is icon-only; hover expands the labels', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(BeuiExpandableActionBar(items: _items())));
      await tester.pumpAndSettle();
      final collapsed = tester
          .getSize(find.byType(BeuiExpandableActionBar))
          .width;

      final gesture = await _mouse(tester);
      await gesture.moveTo(
        tester.getCenter(find.byType(BeuiExpandableActionBar)),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      final expanded = tester
          .getSize(find.byType(BeuiExpandableActionBar))
          .width;
      expect(expanded, greaterThan(collapsed + 60));

      // Leaving collapses again after the 90ms delay.
      await gesture.moveTo(Offset.zero);
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();
      final closed = tester.getSize(find.byType(BeuiExpandableActionBar)).width;
      expect(closed, moreOrLessEquals(collapsed, epsilon: 2));
    });

    testWidgets('controlled expanded renders wide without hover', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(BeuiExpandableActionBar(items: _items(), expanded: false)),
      );
      await tester.pumpAndSettle();
      final collapsed = tester
          .getSize(find.byType(BeuiExpandableActionBar))
          .width;
      await tester.pumpWidget(
        _wrap(BeuiExpandableActionBar(items: _items(), expanded: true)),
      );
      await tester.pumpAndSettle();
      final expanded = tester
          .getSize(find.byType(BeuiExpandableActionBar))
          .width;
      expect(expanded, greaterThan(collapsed + 60));
    });

    testWidgets('tapping an item fires callbacks', (tester) async {
      final tapped = <String>[];
      final actions = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiExpandableActionBar(
            items: _items(tapped: tapped),
            onAction: (item) => actions.add(item.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pumpAndSettle();
      expect(tapped, ['send']);
      expect(actions, ['send']);
    });

    testWidgets('disabled items do not fire', (tester) async {
      final tapped = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiExpandableActionBar(
            items: _items(tapped: tapped, disableSecond: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.send), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tapped, isEmpty);
    });

    testWidgets('the active item carries the highlight pill', (tester) async {
      await tester.pumpWidget(_wrap(BeuiExpandableActionBar(items: _items())));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 50));
      // Highlight = hovered ?? active ('archive' is active) — a translucent
      // primary pill layer must be present.
      final colors = BeuiColors.light();
      final pill = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(BeuiExpandableActionBar),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where(
            (d) =>
                d.color != null &&
                d.color!.a > 0.01 &&
                d.color!.a < 0.2 &&
                (d.color!.r - colors.primary.r).abs() < 0.02,
          );
      expect(pill, isNotEmpty);
    });

    testWidgets('badge renders', (tester) async {
      await tester.pumpWidget(_wrap(BeuiExpandableActionBar(items: _items())));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('reduced motion expands without blur', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiExpandableActionBar(items: _items(), expanded: true),
          reduce: true,
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(_maxBlurSigma(tester), lessThan(0.5));
      }
    });
  });
}
