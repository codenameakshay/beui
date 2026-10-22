import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beui/src/motion/collapsible.dart';
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
