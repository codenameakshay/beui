import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beui/src/motion/combobox.dart';
import 'package:beui/src/theme/beui_colors.dart';
import 'package:beui/src/theme/beui_text_theme.dart';

Widget _testApp(Widget child, {bool reduce = false}) => MaterialApp(
  theme: BeuiTextTheme.trackingNormal(
    ThemeData.light().copyWith(
      extensions: <ThemeExtension<dynamic>>[BeuiColors.light()],
    ),
  ),
  home: Scaffold(
    body: Center(
      child: reduce
          ? Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child,
              ),
            )
          : child,
    ),
  ),
);

Widget _combobox({
  ValueChanged<String>? onValueChange,
  ValueChanged<bool>? onOpenChange,
  ValueChanged<String>? onQueryChange,
  String? value,
  String? defaultValue,
  bool? open,
  bool defaultOpen = false,
  String? query,
  String defaultQuery = '',
  bool reduce = false,
}) => _testApp(
  SizedBox(
    width: 260,
    child: BeuiCombobox(
      value: value,
      defaultValue: defaultValue,
      onValueChange: onValueChange,
      open: open,
      defaultOpen: defaultOpen,
      onOpenChange: onOpenChange,
      query: query,
      defaultQuery: defaultQuery,
      onQueryChange: onQueryChange,
      trigger: const BeuiComboboxTrigger(
        child: BeuiComboboxInput(label: 'Search fruits'),
      ),
      content: const BeuiComboboxContent(
        child: BeuiComboboxList(
          ariaLabel: 'Fruits',
          children: <Widget>[
            BeuiComboboxEmpty(child: Text('Nothing found')),
            BeuiComboboxGroup(
              label: 'Fresh',
              children: <Widget>[
                BeuiComboboxItem(
                  value: 'apple',
                  textValue: 'Apple',
                  keywords: <String>['red fruit'],
                  child: Text('Apple'),
                ),
                BeuiComboboxItem(
                  value: 'banana',
                  textValue: 'Banana',
                  child: Text('Banana'),
                ),
                BeuiComboboxItem(
                  value: 'cherry',
                  textValue: 'Cherry',
                  disabled: true,
                  child: Text('Cherry'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ),
  reduce: reduce,
);

void main() {
  group('BeuiCombobox interactions', () {
    testWidgets('selected input stays editable and opens on keyboard focus', (
      tester,
    ) async {
      await tester.pumpWidget(_combobox(defaultValue: 'apple'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.readOnly, isFalse);
      expect(field.controller!.text, 'Apple');
      field.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      expect(field.controller!.text, '');
      expect(find.text('Banana'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'ban');
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsNothing);
      expect(find.text('Banana'), findsOneWidget);
    });
    testWidgets('opens and filters by subsequence', (tester) async {
      await tester.pumpWidget(_combobox());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BeuiComboboxInput));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).readOnly,
        isFalse,
      );
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'apl');
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsNothing);
    });

    testWidgets('select commits, closes, and reports value', (tester) async {
      String? value;
      bool? open;
      await tester.pumpWidget(
        _combobox(
          onValueChange: (v) => value = v,
          onOpenChange: (v) => open = v,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BeuiComboboxInput));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Banana'));
      await tester.pumpAndSettle();
      expect(value, 'banana');
      expect(open, isFalse);
      expect(find.text('Banana'), findsOneWidget); // selected trigger label
    });

    testWidgets('ArrowDown, Home, End, Enter and Escape work', (tester) async {
      String? value;
      await tester.pumpWidget(_combobox(onValueChange: (v) => value = v));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BeuiComboboxInput));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(value, 'banana');
      await tester.tap(find.byType(BeuiComboboxInput));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsNothing);
    });

    testWidgets('controlled open and query notify without internal ownership', (
      tester,
    ) async {
      bool? requestedOpen;
      String? requestedQuery;
      await tester.pumpWidget(
        _combobox(
          open: false,
          query: '',
          onOpenChange: (v) => requestedOpen = v,
          onQueryChange: (v) => requestedQuery = v,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BeuiComboboxInput));
      await tester.pumpAndSettle();
      expect(requestedOpen, isTrue);
      await tester.pumpWidget(
        _combobox(
          open: true,
          query: '',
          onOpenChange: (v) => requestedOpen = v,
          onQueryChange: (v) => requestedQuery = v,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'red');
      await tester.pumpAndSettle();
      expect(requestedQuery, 'red');
      expect(find.text('Apple'), findsOneWidget); // parent still owns query
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
    });

    testWidgets('disabled option cannot be selected', (tester) async {
      String? value;
      await tester.pumpWidget(_combobox(onValueChange: (v) => value = v));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BeuiComboboxInput));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cherry'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(value, isNull);
    });

    testWidgets('reduced motion still opens and filters', (tester) async {
      await tester.pumpWidget(_combobox(reduce: true));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BeuiComboboxInput));
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);
    });

    testWidgets('trigger border strengthens on pointer hover', (tester) async {
      await tester.pumpWidget(_combobox());
      await tester.pumpAndSettle();
      final trigger = find.byType(BeuiComboboxTrigger);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(trigger));
      await mouse.moveTo(tester.getCenter(trigger));
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(of: trigger, matching: find.byType(Container)).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border!.top.color, BeuiColors.light().borderStrong);
    });

    testWidgets('pointer hover highlights an inactive option', (tester) async {
      await tester.pumpWidget(_combobox());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BeuiComboboxInput));
      await tester.pumpAndSettle();
      final banana = find.ancestor(
        of: find.text('Banana'),
        matching: find.byType(AnimatedContainer),
      );
      expect(
        (tester.widget<AnimatedContainer>(banana).decoration! as BoxDecoration)
            .color,
        Colors.transparent,
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.text('Banana')));
      await mouse.moveTo(tester.getCenter(find.text('Banana')));
      await tester.pumpAndSettle();

      expect(
        (tester.widget<AnimatedContainer>(banana).decoration! as BoxDecoration)
            .color,
        BeuiColors.light().muted,
      );
    });
  });

  group('exit filtering', () {
    for (final reduce in [false, true]) {
      for (final close in ['escape', 'selection', 'no-results']) {
        testWidgets('$close retains exiting rows reduce=$reduce', (
          tester,
        ) async {
          final events = <String>[];
          await tester.pumpWidget(
            _combobox(
              reduce: reduce,
              onOpenChange: (v) => events.add('open:$v'),
              onQueryChange: (v) => events.add('query:$v'),
              onValueChange: (v) => events.add('value:$v'),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byType(BeuiComboboxInput));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byType(TextField),
            close == 'no-results' ? 'zzz' : 'ban',
          );
          await tester.pumpAndSettle();
          events.clear();
          await tester.sendKeyEvent(
            close == 'selection'
                ? LogicalKeyboardKey.enter
                : LogicalKeyboardKey.escape,
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 20));
          expect(find.byType(BeuiComboboxList), findsOneWidget);
          expect(find.text('Apple'), findsNothing);
          expect(find.text('Cherry'), findsNothing);
          expect(
            find.text('FRESH'),
            close == 'no-results' ? findsNothing : findsOneWidget,
          );
          expect(
            find.text('Nothing found'),
            close == 'no-results' ? findsOneWidget : findsNothing,
          );
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            close == 'selection' ? 'Banana' : '',
          );
          expect(events, [
            if (close == 'selection') 'value:banana',
            'open:false',
            'query:',
          ]);
          await tester.pumpAndSettle();
          expect(find.byType(BeuiComboboxList), findsNothing);
        });
      }
      testWidgets(
        'reopen after selection and empty search stays visible reduce=$reduce',
        (tester) async {
          tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(disableAnimations: reduce);
          addTearDown(
            tester
                .binding
                .platformDispatcher
                .clearAccessibilityFeaturesTestValue,
          );
          Future<void> settleFrames() async {
            for (var frame = 0; frame < 60; frame++) {
              await tester.pump(const Duration(milliseconds: 16));
            }
          }

          await tester.pumpWidget(_combobox(reduce: reduce));
          await settleFrames();
          await tester.tap(find.byType(BeuiComboboxInput));
          await settleFrames();
          await tester.enterText(find.byType(TextField), 'ban');
          await settleFrames();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await settleFrames();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await settleFrames();
          await tester.enterText(find.byType(TextField), 'zzz');
          await settleFrames();
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await settleFrames();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await settleFrames();
          await tester.enterText(find.byType(TextField), 'ban');
          await settleFrames();
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 25));
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.enterText(find.byType(TextField), 'apl');
          await settleFrames();
          expect(find.text('Apple'), findsOneWidget);
          expect(find.text('Banana'), findsNothing);
          final panel = find.byType(BeuiComboboxList);
          final opacities = tester.widgetList<Opacity>(
            find.ancestor(of: panel, matching: find.byType(Opacity)),
          );
          for (final opacity in opacities) {
            expect(opacity.opacity, 1.0);
          }
          final fades = tester.widgetList<FadeTransition>(
            find.ancestor(of: panel, matching: find.byType(FadeTransition)),
          );
          for (final fade in fades) {
            expect(fade.opacity.value, 1.0);
          }
        },
      );
      testWidgets('reopen midexit uses fresh query reduce=$reduce', (
        tester,
      ) async {
        final values = <String>[];
        await tester.pumpWidget(
          _combobox(reduce: reduce, onValueChange: values.add),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BeuiComboboxInput));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'ban');
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 20));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'apl');
        await tester.pumpAndSettle();
        expect(find.text('Apple'), findsOneWidget);
        expect(find.text('Banana'), findsNothing);
        expect(
          tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
          isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(values, ['apple']);
      });
    }
    for (final acceptOpen in [false, true]) {
      for (final acceptQuery in [false, true]) {
        testWidgets('controlled close open=$acceptOpen query=$acceptQuery', (
          tester,
        ) async {
          var open = false;
          var query = 'ban';
          final events = <String>[];
          await tester.pumpWidget(
            StatefulBuilder(
              builder: (context, update) => _combobox(
                open: open,
                query: query,
                onOpenChange: (v) {
                  events.add('open:$v');
                  if (v || acceptOpen) update(() => open = v);
                },
                onQueryChange: (v) {
                  events.add('query:$v');
                  if (acceptQuery) update(() => query = v);
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byType(TextField));
          await tester.pumpAndSettle();
          events.clear();
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 20));
          expect(find.byType(BeuiComboboxList), findsOneWidget);
          expect(
            find.text('Apple'),
            !acceptOpen && acceptQuery ? findsOneWidget : findsNothing,
          );
          expect(find.text('FRESH'), findsOneWidget);
          expect(find.text('Nothing found'), findsNothing);
          expect(query, acceptQuery ? '' : 'ban');
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            acceptOpen || acceptQuery ? '' : 'ban',
          );
          expect(events, ['open:false', 'query:', 'open:false', 'query:']);
          await tester.pumpAndSettle();
          expect(
            find.byType(BeuiComboboxList),
            acceptOpen ? findsNothing : findsOneWidget,
          );
        });
      }
    }
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(
      _testApp(
        const SizedBox(
          width: 260,
          child: BeuiCombobox(
            defaultValue: 'apple',
            trigger: BeuiComboboxTrigger(
              child: BeuiComboboxInput(label: 'Search fruits'),
            ),
            content: BeuiComboboxContent(
              child: BeuiComboboxList(
                children: <Widget>[
                  BeuiComboboxItem(
                    value: 'apple',
                    textValue: 'Apple',
                    child: Text('Apple'),
                  ),
                  BeuiComboboxItem(
                    value: 'banana',
                    textValue: 'Banana',
                    child: Text('Banana'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiComboboxTrigger),
      matchesGoldenFile('goldens/beui_combobox.png'),
    );
  });
}
