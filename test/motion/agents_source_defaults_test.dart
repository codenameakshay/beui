import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

Widget _wrap(Widget child, {bool reduce = false}) =>
    beuiTestApp(child, width: 400, reduce: reduce);

List<Transform> _transformsFor(WidgetTester tester, Finder target) => tester
    .widgetList<Transform>(
      find.ancestor(of: target, matching: find.byType(Transform)),
    )
    .toList();

void _expectNoMovement(WidgetTester tester, Finder target) {
  expect(target, findsOneWidget);
  for (final transform in _transformsFor(tester, target)) {
    expect(transform.transform.entry(0, 0), closeTo(1, 0.001));
    expect(transform.transform.entry(1, 1), closeTo(1, 0.001));
    expect(transform.transform.entry(0, 3), closeTo(0, 0.001));
    expect(transform.transform.entry(1, 3), closeTo(0, 0.001));
  }
}

double _bubbleSurfaceScale(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find
        .descendant(
          of: find.byType(BeuiMessageBubble),
          matching: find.byType(Transform),
        )
        .first,
  );
  return transform.transform.entry(0, 0);
}

BeuiToolApproval _approval({bool? open, ValueChanged<bool>? onOpenChange}) =>
    BeuiToolApproval(
      tool: 'terminal.run',
      parameters: const [
        BeuiToolApprovalParameter(
          id: 'command',
          label: 'Command',
          value: 'bun test',
        ),
      ],
      open: open,
      onOpenChange: onOpenChange,
      onApprove: () {},
      onDeny: () {},
    );

BeuiToolApproval _approvalWithDefault(bool defaultOpen) => BeuiToolApproval(
  key: ValueKey(defaultOpen),
  tool: 'terminal.run',
  parameters: const [
    BeuiToolApprovalParameter(
      id: 'command',
      label: 'Command',
      value: 'bun test',
    ),
  ],
  defaultOpen: defaultOpen,
  onApprove: () {},
  onDeny: () {},
);

void main() {
  group('Message source defaults and mount motion', () {
    testWidgets('omitted animateIn inserts without translation or scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiMessage(
            from: BeuiMessageFrom.assistant,
            children: [Text('Stationary message')],
          ),
        ),
      );

      expect(find.text('Stationary message'), findsOneWidget);
      _expectNoMovement(tester, find.text('Stationary message'));
      final insertedAt = tester.getTopLeft(find.text('Stationary message'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(find.text('Stationary message')), insertedAt);
    });

    testWidgets(
      'animateIn true enters once and content updates do not replay',
      (tester) async {
        final content = ValueNotifier('First response');
        await tester.pumpWidget(
          _wrap(
            ValueListenableBuilder<String>(
              valueListenable: content,
              builder: (context, value, _) => BeuiMessage(
                key: const ValueKey('stable-message'),
                from: BeuiMessageFrom.assistant,
                animateIn: true,
                children: [Text(value)],
              ),
            ),
          ),
        );

        final initial = tester.getTopLeft(find.text('First response'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        final entering = tester.getTopLeft(find.text('First response'));
        expect(entering.dy, lessThan(initial.dy));
        await tester.pumpAndSettle();

        content.value = 'Updated response';
        await tester.pump();
        final updatedAt = tester.getTopLeft(find.text('Updated response'));
        await tester.pump(const Duration(milliseconds: 70));
        expect(tester.getTopLeft(find.text('Updated response')), updatedAt);
        expect(
          _transformsFor(
            tester,
            find.text('Updated response'),
          ).map((transform) => transform.transform.entry(0, 0)),
          everyElement(1.0),
        );
        content.dispose();
      },
    );
  });

  group('MessageBubble source defaults and mount motion', () {
    testWidgets('omitted animateIn paints at its settled scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiMessageBubble(
            child: BeuiMessageBubbleContent(child: Text('Still bubble')),
          ),
        ),
      );

      expect(find.text('Still bubble'), findsOneWidget);
      expect(_bubbleSurfaceScale(tester), closeTo(1, 0.001));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_bubbleSurfaceScale(tester), closeTo(1, 0.001));
    });

    testWidgets('animateIn true pops once and content updates do not replay', (
      tester,
    ) async {
      final content = ValueNotifier('First bubble');
      await tester.pumpWidget(
        _wrap(
          ValueListenableBuilder<String>(
            valueListenable: content,
            builder: (context, value, _) => BeuiMessageBubble(
              key: const ValueKey('stable-bubble'),
              animateIn: true,
              child: BeuiMessageBubbleContent(child: Text(value)),
            ),
          ),
        ),
      );

      final initialScale = _bubbleSurfaceScale(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      final enteringScale = _bubbleSurfaceScale(tester);
      expect(initialScale, lessThan(1));
      expect(enteringScale, greaterThan(initialScale));
      await tester.pumpAndSettle();
      expect(_bubbleSurfaceScale(tester), closeTo(1, 0.001));

      content.value = 'Updated bubble';
      await tester.pump();
      expect(_bubbleSurfaceScale(tester), closeTo(1, 0.001));
      await tester.pump(const Duration(milliseconds: 70));
      expect(_bubbleSurfaceScale(tester), closeTo(1, 0.001));
      content.dispose();
    });
  });

  testWidgets('reduced motion opt-in entrance has no translation or scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BeuiMessage(
              from: BeuiMessageFrom.assistant,
              animateIn: true,
              children: [Text('Reduced message')],
            ),
            BeuiMessageBubble(
              animateIn: true,
              child: BeuiMessageBubbleContent(child: Text('Reduced bubble')),
            ),
          ],
        ),
        reduce: true,
      ),
    );

    _expectNoMovement(tester, find.text('Reduced message'));
    expect(_bubbleSurfaceScale(tester), closeTo(1, 0.001));
    await tester.pump(const Duration(milliseconds: 150));
    _expectNoMovement(tester, find.text('Reduced message'));
    expect(_bubbleSurfaceScale(tester), closeTo(1, 0.001));
  });

  group('ToolApproval source open defaults and ownership', () {
    testWidgets('omitted defaultOpen starts closed', (tester) async {
      await tester.pumpWidget(_wrap(_approval()));
      await tester.pumpAndSettle();
      expect(find.text('View details'), findsOneWidget);
      expect(find.text('bun test'), findsNothing);
    });

    testWidgets('explicit true shows evidence', (tester) async {
      await tester.pumpWidget(_wrap(_approvalWithDefault(true)));
      await tester.pumpAndSettle();
      expect(find.text('bun test'), findsOneWidget);
    });

    testWidgets('explicit false starts closed', (tester) async {
      await tester.pumpWidget(_wrap(_approvalWithDefault(false)));
      await tester.pumpAndSettle();
      expect(find.text('View details'), findsOneWidget);
      expect(find.text('bun test'), findsNothing);
    });

    testWidgets('controlled owner decides whether callback requests apply', (
      tester,
    ) async {
      var ownerOpen = false;
      final requests = <bool>[];
      late StateSetter updateOwner;

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              updateOwner = setState;
              return _approval(open: ownerOpen, onOpenChange: requests.add);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('bun test'), findsNothing);

      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(requests, [true]);
      expect(find.text('bun test'), findsNothing);

      updateOwner(() => ownerOpen = true);
      await tester.pumpAndSettle();
      expect(find.text('bun test'), findsOneWidget);

      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(requests, [true, false]);
      expect(find.text('bun test'), findsOneWidget);

      updateOwner(() => ownerOpen = false);
      await tester.pumpAndSettle();
      expect(find.text('bun test'), findsNothing);
    });
  });
}
