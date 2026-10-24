import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beui/src/motion/multi_select.dart';
import 'package:beui/src/theme/beui_colors.dart';
import 'package:beui/src/theme/beui_text_theme.dart';

const _items = [
  BeuiMultiSelectOption(value: 'design', label: 'Design'),
  BeuiMultiSelectOption(value: 'engineering', label: 'Engineering'),
  BeuiMultiSelectOption(value: 'product', label: 'Product'),
  BeuiMultiSelectOption(value: 'research', label: 'Research', disabled: true),
];

Widget _app({
  List<String>? value,
  List<String> defaultValue = const [],
  ValueChanged<List<String>>? onChanged,
  bool reduce = false,
  bool? open,
  String? query,
  bool disabled = false,
  ValueChanged<bool>? onOpenChanged,
  ValueChanged<String>? onQueryChanged,
}) {
  final child = Scaffold(
    body: Center(
      child: SizedBox(
        width: 340,
        child: BeuiMultiSelect(
          items: _items,
          open: open,
          query: query,
          disabled: disabled,
          onOpenChanged: onOpenChanged,
          onQueryChanged: onQueryChanged,
          value: value,
          defaultValue: defaultValue,
          onChanged: onChanged,
          placeholder: 'Choose teams',
        ),
      ),
    ),
  );
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: reduce
        ? MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: child,
          )
        : child,
  );
}

