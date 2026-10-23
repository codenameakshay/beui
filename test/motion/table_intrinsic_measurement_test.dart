import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beui/src/motion/table/intrinsic_layout.dart';
import 'package:beui/src/motion/table/intrinsic_measurement.dart';

Widget host(Widget child, {double scale = 1, double fontSize = 14}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: DefaultTextStyle(
          style: TextStyle(fontSize: fontSize),
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    );

void main() {
  testWidgets('real text, badge and flex intrinsics feed first-frame table', (
    tester,
  ) async {
    MeasurementResult? result;
    final cellKey = GlobalKey();
    const sample = Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text('Account heading')),
          SizedBox(width: 6),
          DecoratedBox(
            decoration: BoxDecoration(color: Colors.blue),
            child: Padding(padding: EdgeInsets.all(4), child: Text('New')),
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 400,
          child: IntrinsicMeasurement(
            columns: const ['name'],
            samples: const [
              BeuiTableIntrinsicSample('name', sample),
              BeuiTableIntrinsicSample('name', Text('Long mounted row value')),
            ],

            builder: (context, value) {
              result = value;
              final layout = resolveSourceTable(
                dataColumns: value.columns,
                viewport: value.viewport,
              );
              return Table(
                columnWidths: {
                  0: FixedColumnWidth(layout.widths[0]),
                  1: FixedColumnWidth(layout.widths[1]),
                },
                children: [
                  TableRow(
                    children: [
                      SizedBox(
                        key: cellKey,
                        height: 30,
                        child: const Text('Visible'),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(result!.supported, isTrue);
    expect(result!.columns.single.maximum, greaterThan(100));
    expect(
      tester.getSize(find.byKey(cellKey)).width,
      resolveSourceTable(
        dataColumns: result!.columns,
        viewport: 400,
      ).widths.first,
    );
    // Compare against the same Flutter subtree laid out normally.
    final measured = result!.columns.single;
    await tester.pumpWidget(
      host(
        const SizedBox(
          width: 400,
          child: Column(children: [sample, Text('Long mounted row value')]),
        ),
      ),
    );
    final box = tester.renderObject<RenderBox>(find.byWidget(sample));
    final row = tester.renderObject<RenderBox>(
      find.text('Long mounted row value'),
    );
    double quantize(double value) => (value * 64).ceil() / 64;
    expect(
      measured.maximum,
      quantize(
        math.max(
          box.getMaxIntrinsicWidth(double.infinity),
          row.getMaxIntrinsicWidth(double.infinity),
        ),
      ),
    );
    expect(
      measured.minimum,
      quantize(
        math.max(
          box.getMinIntrinsicWidth(double.infinity),
          row.getMinIntrinsicWidth(double.infinity),
        ),
      ),
    );
  });

  testWidgets(
    'same constraints refresh content, scale, font and sampled rows',
    (tester) async {
      final results = <MeasurementResult>[];
      Widget tree(
        String text, {
        double scale = 1,
        double font = 14,
        double width = 400,
      }) => host(
        SizedBox(
          width: width,
          child: IntrinsicMeasurement(
            columns: const ['c'],
            samples: [BeuiTableIntrinsicSample('c', Text(text))],

            builder: (context, result) {
              results.add(result);
              return SizedBox(
                height: 20,
                child: Text('${result.columns.single.maximum}'),
              );
            },
          ),
        ),
        scale: scale,
        fontSize: font,
      );
      await tester.pumpWidget(tree('short'));
      final short = results.last.columns.single.maximum;
      await tester.pumpWidget(tree('a much longer overscan row'));
      final long = results.last.columns.single.maximum;
      expect(long, greaterThan(short));
      await tester.pumpWidget(tree('a much longer overscan row', scale: 2));
      expect(results.last.columns.single.maximum, greaterThan(long));
      await tester.pumpWidget(tree('a much longer overscan row', font: 30));
      expect(results.last.columns.single.maximum, greaterThan(long));
      await tester.pumpWidget(tree('short', width: 250));
      expect(results.last.viewport, 250);
      expect(results.last.columns.single.maximum, short);
      expect(results.length, 5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'render-only invalidation rebuilds content at identical constraints',
    (tester) async {
      final results = <MeasurementResult>[];

      await tester.pumpWidget(
        host(
          SizedBox(
            width: 400,
            child: IntrinsicMeasurement(
              columns: const ['c'],
              samples: const [BeuiTableIntrinsicSample('c', Text('probe'))],

              builder: (context, result) {
                results.add(result);
                return const SizedBox(height: 20);
              },
            ),
          ),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('probe'),
      );
      final old = results.single.columns.single.maximum;
      paragraph.text = const TextSpan(
        text: 'font metric invalidation equivalent',
        style: TextStyle(fontSize: 30),
      );
      await tester.pump();
      expect(results.length, 2);
      expect(results.last.columns.single.maximum, greaterThan(old));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unsupported builders, viewports and editors never mount', (
    tester,
  ) async {
    var builderCalls = 0;
    for (final widget in <Widget>[
      LayoutBuilder(
        builder: (_, _) {
          builderCalls++;
          return const Text('bad');
        },
      ),
      ListView.builder(
        itemCount: 10000,
        itemBuilder: (_, _) {
          builderCalls++;
          return const Text('bad');
        },
      ),
      const TextField(autofocus: true),
    ]) {
      MeasurementResult? result;

      await tester.pumpWidget(
        host(
          IntrinsicMeasurement(
            columns: const ['c'],
            samples: [BeuiTableIntrinsicSample('c', widget)],

            builder: (_, value) {
              result = value;
              return const SizedBox(height: 20);
            },
          ),
        ),
      );
      expect(result!.error, contains('explicit widths'));

      expect(find.byType(EditableText), findsNothing);
      expect(tester.takeException(), isNull);
    }
    expect(builderCalls, 0);
  });

  testWidgets(
    'bounded sample, explicit editor contract, semantics and hit testing',
    (tester) async {
      final semantics = tester.ensureSemantics();

      var taps = 0;

      MeasurementResult? result;
      await tester.pumpWidget(
        host(
          IntrinsicMeasurement(
            columns: const ['c'],
            samples: const [
              BeuiTableIntrinsicSample('c', Text('Measurement only')),
              BeuiTableIntrinsicSample.explicit('c', (
                minimum: 120,
                maximum: 200,
              )),
            ],

            builder: (_, value) {
              result = value;
              return GestureDetector(
                onTap: () => taps++,
                child: const SizedBox(
                  width: 300,
                  height: 50,
                  child: Text('Real control'),
                ),
              );
            },
          ),
        ),
      );
      expect(
        result!.columns.single.maximum,
        224,
      ); // Ahem at 14px, 16 characters.
      expect(find.bySemanticsLabel('Measurement only'), findsNothing);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('Measurement only'))
            .debugNeedsPaint,
        isTrue,
      );
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('Real control'))
            .debugNeedsPaint,
        isFalse,
      );
      expect(find.bySemanticsLabel('Real control'), findsOneWidget);
      await tester.tap(find.text('Real control'));
      expect(taps, 1);
      semantics.dispose();
      await tester.pumpWidget(
        host(
          IntrinsicMeasurement(
            columns: const ['c'],
            samples: List.generate(
              257,
              (_) => const BeuiTableIntrinsicSample('c', Text('row')),
            ),

            builder: (_, value) {
              result = value;
              return const SizedBox(height: 20);
            },
          ),
        ),
      );
      expect(result!.error, contains('budget exceeded'));

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('explicit editor widths mount only the real focused editor', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'editable');
    final focus = FocusNode();
    await tester.pumpWidget(
      host(
        IntrinsicMeasurement(
          columns: const ['c'],
          samples: const [
            BeuiTableIntrinsicSample.explicit('c', (
              minimum: 120,
              maximum: 200,
            )),
          ],

          builder: (_, result) => SizedBox(
            width: result.columns.single.maximum,
            child: Material(
              child: TextField(controller: controller, focusNode: focus),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(EditableText), findsOneWidget);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await tester.enterText(find.byType(TextField), 'changed');
    expect(controller.text, 'changed');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    focus.dispose();
  });

  testWidgets('missing, invalid and unbounded measurements report failure', (
    tester,
  ) async {
    for (final samples in <List<BeuiTableIntrinsicSample>>[
      [],
      [
        const BeuiTableIntrinsicSample.explicit('c', (
          minimum: 20,
          maximum: 10,
        )),
      ],
    ]) {
      MeasurementResult? result;
      await tester.pumpWidget(
        host(
          IntrinsicMeasurement(
            columns: const ['c'],
            samples: samples,

            builder: (_, value) {
              result = value;
              return const SizedBox(height: 20);
            },
          ),
        ),
      );
      expect(result!.supported, isFalse);
      expect(result!.columns, isEmpty);
    }
    MeasurementResult? result;
    await tester.pumpWidget(
      host(
        UnconstrainedBox(
          child: IntrinsicMeasurement(
            columns: const ['c'],
            samples: const [BeuiTableIntrinsicSample('c', Text('text'))],

            builder: (_, value) {
              result = value;
              return const SizedBox(width: 20, height: 20);
            },
          ),
        ),
      ),
    );
    expect(result!.error, contains('bounded viewport'));
    expect(tester.takeException(), isNull);
  });
}
