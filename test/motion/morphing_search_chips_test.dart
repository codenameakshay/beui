import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beui/beui.dart';
import '../support.dart';

void main() {
  testWidgets('closed rest state matches golden', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiMorphingSearchChips(
          defaultChips: ['onboarding'],
          placeholder: 'Search inspiration',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiMorphingSearchChips),
      matchesGoldenFile('goldens/beui_morphing_search_chips.png'),
    );
  });

  testWidgets('Enter adds a query chip and Backspace removes it in two steps', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiMorphingSearchChips(defaultRecents: ['dashboards']),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'pricing');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('pricing'), findsWidgets);
    await tester.enterText(find.byType(TextField), '');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('shows matching suggestions and honors maxChips', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiMorphingSearchChips(
          defaultChips: ['existing'],
          maxChips: 1,
          suggestions: ['dark mode', 'dashboards'],
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'dark');
    await tester.pumpAndSettle();
    expect(find.text('dark mode'), findsOneWidget);
    await tester.tap(find.text('dark mode'));
    await tester.pump();
    expect(find.byType(Chip), findsOneWidget);
  });

  testWidgets('recent terms persist in process by storageKey', (tester) async {
    const key = 'morph-search-test-recent-store';
    await tester.pumpWidget(
      beuiTestApp(const BeuiMorphingSearchChips(storageKey: key)),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'shared term');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pumpWidget(beuiTestApp(const SizedBox.shrink()));
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiMorphingSearchChips(storageKey: key, defaultOpen: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('shared term'), findsOneWidget);
  });

  testWidgets('reduced motion preserves add and remove interactions', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiMorphingSearchChips(defaultRecents: ['empty states']),
        reduce: true,
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.text('empty states'), findsOneWidget);
    await tester.tap(find.text('empty states'));
    await tester.pump();
    expect(find.byType(Chip), findsOneWidget);
  });
}
