import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

void main() {
  testWidgets(
    'sort and list updates replace sampled rows without resetting scroll',
    (tester) async {
      List<int> sampled = [];
      Widget tree({int count = 100, bool descending = false}) => beuiTestApp(
        BeuiTable<int>(
          height: 420,
          rowHeight: 52,
          data: List.generate(count, (i) => i),
          sort: BeuiSortState(
            key: 'a',
            direction: descending
                ? BeuiSortDirection.desc
                : BeuiSortDirection.asc,
          ),
          columns: [
            BeuiTableColumn(
              key: 'a',
              header: 'A',
              value: (r) => '$r',
              sortValue: (r) => r,
            ),
          ],
          sizing: BeuiTableSizing.intrinsic,
          intrinsicSamples: (_, rows) {
            sampled = rows;
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
      await tester.pumpWidget(tree());
      final scroll = tester.widget<ListView>(find.byType(ListView)).controller!;
      scroll.jumpTo(1040);
      await tester.pump();
      expect(sampled, List.generate(29, (i) => i + 10));
      await tester.pumpWidget(tree(descending: true));
      expect(scroll.offset, 1040);
      expect(sampled, List.generate(29, (i) => 89 - i));
      scroll.jumpTo(0);
      await tester.pump();
      await tester.pumpWidget(tree(count: 4));
      expect(sampled, [0, 1, 2, 3]);
      await tester.pumpWidget(tree(count: 0));
      expect(sampled, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('source ranges include fractional trailing-row transitions', (
    tester,
  ) async {
    List<int> sampled = [];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiTable<int>(
          height: 420,
          rowHeight: 52,
          data: List.generate(100, (i) => i),
          columns: [BeuiTableColumn(key: 'a', header: 'A', value: (r) => '$r')],
          sizing: BeuiTableSizing.intrinsic,
          intrinsicSamples: (_, rows) {
            sampled = rows;
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
      ),
    );
    final scroll = tester.widget<ListView>(find.byType(ListView)).controller!;
    for (final (offset, start, end) in <(double, int, int)>[
      (0, 0, 19),
      (47.5, 0, 19),
      (48, 0, 19),
      (48.5, 0, 20),
      (52, 0, 20),
      (520, 0, 29),
      (568, 0, 29),
      (568.5, 0, 30),
      (1040, 10, 39),
      (4832, 82, 100),
    ]) {
      scroll.jumpTo(offset);
      await tester.pump();
      expect(
        sampled,
        List.generate(end - start, (i) => start + i),
        reason: 'offset $offset',
      );
    }
  });

  testWidgets('fractional scroll adds and removes a wider trailing sample', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        BeuiTable<int>(
          height: 420,
          rowHeight: 52,
          data: List.generate(100, (i) => i),
          resizable: true,
          columns: [BeuiTableColumn(key: 'a', header: 'A', value: (r) => '$r')],
          sizing: BeuiTableSizing.intrinsic,
          intrinsicSamples: (_, rows) => [
            for (final row in rows)
              BeuiTableIntrinsicSample('a', Text(row == 19 ? 'W' * 50 : 'x')),
          ],
        ),
        width: 250,
        reduce: true,
      ),
    );
    final scroll = tester.widget<ListView>(find.byType(ListView)).controller!;
    final handle = find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Resize a column',
    );
    scroll.jumpTo(48);
    await tester.pump();
    final before = tester.getCenter(handle).dx;
    scroll.jumpTo(48.5);
    await tester.pump();
    expect(tester.getCenter(handle).dx, greaterThan(before + 100));
    scroll.jumpTo(48);
    await tester.pump();
    expect(tester.getCenter(handle).dx, before);
    expect(tester.takeException(), isNull);
  });
}
