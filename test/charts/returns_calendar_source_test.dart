import 'dart:ui' show PointerDeviceKind;
import 'dart:io';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beui/src/motion/_focus_ring.dart';

import '../support.dart' as support;

Widget beuiTestApp(Widget child, {bool reduce = false, bool dark = false}) =>
    support.beuiTestApp(child, reduce: reduce, dark: dark, fontFamily: 'Geist');

Future<void> _loadReturnsFonts() async {
  for (final family in ['Geist', 'GeistMono']) {
    final loader = FontLoader(family == 'GeistMono' ? 'Geist Mono' : family);
    for (final weight
        in family == 'GeistMono'
            ? ['Regular', 'Medium']
            : ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(
        File(
          'example/assets/fonts/$family-$weight.ttf',
        ).readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
      );
    }
    await loader.load();
  }
}

const _previewYears = [2021, 2022, 2023, 2024, 2025];
const _previewReturns = [
  [1.1, 4.0, -4.2, 5.5, 6.9, 5.4, 5.2, -2.9, -2.3, -1.9, -3.9, 1.6],
  [3.4, -3.3, -4.5, -0.4, -3.4, -3.0, -1.4, -1.1, -7.0, 3.8, 0.3, 2.4],
  [4.9, 2.4, 0.7, -1.9, 0.0, 5.3, 6.2, 4.3, 4.6, 5.1, -2.6, -0.6],
  [-3.2, -2.2, -2.3, -2.3, 4.1, -2.2, 3.2, -3.3, -3.7, 4.0, -0.8, 3.5],
  [4.4, -0.8, 3.8, -1.8, -3.1, -2.3, -3.0, 4.6, -1.7, -0.7, -4.8, -2.8],
];

Widget _sourceFixture({
  bool selectionIsControlled = false,
  ValueChanged<BeuiReturnsCalendarSelection?>? onSelectionChange,
}) => BeuiReturnsCalendar(
  years: _previewYears,
  returns: _previewReturns,
  selectionIsControlled: selectionIsControlled,
  onSelectionChange: onSelectionChange,
);

Finder _cell(int row, int month) =>
    find.byKey(ValueKey('beui-returns-cell-$row-$month'));

Finder _semanticsFor(Finder cell) => find
    .ancestor(
      of: cell,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            widget.properties.selected != null &&
            widget.properties.label != null,
      ),
    )
    .first;

Finder _inkWellFor(Finder cell) =>
    find.ancestor(of: cell, matching: find.byType(InkWell)).first;

double _ringOpacity(WidgetTester tester, Finder cell) => tester
    .widgetList<FadeTransition>(
      find.descendant(of: cell, matching: find.byType(FadeTransition)),
    )
    .last
    .opacity
    .value;

Finder _paintedFocusRing(Finder cell) => find.descendant(
  of: cell,
  matching: find.byWidgetPredicate((widget) {
    if (widget is! DecoratedBox || widget.decoration is! BoxDecoration) {
      return false;
    }
    final border = (widget.decoration as BoxDecoration).border;
    return border is Border && border.top.width == 2;
  }),
);

double _renderedOpacity(WidgetTester tester, Finder finder) {
  var opacity = 1.0;
  for (
    RenderObject? node = tester.renderObject<RenderObject>(finder);
    node != null;
    node = node.parent
  ) {
    if (node is RenderOpacity) {
      opacity *= node.opacity;
    } else if (node is RenderAnimatedOpacity) {
      opacity *= node.opacity.value;
    }
  }
  return opacity;
}

double _contentOpacity(WidgetTester tester, Finder cell) => _renderedOpacity(
  tester,
  find.descendant(of: cell, matching: find.byType(Text)).last,
);

double _contentScale(WidgetTester tester, Finder cell) {
  final content = tester.renderObject<RenderObject>(
    find.descendant(of: cell, matching: find.byType(Text)).last,
  );
  return content
      .getTransformTo(tester.renderObject<RenderObject>(cell))
      .entry(0, 0);
}

class _MountedProbe extends StatefulWidget {
  const _MountedProbe({required this.onMount, required this.onDispose});
  final VoidCallback onMount;
  final VoidCallback onDispose;
  @override
  State<_MountedProbe> createState() => _MountedProbeState();
}

