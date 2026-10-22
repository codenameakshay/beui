import 'dart:ui' show PointerDeviceKind;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

final _previews = [
  for (var i = 0; i < 5; i++)
    BeuiProjectFolderPreview(
      id: 'preview-$i',
      content: ColoredBox(
        color: [
          Colors.green,
          Colors.orange,
          Colors.blue,
          Colors.purple,
          Colors.amber,
        ][i],
        child: Center(child: Text('ABCDE'[i])),
      ),
    ),
];

Widget _app({
  bool reduce = false,
  bool disabled = false,
  bool? open,
  bool? expanded,
  ValueChanged<bool>? onOpenChange,
  ValueChanged<bool>? onExpandedChange,
  VoidCallback? onClick,
}) => beuiTestApp(
  BeuiProjectFolder(
    title: 'Brand direction',
    previews: _previews,
    count: 5,
    description: 'Updated recently',
    disabled: disabled,
    open: open,
    expanded: expanded,
    onOpenChange: onOpenChange,
    onExpandedChange: onExpandedChange,
    onClick: onClick,
  ),
  reduce: reduce,
);

void main() {
  group('BeuiProjectFolder', () {
    testWidgets('renders title, count, description, and closed previews', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Brand direction'), findsOneWidget);
      expect(find.text('5 files'), findsOneWidget);
      expect(find.text('Updated recently'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('hover and keyboard focus request fan-open state', (
      tester,
    ) async {
      final changes = <bool>[];
      await tester.pumpWidget(_app(onOpenChange: changes.add));
      final folder = find.byType(BeuiProjectFolder);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(folder));
      await gesture.moveTo(tester.getCenter(folder));
      await tester.pump();
      expect(changes, contains(true));

      await gesture.removePointer();
      await tester.pump();
      final focus = tester.widget<Focus>(
        find.descendant(of: folder, matching: find.byType(Focus)).first,
      );
      focus.focusNode!.requestFocus();
      await tester.pump();
      expect(changes.last, isTrue);
    });

    testWidgets(
      'activation opens the dialog, Escape closes, and focus returns',
      (tester) async {
        await tester.pumpWidget(_app());
        final button = find.bySemanticsLabel('Brand direction');
        await tester.tap(button);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 560));
        expect(find.text('5 files'), findsNWidgets(2));
        expect(find.byTooltip('Close Brand direction'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 560));
        expect(find.byTooltip('Close Brand direction'), findsNothing);
        expect(
          tester.binding.focusManager.primaryFocus?.debugLabel,
          'BeuiProjectFolder',
        );
      },
    );

    testWidgets(
      'controlled open and expanded report changes without taking control',
      (tester) async {
        final openChanges = <bool>[];
        final expandedChanges = <bool>[];
        await tester.pumpWidget(
          _app(
            open: false,
            expanded: false,
            onOpenChange: openChanges.add,
            onExpandedChange: expandedChanges.add,
          ),
        );
        await tester.tap(find.bySemanticsLabel('Brand direction'));
        await tester.pump();
        expect(openChanges, [true]);
        expect(expandedChanges, [true]);
        expect(find.byTooltip('Close Brand direction'), findsNothing);
      },
    );

    testWidgets('disabled folder ignores pointer activation', (tester) async {
      var clicks = 0;
      await tester.pumpWidget(_app(disabled: true, onClick: () => clicks++));
      await tester.tap(find.byType(BeuiProjectFolder));
      await tester.pump();
      expect(clicks, 0);
      expect(find.byTooltip('Close Brand direction'), findsNothing);
    });

    testWidgets('reduced motion opens the overlay without card movement', (
      tester,
    ) async {
      await tester.pumpWidget(_app(reduce: true));
      await tester.tap(find.bySemanticsLabel('Brand direction'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byTooltip('Close Brand direction'), findsOneWidget);
      final overlayPreview = tester.getRect(find.text('A').last);
      expect(overlayPreview.left, greaterThanOrEqualTo(0));
    });

    testWidgets('rest-state matches the project folder golden', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(BeuiProjectFolder),
        matchesGoldenFile('goldens/beui_project_folder.png'),
      );
    });
  });
}
