import 'dart:ui' show PointerDeviceKind;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  testWidgets('chart owns pointer exit and consumed-key reopening', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var open = false;
    var datum = 1;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            return BeuiChartTooltip(
              open: open,
              onOpenChange: (value) => setState(() => open = value),
              content: Text('Datum $datum'),
              child: Focus(
                focusNode: focus,
                onFocusChange: (value) => setState(() => open = value),
                onKeyEvent: (_, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    setState(() {
                      datum++;
                      open = true;
                    });
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: MouseRegion(
                  onEnter: (_) => setState(() => open = true),
                  onExit: (_) => setState(() => open = false),
                  child: GestureDetector(
                    onTap: focus.requestFocus,
                    child: const SizedBox(
                      width: 120,
                      height: 60,
                      child: Text('Inspect'),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Inspect')));
    await tester.tap(find.text('Inspect'));
    await tester.pumpAndSettle();
    expect(find.text('Datum 1'), findsOneWidget);
    final tooltip = tester.widget<BeuiTooltip>(find.byType(BeuiTooltip));
    expect(tooltip.open, isTrue);
    expect(tooltip.externalAnchor, isNotNull);
    expect(tooltip.anchorLink, isNotNull);
    final anchor =
        tooltip.externalAnchor!.currentContext!.findRenderObject() as RenderBox;
    expect(anchor.size, const Size(120, 60));

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    expect(find.text('Datum 1'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pumpAndSettle();
    expect(find.text('Datum 1'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Datum 2'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Datum 2'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Datum 3'), findsOneWidget);
    await mouse.removePointer();
  });
}
