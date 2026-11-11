import 'dart:ui' as ui;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool reducedMotion = false}) => MaterialApp(
  theme: ThemeData(extensions: [BeuiColors.dark()]),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: Scaffold(
      body: SingleChildScrollView(child: Center(child: child)),
    ),
  ),
);

void main() {
  testWidgets(
    'custom slot count overrides rows and invalid boards render empty',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(const BeuiPlinko(rows: 16, slots: <Object>['left', 2, 'right'])),
      );
      expect(find.bySemanticsLabel('Plinko board'), findsOneWidget);
      expect(find.text('Drop ball'), findsOneWidget);

      await tester.pumpWidget(_app(const BeuiPlinko(slots: <Object>[1])));
      expect(find.bySemanticsLabel('Plinko board'), findsNothing);
      expect(find.text('Drop ball'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets('reduced motion lands on the tapped frame and hides peg flash', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final landings = <(int, Object)>[];
    await tester.pumpWidget(
      _app(
        BeuiPlinko(
          rows: 8,
          onLand: (slot, value) => landings.add((slot, value)),
        ),
        reducedMotion: true,
      ),
    );

    expect(find.bySemanticsLabel('Peg flash'), findsNothing);
    expect(find.bySemanticsLabel('Sound'), findsOneWidget);
    await tester.tap(find.text('Drop ball'));
    await tester.pump();

    expect(landings, hasLength(1));
    expect(landings.single.$1, inInclusiveRange(0, 8));
    expect(landings.single.$2, beuiPlinkoSlots(8)[landings.single.$1]);
    semantics.dispose();
  });

  testWidgets('reduced-motion repeat landings announce each numbered drop', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final landings = <int>[];
    await tester.pumpWidget(
      _app(
        BeuiPlinko(rows: 1, onLand: (slot, _) => landings.add(slot)),
        reducedMotion: true,
      ),
    );

    await tester.tap(find.text('Drop ball'));
    await tester.pump();
    await tester.tap(find.text('Drop ball'));
    await tester.pump();

    expect(landings, hasLength(2));
    expect(landings.every((slot) => slot == 0 || slot == 1), isTrue);
    expect(
      find.bySemanticsLabel(RegExp(r'Ball 2 landed in slot [12]:')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('controlled sound toggle reports preference without owning it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final changes = <bool>[];
    await tester.pumpWidget(
      _app(BeuiPlinko(sound: false, onSoundChange: changes.add)),
    );
    final sound = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Sound' &&
          widget.properties.toggled != null,
    );
    await tester.ensureVisible(sound);
    await tester.pump();
    await tester.tap(sound);
    await tester.pumpAndSettle();

    expect(changes, <bool>[true]);
    expect(
      tester.getSemantics(sound).flagsCollection.isToggled,
      ui.Tristate.isFalse,
    );
    semantics.dispose();
  });

  testWidgets('board scales to a narrow parent without horizontal overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const SizedBox(width: 80, child: BeuiPlinko(rows: 2))),
    );
    final paint = tester.widget<CustomPaint>(
      find
          .descendant(
            of: find.byType(BeuiPlinko),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    expect(paint.size.width, 80);
    expect(tester.takeException(), isNull);
  });

  testWidgets('peg flash peaks 90 ms after the observed turn and settles', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const BeuiPlinko(rows: 1)));
    await tester.tap(find.text('Drop ball'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final board = find
        .descendant(
          of: find.byType(BeuiPlinko),
          matching: find.byType(CustomPaint),
        )
        .first;
    expect(
      tester.renderObject(board),
      paints..something((method, arguments) {
        return method == #drawCircle &&
            arguments[0] == const Offset(48, 48) &&
            ((arguments[1] as double) - 6.3).abs() < 0.000001;
      }),
    );
    await tester.pump(const Duration(milliseconds: 210));
    expect(
      tester.renderObject(board),
      paints..something((method, arguments) {
        return method == #drawCircle &&
            arguments[0] == const Offset(48, 48) &&
            arguments[1] == 3.5;
      }),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('overlapping drops respect maxBalls and land once each', (
    tester,
  ) async {
    final landings = <int>[];
    await tester.pumpWidget(
      _app(
        BeuiPlinko(
          rows: 2,
          maxBalls: 2,
          onLand: (slot, _) => landings.add(slot),
        ),
      ),
    );
    await tester.tap(find.text('Drop ball'));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.tap(find.text('Drop ball'));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.tap(find.text('Drop ball'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));

    expect(landings, hasLength(2));
    expect(landings.every((slot) => slot >= 0 && slot <= 2), isTrue);
    await tester.pumpAndSettle();
    expect(landings, hasLength(2));
  });

  testWidgets('landed balls release capacity before their exit fade ends', (
    tester,
  ) async {
    final landings = <int>[];
    await tester.pumpWidget(
      _app(
        BeuiPlinko(
          rows: 2,
          maxBalls: 1,
          onLand: (slot, _) => landings.add(slot),
        ),
      ),
    );
    await tester.tap(find.text('Drop ball'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    expect(landings, hasLength(1));

    await tester.tap(find.text('Drop ball'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(landings, hasLength(2));
  });

  testWidgets('changing board geometry cancels old flights without landing', (
    tester,
  ) async {
    var landingCount = 0;
    Widget board(int rows) =>
        _app(BeuiPlinko(rows: rows, onLand: (_, _) => landingCount++));
    await tester.pumpWidget(board(8));
    await tester.tap(find.text('Drop ball'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpWidget(board(2));
    await tester.pump(const Duration(seconds: 5));

    expect(landingCount, 0);
  });

  testWidgets('disposing an in-flight board prevents later landing callbacks', (
    tester,
  ) async {
    var landingCount = 0;
    await tester.pumpWidget(
      _app(BeuiPlinko(rows: 8, onLand: (_, _) => landingCount++)),
    );
    await tester.tap(find.text('Drop ball'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(_app(const SizedBox.shrink()));
    await tester.pump(const Duration(seconds: 2));

    expect(landingCount, 0);
  });
}
