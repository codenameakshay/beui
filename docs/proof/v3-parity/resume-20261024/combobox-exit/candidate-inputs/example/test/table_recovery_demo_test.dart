import 'package:beui/beui.dart';
import 'package:beui_example/demos/table_demo.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support.dart';

void main() {
  for (final reduce in [false, true]) {
    testWidgets(
      'recovery composition deletes the last row and restores one, reduce=$reduce',
      (tester) async {
        await tester.pumpWidget(
          beuiTestApp(
            SizedBox(
              width: 592,
              child: Builder(
                builder: (context) =>
                    tableDemo(context, example: 'editable-recovery'),
              ),
            ),
            reduce: reduce,
          ),
        );
        await tester.pumpAndSettle();
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        for (final name in ['Ava Cole', 'Leo Frost', 'Mia Vale', 'Kai Reyes']) {
          final cell = find.widgetWithText(TextField, name);
          expect(cell.hitTestable(), findsOneWidget);
          await mouse.moveTo(tester.getCenter(cell));
          await tester.pump();
          final handle = find.byIcon(LucideIcons.ellipsis_vertical);
          expect(handle.hitTestable(), findsOneWidget);
          await tester.tap(handle);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Delete row').hitTestable());
          await tester.pumpAndSettle();
          await mouse.moveTo(Offset.zero);
          await tester.pump(const Duration(milliseconds: 160));
        }
        final insert = find.text('Insert first row').hitTestable();
        expect(insert, findsOneWidget);
        await tester.tap(insert);
        await tester.pumpAndSettle();
        expect(find.text('Insert first row'), findsNothing);
        expect(find.byType(TextField).hitTestable(), findsNWidgets(6));
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
