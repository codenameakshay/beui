import 'package:beui/beui.dart' show BeuiColors, BeuiTextTheme, LucideIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beui/src/motion/expandable_control.dart';
import '../support.dart';

void main() {
  group('BeuiExpandableButton', () {
    testWidgets('tap toggles expanded state and reports changes', (
      tester,
    ) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        beuiTestApp(
          BeuiExpandableButton(
            icon: const Icon(LucideIcons.bell),
            label: const Text('Notifications'),
            onExpandedChange: changes.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsNothing);
      await tester.tap(find.byType(BeuiExpandableButton));
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);
      expect(changes, [true]);
    });

    testWidgets('controlled expanded state reports without changing itself', (
      tester,
    ) async {
      bool? requested;
      await tester.pumpWidget(
        beuiTestApp(
          BeuiExpandableButton(
            icon: const Icon(LucideIcons.bell),
            label: const Text('Notifications'),
            expanded: false,
            onExpandedChange: (value) => requested = value,
          ),
        ),
      );
      await tester.tap(find.byType(BeuiExpandableButton));
      await tester.pumpAndSettle();
      expect(requested, isTrue);
      expect(find.text('Notifications'), findsNothing);
    });
  });

  group('BeuiExpandableChip', () {
    testWidgets('reveals action, invokes it, collapses, and returns focus', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var actions = 0;
      await tester.pumpWidget(
        beuiTestApp(
          BeuiExpandableChip(
            label: const Text('React'),
            actionIcon: const Icon(LucideIcons.x),
            actionLabel: 'Remove React',
            onAction: () => actions++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Remove React'), findsNothing);
      await tester.tap(find.text('React'));
      await tester.pumpAndSettle();
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.bySemanticsLabel('Remove React'), findsOneWidget);
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(actions, 1);
      expect(find.byType(IconButton), findsNothing);
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).focusNode?.hasFocus,
        isTrue,
      );
      semantics.dispose();
    });

    testWidgets('reduced motion snaps layout and keeps reveal fade', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        beuiTestApp(
          BeuiExpandableChip(
            label: const Text('React'),
            actionIcon: const Icon(LucideIcons.x),
            actionLabel: 'Remove React',
            defaultExpanded: true,
          ),
          reduce: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.bySemanticsLabel('Remove React'), findsOneWidget);
      expect(maxBlurSigma(tester), lessThan(0.5));
      expect(
        tester.getSize(find.byType(BeuiExpandableChip)).width,
        greaterThan(40),
      );
      semantics.dispose();
    });
  });

  testWidgets('rest-state golden (one expanded and one collapsed)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        ),
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BeuiExpandableButton(
                  icon: Icon(LucideIcons.bell),
                  label: Text('Notifications'),
                  defaultExpanded: true,
                ),
                SizedBox(height: 12),
                BeuiExpandableChip(
                  label: Text('React'),
                  actionIcon: Icon(LucideIcons.x),
                  actionLabel: 'Remove React',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Column),
      matchesGoldenFile('goldens/beui_expandable_control.png'),
    );
  });
}
