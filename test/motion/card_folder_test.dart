import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

Widget _artwork(bool visible) => Container(
  decoration: const BoxDecoration(
    gradient: LinearGradient(colors: [Color(0xFF383A38), Color(0xFF111211)]),
  ),
  alignment: Alignment.center,
  child: Text(
    visible ? '3745 6987 4096 0806' : '•••• •••• •••• 0806',
    style: const TextStyle(color: Colors.white),
  ),
);

String _renderedText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((widget) => widget.data ?? '')
    .join();

Widget _app({
  bool? open,
  bool defaultOpen = false,
  bool? detailsVisible,
  ValueChanged<bool>? onOpenChange,
  ValueChanged<bool>? onDetailsVisibleChange,
  VoidCallback? onAction,
  bool disabled = false,
  bool reduce = false,
}) => beuiTestApp(
  BeuiCardFolder(
    title: 'Travel Card',
    cardNumber: '3745 6987 4096 0806',
    expiry: '08/29',
    cvv: '123',
    card: _artwork(detailsVisible ?? false),
    open: open,
    defaultOpen: defaultOpen,
    onOpenChange: onOpenChange,
    detailsVisible: detailsVisible,
    onDetailsVisibleChange: onDetailsVisibleChange,
    onAction: onAction,
    disabled: disabled,
  ),
  reduce: reduce,
);

