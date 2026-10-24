import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

class _Host extends StatefulWidget {
  const _Host({required this.initial});
  final num initial;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late num _value = widget.initial;

  void set(num v) => setState(() => _value = v);

  @override
  Widget build(BuildContext context) => beuiTestApp(
    DefaultTextStyle(
      style: const TextStyle(fontSize: 16),
      child: BeuiChartTicker(
        value: _value,
        format: (v) => '\$${v.toStringAsFixed(2)}',
      ),
    ),
  );
}

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
  testWidgets('tooltip ticker formats the live value, not the rounded int', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(initial: 12.4));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(r'$12.40'), findsOneWidget);
  });

  testWidgets('changing the value rolls digit columns', (tester) async {
    await tester.pumpWidget(const _Host(initial: 10));
    await tester.pumpAndSettle();

    tester.state<_HostState>(find.byType(_Host)).set(17);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(
      _translationsY(tester).any((y) => y.abs() > 0.5),
      isTrue,
      reason: 'chart tooltip digits must roll, not pop',
    );

    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(r'$17.00'), findsOneWidget);
  });

  testWidgets('tooltip card paints ticker details instead of static lines', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        BeuiChartTooltipCard(
          title: 'AAPL',
          lines: const ['ignored'],
          details: [
            BeuiChartTicker(value: 210000, format: (v) => v.round().toString()),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ignored'), findsNothing);
    expect(find.byType(BeuiNumberTicker), findsOneWidget);
  });

  testWidgets('tooltip title remains accessible when replaced by a ticker', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        BeuiChartTooltipCard(
          title: 'AAPL',
          titleWidget: BeuiChartTicker(
            value: 210,
            format: (v) => '\$${v.round()}',
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('AAPL'), findsOneWidget);
  });
}
