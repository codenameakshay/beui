import 'dart:io';
import 'dart:ui' as ui;

import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _tabs = [
  BeuiTab(value: 'all', label: Text('All')),
  BeuiTab(value: 'open', label: Text('Open')),
  BeuiTab(value: 'closed', label: Text('Closed')),
];

Rect _trigger(WidgetTester tester, String label) => tester.getRect(
  find
      .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
      .first,
);

Future<Color> _pixel(WidgetTester tester, Key key, Offset point) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final i = (point.dy.floor() * image.width + point.dx.floor()) * 4;
      return Color.fromARGB(
        bytes.getUint8(i + 3),
        bytes.getUint8(i),
        bytes.getUint8(i + 1),
        bytes.getUint8(i + 2),
      );
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  setUpAll(() async {
    await (FontLoader('actualGeist')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('example/assets/fonts/Geist-Medium.ttf').readAsBytes(),
            ),
          ),
        ))
        .load();
  });

  for (final variant in BeuiTabsVariant.values) {
    for (final reduce in [false, true]) {
      for (final controlled in [false, true]) {
        testWidgets(
          'native pointer owns focus $variant reduce=$reduce controlled=$controlled',
          (tester) async {
            String? changed;
            await tester.pumpWidget(
              beuiTestApp(
                BeuiTabs<String>(
                  variant: variant,
                  value: controlled ? 'all' : null,
                  onChanged: (value) => changed = value,
                  tabs: _tabs,
                ),
                reduce: reduce,
                alignment: Alignment.topLeft,
              ),
            );
            await tester.pumpAndSettle();
            final pointer = await tester.createGesture(
              kind: PointerDeviceKind.mouse,
            );
            await pointer.addPointer(location: Offset.zero);
            await pointer.down(_trigger(tester, 'Open').center);
            await tester.pump();
            expect(
              Focus.of(tester.element(find.text('Open'))).hasPrimaryFocus,
              isTrue,
            );
            expect(changed, isNull);
            await pointer.up();
            await tester.pumpAndSettle();
            expect(changed, 'open');
            await tester.sendKeyEvent(LogicalKeyboardKey.end);
            await tester.pumpAndSettle();
            expect(changed, 'closed');
            expect(
              Focus.of(tester.element(find.text('Closed'))).hasPrimaryFocus,
              isTrue,
            );
            await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
            await tester.pumpAndSettle();
            expect(changed, 'open');
            expect(
              Focus.of(tester.element(find.text('Open'))).hasPrimaryFocus,
              isTrue,
            );
            if (controlled) {
              final indicator = tester.getRect(
                find.byKey(const ValueKey('beui_tabs_indicator')),
              );
              expect(indicator.left, _trigger(tester, 'All').left);
            }
            await pointer.removePointer();
          },
        );
      }

      testWidgets(
        'one Tab stop follows controlled selection $variant reduce=$reduce',
        (tester) async {
          final before = FocusNode();
          final after = FocusNode();
          addTearDown(before.dispose);
          addTearDown(after.dispose);
          var value = 'open';
          late StateSetter rebuild;
          await tester.pumpWidget(
            beuiTestApp(
              StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Focus(
                        focusNode: before,
                        child: const SizedBox(width: 10, height: 10),
                      ),
                      BeuiTabs<String>(
                        variant: variant,
                        value: value,
                        tabs: _tabs,
                      ),
                      Focus(
                        focusNode: after,
                        child: const SizedBox(width: 10, height: 10),
                      ),
                    ],
                  );
                },
              ),
              reduce: reduce,
              alignment: Alignment.topLeft,
            ),
          );
          await tester.pumpAndSettle();
          before.requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(
            Focus.of(tester.element(find.text('Open'))).hasPrimaryFocus,
            isTrue,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(after.hasPrimaryFocus, isTrue);
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          await tester.pump();
          expect(
            Focus.of(tester.element(find.text('Open'))).hasPrimaryFocus,
            isTrue,
          );
          before.requestFocus();
          rebuild(() => value = 'closed');
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(
            Focus.of(tester.element(find.text('Closed'))).hasPrimaryFocus,
            isTrue,
          );
          before.requestFocus();
          rebuild(() => value = 'missing');
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(
            Focus.of(tester.element(find.text('All'))).hasPrimaryFocus,
            isTrue,
          );
        },
      );

      for (final dark in [false, true]) {
        testWidgets(
          'keyboard outline leaves interior clear $variant dark=$dark reduce=$reduce',
          (tester) async {
            const capture = ValueKey('focus-paint');
            final colors = dark ? BeuiColors.dark() : BeuiColors.light();
            final surface = variant == BeuiTabsVariant.underline
                ? colors.background
                : colors.card;
            await tester.pumpWidget(
              beuiTestApp(
                RepaintBoundary(
                  key: capture,
                  child: ColoredBox(
                    color: colors.background,
                    child: SizedBox(
                      width: 320,
                      height: 100,
                      child: Align(
                        alignment: Alignment.center,
                        child: BeuiTabs<String>(
                          variant: variant,
                          value: 'all',
                          tabs: _tabs,
                        ),
                      ),
                    ),
                  ),
                ),
                dark: dark,
                reduce: reduce,
                fontFamily: 'actualGeist',
              ),
            );
            await tester.pumpAndSettle();
            final origin = tester.getTopLeft(find.byKey(capture));
            final rect = _trigger(tester, 'Open');
            final inside = rect.topLeft - origin + const Offset(6, 6);
            final edge = Offset(
              (rect.left - origin.dx).ceilToDouble(),
              rect.center.dy - origin.dy,
            );
            expect(await _pixel(tester, capture, inside), surface);
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
            await tester.pumpAndSettle();
            expect(
              Focus.of(tester.element(find.text('Open'))).hasPrimaryFocus,
              isTrue,
            );
            expect(_trigger(tester, 'Open'), rect);
            expect(await _pixel(tester, capture, inside), surface);
            expect(
              (await _pixel(tester, capture, edge)).toARGB32(),
              composite(colors.focusRing, surface).toARGB32(),
            );
            final pointer = await tester.createGesture(
              kind: PointerDeviceKind.mouse,
            );
            await pointer.addPointer(location: Offset.zero);
            await pointer.down(rect.center);
            await pointer.up();
            await tester.pumpAndSettle();
            expect(await _pixel(tester, capture, inside), surface);
            expect(await _pixel(tester, capture, edge), surface);
            await pointer.removePointer();
          },
        );
      }
    }
  }
}
