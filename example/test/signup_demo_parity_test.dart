import 'package:beui/beui.dart';
import 'package:beui_example/demos/signup_form_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support.dart';

void main() {
  testWidgets('signup header and reserved fields follow source geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        Builder(builder: signupFormDemo),
        fontFamily: 'Geist',
        width: 592,
      ),
    );
    await tester.pumpAndSettle();
    final title = tester.widget<Text>(find.text('Create your account'));
    expect(title.style!.fontSize, 20);
    expect(title.style!.fontWeight, FontWeight.w600);
    expect(
      tester
          .getSize(
            find.text(
              'Sign up with taken@example.com to see the failure state.',
            ),
          )
          .height,
      closeTo(40, .01),
    );
    final fields = find.byType(BeuiInput);
    expect(
      tester.getTopLeft(fields.at(1)).dy - tester.getTopLeft(fields.at(0)).dy,
      closeTo(96, .01),
    );
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(fields.at(1)).dy - tester.getTopLeft(fields.at(0)).dy,
      closeTo(96, .01),
    );
  });

  testWidgets('signup footer exposes source Sign in button to keyboard', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beuiTestApp(Builder(builder: signupFormDemo), width: 592),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Already have an account?'));
    await tester.pumpAndSettle();
    final signIn = find.bySemanticsLabel('Sign in');
    expect(signIn, findsOneWidget);
    final signInFocus = Focus.of(tester.element(find.text('Sign in')));
    for (var i = 0; i < 10 && !signInFocus.hasFocus; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(signInFocus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Create your account'), findsOneWidget);
    expect(
      tester.getSemantics(signIn).getSemanticsData().flagsCollection.isButton,
      isTrue,
    );
    semantics.dispose();
  });
}
