import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  testWidgets('long checkbox labels wrap and remain actionable at large text', (
    tester,
  ) async {
    bool checked = false;
    await tester.pumpWidget(
      beuiTestApp(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: StatefulBuilder(
            builder: (context, setState) => BeuiCheckbox(
              label: 'I agree to the Terms and Privacy Policy',
              value: checked,
              onChanged: (value) => setState(() => checked = value),
            ),
          ),
        ),
        width: 220,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final label = find.text('I agree to the Terms and Privacy Policy');
    expect(
      tester.getRect(label).right,
      lessThanOrEqualTo(tester.getRect(find.byType(BeuiCheckbox)).right),
    );
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(checked, isTrue);
  });
}
