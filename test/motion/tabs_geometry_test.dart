import 'dart:io';

import 'package:beui/beui.dart';
import 'package:beui/src/motion/tabs.dart' show beuiTabsIndicatorKey;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

Rect _triggerRect(WidgetTester tester, String label) => tester.getRect(
  find
      .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
      .first,
);

Widget _host(Widget tabs, {bool dark = false, bool reduce = false}) =>
    beuiTestApp(
      Column(mainAxisSize: MainAxisSize.min, children: [tabs]),
      alignment: Alignment.topLeft,
      fontFamily: 'actualGeist',
      dark: dark,
      reduce: reduce,
    );

Widget _alertTabs() => BeuiTabs<String>(
  triggerPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  tabs: [
    for (final label in ['Info', 'Success', 'Warning', 'Error'])
      BeuiTab(
        value: label,
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, height: 16 / 12),
        ),
      ),
  ],
);

void main() {
  setUpAll(() async {
    final font = FontLoader('actualGeist')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            await File('example/assets/fonts/Geist-Medium.ttf').readAsBytes(),
          ),
        ),
      );
    await font.load();
  });

  // a76e57c9 AlertPreview uses px-3 py-1.5 text-xs. Expected widths are
  // from the 1280x1000 DPR1 source capture in round2/measurements-2.
  for (final dark in [false, true]) {
    for (final reduce in [false, true]) {
      testWidgets('compact Alert geometry dark=$dark reduce=$reduce', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            _host(_alertTabs(), dark: dark, reduce: reduce),
          );
          await tester.pumpAndSettle();

          final expectedWidths = {
            'Info': 45.65625,
            'Success': 71.59375,
            'Warning': 70.484375,
            'Error': 51.53125,
          };
          Rect? previous;
          for (final entry in expectedWidths.entries) {
            final rect = _triggerRect(tester, entry.key);
            expect(rect.height, 28);
            expect(rect.width, closeTo(entry.value, 0.05));
            expect(rect.top, 4);
            if (previous != null) expect(rect.left - previous.right, 4);
            previous = rect;

            await tester.tap(find.text(entry.key));
            await tester.pumpAndSettle();
            expect(
              tester.getRect(find.byKey(beuiTabsIndicatorKey)),
              rectMoreOrLessEquals(rect, epsilon: 0.001),
            );
            expect(
              tester.getSemantics(find.text(entry.key)),
              isSemantics(isSelected: true, isButton: true),
            );
          }

          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyEvent(LogicalKeyboardKey.home);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
          expect(
            tester.getRect(find.byKey(beuiTabsIndicatorKey)),
            rectMoreOrLessEquals(
              _triggerRect(tester, 'Success'),
              epsilon: 0.001,
            ),
          );
        } finally {
          semantics.dispose();
        }
      });
    }
  }

  // Live TabsPreview computed geometry, checked against pinned tabs.tsx
  // px-3.5 py-1.5 text-sm and underline px-3 pt-1 pb-2.5 min-h-[44px].
  for (final (variant, labels, widths, height, gap, inset) in [
    (
      BeuiTabsVariant.pill,
      ['Overview', 'Activity', 'Settings'],
      [89.3046875, 77.9375, 82.671875],
      32.0,
      4.0,
      4.0,
    ),
    (
      BeuiTabsVariant.segment,
      ['Day', 'Week', 'Month'],
      [53.2109375, 65.3125, 69.953125],
      32.0,
      0.0,
      2.0,
    ),
    (
      BeuiTabsVariant.underline,
      ['All', 'Open', 'Closed'],
      [41.1015625, 59.0859375, 69.5859375],
      44.0,
      4.0,
      0.0,
    ),
  ]) {
    testWidgets('$variant preserves source default trigger geometry', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          BeuiTabs<String>(
            variant: variant,
            tabs: [
              for (final label in labels)
                BeuiTab(value: label, label: Text(label)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      Rect? previous;
      for (var i = 0; i < labels.length; i++) {
        final rect = _triggerRect(tester, labels[i]);
        expect(rect.height, height);
        expect(rect.width, closeTo(widths[i], 0.05));
        expect(rect.top, inset);
        if (previous != null) expect(rect.left - previous.right, gap);
        previous = rect;
      }
    });
  }

  testWidgets('shader caller padding keeps its larger 36px trigger', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        BeuiTabs<String>(
          wrap: true,
          gap: 8,
          triggerPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          tabs: const [
            BeuiTab(value: 'Overview', label: Text('Overview')),
            BeuiTab(value: 'Activity', label: Text('Activity')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final overview = _triggerRect(tester, 'Overview');
    final activity = _triggerRect(tester, 'Activity');
    expect(overview.height, 36);
    expect(overview.width, closeTo(93.3046875, 0.05));
    expect(activity.height, 36);
    expect(activity.width, closeTo(81.9375, 0.05));
    expect(activity.left - overview.right, 8);
  });
}
