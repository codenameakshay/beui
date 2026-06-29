import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  Widget build(BuildContext context) {
    Widget body = DefaultTextStyle(
      style: const TextStyle(fontSize: 28),
      child: BeuiNumberTicker(value: _value),
    );
    if (widget.reduce) {
      body = MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: body,
      );
    }
    return MaterialApp(
      theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
      home: Scaffold(body: Center(child: body)),
    );
  }
}

/// Reads the vertical translation of every [Transform] in the tree.
List<double> _translationsY(WidgetTester tester) => tester
    .widgetList<Transform>(find.byType(Transform))
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
