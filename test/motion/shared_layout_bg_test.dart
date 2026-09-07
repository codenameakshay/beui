import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _pill = ValueKey<String>('beui_shared_pill');

Widget _app() => beuiTestApp(
  BeuiSharedLayoutBg(
    children: [
      for (var i = 0; i < 4; i++)
        SizedBox(height: 56, child: Center(child: Text('Item $i'))),
    ],
  ),
  width: 300,
);

Future<TestGesture> _mouse(WidgetTester tester) async {
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: Offset.zero);
  addTearDown(g.removePointer);
  return g;
}

double _pillY(WidgetTester t) => t.getTopLeft(find.byKey(_pill)).dy;

void main() {
  testWidgets('pill appears on hover and glides between rows', (tester) async {
    await tester.pumpWidget(_app());
    final g = await _mouse(tester);
    expect(find.byKey(_pill), findsNothing);

    await g.moveTo(tester.getCenter(find.text('Item 0')));
    await tester.pumpAndSettle();
    expect(find.byKey(_pill), findsOneWidget);
    final y0 = _pillY(tester);

    await g.moveTo(tester.getCenter(find.text('Item 3')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final yMid = _pillY(tester);
    await tester.pumpAndSettle();
    final y3 = _pillY(tester);

    expect(y3, greaterThan(y0)); // moved down to row 3
    expect(yMid, greaterThan(y0));
    expect(yMid, lessThan(y3)); // gliding, not snapping
  });

  // The source's pill is `absolute` with `left:-inset; right:-inset`, so it is
  // deliberately wider than the row on both sides (default inset 20). The
  // stack hands the pill tight, list-sized constraints, so it has to be let
  // out of them explicitly or the inset only shifts it instead of widening it.
  testWidgets('pill overhangs each row by `inset` on both sides', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final g = await _mouse(tester);
    await g.moveTo(tester.getCenter(find.text('Item 0')));
    await tester.pumpAndSettle();

    final list = tester.getRect(find.byType(BeuiSharedLayoutBg));
    final pill = tester.getRect(find.byKey(_pill));
    expect(list.width, 300);
    expect(pill.left, moreOrLessEquals(list.left - 20, epsilon: 0.5));
    expect(pill.right, moreOrLessEquals(list.right + 20, epsilon: 0.5));
    expect(pill.width, moreOrLessEquals(340, epsilon: 0.5));
    // Vertically it is `inset-y-0`: exactly the row, no overhang.
    expect(pill.height, moreOrLessEquals(56, epsilon: 0.5));
  });

  testWidgets('pill fades out when the pointer leaves the list', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final g = await _mouse(tester);
    await g.moveTo(tester.getCenter(find.text('Item 1')));
    await tester.pumpAndSettle();
    expect(find.byKey(_pill), findsOneWidget);

    await g.moveTo(const Offset(5, 5)); // off the list
    await tester.pumpAndSettle();
    expect(find.byKey(_pill), findsNothing);
  });

  testWidgets('rows stay tappable through the pill', (tester) async {
    var tapped = -1;
    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: BeuiSharedLayoutBg(
                children: [
                  for (var i = 0; i < 3; i++)
                    GestureDetector(
                      onTap: () => tapped = i,
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        height: 56,
                        child: Center(child: Text('Row $i')),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final g = await _mouse(tester);
    await g.moveTo(tester.getCenter(find.text('Row 1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Row 1'));
    expect(tapped, 1); // pill is IgnorePointer, tap reaches the row
  });
}
