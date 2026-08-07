import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _trigger = ValueKey<String>('trigger');

Widget _app({BeuiTooltipSide side = BeuiTooltipSide.top, Widget? child}) {
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(
      body: Center(
        child: BeuiTooltip(
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
      ),
    ),
  );
}

Future<TestGesture> _hover(WidgetTester tester, Finder target) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(target));
  await tester.pump();
  return gesture;
}

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