class _MountedProbeState extends State<_MountedProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Text('custom descendant');
}

void main() {
  setUpAll(_loadReturnsFonts);
  testWidgets('matches preview fixture and literal settled annual value', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(_sourceFixture()));
    expect(find.text("'21"), findsOneWidget);
    expect(find.text('+14%'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('beui-returns-cell-0-12')),
      findsOneWidget,
    );

    await tester.tap(_cell(0, 12));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final ticker = tester.widget<BeuiChartTicker>(find.byType(BeuiChartTicker));
    expect(ticker.value, closeTo(14.4554339, 0.000001));
    expect(ticker.format(ticker.value), '+14.5%');
    expect(tester.takeException(), isNull);
  });

  testWidgets('source integer tint and numeral mixes use fixed outcomes', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiReturnsCalendar(
          years: [2024],
          returns: [
            [1, 2, 4, 8, -2, 0, 0, 0, 0, 0, 0, 0],
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Jan 2024 +1.0%'), findsOneWidget);

    const expectedBackgrounds = <int, Color>{
      0: Color(0xFFD6F3E6),
      1: Color(0xFFC5EEDC),
      2: Color(0xFFA1E6C7),
      3: Color(0xFF5DD5A0),
      4: Color(0xFFF9D0D2),
    };
    const expectedText = <int, Color>{
      0: Color(0xDE0B0B0B), // source round(85 + 1/8*15) = 87%.
      1: Color(0xE30B0B0B), // 89%.
      2: Color(0xED0B0B0B), // 93%.
      3: Color(0xFF0B0B0B), // 100%.
      4: Color(0xE30B0B0B), // 89%, sign-neutral.
    };
    for (var month = 0; month < expectedBackgrounds.length; month++) {
      final cell = _cell(0, month);
      final panel = tester.widget<AnimatedContainer>(
        find
            .descendant(of: cell, matching: find.byType(AnimatedContainer))
            .last,
      );
      expect(
        (panel.decoration! as BoxDecoration).color!.toARGB32(),
        expectedBackgrounds[month]!.toARGB32(),
      );
      final numeral = tester.widget<Text>(
        find.descendant(of: cell, matching: find.byType(Text)).last,
      );
      expect(numeral.style!.color!.toARGB32(), expectedText[month]!.toARGB32());
      expect(numeral.style!.fontFamily, 'Geist Mono');
      expect(numeral.style!.fontSize, 9);
      expect(numeral.style!.fontWeight, FontWeight.w500);
    }
    final yearCell = _cell(0, 12);
    final annualText = tester.widget<Text>(
      find.descendant(of: yearCell, matching: find.byType(Text)).last,
    );
    expect(annualText.style!.fontFamily, 'Geist Mono');
    expect(annualText.style!.fontSize, 11);
    expect(annualText.style!.fontWeight, FontWeight.w500);
    final yearLabelStyle = tester.widget<AnimatedDefaultTextStyle>(
      find
          .ancestor(
            of: find.text("'24"),
            matching: find.byType(AnimatedDefaultTextStyle),
          )
          .first,
    );
    expect(yearLabelStyle.style.fontFamily, 'Geist Mono');
    expect(yearLabelStyle.style.fontSize, 10);
    expect(yearLabelStyle.style.fontWeight, FontWeight.w400);
    expect(yearLabelStyle.textAlign, TextAlign.right);
  });

  testWidgets(
    'annual and tooltip ink use source OKLCH outcomes by brightness',
    (tester) async {
      for (final (dark, expected) in [
        (false, const Color(0xFF007E2F)),
        (true, const Color(0xFF00BE6A)),
      ]) {
        await tester.pumpWidget(beuiTestApp(_sourceFixture(), dark: dark));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();
        final annual = _cell(0, 12);
        final annualNumeral = tester.widget<Text>(
          find.descendant(of: annual, matching: find.byType(Text)).last,
        );
        expect(annualNumeral.style!.color, expected);

        await tester.tap(annual);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<BeuiChartTicker>(find.byType(BeuiChartTicker))
              .style!
              .color,
          expected,
        );
        expect(
          tester
              .widget<BeuiChartTicker>(find.byType(BeuiChartTicker))
              .style!
              .fontFamily,
          'Geist Mono',
        );
      }
      final heading = tester.widget<AnimatedDefaultTextStyle>(
        find
            .ancestor(
              of: find.text('J').first,
              matching: find.byType(AnimatedDefaultTextStyle),
            )
            .first,
      );
      expect(heading.style.fontFamily, 'Geist');
      expect(heading.style.fontFamily, isNot('Geist Mono'));
    },
  );

  testWidgets(
    'monthly pin, March preview and commit compound the inclusive run',
    (tester) async {
      await tester.pumpWidget(beuiTestApp(_sourceFixture()));
      await tester.tap(_cell(0, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(_cell(0, 2)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      final preview = tester.widget<BeuiChartTicker>(
        find.byType(BeuiChartTicker),
      );
      expect(preview.value, closeTo(0.746, 0.02));
      expect(preview.format(preview.value), '+0.7%');
      await tester.tap(_cell(0, 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final committed = tester.widget<BeuiChartTicker>(
        find.byType(BeuiChartTicker),
      );
      expect(committed.value, closeTo(0.746, 0.02));
      expect(committed.format(committed.value), '+0.7%');
      await mouse.removePointer();
    },
  );

  testWidgets(
    'custom composition and tooltip renderer receive source-shaped data',
    (tester) async {
      BeuiReturnsCalendarTooltipData? received;
      await tester.pumpWidget(
        beuiTestApp(
          BeuiReturnsCalendar(
            years: _previewYears,
            returns: _previewReturns,
            child: BeuiReturnsCalendarGrid(
              child: BeuiReturnsCalendarTooltip(
                builder: (context, data) {
                  received = data;
                  return Text(
                    '${data.label}: ${data.value.toStringAsFixed(1)} ${data.note ?? ''}',
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(_cell(0, 12));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(received?.label, '2021');
      expect(received?.value, closeTo(14.4554339, 0.000001));
      expect(received?.note, 'for the year');
      expect(find.text('2021: 14.5 for the year'), findsOneWidget);
    },
  );

  testWidgets('wrapped tooltip composes once with the root state and anchor', (
    tester,
  ) async {
    var mounts = 0;
    var disposals = 0;
    BeuiReturnsCalendar makeCalendar() => BeuiReturnsCalendar(
      years: _previewYears,
      returns: _previewReturns,
      child: BeuiReturnsCalendarGrid(
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MountedProbe(
                onMount: () => mounts++,
                onDispose: () => disposals++,
              ),
              BeuiReturnsCalendarTooltip(
                builder: (context, data) =>
                    Text('${data.label}: ${data.value.toStringAsFixed(1)}'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(beuiTestApp(makeCalendar()));
    expect(find.text('custom descendant'), findsOneWidget);
    expect(mounts, 1);

    await tester.tap(_cell(0, 0));
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Jan 2021: 1.1'), findsOneWidget);
    final januaryTip = find
        .ancestor(
          of: find.text('Jan 2021: 1.1'),
          matching: find.byType(DecoratedBox),
        )
        .first;
    expect(
      (tester.getCenter(januaryTip).dx - tester.getCenter(_cell(0, 0)).dx)
          .abs(),
      lessThan(20),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(_cell(0, 2)));
    await tester.pump();
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);
    expect(find.text('Jan 2021 – Mar 2021: 0.7'), findsOneWidget);
    final marchTip = find
        .ancestor(
          of: find.text('Jan 2021 – Mar 2021: 0.7'),
          matching: find.byType(DecoratedBox),
        )
        .first;
    expect(
      (tester.getCenter(marchTip).dx - tester.getCenter(_cell(0, 2)).dx).abs(),
      lessThan(20),
    );
    expect(find.text('custom descendant'), findsOneWidget);

    await tester.pumpWidget(beuiTestApp(const SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(mounts, 1);
    expect(disposals, 1);
    expect(find.text('custom descendant'), findsNothing);
    expect(find.byType(BeuiTooltip), findsNothing);
    await mouse.removePointer();
  });

  testWidgets(
    'default root includes a tooltip and an explicit bare grid omits it',
    (tester) async {
      await tester.pumpWidget(beuiTestApp(_sourceFixture()));
      await tester.tap(_cell(0, 0));
      await tester.pump();
      expect(
        tester
            .widgetList<BeuiTooltip>(find.byType(BeuiTooltip))
            .any((tooltip) => tooltip.open == true),
        isTrue,
      );

      await tester.pumpWidget(
        beuiTestApp(
          BeuiReturnsCalendar(
            years: _previewYears,
            returns: _previewReturns,
            child: const BeuiReturnsCalendarGrid(),
          ),
        ),
      );
      await tester.tap(_cell(0, 0));
      await tester.pump();
      expect(find.byType(BeuiTooltip), findsNothing);
      expect(find.text('Jan 2021'), findsNothing);
    },
  );

  testWidgets('uncontrolled anchors, extension and clears each report once', (
    tester,
  ) async {
    final changes = <BeuiReturnsCalendarSelection?>[];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiReturnsCalendar(
          years: _previewYears,
          returns: _previewReturns,
          onSelectionChange: changes.add,
          child: const BeuiReturnsCalendarGrid(),
        ),
        reduce: true,
      ),
    );
    for (final (year, month) in [
      (0, 0),
      (0, 2),
      (0, 5),
      (0, 12),
      (0, 1),
      (0, 1),
    ]) {
      await tester.tap(_cell(year, month));
      await tester.pump();
    }
    expect(
      changes
          .map(
            (selection) => selection == null
                ? null
                : (
                    selection.start.year,
                    selection.start.month,
                    selection.end?.year,
                    selection.end?.month,
                  ),
          )
          .toList(),
      [
        (0, 0, null, null),
        (0, 0, 0, 2),
        null,
        (0, 12, null, null),
        (0, 1, null, null),
        null,
      ],
    );
  });

  testWidgets('explicit controlled null reports clicks without selecting', (
    tester,
  ) async {
    BeuiReturnsCalendarSelection? changed = const BeuiReturnsCalendarSelection(
      start: BeuiReturnsCalendarCell(year: 0, month: 0),
    );
    await tester.pumpWidget(
      beuiTestApp(
        _sourceFixture(
          selectionIsControlled: true,
          onSelectionChange: (value) => changed = value,
        ),
      ),
    );
    await tester.tap(_cell(0, 1));
    await tester.pump();
    expect(changed?.start, const BeuiReturnsCalendarCell(year: 0, month: 1));
    expect(
      tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((node) => node.properties.selected == true),
      isEmpty,
    );
  });

  testWidgets('controlled locked span owns its hot cell and tooltip value', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        BeuiReturnsCalendar(
          years: _previewYears,
          returns: _previewReturns,
          selectionIsControlled: true,
          selection: const BeuiReturnsCalendarSelection(
            start: BeuiReturnsCalendarCell(year: 0, month: 0),
            end: BeuiReturnsCalendarCell(year: 0, month: 2),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    final ticker = tester.widget<BeuiChartTicker>(find.byType(BeuiChartTicker));
    expect(ticker.value, closeTo(0.746, 0.02));
    expect(ticker.format(ticker.value), '+0.7%');
    expect(find.text('Jan 2021 – Mar 2021'), findsOneWidget);
    expect(
      tester.widget<Semantics>(_semanticsFor(_cell(0, 1))).properties.selected,
      isFalse,
    );
    expect(
      tester.widget<Semantics>(_semanticsFor(_cell(0, 2))).properties.selected,
      isTrue,
    );
  });

  testWidgets(
    'month span rings only its endpoints and year span keeps rows lit',
    (tester) async {
      final monthSpan = BeuiReturnsCalendar(
        years: _previewYears,
        returns: _previewReturns,
        selectionIsControlled: true,
        selection: const BeuiReturnsCalendarSelection(
          start: BeuiReturnsCalendarCell(year: 0, month: 11),
          end: BeuiReturnsCalendarCell(year: 1, month: 1),
        ),
      );
      await tester.pumpWidget(beuiTestApp(monthSpan));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      AnimatedContainer cellPanel(int row, int month) =>
          tester.widget<AnimatedContainer>(
            find
                .descendant(
                  of: _cell(row, month),
                  matching: find.byType(AnimatedContainer),
                )
                .last,
          );
      BoxDecoration decoration(int row, int month) =>
          cellPanel(row, month).decoration! as BoxDecoration;
      expect(decoration(0, 11).border, isNotNull);
      expect(decoration(1, 1).border, isNotNull);
      expect(decoration(1, 0).border, isNull);

      await tester.pumpWidget(
        beuiTestApp(
          BeuiReturnsCalendar(
            years: _previewYears,
            returns: _previewReturns,
            selectionIsControlled: true,
            selection: const BeuiReturnsCalendarSelection(
              start: BeuiReturnsCalendarCell(year: 0, month: 12),
              end: BeuiReturnsCalendarCell(year: 2, month: 12),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(_contentOpacity(tester, _cell(1, 0)), 1);
      expect(_contentOpacity(tester, _cell(1, 12)), 1);
      expect(_contentOpacity(tester, _cell(3, 0)), .35);
      expect(_contentOpacity(tester, _cell(3, 12)), .35);
      expect(
        tester
            .widget<Semantics>(_semanticsFor(_cell(1, 12)))
            .properties
            .selected,
        isFalse,
      );
      expect(
        tester
            .widget<Semantics>(_semanticsFor(_cell(0, 12)))
            .properties
            .selected,
        isTrue,
      );
    },
  );

  testWidgets('annual hover dims other annual rows, not its own row', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(_sourceFixture()));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(_cell(0, 12)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(_contentOpacity(tester, _cell(0, 12)), 1);
    expect(_contentOpacity(tester, _cell(1, 12)), .35);
    expect(_contentOpacity(tester, _cell(0, 0)), 1);
    expect(_contentOpacity(tester, _cell(1, 0)), .35);

    await mouse.moveTo(tester.getCenter(_cell(0, 0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(_contentOpacity(tester, _cell(0, 0)), 1);
    expect(_contentOpacity(tester, _cell(1, 0)), 1);
    expect(_contentOpacity(tester, _cell(1, 1)), .35);
    expect(_contentOpacity(tester, _cell(1, 12)), .35);
    await mouse.removePointer();
  });

  testWidgets('initial Tab, mouse, next Tab and focus leave update rings', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        Column(
          children: [
            _sourceFixture(),
            const TextField(key: ValueKey('returns-calendar-outside')),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    final first = _cell(0, 0);
    final second = _cell(0, 1);
    final outside = find.byKey(const ValueKey('returns-calendar-outside'));
    await tester.tap(outside);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester.widget<InkWell>(_inkWellFor(first)).focusNode!.hasPrimaryFocus,
      isTrue,
    );
    expect(tester.widget<BeuiFocusRing>(first).focused, isTrue);
    expect(_paintedFocusRing(first), findsNothing);
    await tester.pump(const Duration(milliseconds: 75));
    expect(_paintedFocusRing(first), findsOneWidget);
    expect(_renderedOpacity(tester, _paintedFocusRing(first)), greaterThan(0));
    expect(_renderedOpacity(tester, _paintedFocusRing(first)), lessThan(1));
    await tester.pump(const Duration(milliseconds: 75));
    expect(_renderedOpacity(tester, _paintedFocusRing(first)), 1);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(first));
    await tester.pump();
    expect(tester.widget<BeuiFocusRing>(first).focused, isFalse);
    await tester.pump(const Duration(milliseconds: 75));
    expect(_paintedFocusRing(first), findsOneWidget);
    expect(_renderedOpacity(tester, _paintedFocusRing(first)), greaterThan(0));
    expect(_renderedOpacity(tester, _paintedFocusRing(first)), lessThan(1));
    await tester.pump(const Duration(milliseconds: 75));
    expect(_paintedFocusRing(first), findsNothing);
    await mouse.down(tester.getCenter(first));
    await tester.pump();
    await mouse.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.widget<BeuiFocusRing>(first).focused, isFalse);
    expect(_paintedFocusRing(first), findsNothing);
    expect(_ringOpacity(tester, first), 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester.widget<InkWell>(_inkWellFor(second)).focusNode!.hasPrimaryFocus,
      isTrue,
    );
    expect(tester.widget<BeuiFocusRing>(first).focused, isFalse);
    expect(tester.widget<BeuiFocusRing>(second).focused, isTrue);
    expect(_paintedFocusRing(second), findsNothing);
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 75));
    expect(_paintedFocusRing(second), findsOneWidget);
    expect(_renderedOpacity(tester, _paintedFocusRing(second)), greaterThan(0));
    expect(_renderedOpacity(tester, _paintedFocusRing(second)), lessThan(1));
    expect(_ringOpacity(tester, second), 0);
    final endpointDecoration =
        tester
                .widget<AnimatedContainer>(
                  find
                      .descendant(
                        of: second,
                        matching: find.byType(AnimatedContainer),
                      )
                      .last,
                )
                .decoration!
            as BoxDecoration;
    expect((endpointDecoration.border! as Border).top.width, 1.5);
    await tester.pump(const Duration(milliseconds: 75));
    expect(_renderedOpacity(tester, _paintedFocusRing(second)), 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    await tester.tap(outside);
    await tester.pump();
    expect(tester.widget<BeuiFocusRing>(second).focused, isFalse);
    await tester.pump(const Duration(milliseconds: 75));
    expect(_paintedFocusRing(second), findsOneWidget);
    expect(_renderedOpacity(tester, _paintedFocusRing(second)), greaterThan(0));
    expect(_renderedOpacity(tester, _paintedFocusRing(second)), lessThan(1));
    await tester.pump(const Duration(milliseconds: 75));
    expect(_paintedFocusRing(second), findsNothing);
    expect(
      tester
          .widgetList<BeuiTooltip>(find.byType(BeuiTooltip))
          .any((tip) => tip.open == true),
      isFalse,
    );
    await mouse.removePointer();
  });

  testWidgets(
    'keyboard-hot month lifts on a hover-capable platform',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          Column(
            children: [
              const TextField(key: ValueKey('returns-calendar-keyboard-start')),
              _sourceFixture(),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('returns-calendar-keyboard-start')),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      final first = _cell(0, 0);
      final scales = tester
          .widgetList<Transform>(
            find.descendant(of: first, matching: find.byType(Transform)),
          )
          .map((transform) => transform.transform.getMaxScaleOnAxis());
      expect(scales.any((scale) => (scale - 1.15).abs() < 0.001), isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'touch-only platform does not lift a keyboard-hot month',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          Column(
            children: [
              const TextField(key: ValueKey('returns-touch-only-start')),
              _sourceFixture(),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('returns-touch-only-start')));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(
        tester
            .widget<InkWell>(_inkWellFor(_cell(0, 0)))
            .focusNode!
            .hasPrimaryFocus,
        isTrue,
      );
      expect(_contentScale(tester, _cell(0, 0)), 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('reduced initial entrance is immediately visible at targets', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(_sourceFixture(), reduce: true));
    for (final cell in [_cell(0, 0), _cell(0, 12)]) {
      expect(_contentOpacity(tester, cell), 1);
      expect(_contentScale(tester, cell), 1);
      final scales = tester
          .widgetList<Transform>(
            find.descendant(of: cell, matching: find.byType(Transform)),
          )
          .map((transform) => transform.transform.getMaxScaleOnAxis());
      expect(scales, everyElement(1));
    }
  });

  testWidgets('hot ring and outer dim use independent source fades', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(_sourceFixture()));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(_cell(0, 0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    double opacityOf(Finder cell, int index) => tester
        .widgetList<FadeTransition>(
          find.descendant(of: cell, matching: find.byType(FadeTransition)),
        )
        .elementAt(index)
        .opacity
        .value;

    final hot = _cell(0, 0);
    final dimmed = _cell(1, 1);
    expect(
      tester
          .widgetList<AnimatedOpacity>(
            find.descendant(of: hot, matching: find.byType(AnimatedOpacity)),
          )
          .last
          .duration,
      const Duration(milliseconds: 120),
    );
    expect(opacityOf(hot, 1), greaterThan(0));
    expect(opacityOf(hot, 1), lessThan(1));
    expect(opacityOf(dimmed, 0), greaterThan(.35));
    expect(opacityOf(dimmed, 0), lessThan(1));
    await tester.pump(const Duration(milliseconds: 80));
    expect(opacityOf(hot, 1), 1);
    await tester.pump(const Duration(milliseconds: 120));
    expect(opacityOf(dimmed, 0), .35);

    await mouse.moveTo(tester.getCenter(_cell(0, 1)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(opacityOf(hot, 1), greaterThan(0));
    expect(opacityOf(hot, 1), lessThan(1));
    await tester.pump(const Duration(milliseconds: 60));
    expect(opacityOf(hot, 1), 0);
    await mouse.removePointer();
  });

  testWidgets('annual replay follows hot state with the annual-anchor guard', (
    tester,
  ) async {
    const month = BeuiReturnsCalendarCell(year: 0, month: 0);
    const annual = BeuiReturnsCalendarCell(year: 0, month: 12);
    const annualEnd = BeuiReturnsCalendarCell(year: 1, month: 12);
    final cases = [
      (null, true),
      (const BeuiReturnsCalendarSelection(start: month), true),
      (const BeuiReturnsCalendarSelection(start: annual), false),
      (
        const BeuiReturnsCalendarSelection(start: annual, end: annualEnd),
        false,
      ),
    ];
    for (var index = 0; index < cases.length; index++) {
      final (selection, pulses) = cases[index];
      BeuiReturnsCalendarSelection? changed = selection;
      await tester.pumpWidget(
        beuiTestApp(
          BeuiReturnsCalendar(
            key: ValueKey('replay-$index'),
            years: _previewYears,
            returns: _previewReturns,
            defaultSelection: selection,
            onSelectionChange: (value) => changed = value,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(_cell(0, 12)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      if (pulses) {
        expect(_contentScale(tester, _cell(0, 0)), greaterThan(1));
        expect(_contentScale(tester, _cell(0, 0)), lessThanOrEqualTo(1.1));
      } else {
        expect(_contentScale(tester, _cell(0, 0)), 1);
      }
      expect(_contentScale(tester, _cell(0, 11)), 1);
      await tester.pump(const Duration(milliseconds: 270));
      expect(_contentScale(tester, _cell(0, 0)), 1);
      expect(_contentScale(tester, _cell(0, 11)), 1);
      await tester.pump(const Duration(milliseconds: 115));
      if (pulses) {
        expect(_contentScale(tester, _cell(0, 11)), greaterThan(1));
        expect(_contentScale(tester, _cell(0, 11)), lessThanOrEqualTo(1.1));
      } else {
        expect(_contentScale(tester, _cell(0, 11)), 1);
      }
      await tester.pump(const Duration(milliseconds: 270));
      expect(_contentScale(tester, _cell(0, 11)), 1);
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(_contentScale(tester, _cell(0, 0)), 1);
      if (index == 2) expect(find.text('2021'), findsOneWidget);
      if (index == 3) expect(find.text('2021 – 2022'), findsOneWidget);
      await mouse.moveTo(tester.getCenter(_cell(0, 12)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      if (pulses) {
        expect(_contentScale(tester, _cell(0, 0)), greaterThan(1));
      } else {
        expect(_contentScale(tester, _cell(0, 0)), 1);
      }
      if (index == 3) {
        await mouse.moveTo(tester.getCenter(_cell(1, 12)));
        await mouse.down(tester.getCenter(_cell(1, 12)));
        await mouse.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 450));
        expect(changed, isNull);
        await mouse.moveTo(Offset.zero);
        await tester.pump();
        await mouse.moveTo(tester.getCenter(_cell(0, 12)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 90));
        expect(_contentScale(tester, _cell(0, 0)), greaterThan(1));
      }
      await mouse.removePointer();
    }
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiReturnsCalendar(
          key: ValueKey('replay-reduced'),
          years: _previewYears,
          returns: _previewReturns,
        ),
        reduce: true,
      ),
    );
    final reducedMouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await reducedMouse.addPointer(location: Offset.zero);
    await reducedMouse.moveTo(tester.getCenter(_cell(0, 12)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(_contentScale(tester, _cell(0, 0)), 1);
    expect(_contentScale(tester, _cell(0, 11)), 1);
    expect(_contentOpacity(tester, _cell(0, 0)), 1);
    await reducedMouse.removePointer();
  });

  testWidgets('navigation keys preserve the source native Tab order', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(_sourceFixture()));
    await tester.tap(_cell(0, 0));
    await tester.pump();
    final first = tester.widget<InkWell>(_inkWellFor(_cell(0, 0))).focusNode!;
    expect(first.hasPrimaryFocus, isTrue);
    for (final key in [
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.home,
      LogicalKeyboardKey.end,
      LogicalKeyboardKey.pageUp,
      LogicalKeyboardKey.pageDown,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
      expect(first.hasPrimaryFocus, isTrue, reason: '$key');
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester
          .widget<InkWell>(_inkWellFor(_cell(0, 1)))
          .focusNode!
          .hasPrimaryFocus,
      isTrue,
    );
  });

  testWidgets('shared tooltip panel stays clamped with source insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 260);
    tester.view.devicePixelRatio = 1;
    final wrappedTooltip = List.filled(
      4,
      'Returns details wrap inside the shared tooltip panel.',
    ).join(' ');
    await tester.pumpWidget(
      beuiTestApp(
        SingleChildScrollView(
          child: SizedBox(
            height: 620,
            child: Column(
              children: [
                Transform.translate(
                  offset: const Offset(12, 8),
                  child: BeuiReturnsCalendar(
                    years: _previewYears,
                    returns: _previewReturns,
                    tooltipBuilder: (context, data) =>
                        SizedBox(width: 180, child: Text(wrappedTooltip)),
                  ),
                ),
                const SizedBox(height: 420),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(_cell(4, 12));
    await tester.tap(_cell(4, 12));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    final text = find.text(wrappedTooltip);
    expect(text, findsOneWidget);
    final panel = find
        .ancestor(of: text, matching: find.byType(DecoratedBox))
        .first;
    var rect = tester.getRect(panel);
    final contentRect = tester.getRect(text);
    expect(contentRect.height, greaterThan(16));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(260));
    expect(rect.left, lessThan(contentRect.left));
    expect(rect.right, greaterThan(contentRect.right));
    expect(rect.top, lessThan(contentRect.top));
    expect(rect.bottom, greaterThan(contentRect.bottom));
    expect(rect.width - contentRect.width, greaterThanOrEqualTo(22));
    expect(rect.height - contentRect.height, greaterThanOrEqualTo(10));

    tester.view.physicalSize = const Size(240, 220);
    await tester.pump();
    await tester.pumpAndSettle();
    rect = tester.getRect(panel);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(240));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(220));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(beuiTestApp(const SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text(wrappedTooltip), findsNothing);
    expect(find.byType(BeuiTooltip), findsNothing);
    expect(tester.takeException(), isNull);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets(
    'hover lift is spring-driven normally and absent under reduced motion',
    (tester) async {
      await tester.pumpWidget(beuiTestApp(_sourceFixture()));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      final cell = _cell(0, 0);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(cell));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      final lifted = tester
          .widgetList<Transform>(
            find.descendant(of: cell, matching: find.byType(Transform)),
          )
          .map((transform) => transform.transform.getMaxScaleOnAxis());
      expect(lifted.any((scale) => (scale - 1.15).abs() < 0.001), isTrue);
      await mouse.removePointer();

      await tester.pumpWidget(beuiTestApp(_sourceFixture(), reduce: true));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      final reducedCell = _cell(0, 0);
      final touch = await tester.createGesture(kind: PointerDeviceKind.touch);
      await touch.down(tester.getCenter(reducedCell));
      await tester.pump();
      await touch.up();
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      final reducedScales = tester
          .widgetList<Transform>(
            find.descendant(of: reducedCell, matching: find.byType(Transform)),
          )
          .map((transform) => transform.transform.getMaxScaleOnAxis());
      expect(reducedScales, everyElement(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('touch press uses source scale feedback without an ink splash', (
    tester,
  ) async {
    await tester.pumpWidget(beuiTestApp(_sourceFixture()));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    final cell = _cell(0, 0);
    final touch = await tester.createGesture(kind: PointerDeviceKind.touch);
    await touch.down(tester.getCenter(cell));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final pressedScale = _contentScale(tester, cell);
    expect(pressedScale, greaterThan(.92));
    expect(pressedScale, lessThan(1));
    await touch.up();
    await tester.pumpAndSettle();
    expect(_contentScale(tester, cell), 1);
  });
}
