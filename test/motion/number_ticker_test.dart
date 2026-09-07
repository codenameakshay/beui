import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

class _Host extends StatefulWidget {
  const _Host({required this.initial, this.reduce = false});
  final int initial;
  final bool reduce;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late int _value = widget.initial;

  void set(int v) => setState(() => _value = v);

  @override
  Widget build(BuildContext context) => beuiTestApp(
    DefaultTextStyle(
      style: const TextStyle(fontSize: 28),
      child: BeuiNumberTicker(value: _value),
    ),
    reduce: widget.reduce,
  );
}

/// Reads the vertical translation of every digit-column [Transform] (scoped to
/// the ticker — the ambient tree adds its own resting Transforms).
List<double> _translationsY(WidgetTester tester) => tester
    .widgetList<Transform>(
      find.descendant(
        of: find.byType(BeuiNumberTicker),
        matching: find.byType(Transform),
      ),
    )
    .map((t) => t.transform.getTranslation().y)
    .toList();

void main() {
  testWidgets('renders one digit column per digit, settled on the target', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(initial: 123));
    await tester.pumpAndSettle();

    // A 0–9 column exists for each digit, so each glyph 0..9 is present at
    // least once. Three digit slots are clipped on screen.
    expect(find.text('0'), findsWidgets);
    expect(find.text('9'), findsWidgets);
    expect(find.byType(ClipRect), findsNWidgets(3));
  });

  testWidgets('exposes the formatted value to semantics', (tester) async {
    await tester.pumpWidget(const _Host(initial: 4207));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('4207'), findsOneWidget);
  });

  testWidgets('changing the value rolls the digit columns', (tester) async {
    await tester.pumpWidget(const _Host(initial: 0));
    await tester.pumpAndSettle();

    // After the entrance reveal window, the column rests at the target (0).
    tester.state<_HostState>(find.byType(_Host)).set(7);
    await tester.pump(); // start the roll
    await tester.pump(const Duration(milliseconds: 120));

    // Mid-roll the column is translated to a non-resting position.
    final moving = _translationsY(tester).any((y) => y.abs() > 0.5);
    expect(moving, isTrue, reason: 'the digit column rolls vertically');

    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('7'), findsOneWidget);
  });

  testWidgets('reduced motion snaps to the target with no roll', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(initial: 0, reduce: true));
    await tester.pumpAndSettle();

    tester.state<_HostState>(find.byType(_Host)).set(5);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    // No SingleMotionBuilder roll under reduced motion: the column is placed
    // statically. Settling immediately shows the target value.
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('5'), findsOneWidget);
  });

  testWidgets('the entrance rolls in from 0, staggered left-to-right', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const DefaultTextStyle(
          style: TextStyle(fontSize: 28),
          child: BeuiNumberTicker(
            value: 999,
            duration: Duration(milliseconds: 300),
            stagger: Duration(milliseconds: 200),
          ),
        ),
      ),
    );
    // First layout arms the ticker (no enclosing scrollable); the first digit
    // releases immediately, the third only after 2 × 200ms.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final ys = _translationsY(tester).where((y) => y.abs() > 0.01).toList();
    expect(ys, isNotEmpty, reason: 'released digits are mid-roll from 0');
    final resting = _translationsY(tester).where((y) => y.abs() <= 0.01);
    expect(
      resting,
      isNotEmpty,
      reason: 'digits whose stagger delay has not elapsed still rest at 0',
    );

    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('999'), findsOneWidget);
    // All columns settled on 9 → all translated to -9 slots.
    expect(_translationsY(tester).every((y) => y < -0.5), isTrue);
  });

  testWidgets('startOnView holds the digits at 0 until scrolled into view', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            controller: controller,
            child: Column(
              children: [
                const SizedBox(height: 1400),
                DefaultTextStyle(
                  style: const TextStyle(fontSize: 28),
                  child: const BeuiNumberTicker(value: 77),
                ),
                const SizedBox(height: 400),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Below the fold: unarmed — every column still rests at glyph 0.
    expect(_translationsY(tester).every((y) => y.abs() <= 0.01), isTrue);

    // Scroll the ticker fully into view; the anchor re-measures post-frame,
    // the in-view check arms the entrance, and the digits roll to 7.
    controller.jumpTo(1200);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(_translationsY(tester).any((y) => y < -0.5), isTrue);
  });

  testWidgets('blur rides each roll for a fixed window, then sharpens', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const DefaultTextStyle(
          style: TextStyle(fontSize: 28),
          child: BeuiNumberTicker(
            value: 8,
            blur: true,
            duration: Duration(milliseconds: 900),
          ),
        ),
      ),
    );
    await tester.pump(); // arm on first layout
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-window (min(900 × 0.75, 320) = 320ms): the roll is blurred.
    expect(find.byType(ImageFiltered), findsOneWidget);

    // Past the 320ms window the blur has fully sharpened and unmounts, even
    // though the 900ms roll is still travelling.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ImageFiltered), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('growing the number adds a leading digit', (tester) async {
    await tester.pumpWidget(const _Host(initial: 9));
    await tester.pumpAndSettle();
    expect(find.byType(ClipRect), findsNWidgets(1));

    tester.state<_HostState>(find.byType(_Host)).set(42);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(ClipRect), findsNWidgets(2));
    expect(find.bySemanticsLabel('42'), findsOneWidget);
  });
}
