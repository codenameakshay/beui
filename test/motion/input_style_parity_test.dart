import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

Finder _fieldBox() => find
    .ancestor(
      of: find.byType(TextField),
      matching: find.byType(AnimatedContainer),
    )
    .first;

void main() {
  testWidgets('input defaults retain 16px text and bordered 14px insets', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiInput(defaultValue: 'Scope'), width: 320),
    );
    await tester.pumpAndSettle();

    final editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    final field = tester.getRect(_fieldBox());
    final text = tester.getRect(find.byType(EditableText));
    expect(field.size, const Size(320, 44));
    expect(text.left - field.left, 15);
    expect(field.right - text.right, 15);
    expect(editable.text!.style!.fontSize, 16);
    expect(editable.preferredLineHeight, 24);
    expect(text.center.dy, field.center.dy);
  });

  testWidgets('default icon and success slots retain their text geometry', (
    tester,
  ) async {
    for (final success in [false, true]) {
      await tester.pumpWidget(
        beuiTestApp(
          BeuiInput(
            defaultValue: 'Scope',
            leftIcon: const Icon(Icons.search),
            rightIcon: const Icon(Icons.close),
            success: success,
          ),
          width: 320,
          reduce: true,
        ),
      );
      await tester.pumpAndSettle();

      final field = tester.getRect(_fieldBox());
      final text = tester.getRect(find.byType(EditableText));
      final editable = tester
          .state<EditableTextState>(find.byType(EditableText))
          .renderEditable;
      expect(field.size, const Size(320, 44));
      expect(text.left - field.left, 41);
      expect(field.right - text.right, 41);
      expect(editable.preferredLineHeight, 24);
      expect(text.center.dy, field.center.dy);
    }
  });

  testWidgets('copied input style renders overrides and directional padding', (
    tester,
  ) async {
    const style = BeuiInputStyle(
      borderWidth: 0,
      textStyle: TextStyle(
        fontSize: 12,
        height: 1.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF123456),
      ),
      contentPadding: EdgeInsetsDirectional.fromSTEB(9, 3, 17, 5),
    );
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        beuiTestApp(
          Directionality(
            textDirection: direction,
            child: BeuiInput(
              defaultValue: 'Scope',
              style: style.copyWith(height: 48),
            ),
          ),
          width: 320,
        ),
      );
      await tester.pumpAndSettle();

      final field = tester.getRect(_fieldBox());
      final text = tester.getRect(find.byType(EditableText));
      final editable = tester
          .state<EditableTextState>(find.byType(EditableText))
          .renderEditable;
      expect(field.size, const Size(320, 48));
      expect(text.left - field.left, direction == TextDirection.ltr ? 9 : 17);
      expect(field.right - text.right, direction == TextDirection.ltr ? 17 : 9);
      expect(text.center.dy, field.center.dy - 1);
      expect(editable.text!.style!.fontSize, 12);
      expect(editable.text!.style!.fontWeight, FontWeight.w700);
      expect(editable.text!.style!.color, const Color(0xFF123456));
      expect(editable.preferredLineHeight, 18);
    }
  });

  testWidgets('approval custom field renders source typography and insets', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiApprovalCard(
          title: 'Approval required',
          questions: [
            BeuiApprovalCardQuestion(
              id: 'scope',
              title: 'Scope?',
              allowCustom: true,
              customPlaceholder: 'Describe another scope…',
            ),
          ],
        ),
        width: 400,
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.getRect(_fieldBox());
    final text = tester.getRect(find.byType(EditableText));
    final editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    expect(editable.text!.style!.fontSize, 14);
    expect(editable.preferredLineHeight, 20);
    expect(field.height, 40);
    expect(text.left - field.left, 12);
    expect(field.right - text.right, 12);
    expect(text.center.dy, field.center.dy);

    final hint = tester.renderObject<RenderParagraph>(
      find.text('Describe another scope…'),
    );
    expect(hint.text.style!.fontSize, 14);
    expect(hint.text.style!.height, 20 / 14);
    await tester.enterText(find.byType(TextField), 'Keep it focused');
    await tester.pumpAndSettle();
    expect(find.text('Keep it focused'), findsOneWidget);
    expect(editable.text!.toPlainText(), 'Keep it focused');
    expect(editable.preferredLineHeight, 20);
    expect(tester.getRect(find.byType(EditableText)), text);
  });

  testWidgets(
    'approval keeps the supplied primary palette on its Next action',
    (tester) async {
      for (final color in [const Color(0xFF0285F7), const Color(0xFFF2F2F2)]) {
        await tester.pumpWidget(
          beuiTestApp(
            const BeuiApprovalCard(
              title: 'Approval required',
              questions: [
                BeuiApprovalCardQuestion(id: 'scope', title: 'Scope?'),
                BeuiApprovalCardQuestion(id: 'checks', title: 'Checks?'),
              ],
            ),
            width: 400,
            dark: true,
            extensions: [BeuiColors.dark().copyWith(primary: color)],
          ),
        );
        await tester.pumpAndSettle();

        final next = find.descendant(
          of: find.byWidgetPredicate(
            (widget) => widget is Tooltip && widget.message == 'Next question',
          ),
          matching: find.byType(DecoratedBox),
        );
        final painted = tester
            .renderObjectList<RenderDecoratedBox>(next)
            .map((render) => render.decoration)
            .whereType<BoxDecoration>()
            .where((decoration) => decoration.color == color);
        expect(painted, hasLength(1));
      }
    },
  );
}
