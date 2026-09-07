import 'package:beui/src/motion/_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  testWidgets('reduced motion stops the shared spinner ticker', (tester) async {
    Finder rotation() => find.descendant(
      of: find.byType(BeuiSpinner),
      matching: find.byType(RotationTransition),
    );
    double turns() => tester.widget<RotationTransition>(rotation()).turns.value;

    const spinner = BeuiSpinner(size: 16, color: Color(0xFF000000));
    await tester.pumpWidget(beuiTestApp(spinner));
    await tester.pump(const Duration(milliseconds: 100));
    final before = turns();
    await tester.pump(const Duration(milliseconds: 100));
    final after = turns();
    expect(rotation(), findsOneWidget);
    expect(after, isNot(closeTo(before, 0.001)));

    await tester.pumpWidget(beuiTestApp(spinner, reduce: true));
    await tester.pump();
    expect(rotation(), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(beuiTestApp(spinner));
    await tester.pump(const Duration(milliseconds: 100));
    final resumed = turns();
    await tester.pump(const Duration(milliseconds: 100));
    final resumedAfter = turns();
    expect(resumedAfter, isNot(closeTo(resumed, 0.001)));
  });
}
