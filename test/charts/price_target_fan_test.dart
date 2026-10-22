import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _history = [
  BeuiPriceHistoryPoint(date: '2025-09-14', price: 158.4),
  BeuiPriceHistoryPoint(date: '2025-10-14', price: 164.2),
  BeuiPriceHistoryPoint(date: '2025-11-14', price: 160.8),
];
const _targets = [
  BeuiPriceTarget(key: 'High', price: 232, analysts: 9),
  BeuiPriceTarget(key: 'Mean', price: 205, analysts: 34),
  BeuiPriceTarget(key: 'Low', price: 168, analysts: 6),
];

Future<void> _pumpChart(
  WidgetTester tester,
  BeuiPriceTargetFan chart, {
  bool reduce = false,
}) async {
  tester.view.physicalSize = const Size(800, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(beuiTestApp(chart, reduce: reduce, width: 640));
}

BeuiPriceTargetFan _chart({
  BeuiPriceTargetFanActive? active,
  BeuiPriceTargetFanActive? defaultActive,
  ValueChanged<BeuiPriceTargetFanActive?>? onActiveChange,
}) => BeuiPriceTargetFan(
  current: 178.52,
  targets: _targets,
  history: _history,
  dates: const BeuiPriceTargetDates(horizon: 'Sep 2027'),
  active: active,
  defaultActive: defaultActive,
  onActiveChange: onActiveChange,
);

void main() {
  testWidgets('renders accessible plot, history, and target buttons', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpChart(tester, _chart());
    expect(find.bySemanticsLabel(RegExp('Price target fan')), findsWidgets);
    expect(find.text('High  \$232'), findsOneWidget);
    expect(find.text('Mean  \$205'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('target buttons report the selected projection', (tester) async {
    BeuiPriceTargetFanActive? changed;
    await _pumpChart(
      tester,
      _chart(onActiveChange: (value) => changed = value),
    );
    await tester.tap(find.text('High  \$232'));
    await tester.pump();
    expect(changed, const BeuiPriceTargetFanActive.target('High'));
  });

  testWidgets('history arrows step the uncontrolled active date', (
    tester,
  ) async {
    BeuiPriceTargetFanActive? changed;
    await _pumpChart(
      tester,
      _chart(
        defaultActive: const BeuiPriceTargetFanActive.history('2025-09-14'),
        onActiveChange: (value) => changed = value,
      ),
    );
    expect(find.text('2025-09-14'), findsWidgets);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(changed, const BeuiPriceTargetFanActive.history('2025-10-14'));
    expect(find.text('2025-10-14'), findsWidgets);
  });

  testWidgets('keyboard inspector selects an endpoint and Escape clears', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpChart(tester, _chart());
    await tester.tap(find.text('Mean  \$205'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(
      tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.selected == true),
      isEmpty,
    );
    semantics.dispose();
  });

  testWidgets(
    'rejects repeated or nonpositive targets and unsorted ISO history',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          BeuiPriceTargetFan(
            current: 10,
            targets: const [
              BeuiPriceTarget(key: 'H', price: 20),
              BeuiPriceTarget(key: 'M', price: 20),
              BeuiPriceTarget(key: 'L', price: -2),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isArgumentError);
      await tester.pumpWidget(
        beuiTestApp(
          BeuiPriceTargetFan(
            current: 10,
            targets: const [
              BeuiPriceTarget(key: 'H', price: 20),
              BeuiPriceTarget(key: 'M', price: 15),
              BeuiPriceTarget(key: 'L', price: 5),
            ],
            history: const [
              BeuiPriceHistoryPoint(date: '2025-02-01', price: 8),
              BeuiPriceHistoryPoint(date: '2025-01-01', price: 9),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isArgumentError);
    },
  );

  testWidgets('reduced-motion rest state matches golden', (tester) async {
    await _pumpChart(tester, _chart(), reduce: true);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(BeuiPriceTargetFan),
      matchesGoldenFile('goldens/beui_price_target_fan.png'),
    );
  });
}
