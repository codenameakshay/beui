import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

Widget _alert({
  BeuiAlertVariant variant = BeuiAlertVariant.info,
  bool? open,
  bool reduce = false,
  ValueChanged<bool>? onOpenChange,
}) => beuiTestApp(
  BeuiAlert(
    variant: variant,
    open: open,
    onOpenChange: onOpenChange,
    children: const [
      BeuiAlertIcon(),
      BeuiAlertContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BeuiAlertTitle(child: Text('A little heads up')),
            BeuiAlertDescription(
              child: Text('Your changes are saved automatically as you work.'),
            ),
          ],
        ),
      ),
      BeuiAlertClose(),
    ],
  ),
  reduce: reduce,
);

void main() {
  testWidgets(
    'close uses the source neutral tone and negative margin position',
    (tester) async {
      await tester.pumpWidget(_alert(open: true, reduce: true));
      final close = find.descendant(
        of: find.byType(BeuiAlertClose),
        matching: find.byType(IconButton),
      );
      final button = tester.widget<IconButton>(close);
      final colors = BeuiColors.resolve(tester.element(close));
      expect(
        button.style!.foregroundColor!.resolve({}),
        colors.mutedForeground,
      );
      final alertRect = tester.getRect(find.byType(BeuiAlert));
      final closeRect = tester.getRect(close);
      expect(closeRect.size, const Size(32, 32));
      expect(closeRect.top - alertRect.top, 10);
      expect(alertRect.right - closeRect.right, 10);
    },
  );
  testWidgets('variant replacement retains the outgoing icon for its exit', (
    tester,
  ) async {
    await tester.pumpWidget(_alert());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_alert(variant: BeuiAlertVariant.success));
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byIcon(LucideIcons.info), findsOneWidget);
    expect(find.byIcon(LucideIcons.circle_check), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 70));
    await tester.pump();
    expect(find.byIcon(LucideIcons.info), findsNothing);
    expect(find.byIcon(LucideIcons.circle_check), findsOneWidget);
  });

  testWidgets('initially closed alert has no visible body before opening', (
    tester,
  ) async {
    await tester.pumpWidget(_alert(open: false));
    expect(tester.getSize(find.byType(BeuiAlert)).height, 0);
    expect(find.text('A little heads up'), findsNothing);
    await tester.pumpWidget(_alert(open: true));
    await tester.pumpAndSettle();
    expect(find.text('A little heads up'), findsOneWidget);
    expect(tester.getSize(find.byType(BeuiAlert)).height, greaterThan(32));
  });

  testWidgets('dismiss calls onOpenChange(false) and exits', (tester) async {
    bool? next;
    var open = true;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) => BeuiAlert(
            open: open,
            onOpenChange: (value) {
              next = value;
              setState(() => open = value);
            },
            children: const [BeuiAlertClose(), Text('A little heads up')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dismiss alert'));
    expect(next, isFalse);
    await tester.pumpAndSettle();
    expect(find.text('A little heads up'), findsNothing);
  });

  testWidgets(
    'controlled close retains layout during exit before unmounting on repeat',
    (tester) async {
      final requests = <bool>[];
      Widget build(bool open) => _alert(open: open, onOpenChange: requests.add);

      await tester.pumpWidget(build(true));
      await tester.pumpAndSettle();
      final alert = find.byType(BeuiAlert);
      final body = find.text('A little heads up');
      final fade = find.ancestor(of: body, matching: find.byType(Opacity));
      final openHeight = tester.getSize(alert).height;

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byTooltip('Dismiss alert'));
        await tester.pumpWidget(build(true));
        await tester.pump(const Duration(milliseconds: 40));
        expect(body, findsOneWidget);
        expect(tester.getSize(alert).height, closeTo(openHeight, 0.01));
        expect(tester.widget<Opacity>(fade).opacity, 1);

        await tester.pumpWidget(build(false));
        expect(body, findsOneWidget);
        await tester.pump(const Duration(milliseconds: 40));
        expect(body, findsOneWidget);
        expect(tester.widget<Opacity>(fade).opacity, inExclusiveRange(0, 1));
        expect(tester.getSize(alert).height, closeTo(openHeight, 0.01));
        await tester.pumpAndSettle();
        expect(body, findsNothing);
        expect(tester.getSize(alert).height, 0);

        await tester.pumpWidget(build(true));
        await tester.pump(const Duration(milliseconds: 40));
        expect(body, findsOneWidget);
        expect(tester.widget<Opacity>(fade).opacity, inExclusiveRange(0, 1));
        expect(tester.getSize(alert).height, closeTo(openHeight, 0.01));
        final translation = tester
            .widget<Transform>(
              find
                  .descendant(of: alert, matching: find.byType(Transform))
                  .first,
            )
            .transform
            .storage[13];
        expect(translation, inExclusiveRange(-6, 0));
        await tester.pumpAndSettle();
        expect(tester.getSize(alert).height, closeTo(openHeight, 0.01));
      }
      expect(requests, [false, false]);
    },
  );

  testWidgets('warning/destructive use alert role; others use status', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    for (final variant in BeuiAlertVariant.values) {
      await tester.pumpWidget(_alert(variant: variant, open: true));
      await tester.pumpAndSettle();
      final expectedRole =
          variant == BeuiAlertVariant.warning ||
              variant == BeuiAlertVariant.destructive
          ? SemanticsRole.alert
          : SemanticsRole.status;
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.role == expectedRole,
        ),
        findsOneWidget,
      );
    }
    handle.dispose();
  });

  testWidgets('reduced motion keeps fade without slide', (tester) async {
    await tester.pumpWidget(_alert(open: true, reduce: true));
    final alert = find.byType(BeuiAlert);
    expect(
      find.descendant(of: alert, matching: find.byType(SlideTransition)),
      findsNothing,
    );
    expect(
      find.descendant(of: alert, matching: find.byType(Opacity)),
      findsWidgets,
    );
  });

  testWidgets('reduced motion snaps height on initial open and reopen', (
    tester,
  ) async {
    var open = true;
    late StateSetter update;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BeuiAlert(
                  open: open,
                  children: const [SizedBox(width: 80, height: 24)],
                ),
              ],
            );
          },
        ),
        reduce: true,
      ),
    );
    final alert = find.byType(BeuiAlert);
    void expectOpenGeometry() {
      expect(tester.getSize(alert).height, 56);
      for (final transform in tester.widgetList<Transform>(
        find.descendant(of: alert, matching: find.byType(Transform)),
      )) {
        expect(transform.transform, Matrix4.identity());
      }
    }

    expectOpenGeometry();
    await tester.pump(const Duration(milliseconds: 40));
    final opacity = tester
        .widget<Opacity>(
          find.descendant(of: alert, matching: find.byType(Opacity)),
        )
        .opacity;
    expect(opacity, 1);
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      update(() => open = false);
      await tester.pump();
      expect(tester.getSize(alert).height, 0);
      await tester.pumpAndSettle();
      update(() => open = true);
      await tester.pump();
      expectOpenGeometry();
      await tester.pumpAndSettle();
      expectOpenGeometry();
    }
  });

  testWidgets('reduced motion variant icon fades without a transform', (
    tester,
  ) async {
    await tester.pumpWidget(_alert(open: true, reduce: true));
    await tester.pumpAndSettle();
    final icon = find.byType(BeuiAlertIcon);
    final before = tester.getRect(icon);
    await tester.pumpWidget(
      _alert(variant: BeuiAlertVariant.success, open: true, reduce: true),
    );
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.getRect(icon), before);
    for (final transform in tester.widgetList<Transform>(
      find.descendant(of: icon, matching: find.byType(Transform)),
    )) {
      expect(transform.transform, Matrix4.identity());
    }
    final opacity = tester
        .widget<Opacity>(
          find.descendant(of: icon, matching: find.byType(Opacity)).last,
        )
        .opacity;
    expect(opacity, inExclusiveRange(0, 1));
    expect(find.byIcon(LucideIcons.circle_check), findsOneWidget);
  });

  testWidgets('initially open alert mounts settled like initial=false', (
    tester,
  ) async {
    await tester.pumpWidget(_alert(open: true));
    final alert = find.byType(BeuiAlert);
    final initialHeight = tester.getSize(alert).height;
    expect(initialHeight, greaterThan(32));
    await tester.pump(const Duration(milliseconds: 40));
    final enteringHeight = tester.getSize(alert).height;
    await tester.pumpAndSettle();
    expect(enteringHeight, initialHeight);
    expect(tester.getSize(alert).height, initialHeight);
    expect(
      find.descendant(of: alert, matching: find.byType(AnimatedSwitcher)),
      findsNothing,
    );
  });

  testWidgets('variant icon swap uses a motor motion builder', (tester) async {
    await tester.pumpWidget(_alert(variant: BeuiAlertVariant.info, open: true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _alert(variant: BeuiAlertVariant.success, open: true),
    );
    await tester.pump(const Duration(milliseconds: 40));
    final icon = find.byType(BeuiAlertIcon);
    final translation = tester
        .widget<Transform>(
          find.descendant(of: icon, matching: find.byType(Transform)).at(2),
        )
        .transform
        .storage[13];
    expect(translation, inExclusiveRange(0, 4));
    expect(find.byIcon(LucideIcons.circle_check), findsOneWidget);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Transform>(
            find.descendant(of: icon, matching: find.byType(Transform)).first,
          )
          .transform,
      Matrix4.identity(),
    );
    expect(
      find.descendant(of: icon, matching: find.byType(AnimatedSwitcher)),
      findsNothing,
    );
  });

  testWidgets('close hover fills its background', (tester) async {
    await tester.pumpWidget(_alert(open: true, reduce: true));
    final close = find.byType(BeuiAlertClose);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(close));
    await tester.pump();
    final decoration = tester.widget<DecoratedBox>(
      find.descendant(of: close, matching: find.byType(DecoratedBox)).first,
    );
    expect((decoration.decoration as BoxDecoration).color!.a, greaterThan(0));
  });

  testWidgets('rest-state info alert golden', (tester) async {
    await tester.pumpWidget(_alert(open: true, reduce: true));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiAlert),
      matchesGoldenFile('goldens/beui_alert.png'),
    );
  });
}
