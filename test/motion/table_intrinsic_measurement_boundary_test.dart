import 'dart:io';
import 'package:flutter/services.dart';
import 'package:beui/src/motion/table/intrinsic_measurement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('asynchronous font loading refreshes unchanged constraints', (
    tester,
  ) async {
    final results = <MeasurementResult>[];
    await tester.pumpWidget(
      MaterialApp(
        home: IntrinsicMeasurement(
          columns: const ['c'],
          samples: const [
            BeuiTableIntrinsicSample(
              'c',
              Text(
                '000000',
                style: TextStyle(
                  fontFamily: 'Intrinsic Async Geist',
                  fontSize: 20,
                ),
              ),
            ),
          ],
          builder: (_, value) {
            results.add(value);
            return const SizedBox(height: 20);
          },
        ),
      ),
    );
    final before = results.last.columns.single.maximum;
    await tester.runAsync(() async {
      final bytes = await File(
        'example/assets/fonts/GeistMono-Regular.ttf',
      ).readAsBytes();
      await (FontLoader(
        'Intrinsic Async Geist',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    });
    await tester.pump();
    expect(results.length, greaterThan(1));
    expect(results.last.columns.single.maximum, isNot(before));
    expect(results.last.columns.single.maximum, closeTo(72, .02));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden samples cannot enter selected content', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: SelectionArea(
          onSelectionChanged: (value) => selected = value?.plainText,
          child: IntrinsicMeasurement(
            columns: const ['c'],
            samples: const [
              BeuiTableIntrinsicSample('c', Text('SECRET SAMPLE')),
            ],
            builder: (_, _) => const Text('VISIBLE'),
          ),
        ),
      ),
    );
    tester
        .state<SelectableRegionState>(find.byType(SelectableRegion))
        .selectAll();
    await tester.pump();
    expect(selected, 'VISIBLE');
    expect(tester.takeException(), isNull);
  });

  final invalid = <String, BeuiTableIntrinsicSample>{
    'root flex': const BeuiTableIntrinsicSample(
      'c',
      Expanded(child: Text('x')),
    ),
    'vertical flex': const BeuiTableIntrinsicSample(
      'c',
      Column(children: [Expanded(child: Text('x'))]),
    ),
    'horizontal cross-axis stretch': const BeuiTableIntrinsicSample(
      'c',
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Text('x')],
      ),
    ),
    'unbounded box': const BeuiTableIntrinsicSample(
      'c',
      SizedBox(width: double.infinity, child: Text('x')),
    ),
    'huge finite width': const BeuiTableIntrinsicSample.explicit('c', (
      minimum: 1e308,
      maximum: 1e308,
    )),
  };
  for (final entry in invalid.entries) {
    testWidgets('rejects ${entry.key} before unsafe layout', (tester) async {
      MeasurementResult? result;
      await tester.pumpWidget(
        MaterialApp(
          home: IntrinsicMeasurement(
            columns: const ['c'],
            samples: [entry.value],
            builder: (_, value) {
              result = value;
              return const SizedBox(height: 20);
            },
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(result!.supported, isFalse);
      expect(result!.columns, isEmpty);
    });
  }
}
