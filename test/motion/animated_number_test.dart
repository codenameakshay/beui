import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Host extends StatefulWidget {
  const _Host({required this.initial, this.reduce = false});
  final num initial;
  final bool reduce;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late num _value = widget.initial;

  void set(num v) => setState(() => _value = v);

  @override
  Widget build(BuildContext context) {
    Widget body = DefaultTextStyle(
      style: const TextStyle(fontSize: 28),
      child: BeuiAnimatedNumber(value: _value),
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

// The string of the single Text widget currently rendered.
String _shown(WidgetTester tester) =>
    tester.widget<Text>(find.byType(Text)).data ?? '';

void main() {
  testWidgets('counts up from 0 to the target on first build', (tester) async {
    await tester.pumpWidget(const _Host(initial: 1000));
    await tester.pump(); // first frame seeds the tween from 0

    // Mid-count: well below the target (still rising).
    await tester.pump(const Duration(milliseconds: 200));
    final mid = int.parse(_shown(tester).replaceAll(',', ''));
    expect(mid, lessThan(1000));
    expect(mid, greaterThanOrEqualTo(0));

    await tester.pumpAndSettle();
    expect(_shown(tester), '1,000');
  });

  testWidgets('a new value counts from the previous one', (tester) async {
    await tester.pumpWidget(const _Host(initial: 100));
    await tester.pumpAndSettle();
    expect(_shown(tester), '100');

    tester.state<_HostState>(find.byType(_Host)).set(200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Counting up from 100, so it is between the old and new value.
    final mid = int.parse(_shown(tester).replaceAll(',', ''));
    expect(mid, inInclusiveRange(100, 200));

    await tester.pumpAndSettle();
    expect(_shown(tester), '200');
  });

  testWidgets('reduced motion snaps straight to the final value', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(initial: 5000, reduce: true));
    await tester.pump();

    // No count-up: the first frame already shows the final formatted value.
    expect(_shown(tester), '5,000');

    tester.state<_HostState>(find.byType(_Host)).set(8000);
    await tester.pump();
    expect(_shown(tester), '8,000');
  });

  testWidgets('honors a custom formatter', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        home: Scaffold(
          body: DefaultTextStyle(
            style: const TextStyle(fontSize: 28),
            child: BeuiAnimatedNumber(
              value: 1200,
              format: (n) => '\$${n.round()}',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_shown(tester), r'$1200');
  });
}
