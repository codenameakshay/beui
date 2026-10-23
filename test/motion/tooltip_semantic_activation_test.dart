import 'dart:ui' as ui;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  for (final reduce in [false, true]) {
    testWidgets(
      'semantic taps toggle tooltip and preserve child action, reduce=$reduce',
      (tester) async {
        final semantics = tester.ensureSemantics();

        var activations = 0;
        await tester.pumpWidget(
          beuiTestApp(
            BeuiTooltip(
              content: const Text('Context'),
              child: TextButton(
                onPressed: () => activations++,
                child: const Text('Action'),
              ),
            ),
            reduce: reduce,
          ),
        );
        void activate() {
          final node = tester.getSemantics(find.byType(TextButton));
          tester.binding.platformDispatcher.onSemanticsActionEvent!(
            ui.SemanticsActionEvent(
              type: ui.SemanticsAction.tap,
              nodeId: node.id,
              viewId: tester.view.viewId,
            ),
          );
        }

        activate();
        await tester.pumpAndSettle();
        expect(activations, 1);
        expect(find.text('Context'), findsOneWidget);
        activate();
        await tester.pumpAndSettle();
        expect(activations, 2);
        expect(find.text('Context'), findsNothing);
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'semantic mouse activation cancels pending hover and keeps child action',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var activations = 0;
      await tester.pumpWidget(
        beuiTestApp(
          BeuiTooltip(
            delay: const Duration(seconds: 1),
            content: const Text('Context'),
            child: TextButton(
              onPressed: () => activations++,
              child: const Text('Action'),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(TextButton)));
      final node = tester.getSemantics(find.byType(TextButton));
      tester.binding.platformDispatcher.onSemanticsActionEvent!(
        ui.SemanticsActionEvent(
          type: ui.SemanticsAction.tap,
          nodeId: node.id,
          viewId: tester.view.viewId,
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(activations, 1);
      expect(find.text('Context'), findsNothing);
      await mouse.removePointer();
      semantics.dispose();
    },
  );

  testWidgets(
    'semantic activation belongs only to its trigger and listeners detach',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var first = 0;
      var second = 0;
      await tester.pumpWidget(
        beuiTestApp(
          Row(
            children: [
              BeuiTooltip(
                content: const Text('First context'),
                child: TextButton(
                  onPressed: () => first++,
                  child: const Text('First'),
                ),
              ),
              BeuiTooltip(
                content: const Text('Second context'),
                child: TextButton(
                  onPressed: () => second++,
                  child: const Text('Second'),
                ),
              ),
            ],
          ),
        ),
      );
      final node = tester.getSemantics(
        find.widgetWithText(TextButton, 'Second'),
      );
      final event = ui.SemanticsActionEvent(
        type: ui.SemanticsAction.tap,
        nodeId: node.id,
        viewId: tester.view.viewId,
      );
      tester.binding.platformDispatcher.onSemanticsActionEvent!(event);
      await tester.pumpAndSettle();
      expect(first, 0);
      expect(second, 1);
      expect(find.text('First context'), findsNothing);
      expect(find.text('Second context'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      tester.binding.platformDispatcher.onSemanticsActionEvent!(event);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(second, 1);
      semantics.dispose();
    },
  );

  testWidgets('nonmodal overlay wrapper cannot acquire focus', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        BeuiTooltip(
          defaultOpen: true,
          content: const Text('Context'),
          child: TextButton(onPressed: () {}, child: const Text('Action')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final wrapper = tester
        .widgetList<Focus>(find.byType(Focus))
        .singleWhere((w) => w.focusNode?.debugLabel == 'BeuiOverlay');
    wrapper.focusNode!.requestFocus();
    await tester.pump();
    expect(wrapper.focusNode!.hasPrimaryFocus, isFalse);
  });
}