void main() {
  testWidgets('later external pointer focus survives chip rebuild', (
    tester,
  ) async {
    final external = FocusNode();
    addTearDown(external.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(
                width: 340,
                child: BeuiMultiSelect(items: _items, defaultValue: ['design']),
              ),
              const SizedBox(height: 250),
              TextField(key: const Key('external'), focusNode: external),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Remove Design'));
    await tester.tap(find.byKey(const Key('external')));
    await tester.idle();
    expect(external.hasFocus, isTrue);
    await tester.pumpAndSettle();
    expect(external.hasFocus, isTrue);
    expect(
      tester
          .widget<TextField>(find.byType(TextField).first)
          .focusNode!
          .hasFocus,
      isFalse,
    );
  });

  testWidgets('typing after Escape reopens without another click', (
    tester,
  ) async {
    final opens = <bool>[];
    final queries = <String>[];
    await tester.pumpWidget(
      _app(onOpenChanged: opens.add, onQueryChanged: queries.add),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    tester.testTextInput.enterText('zz');
    await tester.pumpAndSettle();
    opens.clear();
    queries.clear();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(opens, [false]);
    expect(queries, ['']);
    expect(find.byType(BeuiMultiSelectList), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
    tester.testTextInput.enterText('xy');
    await tester.pumpAndSettle();
    expect(opens, [false, true]);
    expect(queries, ['', 'xy']);
    expect(find.byType(BeuiMultiSelectList), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'xy',
    );
  });

  for (final action in ['dispose', 'replace', 'disable', 'close', 'focus']) {
    testWidgets('chip deferred focus respects owner $action', (tester) async {
      var alive = true;
      var epoch = 0;
      var disabled = false;
      bool? open;
      final external = FocusNode();
      addTearDown(external.dispose);
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setOwner) {
              update = setOwner;
              return Scaffold(
                body: Column(
                  children: [
                    if (alive)
                      SizedBox(
                        width: 340,
                        child: BeuiMultiSelect(
                          key: ValueKey(epoch),
                          items: _items,
                          defaultValue: const ['design'],
                          disabled: disabled,
                          open: open,
                        ),
                      ),
                    const SizedBox(height: 250),
                    TextField(focusNode: external),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Remove Design'));
      update(() {
        switch (action) {
          case 'dispose':
            alive = false;
          case 'replace':
            epoch++;
          case 'disable':
            disabled = true;
          case 'close':
            open = false;
          case 'focus':
            external.requestFocus();
        }
      });
      await tester.idle();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (action == 'focus') expect(external.hasFocus, isTrue);
      if (alive) {
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .focusNode!
              .hasFocus,
          isFalse,
        );
      }
      if (action != 'focus' && action != 'disable') {
        expect(find.byType(BeuiMultiSelectList), findsNothing);
      }
    });
  }

  group('BeuiMultiSelect selection', () {
    testWidgets('trigger hover uses the strong border color', (tester) async {
      await tester.pumpWidget(_app(reduce: true));
      final trigger = find.byType(BeuiMultiSelectTrigger);
      final surface = find
          .descendant(of: trigger, matching: find.byType(Container))
          .first;
      Color borderColor() =>
          (tester.widget<Container>(surface).decoration! as BoxDecoration)
              .border!
              .top
              .color;

      expect(borderColor(), BeuiColors.light().border);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(trigger));
      await tester.pump();
      await mouse.moveTo(tester.getCenter(trigger));
      await tester.pump();
      expect(borderColor(), BeuiColors.light().borderStrong);
    });

    testWidgets('hovering an unselected item highlights its background', (
      tester,
    ) async {
      await tester.pumpWidget(_app(reduce: true));
      await tester.tap(find.byType(BeuiMultiSelectTrigger));
      await tester.pumpAndSettle();
      final item = find.ancestor(
        of: find.text('Engineering'),
        matching: find.byType(AnimatedContainer),
      );
      expect(item, findsOneWidget);
      expect(
        (tester.widget<AnimatedContainer>(item).decoration! as BoxDecoration)
            .color,
        Colors.transparent,
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: tester.getCenter(find.text('Engineering')),
      );
      await tester.pump();
      await mouse.moveTo(tester.getCenter(find.text('Engineering')));
      await tester.pump();
      expect(
        (tester.widget<AnimatedContainer>(item).decoration! as BoxDecoration)
            .color,
        BeuiColors.light().muted,
      );
    });

    testWidgets('opens, picks multiple values, and keeps panel open', (
      tester,
    ) async {
      final changes = <List<String>>[];
      await tester.pumpWidget(_app(onChanged: changes.add));
      await tester.tap(find.byType(BeuiMultiSelectTrigger));
      await tester.pumpAndSettle();
      expect(find.text('Design'), findsOneWidget);

      await tester.tap(find.text('Design'));
      await tester.pumpAndSettle();
      expect(changes.last, ['design']);
      expect(find.byType(BeuiMultiSelectList), findsOneWidget);

      await tester.tap(find.text('Engineering'));
      await tester.pumpAndSettle();
      expect(changes.last, ['design', 'engineering']);
      expect(find.byType(BeuiMultiSelectList), findsOneWidget);
    });

    testWidgets('controlled values report updates without changing tokens', (
      tester,
    ) async {
      List<String>? result;
      await tester.pumpWidget(
        _app(value: const ['design'], onChanged: (v) => result = v),
      );
      expect(find.text('Design'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Remove Design'));
      await tester.pumpAndSettle();
      expect(result, isEmpty);
      expect(find.bySemanticsLabel('Remove Design'), findsOneWidget);
    });

    testWidgets('removes last token with Backspace when query is empty', (
      tester,
    ) async {
      List<String>? result;
      await tester.pumpWidget(
        _app(
          defaultValue: const ['design', 'product'],
          onChanged: (v) => result = v,
        ),
      );
      await tester.tap(find.byType(BeuiMultiSelectInput));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(result, ['design']);
    });

    testWidgets('filters options and displays empty status', (tester) async {
      await tester.pumpWidget(_app());
      await tester.tap(find.byType(BeuiMultiSelectInput));
      await tester.enterText(find.byType(TextField), 'nonsense');
      await tester.pumpAndSettle();
      expect(find.text('No options found.'), findsOneWidget);
      expect(find.bySemanticsLabel('Options'), findsOneWidget);
    });

    testWidgets('disabled options cannot be selected', (tester) async {
      List<String>? result;
      await tester.pumpWidget(_app(onChanged: (v) => result = v));
      await tester.tap(find.byType(BeuiMultiSelectTrigger));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Research'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });

  for (final reduce in [false, true]) {
    for (final initiallyOpen in [false, true]) {
      for (final reject in [false, true]) {
        testWidgets(
          'chip removal keeps input usable reduce=$reduce open=$initiallyOpen reject=$reject',
          (tester) async {
            var values = <String>['design', 'product'];
            final calls = <List<String>>[];
            await tester.pumpWidget(
              StatefulBuilder(
                builder: (context, setOwner) => _app(
                  reduce: reduce,
                  value: values,
                  onChanged: (next) => setOwner(() {
                    calls.add(next);
                    if (!reject) values = next;
                  }),
                ),
              ),
            );
            if (initiallyOpen) {
              await tester.tap(find.byType(TextField));
              await tester.pumpAndSettle();
            }
            await tester.tap(find.bySemanticsLabel('Remove Design'));
            await tester.pumpAndSettle();
            expect(calls, [
              ['product'],
            ]);
            expect(
              find.bySemanticsLabel('Remove Design'),
              reject ? findsOneWidget : findsNothing,
            );
            expect(find.byType(BeuiMultiSelectList), findsOneWidget);
            expect(
              tester
                  .widget<TextField>(find.byType(TextField))
                  .focusNode!
                  .hasFocus,
              isTrue,
            );
            tester.testTextInput.enterText('zz');
            await tester.pumpAndSettle();
            expect(find.text('No options found.'), findsOneWidget);
            expect(calls, [
              ['product'],
            ]);
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            expect(find.byType(BeuiMultiSelectList), findsNothing);
            tester.testTextInput.enterText('xy');
            await tester.pumpAndSettle();
            expect(find.byType(BeuiMultiSelectList), findsOneWidget);
            expect(
              tester.widget<TextField>(find.byType(TextField)).controller!.text,
              'xy',
            );
            await tester.tapAt(const Offset(10, 10));
            await tester.pumpAndSettle();
            expect(find.byType(BeuiMultiSelectList), findsNothing);
            expect(calls, [
              ['product'],
            ]);
          },
        );
      }
    }
  }

  testWidgets('chip respects rejecting controlled open and query owners', (
    tester,
  ) async {
    final changes = <List<String>>[];
    final opens = <bool>[];
    final queries = <String>[];
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, rebuild) => _app(
          value: const ['design'],
          open: false,
          query: 'kept',
          onChanged: changes.add,
          onOpenChanged: opens.add,
          onQueryChanged: (q) => rebuild(() => queries.add(q)),
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Remove Design'));
    await tester.pumpAndSettle();
    expect(changes, [<String>[]]);
    expect(opens, [true]);
    expect(find.byType(BeuiMultiSelectList), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'kept',
    );
    tester.testTextInput.enterText('attempt');
    await tester.pumpAndSettle();
    expect(queries, ['attempt']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'kept',
    );
    expect(changes, [<String>[]]);
  });

  testWidgets('disabled trigger and chip emit no callbacks', (tester) async {
    final changes = <List<String>>[];
    final opens = <bool>[];
    await tester.pumpWidget(
      _app(
        value: const ['design'],
        disabled: true,
        onChanged: changes.add,
        onOpenChanged: opens.add,
      ),
    );
    await tester.tap(find.bySemanticsLabel('Remove Design'));
    await tester.tap(find.byType(BeuiMultiSelectTrigger));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(opens, isEmpty);
    expect(find.byType(BeuiMultiSelectList), findsNothing);
    expect(find.bySemanticsLabel('Remove Design'), findsOneWidget);
  });

  testWidgets('rest-state golden with selected removable tokens', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(defaultValue: const ['design', 'engineering']),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiMultiSelect),
      matchesGoldenFile('goldens/beui_multi_select.png'),
    );
  });
}
