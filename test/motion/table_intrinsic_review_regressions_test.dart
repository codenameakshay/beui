import 'package:beui/beui.dart';
import 'package:beui/src/motion/table/intrinsic_measurement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

void main() {
  testWidgets('fractional declared widths remain supported', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        BeuiTable<String>(
          data: const ['x'],
          columns: [
            BeuiTableColumn(
              key: 'a',
              header: 'A',
              width: 120.1,
              value: (r) => r,
            ),
          ],
          sizing: BeuiTableSizing.intrinsic,
          intrinsicSamples: (_, _) => const [
            BeuiTableIntrinsicSample.explicit('a', (minimum: 64, maximum: 100)),
          ],
        ),
        width: 250,
        reduce: true,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('nested horizontal flex must be rejected safely', (tester) async {
    MeasurementResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: IntrinsicMeasurement(
          columns: const ['a'],
          samples: const [
            BeuiTableIntrinsicSample(
              'a',
              Row(
                children: [
                  Row(children: [Expanded(child: Text('nested'))]),
                ],
              ),
            ),
          ],
          builder: (_, r) {
            result = r;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(result!.supported, false);
  });
  testWidgets('row height update samples current viewport', (tester) async {
    List<String> window = [];
    Widget tree(double rowHeight) => beuiTestApp(
      BeuiTable<String>(
        data: List.generate(1000, (i) => '$i'),
        columns: [BeuiTableColumn(key: 'a', header: 'A', value: (r) => r)],
        sizing: BeuiTableSizing.intrinsic,
        height: 192,
        rowHeight: rowHeight,
        intrinsicSamples: (_, rows) {
          window = rows;
          return const [
            BeuiTableIntrinsicSample.explicit('a', (
              minimum: 100,
              maximum: 100,
            )),
          ];
        },
      ),
      width: 250,
      reduce: true,
    );
    await tester.pumpWidget(tree(48));
    tester.widget<ListView>(find.byType(ListView)).controller!.jumpTo(2400);
    await tester.pump();
    expect(window.first, '40');
    await tester.pumpWidget(tree(24));
    await tester.pump();
    final offset = tester
        .widget<ListView>(find.byType(ListView))
        .controller!
        .offset;
    expect(offset, 2400);
    expect(window.first, '90');
    expect(window, contains('100'));
    expect(tester.takeException(), isNull);
  });
}
