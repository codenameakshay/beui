import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  testWidgets('rapid password reentry keeps one current strength readout', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(const BeuiSignUpForm(), width: 420));
    final password = find.byType(TextField).at(2);
    await tester.enterText(password, 'password');
    await tester.pumpAndSettle();
    await tester.enterText(password, '');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    await tester.enterText(password, 'ExamplePassword123!');
    await tester.pump();
    expect(find.textContaining('Password strength:'), findsOneWidget);
    expect(find.text('Password strength: Strong'), findsOneWidget);
  });
  for (final reduce in [false, true]) {
    testWidgets('strength retains its source exit for 180ms, reduce=$reduce', (
      tester,
    ) async {
      if (reduce) {
        tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      await tester.pumpWidget(
        beuiTestApp(const BeuiSignUpForm(), reduce: reduce, width: 420),
      );
      final password = find.byType(TextField).at(2);
      await tester.enterText(password, 'password');
      await tester.pumpAndSettle();
      await tester.enterText(password, '');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(find.text('Password strength: Weak'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Password strength:'), findsNothing);
    });

    testWidgets(
      'accepting terms retains the 200ms error exit, reduce=$reduce',
      (tester) async {
        await tester.pumpWidget(
          beuiTestApp(const BeuiSignUpForm(), reduce: reduce, width: 420),
        );
        await tester.ensureVisible(find.text('Create account'));
        await tester.tap(find.text('Create account'));
        await tester.pumpAndSettle();
        expect(find.text('Accept the terms to continue.'), findsOneWidget);
        await tester.ensureVisible(find.byType(BeuiCheckbox));
        await tester.tap(find.byType(BeuiCheckbox));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Accept the terms to continue.'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 110));
        expect(find.text('Accept the terms to continue.'), findsNothing);
      },
    );

    testWidgets(
      'server error retains its source exit for 200ms, reduce=$reduce',
      (tester) async {
        if (reduce) {
          tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
            tester
                .binding
                .platformDispatcher
                .clearAccessibilityFeaturesTestValue,
          );
        }
        await tester.pumpWidget(
          beuiTestApp(
            const BeuiSignUpForm(errorMessage: 'Email is registered.'),
            reduce: reduce,
            width: 420,
          ),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          beuiTestApp(const BeuiSignUpForm(), reduce: reduce, width: 420),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Email is registered.'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 110));
        expect(find.text('Email is registered.'), findsNothing);
      },
    );
  }
}
