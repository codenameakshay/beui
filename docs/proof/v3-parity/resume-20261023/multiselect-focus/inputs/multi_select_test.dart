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
      await tester.tap(find.byTooltip('Remove Design'));
      await tester.pumpAndSettle();
      expect(result, isEmpty);
      expect(find.byTooltip('Remove Design'), findsOneWidget);
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
            await tester.tap(find.byTooltip('Remove Design'));
            await tester.pumpAndSettle();
            expect(calls, [
              ['product'],
            ]);
            expect(
              find.byTooltip('Remove Design'),
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
            await tester.tap(find.byType(TextField));
            await tester.pumpAndSettle();
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
    await tester.tap(find.byTooltip('Remove Design'));
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
    await tester.tap(find.byTooltip('Remove Design'));
    await tester.tap(find.byType(BeuiMultiSelectTrigger));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
    expect(opens, isEmpty);
    expect(find.byType(BeuiMultiSelectList), findsNothing);
    expect(find.byTooltip('Remove Design'), findsOneWidget);
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
