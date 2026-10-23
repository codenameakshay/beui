import 'package:beui/beui.dart';
import 'package:beui_example/demos/alert_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support.dart';

void main() {
  testWidgets('Alert caller keeps source tab metrics and muted list', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(Builder(builder: alertDemo), fontFamily: 'Geist'),
    );
    await tester.pumpAndSettle();
    for (final (label, width) in [
      ('Info', 45.65625),
      ('Success', 71.59375),
      ('Warning', 70.484375),
      ('Error', 51.53125),
    ]) {
      final trigger = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.selected != null,
        ),
      );
      expect(tester.getSize(trigger).height, 28);
      expect(tester.getSize(trigger).width, closeTo(width, .05));
    }
    final tabs = find.byType(BeuiTabs<BeuiAlertVariant>);
    final colors = BeuiColors.resolve(tester.element(tabs));
    expect(colors.card, colors.muted);
    await tester.tap(find.text('Warning'));
    await tester.pumpAndSettle();
    expect(find.text('Almost at the limit'), findsOneWidget);
    await tester.tap(find.text('Error'));
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
  });
}
