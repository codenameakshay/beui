import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({ValueChanged<String>? onSelect}) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(
      body: Center(child: BeuiBloomMenu(onSelect: onSelect)),
    ),
  );
}

void main() {
  testWidgets('tapping the trigger opens the grid', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    // Collapsed: the "Create" trigger label is shown, grid items are not.
    expect(find.text('Doc'), findsNothing);

    await tester.tap(find.text('Create').first);
    await tester.pumpAndSettle();
    expect(find.text('Doc'), findsOneWidget);
    expect(find.text('Link'), findsOneWidget);
  });

  testWidgets('selecting an item reports and closes', (tester) async {
    String? picked;
    await tester.pumpWidget(_app(onSelect: (v) => picked = v));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Board'));
    await tester.pumpAndSettle();
    expect(picked, 'Board');
    // Closed again — grid gone.
    expect(find.text('Board'), findsNothing);
  });

  testWidgets('default item set has six entries', (tester) async {
    expect(beuiDefaultBloomMenuItems, hasLength(6));
  });

  testWidgets('open-state golden', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create').first);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiBloomMenu),
      matchesGoldenFile('goldens/beui_bloom_menu.png'),
    );
  });
}
