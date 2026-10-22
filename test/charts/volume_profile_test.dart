import 'package:beui/beui.dart';
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
    expect(find.textContaining('POC'), findsOneWidget);
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
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(changed, '2');
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
