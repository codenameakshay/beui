import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart' show MotionBuilder;

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = Center(child: child);
  if (reduce) {
    final inner = body;
    body = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: body),
  );
}

List<BeuiContextMenuItem> _items({
  List<String>? selected,
  bool offline = false,
  ValueChanged<bool>? onOffline,
  String view = 'grid',
  ValueChanged<String>? onView,
}) {
  return [
    const BeuiContextMenuItem.label('Actions'),
    BeuiContextMenuItem(
      id: 'open',
      label: 'Open',
      onSelect: () => selected?.add('open'),
    ),
    BeuiContextMenuItem(
      id: 'rename',
      label: 'Rename',
      onSelect: () => selected?.add('rename'),
    ),
    const BeuiContextMenuItem.separator(),
    BeuiContextMenuItem.checkbox(
      id: 'offline',
      label: 'Keep offline',
      checked: offline,
      onCheckedChange: onOffline,
    ),
    BeuiContextMenuItem.radio(
      id: 'grid',
      label: 'Grid',
      checked: view == 'grid',
      onSelect: () => onView?.call('grid'),
    ),
    BeuiContextMenuItem.radio(
      id: 'list',
      label: 'List',
      checked: view == 'list',
      onSelect: () => onView?.call('list'),
    ),
    BeuiContextMenuItem(
      id: 'trash',
      label: 'Move to trash',
      tone: BeuiContextMenuTone.destructive,
      onSelect: () => selected?.add('trash'),
    ),
  ];
}

Future<void> _openSecondary(WidgetTester tester, Finder trigger) async {
  await tester.tap(trigger, buttons: kSecondaryButton);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  group('BeuiContextMenu', () {
    testWidgets('opens on secondary tap', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiContextMenu(
            items: _items(),
            child: const SizedBox(
              width: 160,
              height: 80,
              child: Center(child: Text('Trigger')),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Open'), findsNothing);

      await _openSecondary(tester, find.text('Trigger'));
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Keep offline'), findsOneWidget);
    });

    testWidgets('opens on long press', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiContextMenu(
            items: _items(),
            child: const SizedBox(
              width: 160,
              height: 80,
              child: Center(child: Text('Hold me')),
            ),
          ),
        ),
      );
      await tester.pump();

      // Source delay is 520ms; Flutter long-press is 500ms — use a timed
      // pointer gesture so the custom 520ms timer fires.
      final center = tester.getCenter(find.text('Hold me'));
      final gesture = await tester.startGesture(
        center,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(const Duration(milliseconds: 560));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('item selection invokes callback and closes', (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiContextMenu(
            items: _items(selected: selected),
            child: const SizedBox(
              width: 160,
              height: 80,
              child: Center(child: Text('Trigger')),
            ),
          ),
        ),
      );
      await _openSecondary(tester, find.text('Trigger'));
      expect(find.text('Open'), findsOneWidget);

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(selected, ['open']);
      expect(find.text('Open'), findsNothing);
    });

    testWidgets(
      'checkbox toggles without closing when closeOnSelect is false',
      (tester) async {
        var offline = false;
        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (context, setState) {
                return BeuiContextMenu(
                  items: _items(
                    offline: offline,
                    onOffline: (v) => setState(() => offline = v),
                  ),
                  child: const SizedBox(
                    width: 160,
                    height: 80,
                    child: Center(child: Text('Trigger')),
                  ),
                );
              },
            ),
          ),
        );
        await _openSecondary(tester, find.text('Trigger'));
        await tester.tap(find.text('Keep offline'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(offline, isTrue);
        // Menu stays open for checkbox default.
        expect(find.text('Keep offline'), findsOneWidget);
      },
    );

    testWidgets('Esc dismisses', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiContextMenu(
            items: _items(),
            child: const SizedBox(
              width: 160,
              height: 80,
              child: Center(child: Text('Trigger')),
            ),
          ),
        ),
      );
      await _openSecondary(tester, find.text('Trigger'));
      expect(find.text('Open'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Open'), findsNothing);
    });

    testWidgets('keyboard arrows + Enter select active item', (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiContextMenu(
            items: _items(selected: selected),
            child: const SizedBox(
              width: 160,
              height: 80,
              child: Center(child: Text('Trigger')),
            ),
          ),
        ),
      );
      await _openSecondary(tester, find.text('Trigger'));
      await tester.pump(const Duration(milliseconds: 50));

      // First selectable is Open; move down to Rename, then Enter.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(selected, ['rename']);
    });

    testWidgets('reduced motion still opens and selects', (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiContextMenu(
            items: _items(selected: selected),
            child: const SizedBox(
              width: 160,
              height: 80,
              child: Center(child: Text('Trigger')),
            ),
          ),
          reduce: true,
        ),
      );
      await _openSecondary(tester, find.text('Trigger'));
      expect(find.text('Open'), findsOneWidget);

      // No morph springs — panel should still be interactive.
      await tester.tap(find.text('Rename'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(selected, ['rename']);
    });

    testWidgets('controlled open + onOpenChange', (tester) async {
      var open = false;
      final changes = <bool>[];
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              return BeuiContextMenu(
                open: open,
                onOpenChange: (v) {
                  changes.add(v);
                  setState(() => open = v);
                },
                items: _items(),
                child: const SizedBox(
                  width: 160,
                  height: 80,
                  child: Center(child: Text('Trigger')),
                ),
              );
            },
          ),
        ),
      );
      await _openSecondary(tester, find.text('Trigger'));
      expect(changes, contains(true));
      expect(find.text('Open'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(changes, contains(false));
      expect(find.text('Open'), findsNothing);
    });

    testWidgets('disabled trigger does not open', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiContextMenu(
            enabled: false,
            items: _items(),
            child: const SizedBox(
              width: 160,
              height: 80,
              child: Center(child: Text('Trigger')),
            ),
          ),
        ),
      );
      await _openSecondary(tester, find.text('Trigger'));
      expect(find.text('Open'), findsNothing);
    });

    // Same defect as the command palette's: the active-row highlight is a
    // `MotionBuilder<Rect>` fed `const NoMotion()` under reduced motion, and
    // NoMotion holds the rect it was seeded with forever rather than reaching
    // the target (see `_no_motion_semantics_test.dart`). The highlight stuck
    // on whichever row was first activated, so keyboard navigation had no
    // visible indicator.
    //
    // Reduced motion is forced through the platform dispatcher, not an in-tree
    // MediaQuery: the panel renders into the ROOT overlay, above the test's
    // wrapper, so a wrapper-level MediaQuery never reaches it.
    testWidgets('reduced motion: arrow keys move the active-row highlight', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(
        _wrap(
          BeuiContextMenu(
            items: _items(),
            child: const SizedBox(
              width: 160,
              height: 80,
              child: Center(child: Text('Trigger')),
            ),
          ),
        ),
      );
      await _openSecondary(tester, find.text('Trigger'));

      Rect highlight() => tester.getRect(
        find
            .descendant(
              of: find.byType(MotionBuilder<Rect>),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );

      // The pill only exists once a row is active, so the first arrow both
      // creates it (seeded on 'Open') and gives us the baseline.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      final first = highlight();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        highlight().top,
        greaterThan(first.top),
        reason:
            'the highlight must follow the active row under reduced motion '
            'instead of freezing on the row it was seeded with',
      );
    });
  });
}
