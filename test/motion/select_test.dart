import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

Widget _compactSelect({
  required List<BeuiSelectOption> options,
  String? value,
  String placeholder = 'Pick',
  bool enabled = true,
}) => BeuiSelect(
  options: options,
  value: value,
  placeholder: placeholder,
  enabled: enabled,
  variant: BeuiSelectVariant.compact,
);

Rect _panelRectForOption(WidgetTester tester, String label) {
  final containers = find.ancestor(
    of: find.text(label),
    matching: find.byType(Container),
  );
  final panel = containers
      .evaluate()
      .map((element) {
        final box = element.renderObject! as RenderBox;
        return box.size.width == 208 ? box : null;
      })
      .whereType<RenderBox>()
      .first;
  return panel.localToGlobal(Offset.zero) & panel.size;
}

Container _triggerContainer(WidgetTester tester) => tester.widget<Container>(
  find
      .descendant(of: find.byType(BeuiSelect), matching: find.byType(Container))
      .first,
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
  group('BeuiSelect compact trigger', () {
    testWidgets('3x text grows the compact trigger instead of clipping', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3)),
            child: _compactSelect(
              options: const [
                BeuiSelectOption(
                  value: 'long',
                  label: 'GPT',
                  icon: Icon(Icons.star),
                ),
              ],
              value: 'long',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final paragraph = tester.renderObject<RenderParagraph>(find.text('GPT'));
      expect(paragraph.textSize.height, 48);
      expect(paragraph.size.height, paragraph.textSize.height);
      expect(tester.getSize(find.byType(BeuiSelect)).height, 48);
      expect(tester.getSize(find.byIcon(Icons.star)), const Size(14, 14));
    });

    testWidgets('caps long labels at 208px and truncates them', (tester) async {
      const label =
          'A very long selected model label that should not widen the picker';
      await tester.pumpWidget(
        _app(
          _compactSelect(
            options: const [BeuiSelectOption(value: 'long', label: label)],
            value: 'long',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final trigger = find.byType(BeuiSelect);
      expect(tester.getSize(trigger).width, lessThanOrEqualTo(208));
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.overflow, TextOverflow.ellipsis);
      expect(paragraph.maxLines, 1);
      expect(paragraph.didExceedMaxLines, isTrue);
    });

    testWidgets('single-lines a long placeholder without options', (
      tester,
    ) async {
      const placeholder = 'Choose a very long model name';
      await tester.pumpWidget(
        _app(_compactSelect(options: const [], placeholder: placeholder)),
      );
      await tester.pumpAndSettle();

      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(placeholder),
      );
      expect(paragraph.maxLines, 1);
      expect(paragraph.didExceedMaxLines, isTrue);
      await tester.tap(find.text(placeholder));
      await tester.pumpAndSettle();
      expect(find.text(placeholder), findsOneWidget);
      expect(find.byType(CompositedTransformFollower), findsOneWidget);
    });

    testWidgets('uses muted fill on hover and focus ring on focus', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_compactSelect(options: _options)));
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.text('Pick')));
      await mouse.moveTo(tester.getCenter(find.text('Pick')));
      await tester.pumpAndSettle();

      var trigger = _triggerContainer(tester);
      expect(
        (trigger.decoration! as BoxDecoration).color,
        BeuiColors.light().muted,
      );

      await mouse.removePointer();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      trigger = _triggerContainer(tester);
      expect((trigger.decoration! as BoxDecoration).boxShadow, isNotEmpty);
      await tester.pumpAndSettle();
    });

    testWidgets('keeps the 208px panel on-screen at the right edge', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.topRight,
                child: _compactSelect(options: _options),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();

      final panelRect = _panelRectForOption(tester, 'Apple');
      expect(panelRect.width, 208);
      expect(panelRect.right, lessThanOrEqualTo(320));
    });

    testWidgets('clamps the transformed panel in root-overlay coordinates', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(left: 200),
              child: Align(
                alignment: Alignment.topLeft,
                child: Transform.scale(
                  scale: 1.5,
                  alignment: Alignment.topLeft,
                  child: _compactSelect(options: _options),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();

      final panelFinder = find
          .ancestor(of: find.text('Apple'), matching: find.byType(Container))
          .evaluate()
          .map((element) => element.renderObject! as RenderBox)
          .firstWhere((box) => box.size.width == 208);
      final panel = panelFinder;
      final panelBounds = MatrixUtils.transformRect(
        panel.getTransformTo(null),
        Offset.zero & panel.size,
      );

      expect(panelBounds.width, closeTo(312, 0.01));
      expect(panelBounds.left, greaterThanOrEqualTo(0));
      expect(panelBounds.right, lessThanOrEqualTo(320));
    });

    testWidgets('keeps the panel on-screen at the left edge', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.topLeft,
                child: _compactSelect(options: _options),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();

      final panelRect = _panelRectForOption(tester, 'Apple');
      expect(panelRect.width, 208);
      expect(panelRect.left, greaterThanOrEqualTo(0));
    });

    testWidgets('flips the panel above a trigger near the bottom edge', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomLeft,
              child: _compactSelect(options: _options),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final triggerRect = tester.getRect(find.byType(BeuiSelect));
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();

      final panelRect = _panelRectForOption(tester, 'Apple');
      expect(panelRect.bottom, lessThanOrEqualTo(triggerRect.top));
    });

    testWidgets('does not retain hover fill across a disabled transition', (
      tester,
    ) async {
      Widget build({required bool enabled}) =>
          _app(_compactSelect(options: _options, enabled: enabled));

      await tester.pumpWidget(build(enabled: true));
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.text('Pick')));
      await mouse.moveTo(tester.getCenter(find.text('Pick')));
      await tester.pumpAndSettle();

      await tester.pumpWidget(build(enabled: false));
      await tester.pumpAndSettle();
      expect(
        (_triggerContainer(tester).decoration! as BoxDecoration).color,
        const Color(0x00000000),
      );
      await mouse.moveTo(const Offset(280, 280));
      await tester.pumpAndSettle();
      expect(
        (_triggerContainer(tester).decoration! as BoxDecoration).color,
        const Color(0x00000000),
      );
      await tester.pumpWidget(build(enabled: true));
      await tester.pumpAndSettle();

      expect(
        (_triggerContainer(tester).decoration! as BoxDecoration).color,
        const Color(0x00000000),
      );
      await mouse.moveTo(tester.getCenter(find.text('Pick')));
      await tester.pumpAndSettle();
      expect(
        (_triggerContainer(tester).decoration! as BoxDecoration).color,
        BeuiColors.light().muted,
      );
      await mouse.removePointer();
    });
  });

  testWidgets(
    'standard and MorphSelect keep their default width and 16px icon',
    (tester) async {
      const option = BeuiSelectOption(
        value: 'icon',
        label: 'Icon option',
        icon: Icon(Icons.star),
      );
      await tester.pumpWidget(
        _app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 200,
                child: BeuiSelect(options: const [option], value: 'icon'),
              ),
              SizedBox(
                width: 200,
                child: BeuiMorphSelect(options: const [option], value: 'icon'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(BeuiSelect)).width, 200);
      expect(tester.getSize(find.byType(BeuiMorphSelect)).width, 200);
      expect(tester.getSize(find.byIcon(Icons.star).first), const Size(16, 16));
      expect(tester.getSize(find.byIcon(Icons.star).last), const Size(16, 16));
    },
  );

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
      // The panel is closed, so its off-stage measurement copy (which also
      // carries the label) is excluded by find.text's default skipOffstage —
      // this must resolve to the closed trigger alone.
      expect(find.text('Banana'), findsOneWidget);
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
