import 'dart:io';
import 'package:flutter/services.dart';
import 'package:beui/beui.dart';
import 'package:beui/src/motion/table/intrinsic_measurement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

void main() {
  testWidgets(
    'font replacement preserves focused editor and disposes listener',
    (tester) async {
      final focus = FocusNode();
      final controller = TextEditingController(text: 'draft');
      MeasurementResult? result;
      Widget tree(int revision, int count) => MaterialApp(
        home: IntrinsicMeasurement(
          revision: revision,
          columns: const ['a'],
          samples: List.generate(
            count,
            (_) => const BeuiTableIntrinsicSample(
              'a',
              Text(
                '000000',
                style: TextStyle(fontFamily: 'Final Review Font', fontSize: 20),
              ),
            ),
          ),
          builder: (_, r) {
            result = r;
            return Material(
              child: TextField(focusNode: focus, controller: controller),
            );
          },
        ),
      );
      await tester.pumpWidget(tree(0, 1));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      final state = tester.state(find.byType(EditableText));
      final before = result!.columns.single.maximum;
      await tester.runAsync(() async {
        final bytes = await File(
          'example/assets/fonts/GeistMono-Regular.ttf',
        ).readAsBytes();
        await (FontLoader(
          'Final Review Font',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      });
      await tester.pump();
      expect(result!.columns.single.maximum, lessThan(before));
      expect(tester.state(find.byType(EditableText)), same(state));
      expect(focus.hasFocus, true);
      await tester.pumpWidget(tree(1, 3));
      expect(tester.state(find.byType(EditableText)), same(state));
      expect(focus.hasFocus, true);
      expect(controller.text, 'draft');
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        final bytes = await File(
          'example/assets/fonts/GeistMono-Regular.ttf',
        ).readAsBytes();
        await (FontLoader(
          'Final Review Font After Dispose',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
      focus.dispose();
      controller.dispose();
    },
  );
  testWidgets('row height change then jump back samples actual viewport', (
    tester,
  ) async {
    List<String> window = [];
    Widget tree(double h) => beuiTestApp(
      BeuiTable<String>(
        data: List.generate(1000, (i) => '$i'),
        columns: [BeuiTableColumn(key: 'a', header: 'A', value: (r) => r)],
        sizing: BeuiTableSizing.intrinsic,
        height: 192,
        rowHeight: h,
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
    final scroll = tester.widget<ListView>(find.byType(ListView)).controller!;
    scroll.jumpTo(2400);
    await tester.pump();
    expect(window.first, '40');
    await tester.pumpWidget(tree(24));
    await tester.pump();
    expect(window.first, '90');
    scroll.jumpTo(1200);
    await tester.pump();
    expect(window.first, '40');
    expect(window, contains('50'));
  });
}
