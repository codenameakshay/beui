import 'dart:ui' as ui;
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

void activate(WidgetTester t) {
  final n = t.getSemantics(find.byType(TextButton));
  t.binding.platformDispatcher.onSemanticsActionEvent!(
    ui.SemanticsActionEvent(
      type: ui.SemanticsAction.tap,
      nodeId: n.id,
      viewId: t.view.viewId,
    ),
  );
}

void main() {
  for (final history in ['none', 'mouse-exit', 'mouse-exit-keyboard']) {
    testWidgets('accessibility activation after $history', (t) async {
      final s = t.ensureSemantics();
      try {
        var calls = 0;
        await t.pumpWidget(
          beuiTestApp(
            BeuiTooltip(
              content: const Text('Context'),
              child: TextButton(
                onPressed: () => calls++,
                child: const Text('Action'),
              ),
            ),
          ),
        );
        if (history != 'none') {
          final m = await t.createGesture(kind: PointerDeviceKind.mouse);
          await m.addPointer(location: Offset.zero);
          await m.moveTo(t.getCenter(find.byType(TextButton)));
          await t.pumpAndSettle();
          expect(find.text('Context'), findsOneWidget);
          await m.moveTo(const Offset(1, 1));
          await m.removePointer();
          await t.pumpAndSettle();
          expect(find.text('Context'), findsNothing);
        }
        if (history == 'mouse-exit-keyboard')
          await t.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
        activate(t);
        await t.pumpAndSettle();
        expect(calls, 1, reason: 'child action must remain intact');
        expect(
          find.text('Context'),
          findsOneWidget,
          reason: 'accessibility activation must open after pointer has left',
        );
      } finally {
        s.dispose();
      }
    });
  }
  for (final disabled in [false, true]) {
    testWidgets('controlled semantic child action disabled=$disabled', (
      t,
    ) async {
      final s = t.ensureSemantics();
      try {
        var calls = 0;
        final requests = <bool>[];
        await t.pumpWidget(
          beuiTestApp(
            BeuiTooltip(
              disabled: disabled,
              open: false,
              onOpenChange: requests.add,
              content: const Text('Context'),
              child: TextButton(
                onPressed: () => calls++,
                child: const Text('Action'),
              ),
            ),
          ),
        );
        activate(t);
        await t.pumpAndSettle();
        expect(calls, 1);
        expect(requests, disabled ? [] : [true]);
        expect(find.text('Context'), findsNothing);
        await t.pumpWidget(const SizedBox());
        activateAfterDispose(t);
        await t.pump();
        expect(t.takeException(), isNull);
      } finally {
        s.dispose();
      }
    });
  }
}

void activateAfterDispose(WidgetTester t) =>
    t.binding.platformDispatcher.onSemanticsActionEvent!(
      ui.SemanticsActionEvent(
        type: ui.SemanticsAction.tap,
        nodeId: 9999,
        viewId: t.view.viewId,
      ),
    );
