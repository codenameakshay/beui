import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _anchor = ValueKey('parity-tooltip-anchor');

Widget _tooltip({FocusNode? focus, Widget content = const Text('Context')}) =>
    beuiTestApp(
      BeuiTooltip(
        delay: const Duration(milliseconds: 800),
        content: content,
        child: TextButton(
          key: _anchor,
          focusNode: focus,
          onPressed: () {},
          child: const Text('Action'),
        ),
      ),
    );

Future<TestGesture> _open(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await mouse.moveTo(tester.getCenter(find.byKey(_anchor)));
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pumpAndSettle();
  expect(find.text('Context'), findsOneWidget);
  return mouse;
}

void main() {
  testWidgets('keyboard use restores a mouse-focused suppressed label', (
    tester,
  ) async {
    await tester.pumpWidget(_tooltip());
    final mouse = await _open(tester);
    await mouse.down(tester.getCenter(find.byKey(_anchor)));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.text('Context'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpAndSettle();
    expect(find.text('Context'), findsOneWidget);
  });

  testWidgets('arrow overlaps the body without increasing its anchor gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiTooltip(
          defaultOpen: true,
          arrow: true,
          avoidCollisions: false,
          content: Text('Context'),
          child: SizedBox(key: _anchor, width: 80, height: 40),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final body = find.byWidgetPredicate((widget) {
      if (widget is! DecoratedBox) return false;
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.borderRadius == BorderRadius.circular(8) &&
          decoration.boxShadow?.length == 2;
    });
    expect(tester.getSize(body).height, 26);
    expect(
      tester.getTopLeft(find.byKey(_anchor)).dy - tester.getBottomLeft(body).dy,
      8,
    );
  });

  testWidgets(
    'controlled composed tooltip requests visibility without owning it',
    (tester) async {
      final requests = <bool>[];
      final visible = ValueNotifier(false);
      addTearDown(visible.dispose);
      await tester.pumpWidget(
        beuiTestApp(
          ValueListenableBuilder(
            valueListenable: visible,
            builder: (context, value, _) => BeuiTooltip.composed(
              open: value,
              onOpenChange: requests.add,
              trigger: BeuiTooltipTrigger(
                child: TextButton(
                  key: _anchor,
                  onPressed: () {},
                  child: const Text('Action'),
                ),
              ),
              tooltip: const BeuiTooltipContent(
                side: BeuiTooltipSide.bottom,
                child: Text('Controlled context'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(requests, [true]);
      expect(find.text('Controlled context'), findsNothing);
      visible.value = true;
      await tester.pumpAndSettle();
      expect(find.text('Controlled context'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Controlled context')).dy,
        greaterThan(tester.getBottomLeft(find.byKey(_anchor)).dy),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(requests, [true, false]);
      expect(find.text('Controlled context'), findsOneWidget);
      visible.value = false;
      await tester.pumpAndSettle();
      expect(find.text('Controlled context'), findsNothing);
    },
  );

  testWidgets('keyboard focus bypasses the cold hover delay', (tester) async {
    await tester.pumpWidget(_tooltip());
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump();
    await tester.pump();
    expect(find.text('Context'), findsOneWidget);
  });

  testWidgets('touch taps toggle the label without stealing the action', (
    tester,
  ) async {
    var activations = 0;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiTooltip(
          content: const Text('Context'),
          child: TextButton(
            key: _anchor,
            onPressed: () => activations++,
            child: const Text('Action'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(_anchor));
    await tester.pumpAndSettle();
    expect(activations, 1);
    expect(find.text('Context'), findsOneWidget);
    await tester.tap(find.byKey(_anchor));
    await tester.pumpAndSettle();
    expect(activations, 2);
    expect(find.text('Context'), findsNothing);
  });

  testWidgets('mouse press dismisses until the pointer leaves and reenters', (
    tester,
  ) async {
    await tester.pumpWidget(_tooltip());
    final mouse = await _open(tester);
    await mouse.down(tester.getCenter(find.byKey(_anchor)));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.text('Context'), findsNothing);
    await mouse.moveTo(
      tester.getCenter(find.byKey(_anchor)) + const Offset(2, 0),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Context'), findsNothing);
    await mouse.moveTo(const Offset(5, 5));
    await tester.pump();
    await mouse.moveTo(tester.getCenter(find.byKey(_anchor)));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.text('Context'), findsOneWidget);
  });

  testWidgets('pointer can cross the gap and remain on the tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(_tooltip());
    final mouse = await _open(tester);
    await mouse.moveTo(
      tester.getCenter(find.text('Context')),
      timeStamp: const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('Context'), findsOneWidget);
    await mouse.moveTo(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Context'), findsNothing);
  });

  testWidgets('live text changes update the open surface without closing', (
    tester,
  ) async {
    final text = ValueNotifier('Context');
    addTearDown(text.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder(
        valueListenable: text,
        builder: (context, value, _) => _tooltip(content: Text(value)),
      ),
    );
    await _open(tester);
    text.value = 'A longer explanation';
    await tester.pumpAndSettle();
    expect(find.text('A longer explanation'), findsOneWidget);
    expect(find.text('Context'), findsNothing);
  });
}
