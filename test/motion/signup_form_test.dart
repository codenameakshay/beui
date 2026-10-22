import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beui/beui.dart';
import '../support.dart';

Widget _app({
  bool reduce = false,
  Future<void> Function(BeuiSignUpValues)? onSubmit,
  String? errorMessage,
  BeuiSignUpStatus? status,
  BeuiSignUpValues defaultValues = const BeuiSignUpValues(),
}) => beuiTestApp(
  BeuiSignUpForm(
    defaultValues: defaultValues,
    onSubmit: onSubmit,
    errorMessage: errorMessage,
    status: status,
  ),
  reduce: reduce,
  width: 420,
);

void main() {
  testWidgets('rest renders title, fields, and submit', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('invalid email stays quiet until blur and clears after fix', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final email = find.byType(TextField).at(1);
    await tester.enterText(email, 'bad');
    expect(find.text("That doesn't look like an email address."), findsNothing);
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(
      find.text("That doesn't look like an email address."),
      findsOneWidget,
    );
    await tester.ensureVisible(email);
    await tester.enterText(email, 'ada@example.com');
    await tester.pumpAndSettle();
    expect(find.text("That doesn't look like an email address."), findsNothing);
  });

  testWidgets(
    'invalid submit is blocked until required values and terms exist',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(_app(onSubmit: (_) async => calls++));
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Accept the terms to continue.'), findsOneWidget);
    },
  );

  testWidgets('valid submit transitions loading to success', (tester) async {
    var calls = 0;
    final completer = Completer<void>();
    await tester.pumpWidget(
      _app(
        defaultValues: const BeuiSignUpValues(terms: true),
        onSubmit: (_) {
          calls++;
          return completer.future;
        },
      ),
    );
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Ada Lovelace');
    await tester.enterText(fields.at(1), 'ada@example.com');
    await tester.enterText(fields.at(2), 'password123');
    await tester.enterText(fields.at(3), 'password123');
    expect(
      tester.widget<BeuiCheckbox>(find.byType(BeuiCheckbox)).value,
      isTrue,
    );
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, 1);
    expect(
      tester.widget<BeuiStatefulButton>(find.byType(BeuiStatefulButton)).state,
      BeuiButtonState.loading,
    );
    completer.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<BeuiStatefulButton>(find.byType(BeuiStatefulButton)).state,
      BeuiButtonState.success,
    );
  });

  testWidgets('error message renders with error status', (tester) async {
    await tester.pumpWidget(
      _app(
        errorMessage: 'That email is already registered.',
        status: BeuiSignUpStatus.error,
      ),
    );
    expect(find.text('That email is already registered.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('reduced motion keeps the form usable', (tester) async {
    await tester.pumpWidget(_app(reduce: true));
    await tester.enterText(find.byType(TextField).at(1), 'bad');
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(
      find.text("That doesn't look like an email address."),
      findsOneWidget,
    );
  });

  testWidgets('rest-state golden', (tester) async {
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiSignUpForm),
      matchesGoldenFile('goldens/beui_signup_form.png'),
    );
  });

  test('password strength is length weighted with class bonus', () {
    expect(beuiPasswordStrength(''), 0);
    expect(beuiPasswordStrength('short'), 0);
    expect(beuiPasswordStrength('password'), 1);
    expect(beuiPasswordStrength('passwordlong'), 2);
    expect(beuiPasswordStrength('Password12'), 2);
    expect(beuiPasswordStrength('Password12345678!'), 4);
  });
}