void main() {
  testWidgets('pointer activation transfers keyboard control to the folder', (
    tester,
  ) async {
    final opens = <bool>[];
    await tester.pumpWidget(_app(onOpenChange: opens.add));
    await tester.tap(find.byType(BeuiCardFolder));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opens, [true, false]);
  });

  testWidgets(
    'folder focus paints the source two-pixel ring beyond a four-pixel gap',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final painter = find
          .descendant(
            of: find.byType(BeuiCardFolder),
            matching: find.byWidgetPredicate(
              (w) => w is CustomPaint && w.foregroundPainter != null,
            ),
          )
          .first;
      expect(
        tester.renderObject(painter),
        paints..something((method, arguments) {
          if (method != #drawRRect) return false;
          final rect = arguments[0] as RRect;
          final paint = arguments[1] as Paint;
          return rect.left == -5 &&
              rect.top == -5 &&
              paint.strokeWidth == 2 &&
              paint.style == PaintingStyle.stroke;
        }),
      );
    },
  );

  for (final reduce in [false, true]) {
    testWidgets(
      'held card press leaves pocket and action stationary, reduce=$reduce',
      (tester) async {
        final opens = <bool>[];
        var actions = 0;
        await tester.pumpWidget(
          _app(
            reduce: reduce,
            onOpenChange: opens.add,
            onAction: () => actions++,
          ),
        );
        await tester.pumpAndSettle();
        final privacy = find.bySemanticsLabel('Show card details');
        final action = find.byTooltip('Open actions for Travel Card');
        final card = find.byType(ClipRRect).first;
        final privacyBefore = tester.getTopLeft(privacy);
        final actionBefore = tester.getTopLeft(action);
        final cardBefore = tester.getTopLeft(card);
        final bounds = tester.getRect(find.byType(BeuiCardFolder));
        final point = Offset(
          bounds.center.dx,
          bounds.top + bounds.height * .12,
        );
        final gesture = await tester.startGesture(
          point,
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.getTopLeft(privacy), privacyBefore);
        expect(tester.getTopLeft(action), actionBefore);
        if (reduce) {
          expect(tester.getTopLeft(card), cardBefore);
        } else {
          expect(tester.getTopLeft(card).dx, greaterThan(cardBefore.dx + 6));
          expect(tester.getTopLeft(card).dy, greaterThan(cardBefore.dy + 4));
        }
        await gesture.moveBy(const Offset(2, 2));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.getTopLeft(privacy), privacyBefore);
        await gesture.up();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(opens, [true, false]);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(actions, 1);
        expect(opens, [true, false]);
        await tester.tap(privacy);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Hide card details'), findsOneWidget);
        expect(opens, [true, false]);
      },
    );

    testWidgets(
      'privacy uses the shared tooltip on hover and keyboard, reduce=$reduce',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final opens = <bool>[];
        await tester.pumpWidget(_app(reduce: reduce, onOpenChange: opens.add));
        final privacy = find.bySemanticsLabel('Show card details');
        expect(find.byType(Tooltip), findsNothing);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer();
        await mouse.moveTo(tester.getCenter(privacy));
        await tester.pump(const Duration(milliseconds: 121));
        await tester.pumpAndSettle();
        expect(find.text('Show card details'), findsOneWidget);
        await mouse.moveTo(Offset.zero);
        await tester.pumpAndSettle();
        expect(find.text('Show card details'), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump(const Duration(milliseconds: 121));
        await tester.pumpAndSettle();
        expect(find.text('Show card details'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Hide card details',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .getSemantics(
                find.byWidgetPredicate(
                  (w) =>
                      w is Semantics &&
                      w.properties.label == 'Hide card details',
                ),
              )
              .label,
          'Hide card details',
        );
        expect(opens, isEmpty);
        expect(find.text('1'), findsWidgets);
        await mouse.removePointer();
        semantics.dispose();
      },
    );
  }

  testWidgets('keyboard opens and closes the folder before privacy control', (
    tester,
  ) async {
    final changes = <bool>[];
    await tester.pumpWidget(_app(onOpenChange: changes.add));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(changes, [true]);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(changes, [true, false]);
  });

  testWidgets('closed rest state masks details and retains last four', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(_renderedText(tester), contains('0806'));
    expect(_renderedText(tester), contains('•••'));
    expect(_renderedText(tester), isNot(contains('123')));
    expect(
      find.bySemanticsLabel(
        'Open Travel Card, card ending in 0806, expires 08/29',
      ),
      findsOneWidget,
    );
  });

  testWidgets('folder tap reports open state', (tester) async {
    final states = <bool>[];
    await tester.pumpWidget(_app(onOpenChange: states.add));
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsLabel(
        'Open Travel Card, card ending in 0806, expires 08/29',
      ),
    );
    await tester.pump();
    expect(states, [true]);
  });

  testWidgets('details toggle reveals number and CVV', (tester) async {
    var visible = false;
    await tester.pumpWidget(
      _app(onDetailsVisibleChange: (next) => visible = next),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Show card details'));
    await tester.pumpAndSettle();
    expect(visible, isTrue);
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    expect(find.text('3'), findsWidgets);
    expect(find.text('4'), findsWidgets);
    expect(find.bySemanticsLabel('Hide card details'), findsOneWidget);
  });

  testWidgets('closed eye toggle reveals CVV and keeps expiry static', (
    tester,
  ) async {
    final changes = <bool>[];
    await tester.pumpWidget(_app(onDetailsVisibleChange: changes.add));
    await tester.pumpAndSettle();

    expect(find.text('08/29'), findsOneWidget);
    expect(find.text('123'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Show card details'));
    await tester.pumpAndSettle();

    expect(changes, [true]);
    expect(find.text('08/29'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    expect(find.text('3'), findsWidgets);
  });

  testWidgets('details toggle is active while the folder is closed', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Show card details'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Hide card details'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    expect(find.text('3'), findsWidgets);
  });

  testWidgets('CVV reveal retains outgoing glyphs and rolls incoming glyphs', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final cvv = find.byWidgetPredicate(
      (widget) =>
          widget is BeuiDigitSwap &&
          (widget.value == '•••' || widget.value == '123'),
    );
    Finder glyph(String character) => find.descendant(
      of: cvv,
      matching: find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == character,
      ),
    );
    double glyphOffset(String character) => tester
        .widget<SlideTransition>(
          find
              .ancestor(
                of: glyph(character).first,
                matching: find.byType(SlideTransition),
              )
              .first,
        )
        .position
        .value
        .dy;

    expect(glyph('•'), findsNWidgets(3));
    await tester.tap(find.bySemanticsLabel('Show card details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(glyph('•'), findsNWidgets(3));
    for (final digit in ['1', '2', '3']) {
      expect(glyph(digit), findsOneWidget);
      expect(glyphOffset(digit), inInclusiveRange(0, 0.45));
    }
    final firstOffset = glyphOffset('1');
    await tester.pump(const Duration(milliseconds: 60));
    expect(glyphOffset('1'), inExclusiveRange(0, firstOffset));
    expect(find.text('08/29'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(glyph('•'), findsNothing);
    expect(glyphOffset('1'), 0);
    expect(glyph('1'), findsOneWidget);
  });

  testWidgets('action fires without toggling the folder', (tester) async {
    var actions = 0;
    var opens = 0;
    await tester.pumpWidget(
      _app(onAction: () => actions++, onOpenChange: (_) => opens++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open actions for Travel Card'));
    await tester.pump();
    expect(actions, 1);
    expect(opens, 0);
  });

  testWidgets('disabled folder ignores tap and detail toggle', (tester) async {
    var changes = 0;
    await tester.pumpWidget(
      _app(
        disabled: true,
        onOpenChange: (_) => changes++,
        onDetailsVisibleChange: (_) => changes++,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsLabel(
        'Open Travel Card, card ending in 0806, expires 08/29',
      ),
    );
    await tester.tap(find.bySemanticsLabel('Show card details'));
    await tester.pump();
    expect(changes, 0);
  });

  testWidgets('reduced motion does not lift the card', (tester) async {
    await tester.pumpWidget(_app(reduce: true, open: false));
    await tester.pumpAndSettle();
    final topBefore = tester.getTopLeft(find.byType(ClipRRect)).dy;
    await tester.pumpWidget(_app(reduce: true, open: true));
    await tester.pump(const Duration(milliseconds: 80));
    final topAfter = tester.getTopLeft(find.byType(ClipRRect)).dy;
    expect(topAfter, topBefore);
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiCardFolder),
      matchesGoldenFile('goldens/beui_card_folder.png'),
    );
  });
}
