import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

Widget _alert({
  BeuiAlertVariant variant = BeuiAlertVariant.info,
  bool? open,
  bool reduce = false,
  ValueChanged<bool>? onOpenChange,
}) => beuiTestApp(
  BeuiAlert(
    variant: variant,
    open: open,
    onOpenChange: onOpenChange,
    children: const [
      BeuiAlertIcon(),
      BeuiAlertContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BeuiAlertTitle(child: Text('A little heads up')),
            BeuiAlertDescription(
              child: Text('Your changes are saved automatically as you work.'),
            ),
          ],
        ),
      ),
      BeuiAlertClose(),
    ],
  ),
  reduce: reduce,
);

void main() {
  testWidgets('dismiss calls onOpenChange(false) and exits', (tester) async {
    bool? next;
    var open = true;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) => BeuiAlert(
            open: open,
            onOpenChange: (value) {
              next = value;
              setState(() => open = value);
            },
            children: const [BeuiAlertClose(), Text('A little heads up')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dismiss alert'));
    expect(next, isFalse);
    await tester.pumpAndSettle();
    expect(find.text('A little heads up'), findsNothing);
  });

  testWidgets('warning/destructive use alert role; others use status', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    for (final variant in BeuiAlertVariant.values) {
      await tester.pumpWidget(_alert(variant: variant, open: true));
      await tester.pumpAndSettle();
      final expectedRole =
          variant == BeuiAlertVariant.warning ||
              variant == BeuiAlertVariant.destructive
          ? SemanticsRole.alert
          : SemanticsRole.status;
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.role == expectedRole,
        ),
        findsOneWidget,
      );
    }
    handle.dispose();
  });

  testWidgets('reduced motion keeps fade without slide', (tester) async {
    await tester.pumpWidget(_alert(open: true, reduce: true));
    final alert = find.byType(BeuiAlert);
    expect(
      find.descendant(of: alert, matching: find.byType(SlideTransition)),
      findsNothing,
    );
    expect(
      find.descendant(of: alert, matching: find.byType(FadeTransition)),
      findsWidgets,
    );
  });

  testWidgets('rest-state info alert golden', (tester) async {
    await tester.pumpWidget(_alert(open: true, reduce: true));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiAlert),
      matchesGoldenFile('goldens/beui_alert.png'),
    );
  });
}
