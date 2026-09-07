import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

Widget _app({
  ValueChanged<String>? onSelect,
  String triggerLabel = 'Create',
  bool reduce = false,
}) => beuiTestApp(
  BeuiBloomMenu(onSelect: onSelect, triggerLabel: triggerLabel),
  reduce: reduce,
);

/// Opens the menu and lets the bloom choreography settle (the overlay renders
/// in the root overlay, so explicit pumps are used instead of pumpAndSettle).
Future<void> _open(WidgetTester tester, {String label = 'Create'}) async {
  await tester.tap(find.text(label).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 800));
}

Future<void> _drainClose(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 800));
}

void main() {
  group('BeuiBloomMenu', () {
    testWidgets('renders the trigger; menu closed by default', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Doc'), findsNothing); // default item hidden
    });

    testWidgets('the collapsed pill shrink-wraps instead of filling a loose '
        'parent', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final size = tester.getSize(find.byType(BeuiBloomMenu));
      expect(size.height, 44); // h-11
      // w-36 (144) at the default label; the test font is wider than the real
      // one, so pin the property that matters: it never goes full-bleed.
      expect(size.width, greaterThanOrEqualTo(144));
      expect(size.width, lessThan(240));
    });

    testWidgets('tapping the trigger blooms the grid menu', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _open(tester);
      // Default items (source ITEMS).
      expect(find.text('Doc'), findsOneWidget);
      expect(find.text('Board'), findsOneWidget);
      expect(find.text('Link'), findsOneWidget);
      expect(find.byIcon(LucideIcons.x), findsOneWidget); // header close
    });

    testWidgets('triggerLabel drives BOTH the pill and the panel header', (
      tester,
    ) async {
      await tester.pumpWidget(_app(triggerLabel: 'Blueprint'));
      await tester.pumpAndSettle();
      // Collapsed pill uses the custom label.
      expect(find.text('Blueprint'), findsOneWidget);

      await _open(tester, label: 'Blueprint');
      // The open panel header shows the same label — the header must NOT fall
      // back to the old hardcoded 'Create'.
      expect(find.text('Create'), findsNothing);
      expect(find.text('Blueprint'), findsWidgets);
    });

    testWidgets('selecting an item reports and closes', (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(_app(onSelect: selected.add));
      await tester.pumpAndSettle();
      await _open(tester);
      await tester.tap(find.text('Board'));
      await _drainClose(tester);
      expect(selected, ['Board']);
      expect(find.text('Doc'), findsNothing);
    });

    testWidgets('the header close button folds the menu', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _open(tester);
      await tester.tap(find.byIcon(LucideIcons.x));
      await _drainClose(tester);
      expect(find.text('Doc'), findsNothing);
    });

    testWidgets('Escape closes', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _drainClose(tester);
      expect(find.text('Doc'), findsNothing);
    });

    testWidgets('tapping outside closes', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await _open(tester);
      await tester.tapAt(const Offset(5, 5));
      await _drainClose(tester);
      expect(find.text('Doc'), findsNothing);
    });

    testWidgets('reduced motion opens with no blur', (tester) async {
      await tester.pumpWidget(_app(reduce: true));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Create').first);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        expect(maxBlurSigma(tester), lessThan(0.5));
      }
      expect(find.text('Doc'), findsOneWidget);
    });
  });
}
