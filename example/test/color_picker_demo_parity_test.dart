import 'package:beui/beui.dart';
import 'package:beui_example/demos/color_picker_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support.dart';

void main() {
  testWidgets(
    'brand picker keeps source placement and cycles channel formats',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          SizedBox(width: 592, child: Builder(builder: colorPickerDemo)),
        ),
      );
      final trigger = find.byType(BeuiColorPickerTrigger);
      final demo = find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == 460,
      );
      expect(tester.getTopLeft(trigger).dy - tester.getTopLeft(demo).dy, 8);
      expect(tester.getSize(trigger).height, 40);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(find.byType(BeuiColorPickerHex), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Format HEX, switch to RGB'));
      await tester.pumpAndSettle();
      expect(find.byType(BeuiColorPickerHex), findsNothing);
      expect(
        tester
            .widget<BeuiColorPickerChannels>(
              find.byType(BeuiColorPickerChannels),
            )
            .format,
        BeuiColorFormat.rgb,
      );
      expect(find.byType(BeuiColorPickerSwatch), findsNothing);
      await tester.tap(find.bySemanticsLabel('Format RGB, switch to HSL'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BeuiColorPickerChannels>(
              find.byType(BeuiColorPickerChannels),
            )
            .format,
        BeuiColorFormat.hsl,
      );
      await tester.tap(find.bySemanticsLabel('Format HSL, switch to HEX'));
      await tester.pumpAndSettle();
      expect(find.byType(BeuiColorPickerHex), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Red'));
      await tester.pumpAndSettle();
      expect(find.text('#E55656'), findsOneWidget);
    },
  );
}
