import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  testWidgets('signup exposes a separately actionable password reveal', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(beuiTestApp(const BeuiSignUpForm(), width: 420));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    final reveal = find.bySemanticsLabel('Show password');
    expect(reveal, findsOneWidget);
    final node = tester.getSemantics(reveal);
    expect(node.getSemanticsData().tooltip, isEmpty);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(node.getSemanticsData().flagsCollection.isTextField, isFalse);
    tester
        .renderObject(find.byType(TextField).at(2))
        .owner!
        .semanticsOwner!
        .performAction(node.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).at(2)).obscureText,
      isFalse,
    );
    expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Password')), findsOneWidget);
    semantics.dispose();
  });
  testWidgets('signup terms name and toggle belong to one accessible control', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(beuiTestApp(const BeuiSignUpForm(), width: 420));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(BeuiCheckbox));
    await tester.pumpAndSettle();
    final node = tester.getSemantics(
      find.bySemanticsLabel('I agree to the Terms and Privacy Policy'),
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester
        .renderObject(find.byType(BeuiCheckbox))
        .owner!
        .semanticsOwner!
        .performAction(node.id, SemanticsAction.tap);
    await tester.pumpAndSettle();
    expect(
      tester.widget<BeuiCheckbox>(find.byType(BeuiCheckbox)).value,
      isTrue,
    );
    semantics.dispose();
  });
}
