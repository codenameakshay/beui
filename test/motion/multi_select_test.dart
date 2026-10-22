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
}) {
  final child = Scaffold(
    body: Center(
      child: SizedBox(
        width: 340,
        child: BeuiMultiSelect(
          items: _items,
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
      expect(find.text('Design'), findsOneWidget);
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
