import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = Center(child: child);
  if (reduce) {
    final inner = body;
    body = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: body),
  );
}

Future<void> _type(WidgetTester tester, String digits) async {
  for (final ch in digits.split('')) {
    await tester.sendKeyEvent(
      LogicalKeyboardKey(0x30 + int.parse(ch)), // digit0..digit9
    );
    await tester.pump();
  }
}

Future<void> _focus(WidgetTester tester) async {
  await tester.tap(find.byType(BeuiOtpInput), warnIfMissed: false);
  await tester.pump();
}

void main() {
  group('BeuiOtpInput', () {
    testWidgets('renders one slot per digit, plus the label and hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiOtpInput(
            length: 6,
            label: 'Verify',
            hint: 'Enter the 6-digit code',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Verify'), findsOneWidget);
      expect(find.text('Enter the 6-digit code'), findsOneWidget);
      // AnimatedContainer is only used to draw the slot cells, so its count
      // is the slot count.
      expect(
        find.descendant(
          of: find.byType(BeuiOtpInput),
          matching: find.byType(AnimatedContainer),
        ),
        findsNWidgets(6),
      );
    });

    testWidgets('typing fills slots forward and reports onChanged', (
      tester,
    ) async {
      final changes = <String>[];
      await tester.pumpWidget(
        _wrap(BeuiOtpInput(length: 4, onChanged: changes.add)),
      );
      await _focus(tester);
      await _type(tester, '12');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(changes.last, '12');
    });

    testWidgets('onComplete fires once when every slot fills', (tester) async {
      final completions = <String>[];
      await tester.pumpWidget(
        _wrap(BeuiOtpInput(length: 4, onComplete: completions.add)),
      );
      await _focus(tester);
      await _type(tester, '1234');
      await tester.pump(const Duration(milliseconds: 300));
      expect(completions, ['1234']);
      // Editing a full code again only fires on the next empty→full edge.
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      await _type(tester, '9');
      await tester.pump(const Duration(milliseconds: 300));
      expect(completions, ['1234', '1239']);
    });

    testWidgets('backspace clears the previous slot and steps back', (
      tester,
    ) async {
      final changes = <String>[];
      await tester.pumpWidget(
        _wrap(BeuiOtpInput(length: 4, onChanged: changes.add)),
      );
      await _focus(tester);
      await _type(tester, '12');
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump(const Duration(milliseconds: 300));
      expect(changes.last, '1');
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump(const Duration(milliseconds: 300));
      expect(changes.last, '');
    });

    testWidgets('paste/autofill spreads a whole code across the slots', (
      tester,
    ) async {
      final changes = <String>[];
      await tester.pumpWidget(
        _wrap(BeuiOtpInput(length: 6, onChanged: changes.add)),
      );
      await _focus(tester);
      await tester.enterText(find.byType(EditableText), '4  2-1 9 07');
      await tester.pump(const Duration(milliseconds: 300));
      expect(changes.last, '421907');
      expect(find.text('4'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets(
      'soft keyboard: sequential onChanged entry accumulates and advances',
      (tester) async {
        // The mobile keyboard reports the whole field on every keystroke via
        // onChanged (no per-key preventDefault as on the web). Successive
        // reports must accumulate — "1", then "12", then "123" — not overwrite
        // slot 0 each time.
        final changes = <String>[];
        await tester.pumpWidget(
          _wrap(BeuiOtpInput(length: 6, onChanged: changes.add)),
        );
        await _focus(tester);
        final field = find.byType(EditableText);
        await tester.enterText(field, '1');
        await tester.pump();
        await tester.enterText(field, '12');
        await tester.pump();
        await tester.enterText(field, '123');
        await tester.pump(const Duration(milliseconds: 300));

        expect(changes, ['1', '12', '123']);
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
      },
    );

    testWidgets('soft keyboard: onChanged deletion steps back a slot', (
      tester,
    ) async {
      final changes = <String>[];
      await tester.pumpWidget(
        _wrap(BeuiOtpInput(length: 6, onChanged: changes.add)),
      );
      await _focus(tester);
      final field = find.byType(EditableText);
      await tester.enterText(field, '1');
      await tester.enterText(field, '12');
      await tester.enterText(field, '123');
      await tester.pump();
      // Soft backspace: the mirrored field loses its last character.
      await tester.enterText(field, '12');
      // First frame applies the edit and starts the digit roll-out; the second
      // advances past it so the cleared slot no longer renders the old digit.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(changes.last, '12');
      expect(find.text('3'), findsNothing);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('mask renders dots instead of digits', (tester) async {
      await tester.pumpWidget(_wrap(const BeuiOtpInput(length: 4, mask: true)));
      await _focus(tester);
      await _type(tester, '12');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('1'), findsNothing);
      expect(find.text('•'), findsNWidgets(2));
    });

    testWidgets('controlled value updates the slots', (tester) async {
      await tester.pumpWidget(_wrap(const BeuiOtpInput(value: '12')));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      await tester.pumpWidget(_wrap(const BeuiOtpInput(value: '87')));
      await tester.pumpAndSettle();
      expect(find.text('8'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('error status shakes the row and shows the message', (
      tester,
    ) async {
      Widget app(BeuiOtpStatus status) => _wrap(
        BeuiOtpInput(
          length: 4,
          status: status,
          errorMessage: 'Wrong code',
          hint: 'hint',
        ),
      );
      await tester.pumpWidget(app(BeuiOtpStatus.idle));
      await tester.pumpAndSettle();
      expect(find.text('Wrong code'), findsNothing);

      await tester.pumpWidget(app(BeuiOtpStatus.error));
      await tester.pump(const Duration(milliseconds: 80)); // mid-shake
      final xs = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(BeuiOtpInput),
              matching: find.byType(Transform),
            ),
          )
          .map((t) => t.transform.getTranslation().x.abs())
          .fold<double>(0, math.max);
      expect(xs, greaterThan(0.5), reason: 'row displaced mid-shake');

      // The source eases each keyframe segment, not the whole timeline, so the
      // six hops stay spread over the full 450ms. At 270ms (segment 4 of 6) the
      // row is still well off-centre; a globally-eased timeline would have
      // collapsed to ~0 by here.
      await tester.pump(const Duration(milliseconds: 190));
      final late = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(BeuiOtpInput),
              matching: find.byType(Transform),
            ),
          )
          .map((t) => t.transform.getTranslation().x.abs())
          .fold<double>(0, math.max);
      expect(late, greaterThan(1.5), reason: 'shake spans the full duration');

      await tester.pumpAndSettle();
      expect(find.text('Wrong code'), findsOneWidget);
    });

    testWidgets('success draws the check and shows the message', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiOtpInput(
            length: 4,
            value: '1234',
            status: BeuiOtpStatus.success,
            successMessage: 'Verified',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Verified'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BeuiOtpInput),
          matching: find.byType(CustomPaint),
        ),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('reduced motion: no shake and no roll blur', (tester) async {
      Widget app(BeuiOtpStatus status) =>
          _wrap(BeuiOtpInput(length: 4, status: status), reduce: true);
      await tester.pumpWidget(app(BeuiOtpStatus.idle));
      await _focus(tester);
      await _type(tester, '1');
      await tester.pump(const Duration(milliseconds: 60));
      final blurs = tester
          .widgetList<ImageFiltered>(find.byType(ImageFiltered))
          .length;
      expect(blurs, 0);

      await tester.pumpWidget(app(BeuiOtpStatus.error));
      await tester.pump(const Duration(milliseconds: 80));
      final xs = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(BeuiOtpInput),
              matching: find.byType(Transform),
            ),
          )
          .map((t) => t.transform.getTranslation().x.abs())
          .fold<double>(0, math.max);
      expect(xs, lessThan(0.5));
    });

    testWidgets('disabled ignores input', (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(
        _wrap(BeuiOtpInput(length: 4, disabled: true, onChanged: changes.add)),
      );
      await _focus(tester);
      await _type(tester, '12');
      await tester.pump(const Duration(milliseconds: 300));
      expect(changes, isEmpty);
    });
  });
}
