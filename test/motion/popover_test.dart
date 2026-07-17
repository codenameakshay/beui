import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  bool? open,
  ValueChanged<bool>? onOpenChange,
  bool reduce = false,
}) {
  Widget body = Center(
    child: BeuiPopover(
      open: open,
      onOpenChange: onOpenChange,
      content: const Text('Panel body'),
      child: const SizedBox(
        width: 120,
        height: 44,
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

  testWidgets('reduced motion drops the goo ImageFiltered layer', (
    tester,
  ) async {
    await tester.pumpWidget(_app(open: true, reduce: true));
    await tester.pumpAndSettle();
    // The goo filter is skipped under reduced motion.
    expect(
      find.descendant(
        of: find.byType(BeuiPopover),
        matching: find.byType(ImageFiltered),
      ),
      findsNothing,
    );
  });

  testWidgets('open-state golden', (tester) async {
    await tester.pumpWidget(_app(open: true));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiPopover),
      matchesGoldenFile('goldens/beui_popover.png'),
    );
  });
}
