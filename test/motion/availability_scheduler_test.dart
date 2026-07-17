import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A controlled harness that holds the week and feeds it back on change, so
/// interaction tests observe the real re-render.
class _Harness extends StatefulWidget {
  const _Harness({this.reduce = false});

  final bool reduce;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  BeuiWeekAvailability _week = beuiDefaultWeek();

  @override
  Widget build(BuildContext context) {
    Widget child = BeuiAvailabilityScheduler(
      value: _week,
      onChanged: (next) => setState(() => _week = next),
    );
    if (widget.reduce) {
      final inner = child;
      child = Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: inner,
        ),
      );
    }
    return MaterialApp(
      theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
      home: Scaffold(body: Align(alignment: Alignment.topCenter, child: child)),
    );
  }
}

void main() {
  group('BeuiAvailabilityScheduler interaction', () {
    testWidgets('renders one toggle per weekday', (tester) async {
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();
      expect(find.byType(BeuiSwitch), findsNWidgets(7));
    });

    testWidgets('default week marks the weekend unavailable', (tester) async {
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();
      // Sat + Sun are off in the default week.
      expect(find.text('Unavailable'), findsNWidgets(2));
    });

    testWidgets('disabling a day adds an Unavailable line', (tester) async {
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();
      // Monday is the first switch; toggle it off.
      await tester.tap(find.byType(BeuiSwitch).first);
      await tester.pumpAndSettle();
      expect(find.text('Unavailable'), findsNWidgets(3));
    });

    testWidgets('add button appends a range to the day', (tester) async {
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();
      // Each of Mon–Fri has one range → five range separators.
      expect(find.text('–'), findsNWidgets(5));
      await tester.tap(find.byIcon(LucideIcons.plus).first);
      await tester.pumpAndSettle();
      expect(find.text('–'), findsNWidgets(6));
    });

    testWidgets('removing the only range marks the day unavailable', (
      tester,
    ) async {
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();
      // Remove Monday's single range.
      await tester.tap(find.byIcon(LucideIcons.x).first);
      await tester.pumpAndSettle();
      expect(find.text('Unavailable'), findsNWidgets(3));
    });
  });

  group('BeuiAvailabilityScheduler motion fidelity', () {
    testWidgets('a newly added range blurs in under normal motion', (
      tester,
    ) async {
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.plus).first);
      // One frame into the enter spring: the slot is mid-blur.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.descendant(
          of: find.byType(BeuiAvailabilityScheduler),
          matching: find.byType(ImageFiltered),
        ),
        findsWidgets,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion drops the range blur', (tester) async {
      await tester.pumpWidget(const _Harness(reduce: true));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.plus).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.descendant(
          of: find.byType(BeuiAvailabilityScheduler),
          matching: find.byType(ImageFiltered),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
    });
  });

  testWidgets('rest-state golden (default week)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: BeuiAvailabilityScheduler(
                value: beuiDefaultWeek(),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiAvailabilityScheduler),
      matchesGoldenFile('goldens/beui_availability_scheduler.png'),
    );
  });
}
