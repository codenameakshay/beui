import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

Finder resize(String key) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == 'Resize $key column',
);

void main() {
  Widget table({
    bool intrinsic = true,
    bool selectable = false,
    List<String> rows = const ['short'],
    List<BeuiTableColumn<String>>? columns,
    List<BeuiTableIntrinsicSample> Function(BuildContext, List<String>)?
    samples,
    void Function(String, double)? onResize,
  }) => beuiTestApp(
    BeuiTable<String>(
      data: rows,
      height: 192,
      resizable: true,
      selectable: selectable,
      sizing: intrinsic ? BeuiTableSizing.intrinsic : BeuiTableSizing.flex,
      onColumnResize: onResize,
      columns:
          columns ??
          [
            BeuiTableColumn(key: 'a', header: 'A', value: (r) => r),
            BeuiTableColumn(key: 'b', header: 'B', value: (_) => 'body'),
          ],
      intrinsicSamples:
          samples ??
          (_, rows) => [
            if (selectable)
              const BeuiTableIntrinsicSample.selectionWidths(24, 24),
            const BeuiTableIntrinsicSample.explicit('a', (
              minimum: 112.453125,
              maximum: 112.453125,
            )),
            const BeuiTableIntrinsicSample.explicit('b', (
              minimum: 194.859375,
              maximum: 194.859375,
            )),
          ],
    ),
    width: 250,
    reduce: true,
  );

  testWidgets('default flex retains weighted widths', (tester) async {
    await tester.pumpWidget(
      table(
        intrinsic: false,
        columns: [
          BeuiTableColumn(key: 'a', header: 'A', flex: 1.4, value: (r) => r),
          BeuiTableColumn(key: 'b', header: 'B', flex: 1.8, value: (r) => r),
        ],
      ),
    );
    final left = tester.getTopLeft(find.text('A')).dx;
    final boundary = tester.getTopLeft(find.text('B')).dx;
    expect(boundary - left, closeTo(248 * 1.4 / 3.2, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fractional freeze separates override from rendered width', (
    tester,
  ) async {
    double? reported;
    await tester.pumpWidget(
      table(selectable: true, onResize: (_, value) => reported = value),
    );
    final before = tester.getCenter(resize('a'));
    final drag = await tester.startGesture(before);
    await tester.pump();
    final frozen = tester.getCenter(resize('a'));
    expect(frozen.dx - before.dx, 24);
    await drag.moveBy(const Offset(50, 0));
    await tester.pump();
    expect(
      tester.getCenter(resize('a')).dx - frozen.dx,
      closeTo(49.546875, .001),
    );
    await drag.up();
    await tester.pump();
    expect(reported, 162);
    expect(
      tester.getTopLeft(find.text('A')).dx,
      tester.getTopLeft(find.text('short')).dx,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('real passive text changes widths on the first updated frame', (
    tester,
  ) async {
    List<BeuiTableIntrinsicSample> samples(
      BuildContext _,
      List<String> rows,
    ) => [
      const BeuiTableIntrinsicSample(
        'a',
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('A', style: TextStyle(fontSize: 14)),
        ),
      ),
      for (final row in rows)
        BeuiTableIntrinsicSample(
          'a',
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(row, style: const TextStyle(fontSize: 14)),
          ),
        ),
      const BeuiTableIntrinsicSample.explicit('b', (minimum: 64, maximum: 64)),
    ];
    await tester.pumpWidget(table(samples: samples));
    final before = tester.getCenter(resize('a')).dx;
    await tester.pumpWidget(
      table(samples: samples, rows: ['verylongunbreakablevalue']),
    );
    expect(tester.getCenter(resize('a')).dx, greaterThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sampling follows scrolling without onEndReached', (
    tester,
  ) async {
    final windows = <List<String>>[];
    await tester.pumpWidget(
      table(
        rows: List.generate(10000, (i) => '$i'),
        samples: (_, rows) {
          windows.add(rows);
          return const [
            BeuiTableIntrinsicSample.explicit('a', (
              minimum: 100,
              maximum: 100,
            )),
            BeuiTableIntrinsicSample.explicit('b', (
              minimum: 100,
              maximum: 100,
            )),
          ];
        },
      ),
    );
    expect(windows.last.first, '0');
    expect(windows.last.length, 13);
    final list = tester.widget<ListView>(find.byType(ListView));
    list.controller!.jumpTo(48 * 50);
    await tester.pump();
    expect(windows.last.first, '40');
    expect(windows.last.last, '62');
    expect(windows.every((w) => w.length <= 23), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new column after freezing returns to partial allocation', (
    tester,
  ) async {
    await tester.pumpWidget(table());
    final drag = await tester.startGesture(tester.getCenter(resize('a')));
    await drag.up();
    await tester.pump();
    await tester.pumpWidget(
      table(
        columns: [
          BeuiTableColumn(key: 'a', header: 'A', value: (r) => r),
          BeuiTableColumn(key: 'b', header: 'B', value: (r) => r),
          BeuiTableColumn(key: 'c', header: 'C', value: (_) => 'third'),
        ],
        samples: (_, _) => const [
          BeuiTableIntrinsicSample.explicit('a', (
            minimum: 112.453125,
            maximum: 112.453125,
          )),
          BeuiTableIntrinsicSample.explicit('b', (
            minimum: 194.859375,
            maximum: 194.859375,
          )),
          BeuiTableIntrinsicSample.explicit('c', (minimum: 80, maximum: 200)),
        ],
      ),
    );
    expect(find.text('C'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester.getCenter(resize('c')).dx - tester.getCenter(resize('b')).dx,
      80,
    );
  });
}
