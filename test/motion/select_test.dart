import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _options = <BeuiSelectOption>[
  BeuiSelectOption(value: 'apple', label: 'Apple'),
  BeuiSelectOption(value: 'banana', label: 'Banana'),
  BeuiSelectOption(value: 'cherry', label: 'Cherry', enabled: false),
];

Widget _app(Widget child, {bool reduce = false}) {
  Widget body = Align(alignment: Alignment.topCenter, child: child);
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
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(40), child: body),
    ),
  );
}

Widget _select({
  ValueChanged<String>? onChanged,
  String? defaultValue,
  bool enabled = true,
}) => SizedBox(
  width: 200,
  child: BeuiSelect(
    options: _options,
    defaultValue: defaultValue,
    enabled: enabled,
    placeholder: 'Pick',
    onChanged: onChanged,
  ),
);

Widget _morph({ValueChanged<String>? onChanged, String? defaultValue}) =>
    SizedBox(
      width: 200,
      child: BeuiMorphSelect(
        options: _options,
        defaultValue: defaultValue,
        placeholder: 'Pick',
        onChanged: onChanged,
      ),
    );

void main() {
  group('BeuiSelect interaction', () {
    testWidgets('tap trigger opens the panel', (tester) async {
      await tester.pumpWidget(_app(_select()));
      await tester.pumpAndSettle();
      // Options live only in the (skipped) offstage measurement while closed.
      expect(find.text('Apple'), findsNothing);

      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Banana'), findsOneWidget);
    });

    testWidgets('selecting an option commits and closes', (tester) async {
      String? picked;
      await tester.pumpWidget(_app(_select(onChanged: (v) => picked = v)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Banana'));
      await tester.pumpAndSettle();
      expect(picked, 'banana');
      // Panel closed → options gone from the on-stage tree.
      expect(find.text('Apple'), findsNothing);
    });

    testWidgets('disabled option does not commit', (tester) async {
      String? picked;
      await tester.pumpWidget(_app(_select(onChanged: (v) => picked = v)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cherry'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(picked, isNull);
    });

    testWidgets('disabled select does not open', (tester) async {
      await tester.pumpWidget(_app(_select(enabled: false)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pick'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsNothing);
    });
  });

  group('BeuiSelect keyboard', () {
    testWidgets('ArrowDown navigates and Enter commits', (tester) async {
      String? picked;
      await tester.pumpWidget(_app(_select(onChanged: (v) => picked = v)));
      await tester.pumpAndSettle();
      // Open via the trigger.
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      // Panel autofocuses; active starts at first enabled (Apple).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // -> Banana
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(picked, 'banana');
    });

    testWidgets('Escape closes the panel', (tester) async {
      await tester.pumpWidget(_app(_select()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsNothing);
    });
  });

  group('BeuiSelect motion fidelity', () {
    testWidgets('options stagger with blur under normal motion', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_select()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pick'));
      await tester.pump(); // one frame into the open — mid-stagger
      await tester.pump(const Duration(milliseconds: 40));
      // A blur ImageFilter is applied to still-entering option rows.
      expect(find.byType(ImageFiltered), findsWidgets);
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion drops the option blur', (tester) async {
      await tester.pumpWidget(_app(_select(), reduce: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pick'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byType(ImageFiltered), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);
    });
  });

  group('BeuiMorphSelect', () {
    testWidgets('shows the selected value in the trigger', (tester) async {
      await tester.pumpWidget(_app(_morph(defaultValue: 'banana')));
      await tester.pumpAndSettle();
      expect(find.text('Banana'), findsWidgets);
    });

    testWidgets('tap header opens and selecting commits', (tester) async {
      String? picked;
      await tester.pumpWidget(_app(_morph(onChanged: (v) => picked = v)));
      await tester.pumpAndSettle();
      // Tap the collapsed trigger/header (placeholder) to open.
      await tester.tap(find.text('Pick').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apple').first);
      await tester.pumpAndSettle();
      expect(picked, 'apple');
    });

    testWidgets('reduced motion still commits a selection', (tester) async {
      String? picked;
      await tester.pumpWidget(
        _app(_morph(onChanged: (v) => picked = v), reduce: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pick').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Banana').first);
      await tester.pumpAndSettle();
      expect(picked, 'banana');
    });
  });

  testWidgets('rest-state golden (default + morph closed)', (tester) async {
    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 200,
              child: BeuiSelect(
                options: _options,
                defaultValue: 'apple',
                placeholder: 'Pick',
                onChanged: _noop,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: BeuiMorphSelect(
                options: _options,
                defaultValue: 'banana',
                placeholder: 'Pick',
                onChanged: _noop,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Column).first,
      matchesGoldenFile('goldens/beui_select.png'),
    );
  });
}

void _noop(String _) {}
