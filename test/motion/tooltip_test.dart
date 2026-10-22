import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beui/src/motion/tooltip.dart';

import '../support.dart';

const _trigger = ValueKey<String>('trigger');

Widget _app({BeuiTooltipSide side = BeuiTooltipSide.top, Widget? child}) =>
    beuiTestApp(
      BeuiTooltip(
        side: side,
        content: const Text('TIP'),
        child:
            child ??
            const SizedBox(
              key: _trigger,
              width: 80,
              height: 32,
              child: ColoredBox(color: Color(0xFF888888)),
            ),
      ),
    );

Future<TestGesture> _hover(WidgetTester tester, Finder target) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(target));
  await tester.pump();
  return gesture;
}

Widget _providerApp() => beuiTestApp(
  BeuiTooltipProvider(
    delay: const Duration(milliseconds: 800),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final name in ['A', 'B'])
          BeuiTooltip(
            content: Text(name),
            child: SizedBox(key: ValueKey(name), width: 60, height: 40),
          ),
      ],
    ),
  ),
);

void main() {
  testWidgets('hover shows after delay, hides on exit', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.text('TIP'), findsNothing);

    final gesture = await _hover(tester, find.byKey(_trigger));
    await tester.pump(const Duration(milliseconds: 250)); // past delay
    await tester.pumpAndSettle();
    expect(find.text('TIP'), findsOneWidget);

    await gesture.moveTo(const Offset(5, 5)); // off the trigger
    await tester.pumpAndSettle();
    expect(find.text('TIP'), findsNothing);
  });

  testWidgets('hover does not show before its delay', (tester) async {
    await tester.pumpWidget(_app());
    await _hover(tester, find.byKey(_trigger));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('TIP'), findsNothing);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('TIP'), findsOneWidget);
  });

  testWidgets('disabling an open tooltip closes it and permits reentry', (
    tester,
  ) async {
    var disabled = false;
    late StateSetter update;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiTooltip(
              disabled: disabled,
              content: const Text('TIP'),
              child: const SizedBox(key: _trigger, width: 80, height: 32),
            );
          },
        ),
      ),
    );
    final gesture = await _hover(tester, find.byKey(_trigger));
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pumpAndSettle();
    expect(find.text('TIP'), findsOneWidget);
    update(() => disabled = true);
    await tester.pumpAndSettle();
    expect(find.text('TIP'), findsNothing);
    await gesture.moveTo(const Offset(5, 5));
    update(() => disabled = false);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byKey(_trigger)));
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pumpAndSettle();
    expect(find.text('TIP'), findsOneWidget);
  });

  testWidgets('disabling a pending tooltip cancels its timer', (tester) async {
    var disabled = false;
    late StateSetter update;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeuiTooltip(
              disabled: disabled,
              delay: const Duration(seconds: 2),
              content: const Text('TIP'),
              child: const SizedBox(key: _trigger, width: 80, height: 32),
            );
          },
        ),
      ),
    );
    final gesture = await _hover(tester, find.byKey(_trigger));
    await tester.pump(const Duration(milliseconds: 10));
    update(() => disabled = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    update(() => disabled = false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump();
    expect(find.text('TIP'), findsNothing);
    await gesture.moveTo(const Offset(5, 5));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.byKey(_trigger)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('TIP'), findsOneWidget);
  });

  testWidgets('disabling collision handling clears a prior flip and shift', (
    tester,
  ) async {
    var avoid = true;
    late StateSetter update;
    const text = 'A tooltip wider than its trigger';
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Stack(
              children: [
                Positioned(
                  top: 1,
                  right: 1,
                  child: BeuiTooltip(
                    side: BeuiTooltipSide.top,
                    align: BeuiTooltipAlign.start,
                    avoidCollisions: avoid,
                    content: const Text(text),
                    child: const SizedBox(key: _trigger, width: 80, height: 32),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    await _hover(tester, find.byKey(_trigger));
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text(text)).dy,
      greaterThan(tester.getBottomLeft(find.byKey(_trigger)).dy),
    );
    expect(tester.getTopRight(find.text(text)).dx, lessThan(800));
    update(() => avoid = false);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(find.text(text)).dy,
      lessThan(tester.getTopLeft(find.byKey(_trigger)).dy),
    );
    expect(tester.getTopRight(find.text(text)).dx, greaterThan(800));
  });

  testWidgets('aborted hover does not warm a sibling tooltip', (tester) async {
    await tester.pumpWidget(_providerApp());
    final gesture = await _hover(tester, find.byKey(const ValueKey('A')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('A'), findsNothing);
    await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('B'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    // Flush the post-frame overlay mount before checking for early content.
    await tester.pump();
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsNothing);
    await tester.pump(const Duration(milliseconds: 99));
    await tester.pump();
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('aborted hover retries the same trigger with a cold delay', (
    tester,
  ) async {
    await tester.pumpWidget(_providerApp());
    final trigger = find.byKey(const ValueKey('A'));
    final gesture = await _hover(tester, trigger);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('A'), findsNothing);
    await gesture.moveTo(const Offset(5, 5));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(trigger));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.text('A'), findsNothing);
    await tester.pump(const Duration(milliseconds: 99));
    await tester.pump();
    expect(find.text('A'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('A'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('a pending hover does not warm a focused sibling', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      beuiTestApp(
        BeuiTooltipProvider(
          delay: const Duration(milliseconds: 800),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BeuiTooltip(
                content: Text('A'),
                child: SizedBox(key: ValueKey('A'), width: 60, height: 40),
              ),
              BeuiTooltip(
                content: const Text('B'),
                child: Focus(
                  focusNode: focus,
                  child: const SizedBox(width: 60, height: 40),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await _hover(tester, find.byKey(const ValueKey('A')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('A'), findsNothing);
    focus.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(focus.hasPrimaryFocus, isTrue);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsNothing);
    await tester.pump(const Duration(milliseconds: 99));
    await tester.pump();
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('same pending trigger focus retries with a cold delay', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      beuiTestApp(
        BeuiTooltipProvider(
          delay: const Duration(milliseconds: 800),
          child: BeuiTooltip(
            content: const Text('TIP'),
            child: Focus(
              focusNode: focus,
              child: const SizedBox(key: _trigger, width: 80, height: 32),
            ),
          ),
        ),
      ),
    );
    await _hover(tester, find.byKey(_trigger));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('TIP'), findsNothing);
    focus.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(focus.hasPrimaryFocus, isTrue);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.text('TIP'), findsNothing);
    await tester.pump(const Duration(milliseconds: 99));
    await tester.pump();
    expect(find.text('TIP'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('TIP'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('TIP'), findsOneWidget);
  });

  testWidgets('followCursor moves the open overlay with the pointer', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        BeuiTooltip(
          content: const Text('TIP'),
          followCursor: true,
          avoidCollisions: false,
          child: const SizedBox(key: _trigger, width: 120, height: 40),
        ),
      ),
    );
    final gesture = await _hover(tester, find.byKey(_trigger));
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pumpAndSettle();
    final before = tester.getCenter(find.text('TIP'));
    await gesture.moveTo(
      tester.getCenter(find.byKey(_trigger)) + const Offset(25, 0),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    final after = tester.getCenter(find.text('TIP'));
    expect(after.dx - before.dx, closeTo(25, 2));
  });

  testWidgets('preferred side flips when it has no viewport room', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: BeuiTooltip(
              content: const Text('TIP'),
              side: BeuiTooltipSide.top,
              child: const SizedBox(key: _trigger, width: 80, height: 32),
            ),
          ),
        ),
      ),
    );
    await _hover(tester, find.byKey(_trigger));
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('TIP')).dy,
      greaterThan(tester.getBottomLeft(find.byKey(_trigger)).dy),
    );
  });

  testWidgets('provider skips delay when moving to a sibling tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        BeuiTooltipProvider(
          delay: const Duration(milliseconds: 800),
          child: Row(
            children: [
              BeuiTooltip(
                content: const Text('A'),
                child: const SizedBox(
                  key: ValueKey('a'),
                  width: 60,
                  height: 40,
                ),
              ),
              BeuiTooltip(
                content: const Text('B'),
                child: const SizedBox(
                  key: ValueKey('b'),
                  width: 60,
                  height: 40,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final gesture = await _hover(tester, find.byKey(const ValueKey('a')));
    await tester.pump(const Duration(milliseconds: 810));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);
    await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('b'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('keyboard focus shows', (tester) async {
    await tester.pumpWidget(
      _app(
        child: ElevatedButton(onPressed: () {}, child: const Text('btn')),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // focus the button
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('TIP'), findsOneWidget);
  });

  testWidgets('long-press reveals on touch, releases to hide', (tester) async {
    await tester.pumpWidget(_app());
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_trigger)),
    );
    await tester.pump(const Duration(milliseconds: 600)); // long-press fires
    await tester.pumpAndSettle();
    expect(find.text('TIP'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('TIP'), findsNothing);
  });

  testWidgets('surface is opaque — no backdrop blur', (tester) async {
    await tester.pumpWidget(_app());
    final gesture = await _hover(tester, find.byKey(_trigger));
    await tester.pump(const Duration(milliseconds: 250)); // past delay
    await tester.pumpAndSettle();
    expect(find.text('TIP'), findsOneWidget);
    // Source is a SOLID `bg-background` pill with `shadow-lg`, not a frosted
    // surface — the port must not reintroduce a BackdropFilter. (barrier:false
    // means the overlay contributes none either.)
    expect(find.byType(BackdropFilter), findsNothing);
    await gesture.moveTo(const Offset(5, 5)); // release for a clean teardown
    await tester.pumpAndSettle();
  });

  for (final side in BeuiTooltipSide.values) {
    testWidgets('renders on $side', (tester) async {
      await tester.pumpWidget(_app(side: side));
      await _hover(tester, find.byKey(_trigger));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('TIP'), findsOneWidget);
    });
  }
}
