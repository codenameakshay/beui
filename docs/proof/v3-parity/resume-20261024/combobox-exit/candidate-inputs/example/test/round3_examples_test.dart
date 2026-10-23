import 'package:beui/beui.dart';
import 'package:beui_example/demos/button_demo.dart';
import 'package:beui_example/demos/range_slider_demo.dart';
import 'package:beui_example/demos/table_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support.dart';

void main() {
  for (final reduce in [false, true]) {
    testWidgets(
      'stateful previews finish both source lifecycles, reduce=$reduce',
      (tester) async {
        await tester.pumpWidget(
          beuiTestApp(
            Builder(
              builder: (context) => buttonDemo(context, example: 'stateful'),
            ),
            reduce: reduce,
          ),
        );
        for (final flow in [
          ('Save changes', 'Saving', 'Saved'),
          ('Submit', 'Submitting', 'Failed'),
        ]) {
          await tester.tap(find.text(flow.$1));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 650));
          expect(find.text(flow.$2), findsOneWidget);
          final busy = tester.widget<BeuiButton>(
            find
                .ancestor(
                  of: find.text(flow.$2),
                  matching: find.byType(BeuiButton),
                )
                .first,
          );
          expect(busy.onPressed, isNull);
          await tester.pump(const Duration(milliseconds: 749));
          expect(find.text(flow.$2), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 1));
          await tester.pump(const Duration(milliseconds: 650));
          expect(find.text(flow.$3), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 1149));
          expect(find.text(flow.$3), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 1));
          await tester.pump(const Duration(milliseconds: 650));
          expect(find.text(flow.$1), findsOneWidget);
          await tester.pump(const Duration(milliseconds: 400));
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'inline example owns its value and keyboard reaches the source bound',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          Builder(
            builder: (context) => rangeSliderDemo(context, example: 'inline'),
          ),
        ),
      );
      await tester.tap(find.byType(BeuiInlineSlider));
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pump();
      expect(find.text('128'), findsOneWidget);
    },
  );

  testWidgets('editable example clips to the source body height', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        SizedBox(
          width: 592,
          child: Builder(
            builder: (context) => tableDemo(context, example: 'editable'),
          ),
        ),
      ),
    );
    await tester.pump();
    final table = tester.widget<BeuiTable>(
      find.byWidgetPredicate((w) => w is BeuiTable),
    );
    expect(table.height, 192);
    expect(table.borderRadius, BorderRadius.zero);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 700));
  });
}
