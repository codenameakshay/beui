import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

const _bins = [
  BeuiVolumeProfileBin(price: 10, volume: 8, buy: 5, sell: 3),
  BeuiVolumeProfileBin(price: 11, volume: 20, buy: 13, sell: 7),
  BeuiVolumeProfileBin(price: 12, volume: 16, buy: 10, sell: 6),
  BeuiVolumeProfileBin(price: 13, volume: 6, buy: 2, sell: 4),
];

void main() {
  testWidgets('value area stops before the next bin exceeds its target', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiVolumeProfile(data: _bins), reduce: true),
    );
    expect(find.text('Value area 10.50 – 11.50 (40.0%)'), findsOneWidget);
  });

  testWidgets('a full value area includes empty edge bins', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiVolumeProfile(
          valueArea: 1,
          data: [
            BeuiVolumeProfileBin(price: 10, volume: 0),
            BeuiVolumeProfileBin(price: 11, volume: 10),
            BeuiVolumeProfileBin(price: 12, volume: 0),
          ],
        ),
        reduce: true,
      ),
    );
    expect(find.text('Value area 9.50 – 12.50 (100.0%)'), findsOneWidget);
  });

  testWidgets('renders profile, summary, tooltip data and slider semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiVolumeProfile(
          data: _bins,
          label: 'Test volume profile',
          unit: 'BTC',
          defaultActiveId: '1',
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(BeuiVolumeProfilePlot), findsOneWidget);
    expect(find.byType(BeuiVolumeProfileSummary), findsOneWidget);
    expect(find.text('POC'), findsOneWidget);
    expect(find.text('POC 11.00'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Test volume profile: inspect price level'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('supports active control and inspector keys', (tester) async {
    String? changed;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiVolumeProfile(
          data: _bins,
          activeId: '1',
          onActiveChange: (id) => changed = id,
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(changed, '2');
  });

  testWidgets('hovering a bin shows formatted animated tooltip values', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiVolumeProfile(data: _bins, unit: 'BTC')),
    );
    final plot = tester.getRect(find.byType(BeuiVolumeProfilePlot));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final position = Offset(
      plot.left + plot.width * 0.35,
      plot.top + plot.height / 3,
    );
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(position);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.byType(BeuiChartTicker), findsWidgets);
    expect(find.byType(BeuiNumberTicker), findsWidgets);
    expect(find.textContaining('BTC'), findsWidgets);
    await mouse.removePointer();
  });

  testWidgets('tapping the top row selects the highest-price bin', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      beuiTestApp(
        BeuiVolumeProfile(data: _bins, onActiveChange: (id) => selected = id),
      ),
    );
    final plot = tester.getRect(find.byType(BeuiVolumeProfilePlot));
    await tester.tapAt(Offset(plot.center.dx, plot.top + 1));
    await tester.pump();
    expect(selected, '3');
  });

  testWidgets('tapping a clamped uneven-price bar selects its visible bin', (
    tester,
  ) async {
    String? selected;
    const data = [
      BeuiVolumeProfileBin(price: 10, volume: 1),
      BeuiVolumeProfileBin(price: 11, volume: 1),
      BeuiVolumeProfileBin(price: 12, volume: 1),
      BeuiVolumeProfileBin(price: 100, volume: 1),
    ];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiVolumeProfile(
          data: data,
          onActiveChange: (id) => selected = id,
          child: const BeuiVolumeProfilePlot(height: 300),
        ),
      ),
    );
    final plot = tester.getRect(find.byType(BeuiVolumeProfilePlot));
    await tester.tapAt(Offset(plot.left + 100, plot.top + 262.5));
    await tester.pump();
    expect(selected, '2');
  });

  testWidgets('hovering a clamped uneven-price bar inspects its visible bin', (
    tester,
  ) async {
    const data = [
      BeuiVolumeProfileBin(price: 10, volume: 1),
      BeuiVolumeProfileBin(price: 11, volume: 1),
      BeuiVolumeProfileBin(price: 12, volume: 1),
      BeuiVolumeProfileBin(price: 100, volume: 1),
    ];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiVolumeProfile(
          data: data,
          formatPrice: (price) => 'P${price.toStringAsFixed(0)}',
          child: const Column(
            children: [
              BeuiVolumeProfilePlot(height: 300),
              BeuiVolumeProfileSummary(),
            ],
          ),
        ),
      ),
    );
    final plot = tester.getRect(find.byType(BeuiVolumeProfilePlot));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset(plot.left + 100, plot.top + 262.5));
    await mouse.moveTo(Offset(plot.left + 100, plot.top + 262.5));
    await tester.pump();
    expect(find.textContaining('P12 · 1'), findsOneWidget);
    await mouse.removePointer();
  });

  testWidgets('emptying and restoring data clears the hovered bin', (
    tester,
  ) async {
    var data = _bins;
    void Function(List<BeuiVolumeProfileBin>)? updateData;
    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            updateData = (next) => setState(() => data = next);
            return BeuiVolumeProfile(data: data);
          },
        ),
      ),
    );
    final plot = tester.getRect(find.byType(BeuiVolumeProfilePlot));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset(plot.center.dx, plot.top + 1));
    await mouse.moveTo(Offset(plot.center.dx, plot.top + 1));
    await tester.pump();
    expect(find.byType(BeuiChartTooltipCard), findsOneWidget);

    updateData!([]);
    await tester.pump();
    updateData!([
      for (var index = 0; index < 4; index++)
        BeuiVolumeProfileBin(price: 30.0 + index, volume: 1.0 + index),
    ]);
    await tester.pump();
    expect(find.byType(BeuiChartTooltipCard), findsNothing);
    await mouse.removePointer();
  });

  testWidgets('reduced motion snaps profile bars to their target widths', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiVolumeProfile(data: _bins), reduce: true),
    );
    await tester.pump();
    expect(find.byType(BeuiVolumeProfilePlot), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(640, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      beuiTestApp(
        const RepaintBoundary(
          child: BeuiVolumeProfile(data: _bins, label: 'Volume profile'),
        ),
        width: 640,
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(BeuiVolumeProfile),
      matchesGoldenFile('goldens/beui_volume-profile.png'),
    );
  });
}
