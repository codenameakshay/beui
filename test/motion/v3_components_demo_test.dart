import 'dart:ui' show CheckedState, Tristate;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The separate example package is not in the root package configuration.
// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/card_demo.dart';
// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/number_demo.dart';
import '../support.dart';

void main() {
  for (final layout in [
    (width: 280.0, bandWidth: 280.0),
    (width: 800.0, bandWidth: 320.0),
  ]) {
    testWidgets(
      'number demo fits its band and keeps Animate compact at ${layout.width}px',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.binding.setSurfaceSize(Size(layout.width, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        try {
          await tester.pumpWidget(
            beuiTestApp(Builder(builder: numberDemo), width: layout.width),
          );

          final button = find.byType(OutlinedButton);

          void expectBand(String value) {
            expect(tester.takeException(), isNull);
            expect(find.bySemanticsLabel(value), findsOneWidget);
            expect(button, findsOneWidget);
            expect(
              find.descendant(of: button, matching: find.text('Animate')),
              findsOneWidget,
            );
            final band = tester.getRect(
              find
                  .ancestor(
                    of: find.text('Card number'),
                    matching: find.byType(Column),
                  )
                  .first,
            );
            final digits = tester.getRect(find.byType(BeuiDigitSwap));
            final animate = tester.getRect(button);
            expect(band.width, closeTo(layout.bandWidth, 0.001));
            expect(band.center.dx, closeTo(layout.width / 2, 0.001));
            expect(digits.left, greaterThanOrEqualTo(band.left - 0.001));
            expect(digits.right, lessThanOrEqualTo(band.right + 0.001));
            expect(animate.width, lessThan(band.width));
            expect(animate.left, closeTo(band.left, 0.001));
            expect(animate.right, lessThanOrEqualTo(band.right));
            expect(animate.top, greaterThanOrEqualTo(digits.bottom));
          }

          expectBand('•••• •••• •••• 0806');
          await tester.tap(button);
          await tester.pump();
          await pumpFrames(tester, 20);
          expectBand('4242 4242 4242 0806');
          await tester.tap(button);
          await tester.pump();
          await pumpFrames(tester, 20);
          expectBand('•••• •••• •••• 0806');
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          semantics.dispose();
        }
      },
    );
  }

  for (final control in [
    (label: 'Signed contract', checkbox: true, initialValue: true),
    (label: 'Invoice', checkbox: true, initialValue: false),
    (label: 'Mentions and replies', checkbox: false, initialValue: true),
    (label: 'Weekly digest', checkbox: false, initialValue: false),
  ]) {
    testWidgets('card demo labels and activates ${control.label}', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          beuiTestApp(Builder(builder: cardDemo), width: 560, reduce: true),
        );
        await tester.pumpAndSettle();

        final node = find.semantics.byPredicate((node) {
          if (node.isMergedIntoParent || node.label != control.label) {
            return false;
          }
          final flags = node.getSemanticsData().flagsCollection;
          return control.checkbox
              ? flags.isChecked != CheckedState.none
              : flags.isToggled != Tristate.none;
        });

        void expectValue(bool value) {
          expect(node, findsOneWidget);
          expect(
            node.evaluate().single,
            isSemantics(
              label: control.label,
              hasCheckedState: control.checkbox,
              isChecked: control.checkbox ? value : null,
              hasToggledState: !control.checkbox,
              isToggled: control.checkbox ? null : value,
              isEnabled: true,
              hasTapAction: true,
            ),
          );
        }

        expectValue(control.initialValue);
        tester.semantics.tap(node);
        await tester.pumpAndSettle();
        expectValue(!control.initialValue);
        tester.semantics.tap(node);
        await tester.pumpAndSettle();
        expectValue(control.initialValue);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        semantics.dispose();
      }
    });
  }
}
