import 'package:beui/src/motion/date_range_picker.dart';
import 'package:beui/src/theme/beui_colors.dart';
import 'package:beui/src/theme/beui_text_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool reduce = false}) => MaterialApp(
  theme: BeuiTextTheme.trackingNormal(
    ThemeData.light().copyWith(
      extensions: <ThemeExtension<dynamic>>[BeuiColors.light()],
    ),
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: Center(child: child),
      ),
    ),
  ),
);

void main() {
  testWidgets('trigger keeps the source 36px height and 13px type', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const BeuiDateRangePickerDropdown(
          value: BeuiDateRange(from: '2026-10-17', to: '2026-10-23'),
        ),
      ),
    );
    final trigger = find.byType(OutlinedButton);
    expect(tester.getSize(trigger).height, 36);
    final button = tester.widget<OutlinedButton>(trigger);
    expect(button.style!.textStyle!.resolve({})!.fontSize, 13);
    expect(find.text('Oct 17 – Oct 23, 2026'), findsOneWidget);
  });
  testWidgets(
    'trigger summarizes same-year, cross-year and incomplete ranges',
    (tester) async {
      for (final (range, expected) in <(BeuiDateRange, String)>[
        (
          const BeuiDateRange(from: '2026-10-17', to: '2026-10-23'),
          'Oct 17 – Oct 23, 2026',
        ),
        (
          const BeuiDateRange(from: '2025-12-30', to: '2026-01-02'),
          'Dec 30, 2025 – Jan 2, 2026',
        ),
        (const BeuiDateRange(from: '2026-10-17'), 'Oct 17, 2026 – Select end'),
      ]) {
        await tester.pumpWidget(
          _app(BeuiDateRangePickerDropdown(value: range)),
        );
        expect(find.text(expected), findsOneWidget);
      }
    },
  );

  group('BeuiDateRangePicker selection', () {
    testWidgets('hovering an idle day paints the muted background', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const BeuiDateRangePicker(defaultMonth: '2026-01-01')),
      );

      final day = find.text('13');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(day));
      await mouse.moveTo(tester.getCenter(day));
      await tester.pumpAndSettle();

      final dayContainer = tester.widget<AnimatedContainer>(
        find.ancestor(of: day, matching: find.byType(AnimatedContainer)).first,
      );
      expect(
        (dayContainer.decoration! as BoxDecoration).color,
        BeuiColors.light().muted,
      );
      await mouse.removePointer();
    });

    testWidgets('uncontrolled picker completes an inclusive range', (
      tester,
    ) async {
      BeuiDateRange? changed;
      await tester.pumpWidget(
        _app(
          BeuiDateRangePicker(
            defaultMonth: '2026-01-01',
            defaultValue: const BeuiDateRange(from: '2026-01-15'),
            onChanged: (value) => changed = value,
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel('Tuesday, January 20, 2026'));
      await tester.pumpAndSettle();

      expect(find.text('6 days selected'), findsOneWidget);
      expect(find.text('Jan 15, 2026'), findsOneWidget);
      expect(find.text('Jan 20, 2026'), findsOneWidget);
      expect(
        changed,
        const BeuiDateRange(from: '2026-01-15', to: '2026-01-20'),
      );
    });

    testWidgets('controlled picker reports a complete ordered range', (
      tester,
    ) async {
      BeuiDateRange? changed;
      await tester.pumpWidget(
        _app(
          BeuiDateRangePicker(
            value: const BeuiDateRange(from: '2026-01-15'),
            defaultMonth: '2026-01-01',
            onChanged: (value) => changed = value,
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel('Tuesday, January 13, 2026'));
      await tester.pump();

      expect(
        changed,
        const BeuiDateRange(from: '2026-01-13', to: '2026-01-15'),
      );
    });

    testWidgets('minimum and disabled dates cannot be selected', (
      tester,
    ) async {
      BeuiDateRange? changed;
      await tester.pumpWidget(
        _app(
          BeuiDateRangePicker(
            value: const BeuiDateRange(from: '2026-01-15'),
            defaultMonth: '2026-01-01',
            min: '2026-01-10',
            isDateDisabled: (date) => date == '2026-01-20',
            onChanged: (value) => changed = value,
          ),
        ),
      );

      await tester.tap(
        find.bySemanticsLabel('Friday, January 9, 2026'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(changed, isNull);
      await tester.tap(
        find.bySemanticsLabel('Tuesday, January 20, 2026'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(changed, isNull);
    });

    testWidgets('unavailable interior days invalidate a completed range', (
      tester,
    ) async {
      BeuiDateRange? changed;
      await tester.pumpWidget(
        _app(
          BeuiDateRangePicker(
            value: const BeuiDateRange(from: '2026-01-15'),
            defaultMonth: '2026-01-01',
            isDateDisabled: (date) => date == '2026-01-20',
            onChanged: (value) => changed = value,
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel('Thursday, January 22, 2026'));
      await tester.pump();

      expect(changed, isNull);
      expect(find.text('Choose an end date'), findsOneWidget);
    });

    testWidgets('keyboard arrows move the active date and Enter selects it', (
      tester,
    ) async {
      BeuiDateRange? changed;
      await tester.pumpWidget(
        _app(
          BeuiDateRangePicker(
            value: null,
            defaultMonth: '2026-01-01',
            onChanged: (value) => changed = value,
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(changed, isNotNull);
      expect(changed!.to, isNull);
    });
  });

  testWidgets('dropdown opens and dismisses through the shared overlay', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const BeuiDateRangePickerDropdown(
          defaultValue: BeuiDateRange(from: '2026-01-15', to: '2026-01-20'),
        ),
      ),
    );
    await tester.tap(find.byType(OutlinedButton).first);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Calendar, January 2026'), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Calendar, January 2026'), findsNothing);
  });

  testWidgets('preset selection and Clear update the uncontrolled range', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const BeuiDateRangePicker(
          defaultMonth: '2026-01-01',
          presets: <BeuiDateRangePreset>[
            BeuiDateRangePreset(
              label: 'Last week',
              value: BeuiDateRange(from: '2026-01-12', to: '2026-01-18'),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Last week'));
    await tester.pumpAndSettle();
    expect(find.text('7 days selected'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a start date'), findsOneWidget);
  });

  testWidgets('Page Down navigates to the next calendar month', (tester) async {
    await tester.pumpWidget(
      _app(const BeuiDateRangePicker(defaultMonth: '2026-01-01')),
    );
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Calendar, February 2026'), findsOneWidget);
  });

  testWidgets(
    'month motion slides normally and removes translation when reduced',
    (tester) async {
      Future<void> pageDown({required bool reduce}) async {
        await tester.pumpWidget(
          _app(
            const BeuiDateRangePicker(defaultMonth: '2026-01-01'),
            reduce: reduce,
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pump(const Duration(milliseconds: 40));
      }

      await pageDown(reduce: false);
      final calendarSlides = find.descendant(
        of: find.byType(BeuiDateRangePickerCalendar),
        matching: find.byType(SlideTransition),
      );
      expect(calendarSlides, findsWidgets);
      await tester.pumpAndSettle();

      await pageDown(reduce: true);
      expect(
        find.descendant(
          of: find.byType(BeuiDateRangePickerCalendar),
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets('reduced motion still selects dates without scaling movement', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const BeuiDateRangePicker(defaultMonth: '2026-01-01'), reduce: true),
    );
    await tester.tap(find.bySemanticsLabel('Thursday, January 15, 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Choose an end date'), findsOneWidget);
  });

  testWidgets('rest-state golden shows a selected range and date controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const BeuiDateRangePicker(
          defaultMonth: '2026-01-01',
          defaultValue: BeuiDateRange(from: '2026-01-12', to: '2026-01-18'),
          presets: <BeuiDateRangePreset>[
            BeuiDateRangePreset(
              label: 'Last week',
              value: BeuiDateRange(from: '2026-01-12', to: '2026-01-18'),
            ),
            BeuiDateRangePreset(
              label: 'This month',
              value: BeuiDateRange(from: '2026-01-01', to: '2026-01-31'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiDateRangePickerCalendar),
      matchesGoldenFile('goldens/beui_date_range_picker.png'),
    );
  });
}
