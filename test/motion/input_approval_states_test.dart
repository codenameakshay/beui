import 'dart:ui' as ui;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _placeholder = 'Describe another scope…';
const _capture = ValueKey('capture');

Widget _approval({bool disabled = false, bool dark = true}) => RepaintBoundary(
  key: _capture,
  child: beuiTestApp(
    BeuiApprovalCard(
      title: 'Approval required',
      status: disabled
          ? BeuiApprovalCardStatus.submitting
          : BeuiApprovalCardStatus.pending,
      questions: const [
        BeuiApprovalCardQuestion(
          id: 'scope',
          title: 'Scope?',
          allowCustom: true,
          customPlaceholder: _placeholder,
        ),
      ],
    ),
    dark: dark,
    width: 400,
  ),
);

Finder _box() => find
    .ancestor(
      of: find.byType(TextField),
      matching: find.byType(AnimatedContainer),
    )
    .first;

BoxDecoration _decoration(WidgetTester tester) =>
    tester
            .renderObject<RenderDecoratedBox>(
              find
                  .descendant(of: _box(), matching: find.byType(DecoratedBox))
                  .first,
            )
            .decoration
        as BoxDecoration;

Future<List<int>?> _pixel(WidgetTester tester, Offset point) => tester.runAsync(
  () async {
    final image = await tester
        .renderObject<RenderRepaintBoundary>(find.byKey(_capture))
        .toImage();
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
    final channels = List.generate(4, (i) => bytes.getUint8(offset + i));
    image.dispose();
    return channels;
  },
);

void main() {
  for (final dark in [false, true]) {
    testWidgets('approval idle/focus/disabled pixels, dark=$dark', (
      tester,
    ) async {
      await tester.pumpWidget(_approval(dark: dark));
      await tester.pumpAndSettle();
      final field = tester.getRect(_box());
      final sample = Offset(field.center.dx, field.top + 3);
      final idle = dark ? 23 : 250;
      final focused = dark ? 21 : 252;
      final disabled = dark ? 25 : 248;
      expect(await _pixel(tester, sample), [idle, idle, idle, 255]);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text(_placeholder))
            .text
            .style!
            .color!
            .toARGB32(),
        dark ? 0x99868686 : 0x99636363,
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(await _pixel(tester, sample), [focused, focused, focused, 255]);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text(_placeholder))
            .text
            .style!
            .color!
            .toARGB32(),
        dark ? 0x99868686 : 0x99636363,
      );

      await tester.pumpWidget(_approval(dark: dark, disabled: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(await _pixel(tester, sample), [disabled, disabled, disabled, 255]);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text(_placeholder))
            .text
            .style!
            .color!
            .toARGB32(),
        dark ? 0x99868686 : 0x99636363,
      );
      final opacity = find.ancestor(
        of: find.byType(TextField),
        matching: find.byWidgetPredicate(
          (w) => w is Opacity && w.opacity == 0.6,
        ),
      );
      expect(opacity, findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('shared defaults keep a transparent fill and full muted hint', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiInput(placeholder: _placeholder),
        dark: true,
        width: 320,
      ),
    );
    await tester.pumpAndSettle();
    for (final focused in [false, true]) {
      if (focused) {
        await tester.tap(find.byType(TextField));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(_decoration(tester).color, isNull);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text(_placeholder))
            .text
            .style!
            .color!
            .toARGB32(),
        0xFF868686,
      );
    }
  });

  testWidgets('copied style retains custom hint and focus fills', (
    tester,
  ) async {
    const style = BeuiInputStyle(
      placeholderColor: Color(0x80445566),
      backgroundColor: Color(0xFF112233),
      focusedBackgroundColor: Color(0xFF334455),
    );
    await tester.pumpWidget(
      beuiTestApp(
        BeuiInput(placeholder: _placeholder, style: style.copyWith(height: 40)),
        width: 320,
      ),
    );
    await tester.pumpAndSettle();
    expect(_decoration(tester).color!.toARGB32(), 0xFF112233);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(_decoration(tester).color!.toARGB32(), 0xFF334455);
    expect(
      tester
          .renderObject<RenderParagraph>(find.text(_placeholder))
          .text
          .style!
          .color!
          .toARGB32(),
      0x80445566,
    );
    await tester.enterText(find.byType(TextField), 'Keep it focused');
    await tester.pump();
    final editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    expect(editable.text!.toPlainText(), 'Keep it focused');
    expect(editable.text!.style!.color!.toARGB32(), 0xFF0B0B0B);
  });
  testWidgets('approval placeholder uses source 60% muted color', (
    tester,
  ) async {
    await tester.pumpWidget(_approval());
    await tester.pumpAndSettle();
    final hint = tester.renderObject<RenderParagraph>(find.text(_placeholder));
    expect(hint.text.style!.color!.toARGB32(), 0x99868686);
  });

  testWidgets('approval paints idle and focused fills inside the input', (
    tester,
  ) async {
    await tester.pumpWidget(_approval());
    await tester.pumpAndSettle();
    expect(_decoration(tester).color?.toARGB32(), 0xB3151515);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(_decoration(tester).color?.toARGB32(), 0xFF151515);
    expect(
      tester
          .renderObject<RenderParagraph>(find.text(_placeholder))
          .text
          .style!
          .color!
          .toARGB32(),
      0x99868686,
    );
  });
}
