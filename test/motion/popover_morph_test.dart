import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  bool? open,
  ValueChanged<bool>? onOpenChange,
  bool defaultOpen = false,
  BeuiMorphPopoverSide side = BeuiMorphPopoverSide.bottom,
  BeuiMorphPopoverAlign align = BeuiMorphPopoverAlign.end,
  bool reduce = false,
}) {
  Widget body = Center(
    child: BeuiMorphPopover(
      open: open,
      defaultOpen: defaultOpen,
      onOpenChange: onOpenChange,
      side: side,
      align: align,
      content: const SizedBox(
        width: 180,
        height: 120,
        child: Center(child: Text('Panel body')),
      ),
      child: const SizedBox(
        width: 120,
        height: 40,
        child: Center(child: Text('Trigger')),
      ),
    ),
  );
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
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: body),
  );
}

void main() {
  testWidgets('tap toggles open via onOpenChange (uncontrolled)', (
    tester,
  ) async {
    final changes = <bool>[];
    await tester.pumpWidget(_app(onOpenChange: changes.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();
    expect(changes.last, isTrue);
    expect(find.text('Panel body'), findsWidgets);
  });

  testWidgets('controlled open renders the panel content', (tester) async {
    await tester.pumpWidget(_app(open: true));
    await tester.pumpAndSettle();
    expect(find.text('Panel body'), findsWidgets);
  });

  testWidgets('defaultOpen seeds the uncontrolled open state', (tester) async {
    await tester.pumpWidget(_app(defaultOpen: true));
    await tester.pumpAndSettle();
    expect(find.text('Panel body'), findsWidgets);
  });

  testWidgets('Escape closes the popover', (tester) async {
    final changes = <bool>[];
    await tester.pumpWidget(_app(defaultOpen: true, onOpenChange: changes.add));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(changes.last, isFalse);
  });

  testWidgets('motion: panel morphs open through a clip (ClipRRect present)', (
    tester,
  ) async {
    await tester.pumpWidget(_app(open: true));
    // Mid-open frame: the morph clip is mounted while the spring runs.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      find.descendant(
        of: find.byType(BeuiMorphPopover),
        matching: find.byType(ClipRRect),
      ),
      findsWidgets,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('motion: panel scales up while opening (Transform present)', (
    tester,
  ) async {
    await tester.pumpWidget(_app(open: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // The scale morph is only present when NOT reduced.
    expect(
      find.descendant(
        of: find.byType(BeuiMorphPopover),
        matching: find.byType(Transform),
      ),
      findsWidgets,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion drops the scale Transform, keeps opacity', (
    tester,
  ) async {
    await tester.pumpWidget(_app(open: true, reduce: true));
    await tester.pumpAndSettle();
    // Panel still visible (opacity kept)...
    expect(find.text('Panel body'), findsWidgets);
    // ...but the morph's scale Transform is not applied under reduced motion.
    // Transform.scale renders a Transform; without it the panel is un-scaled.
    final transforms = tester.widgetList<Transform>(
      find.descendant(
        of: find.byType(BeuiMorphPopover),
        matching: find.byType(Transform),
      ),
    );
    for (final t in transforms) {
      // No scaling component (identity on the diagonal) under reduced motion.
      expect(t.transform.entry(0, 0), 1.0);
      expect(t.transform.entry(1, 1), 1.0);
    }
  });

  testWidgets('open-state golden', (tester) async {
    await tester.pumpWidget(_app(open: true));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiMorphPopover),
      matchesGoldenFile('goldens/beui_popover_morph.png'),
    );
  });
}
