import 'package:beui/beui.dart';
import 'package:beui/src/motion/table/intrinsic_measurement.dart';
import 'package:beui_example/demos/table_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support.dart';

const _keys = ['name', 'email', 'role', 'status', 'mrr'];

Finder _headers() => find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString().startsWith('_HeaderCell<'),
);

Finder _bodyRows() => find.byWidgetPredicate(
  (widget) =>
      widget is Row &&
      widget.children.length == 7 &&
      widget.children.take(6).every((child) => child is SizedBox),
);

List<Rect> _headerRects(WidgetTester tester) => [
  for (final element in _headers().evaluate())
    tester.getRect(find.byWidget(element.widget)),
];

void _expectAligned(WidgetTester tester) {
  final headers = _headerRects(tester);
  expect(headers, hasLength(5));
  expect(_bodyRows(), findsWidgets);
  for (final row in tester.widgetList<Row>(_bodyRows())) {
    for (var i = 0; i < headers.length; i++) {
      final cell = tester.getRect(find.byWidget(row.children[i + 1]));
      expect(cell.left, closeTo(headers[i].left, 0.001));
      expect(cell.width, closeTo(headers[i].width, 0.001));
    }
  }
}

Future<void> _pump(WidgetTester tester, {double width = 592}) async {
  await tester.pumpWidget(
    beuiTestApp(
      Builder(builder: (context) => tableDemo(context, example: 'data')),
      width: width,
      fontFamily: 'actualGeist',
      reduce: true,
    ),
  );
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('actualGeist');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/Geist-$weight.ttf'));
    }
    await loader.load();
  });

  testWidgets('first layout measures bounded sorted DATA with real fonts', (
    tester,
  ) async {
    await _pump(tester);
    final measurement = tester.widget<IntrinsicMeasurement>(
      find.byType(IntrinsicMeasurement),
    );
    // ceil(420 / 52) visible rows plus ten forward overscan rows.
    expect(measurement.samples, hasLength(6 + 19 * 5));
    expect(measurement.samples.first.widths, (minimum: 24.0, maximum: 24.0));
    for (final key in _keys) {
      expect(measurement.samples.where((s) => s.column == key), hasLength(20));
    }
    final mrr = measurement.samples
        .where((s) => s.column == 'mrr')
        .skip(1)
        .map((s) => ((s.widget! as Padding).child! as Text).data)
        .toList();
    expect(mrr, everyElement(r'$499'));
    final emails = measurement.samples
        .where((s) => s.column == 'email')
        .skip(1)
        .map((s) => ((s.widget! as Padding).child! as Text).data)
        .toList();
    expect(emails.first, 'leo.marsh211@beui.dev');
    _expectAligned(tester);
    final widths = _headerRects(tester).map((r) => r.width).toList();
    const sourceWidths = [
      112.453125,
      194.859375,
      103.40625,
      111.265625,
      105.25,
    ];
    for (var i = 0; i < widths.length; i++) {
      expect(widths[i], closeTo(sourceWidths[i], .05));
    }
    // Font loading is observable, rather than merely a requested family name.
    final painter = TextPainter(
      text: const TextSpan(
        text: 'iiii',
        style: TextStyle(fontFamily: 'actualGeist', fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(painter.width, lessThan(20));
    painter.dispose();
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('scroll samples only the sorted viewport and overscan window', (
    tester,
  ) async {
    await _pump(tester);
    List<String?> emails() => tester
        .widget<IntrinsicMeasurement>(find.byType(IntrinsicMeasurement))
        .samples
        .where((s) => s.column == 'email')
        .skip(1)
        .map((s) => ((s.widget! as Padding).child! as Text).data)
        .toList();
    final before = emails();
    final list = tester.widget<ListView>(find.byType(ListView));
    list.controller!.jumpTo(52 * 100);
    await tester.pump();
    expect(emails(), hasLength(29));
    expect(emails().toSet().intersection(before.toSet()), isEmpty);
    _expectAligned(tester);
    await tester.tap(find.text('Name').hitTestable());
    await tester.pump();
    expect(emails(), hasLength(29));
    expect(emails(), everyElement(startsWith('ava.cole')));
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('resize freeze, drag and selection preserve live alignment', (
    tester,
  ) async {
    await _pump(tester);
    final semantics = tester.ensureSemantics();

    final rest = _headerRects(tester);
    final handle = find.bySemanticsLabel('Resize name column');
    expect(handle, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    final frozen = _headerRects(tester);
    _expectAligned(tester);
    // Pointer down freezes all current data columns and expands selection's
    // absolute preference. The probe still reports its actual 24px header label.
    expect(frozen.first.left - rest.first.left, greaterThan(0));
    await gesture.moveBy(const Offset(50, 0));
    await tester.pump();
    final dragged = _headerRects(tester);
    expect(dragged.first.width, greaterThan(frozen.first.width + 40));
    _expectAligned(tester);
    await gesture.up();
    await tester.pump();
    expect(_headerRects(tester), dragged);
    await tester.tap(find.byType(BeuiCheckbox).at(1));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    expect(_headerRects(tester), dragged);
    _expectAligned(tester);
    // Only real checkboxes and controls exist; passive copies have no semantics.
    expect(
      find.byType(BeuiCheckbox),
      findsNWidgets(_bodyRows().evaluate().length + 1),
    );
    for (final key in _keys) {
      expect(find.bySemanticsLabel('Resize $key column'), findsOneWidget);
      expect(find.bySemanticsLabel('Reorder $key column'), findsOneWidget);
    }
    expect(find.bySemanticsLabel(RegExp(r'^Name$')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    semantics.dispose();
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });

  testWidgets('wide layout keeps the same header and body column boundaries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, width: 1000);
    _expectAligned(tester);
    final headers = _headerRects(tester);
    expect(headers.last.right - headers.first.left, greaterThan(900));
    expect(tester.takeException(), isNull);
    await _dispose(tester);
  });
}
