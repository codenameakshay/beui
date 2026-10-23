import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beui/src/motion/collapsible.dart';
import 'package:beui/src/theme/beui_colors.dart';
import '../support.dart';

Widget _app({
  bool? open,
  bool defaultOpen = false,
  ValueChanged<bool>? onOpenChange,
  bool disabled = false,
  bool reduce = false,
  Widget content = const Text('Hidden details'),
}) => beuiTestApp(
  BeuiCollapsible(
    open: open,
    defaultOpen: defaultOpen,
    onOpenChange: onOpenChange,
    disabled: disabled,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BeuiCollapsibleTrigger(
          child: Row(
            children: [
              Expanded(child: Text('More details')),
              BeuiCollapsibleIndicator(),
            ],
          ),
        ),
        BeuiCollapsibleContent(child: content),
      ],
    ),
  ),
  reduce: reduce,
  width: 320,
);

void main() {
  group('BeuiCollapsible interaction', () {
    testWidgets('hovering the trigger paints muted at 60% opacity', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      final trigger = find.byType(BeuiCollapsibleTrigger);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(trigger));
      await tester.pump();
      await mouse.moveTo(tester.getCenter(trigger));
      await tester.pump();

      final decoration = tester.widget<DecoratedBox>(
        find.descendant(of: trigger, matching: find.byType(DecoratedBox)),
      );
      final colors = BeuiColors.resolve(tester.element(trigger));
      expect(
        (decoration.decoration as BoxDecoration).color,
        colors.muted.withValues(alpha: 0.6),
      );
      expect(
        (decoration.decoration as BoxDecoration).borderRadius,
        BorderRadius.circular(12),
      );
    });

    testWidgets('tap toggles open and closed', (tester) async {
      bool? changed;
      await tester.pumpWidget(_app(onOpenChange: (value) => changed = value));
      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();
      expect(changed, isTrue);
      expect(find.text('Hidden details'), findsOneWidget);

      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();
      expect(changed, isFalse);
    });

    testWidgets('controlled state reports change without changing itself', (
      tester,
    ) async {
      bool? requested;
      await tester.pumpWidget(
        _app(open: false, onOpenChange: (value) => requested = value),
      );
      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();
      expect(requested, isTrue);
      expect(find.bySemanticsLabel('Hidden details'), findsNothing);
      expect(
        tester.getSemantics(find.text('More details')),
        isSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
        ),
      );
      final triggerData = tester
          .getSemantics(find.text('More details'))
          .getSemanticsData();
      final contentIdentifier = tester
          .getSemantics(find.byType(BeuiCollapsibleContent))
          .getSemanticsData()
          .identifier;
      expect(triggerData.controlsNodes, hasLength(1));
      expect(triggerData.controlsNodes, contains(contentIdentifier));
    });

    testWidgets('disabled trigger does not request a state change', (
      tester,
    ) async {
      var called = false;
      await tester.pumpWidget(
        _app(disabled: true, onOpenChange: (_) => called = true),
      );
      await tester.tap(find.text('More details'));
      await tester.pump();
      expect(called, isFalse);
    });

    testWidgets('Space activates the focused trigger', (tester) async {
      bool? requested;
      await tester.pumpWidget(_app(onOpenChange: (value) => requested = value));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(requested, isTrue);
    });

    testWidgets('closing returns focus from content to the trigger', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(content: const TextField(key: ValueKey('details-field'))),
      );
      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('details-field')));
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.context, isNotNull);

      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'collapsible trigger',
      );
    });
  });

  testWidgets('closed content is excluded from accessibility and focus', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(content: const TextField(key: ValueKey('details-field'))),
    );
    expect(find.byKey(const ValueKey('details-field')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BeuiCollapsibleContent),
        matching: find.byType(ExcludeFocus),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.byType(BeuiCollapsibleContent)),
      matchesSemantics(isHidden: true),
    );
    semantics.dispose();
  });

  testWidgets('reduced motion snaps height and indicator, keeps the fade', (
    tester,
  ) async {
    await tester.pumpWidget(_app(defaultOpen: true, reduce: true));
    await tester.pumpAndSettle();
    expect(find.text('Hidden details'), findsOneWidget);
    final panel = tester.widget<Align>(
      find.descendant(
        of: find.byType(BeuiCollapsibleContent),
        matching: find.byType(Align),
      ),
    );
    expect(panel.heightFactor, 1);
    expect(find.byType(Opacity), findsWidgets);
  });

  for (final reduce in [false, true]) {
    testWidgets('lifecycle external close restores descendant focus $reduce', (
      tester,
    ) async {
      var open = true;
      late StateSetter update;
      final calls = <bool>[];
      final outside = FocusNode(debugLabel: 'outside');
      addTearDown(outside.dispose);
      await tester.pumpWidget(
        beuiTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BeuiCollapsible(
                    open: open,
                    onOpenChange: calls.add,
                    child: const Column(
                      children: [
                        BeuiCollapsibleTrigger(child: Text('Toggle')),
                        BeuiCollapsibleContent(child: TextField()),
                      ],
                    ),
                  ),
                  TextField(focusNode: outside),
                ],
              );
            },
          ),
          reduce: reduce,
          width: 320,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      update(() => open = false);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'collapsible trigger',
      );
      expect(calls, isEmpty);
      expect(
        tester.getSize(find.byType(BeuiCollapsibleContent)).height,
        closeTo(0, .01),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(outside.hasFocus, isTrue);
      update(() => open = true);
      await tester.pumpAndSettle();
      update(() => open = false);
      await tester.pumpAndSettle();
      expect(outside.hasFocus, isTrue);
      expect(calls, isEmpty);
    });

    testWidgets('lifecycle rejected close keeps child focus $reduce', (
      tester,
    ) async {
      final calls = <bool>[];
      final field = FocusNode();
      addTearDown(field.dispose);
      await tester.pumpWidget(
        _app(
          open: true,
          reduce: reduce,
          onOpenChange: calls.add,
          content: TextField(focusNode: field),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();
      expect(calls, [false]);
      expect(field.hasFocus, isTrue);
      expect(
        tester.getSize(find.byType(BeuiCollapsibleContent)).height,
        greaterThan(40),
      );
    });

    testWidgets('lifecycle reparent close later focus and disposal $reduce', (
      tester,
    ) async {
      final key = GlobalKey();
      final outside = FocusNode(debugLabel: 'outside');
      addTearDown(outside.dispose);
      var open = true;
      var moved = false;
      var alive = true;
      late StateSetter update;
      final calls = <bool>[];
      await tester.pumpWidget(
        beuiTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              final component = BeuiCollapsible(
                key: key,
                open: open,
                onOpenChange: calls.add,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BeuiCollapsibleTrigger(child: Text('Toggle')),
                    BeuiCollapsibleContent(child: TextField()),
                  ],
                ),
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (alive)
                    Row(
                      children: [
                        Expanded(child: moved ? const SizedBox() : component),
                        Expanded(child: moved ? component : const SizedBox()),
                      ],
                    ),
                  TextField(focusNode: outside),
                ],
              );
            },
          ),
          reduce: reduce,
          width: 600,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      update(() {
        moved = true;
        open = false;
      });
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'collapsible trigger',
      );
      update(() => open = true);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      update(() => open = false);
      await tester.pump();
      outside.requestFocus();
      await tester.pumpAndSettle();
      expect(outside.hasFocus, isTrue);
      update(() => open = true);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      update(() => open = false);
      outside.requestFocus();
      await tester.pumpAndSettle();
      expect(outside.hasFocus, isTrue);
      update(() {
        alive = false;
      });
      await tester.pumpAndSettle();
      expect(outside.hasFocus, isTrue);
      expect(calls, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lifecycle stable nested size and width changes $reduce', (
      tester,
    ) async {
      final height = ValueNotifier<double>(40);
      addTearDown(height.dispose);
      var width = 320.0;
      var open = true;
      late StateSetter update;
      final content = BeuiCollapsibleContent(
        child: ValueListenableBuilder<double>(
          valueListenable: height,
          builder: (context, value, _) => LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              key: const ValueKey('extent'),
              height: value + (constraints.maxWidth < 200 ? 80 : 0),
            ),
          ),
        ),
      );
      await tester.pumpWidget(
        beuiTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SizedBox(
                width: width,
                child: BeuiCollapsible(
                  open: open,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BeuiCollapsibleTrigger(child: Text('Toggle')),
                      content,
                    ],
                  ),
                ),
              );
            },
          ),
          reduce: reduce,
        ),
      );
      Future<void> extent(double expected) async {
        await tester.pumpAndSettle();
        expect(
          tester.widget(find.byType(BeuiCollapsibleContent)),
          same(content),
        );
        expect(
          tester.getSize(find.byType(BeuiCollapsibleContent)).height,
          closeTo(expected + 12, .01),
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('extent'))).height,
          expected,
        );
      }

      await extent(40);
      height.value = 140;
      await extent(140);
      height.value = 20;
      await extent(20);
      update(() => width = 180);
      await extent(100);
      update(() => open = false);
      await tester.pumpAndSettle();
      height.value = 160;
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(BeuiCollapsibleContent)).height,
        closeTo(0, .01),
      );
      update(() => open = true);
      await extent(240);
    });
  }

  for (final reduce in [false, true]) {
    for (final scenario in [
      'outside',
      'nested outside',
      'removed',
      'reparented',
      'disabled',
      'second control',
      'later callback',
      'uncontrolled pending',
    ]) {
      testWidgets('pending rebuild focus $scenario reduce=$reduce', (
        tester,
      ) async {
        final inside = FocusNode(debugLabel: 'inside');
        final outside = FocusNode(debugLabel: 'outside');
        addTearDown(inside.dispose);
        addTearDown(outside.dispose);
        final key = GlobalKey();
        var open = true;
        var pending = false;
        var alive = true;
        var moved = false;
        final calls = <bool>[];
        late StateSetter update;
        await tester.pumpWidget(
          beuiTestApp(
            StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                if (pending) {
                  pending = false;
                  outside.requestFocus();
                  expect(inside.hasFocus, isTrue);
                }
                final panel = BeuiCollapsible(
                  key: key,
                  open: scenario == 'uncontrolled pending' ? null : open,
                  defaultOpen: true,
                  disabled: scenario == 'disabled',
                  onOpenChange: (value) {
                    calls.add(value);
                    if (scenario == 'later callback') {
                      update(() => open = value);
                      outside.requestFocus();
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const BeuiCollapsibleTrigger(
                        child: Text('Pending toggle'),
                      ),
                      BeuiCollapsibleContent(
                        child: Focus(
                          focusNode: inside,
                          child: const Text('Inside'),
                        ),
                      ),
                    ],
                  ),
                );
                Widget target = Focus(
                  focusNode: outside,
                  child: const Text('Outside'),
                );
                if (scenario == 'nested outside')
                  target = FocusScope(child: target);
                if (scenario == 'second control') {
                  target = BeuiCollapsible(
                    defaultOpen: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BeuiCollapsibleTrigger(
                          child: Text('Second toggle'),
                        ),
                        BeuiCollapsibleContent(child: target),
                      ],
                    ),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (alive)
                      Row(
                        children: [
                          Expanded(child: moved ? const SizedBox() : panel),
                          Expanded(child: moved ? panel : const SizedBox()),
                        ],
                      ),
                    target,
                  ],
                );
              },
            ),
            reduce: reduce,
            width: 600,
          ),
        );
        await tester.pumpAndSettle();
        inside.requestFocus();
        await tester.pump();
        if (scenario == 'later callback') {
          await tester.tap(find.text('Pending toggle'));
        } else if (scenario == 'uncontrolled pending') {
          outside.requestFocus();
          // Invoke the public semantics action before focus notifications run.
          tester
              .widgetList<Semantics>(
                find.descendant(
                  of: find.byType(BeuiCollapsibleTrigger),
                  matching: find.byType(Semantics),
                ),
              )
              .singleWhere((widget) => widget.properties.onTap != null)
              .properties
              .onTap!();
        } else {
          update(() {
            open = false;
            pending = true;
            alive = scenario != 'removed';
            moved = scenario == 'reparented';
          });
        }
        await tester.pumpAndSettle();
        expect(outside.hasPrimaryFocus, isTrue);
        expect(
          calls,
          scenario == 'later callback' || scenario == 'uncontrolled pending'
              ? [false]
              : isEmpty,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('rest-state golden (closed and open)', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        const Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 260,
              child: BeuiCollapsible(
                child: Column(
                  children: [
                    BeuiCollapsibleTrigger(
                      child: Row(
                        children: [
                          Expanded(child: Text('Closed')),
                          BeuiCollapsibleIndicator(),
                        ],
                      ),
                    ),
                    BeuiCollapsibleContent(
                      child: Text('Keep extra information tucked away.'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 24),
            SizedBox(
              width: 260,
              child: BeuiCollapsible(
                defaultOpen: true,
                child: Column(
                  children: [
                    BeuiCollapsibleTrigger(
                      child: Row(
                        children: [
                          Expanded(child: Text('Open')),
                          BeuiCollapsibleIndicator(),
                        ],
                      ),
                    ),
                    BeuiCollapsibleContent(
                      child: Text('Keep extra information tucked away.'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        width: 620,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Row).first,
      matchesGoldenFile('goldens/beui_collapsible.png'),
    );
  });
}
