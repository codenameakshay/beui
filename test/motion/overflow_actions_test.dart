import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = Center(child: child);
  if (reduce) {
    final inner = body;
    body = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: body),
  );
}

BeuiOverflowActions _rail({
  List<String>? actions,
  bool? expanded,
  ValueChanged<bool>? onExpandedChange,
  bool collapseOnAction = false,
}) => BeuiOverflowActions(
  expanded: expanded,
  onExpandedChange: onExpandedChange,
  collapseOnAction: collapseOnAction,
  onAction: (item) => actions?.add(item.id),
  primaryActions: const [
    BeuiOverflowActionItem(id: 'reply', label: 'Reply'),
    BeuiOverflowActionItem(id: 'forward', label: 'Forward'),
  ],
  overflowActions: const [
    BeuiOverflowActionItem(id: 'archive', label: 'Archive'),
    BeuiOverflowActionItem(id: 'delete', label: 'Delete'),
  ],
);

void main() {
  group('BeuiOverflowActions', () {
    testWidgets('collapsed shows primaries and the ⋯ toggle only', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_rail()));
      await tester.pumpAndSettle();
      expect(find.text('Reply'), findsOneWidget);
      expect(find.byIcon(LucideIcons.ellipsis), findsOneWidget);
      final width = tester.getSize(find.byType(BeuiOverflowActions)).width;

      await tester.tap(find.byIcon(LucideIcons.ellipsis));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Archive'), findsOneWidget);
      expect(find.byIcon(LucideIcons.x), findsOneWidget);
      final expanded = tester.getSize(find.byType(BeuiOverflowActions)).width;
      expect(expanded, greaterThan(width + 60));
    });

    testWidgets('X collapses the rail again', (tester) async {
      await tester.pumpWidget(_wrap(_rail()));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.ellipsis));
      await tester.pumpAndSettle();
      final expanded = tester.getSize(find.byType(BeuiOverflowActions)).width;
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();
      final collapsed = tester.getSize(find.byType(BeuiOverflowActions)).width;
      expect(collapsed, lessThan(expanded - 60));
      expect(find.byIcon(LucideIcons.ellipsis), findsOneWidget);
    });

    testWidgets('actions fire onAction; collapseOnAction folds the rail', (
      tester,
    ) async {
      final actions = <String>[];
      await tester.pumpWidget(
        _wrap(_rail(actions: actions, collapseOnAction: true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reply'));
      expect(actions, ['reply']);

      await tester.tap(find.byIcon(LucideIcons.ellipsis));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(actions, ['reply', 'delete']);
      expect(find.byIcon(LucideIcons.ellipsis), findsOneWidget);
    });

    testWidgets('controlled expanded reports through onExpandedChange', (
      tester,
    ) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        _wrap(_rail(expanded: false, onExpandedChange: changes.add)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.ellipsis));
      await tester.pump();
      expect(changes, [true]);
      // Still collapsed: the parent hasn't echoed the new value.
      expect(find.text('Archive'), findsNothing);
    });

    testWidgets('reduced motion expands without blur', (tester) async {
      await tester.pumpWidget(_wrap(_rail(), reduce: true));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byIcon(LucideIcons.ellipsis));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(maxBlurSigma(tester), lessThan(0.5));
      }
      expect(find.text('Archive'), findsOneWidget);
    });
  });
}
