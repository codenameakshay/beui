import 'package:beui_example/demos/tooltip_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support.dart';

void main() {
  testWidgets(
    'placement preview has source line metrics and whole-pixel triggers',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(Builder(builder: tooltipDemo), fontFamily: 'Geist'),
      );
      await tester.pumpAndSettle();
      final top = find.ancestor(
        of: find.text('Top'),
        matching: find.byType(InkWell),
      );
      expect(tester.getRect(top), const Rect.fromLTWH(360, 196, 80, 40));
      final hint = tester.widget<Text>(
        find.text('Hover or focus. Press Esc to dismiss.'),
      );
      expect(hint.style!.height, 16 / 12);
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Top'), findsOneWidget);
      semantics.dispose();
    },
  );
}
