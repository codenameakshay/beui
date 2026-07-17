import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({
  ValueChanged<String>? onSelect,
  String triggerLabel = 'Create',
  bool reduce = false,
}) {
  Widget body = Center(
    child: BeuiBloomMenu(onSelect: onSelect, triggerLabel: triggerLabel),
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

double _maxBlurSigma(WidgetTester tester) => tester
    .widgetList<ImageFiltered>(find.byType(ImageFiltered))
    .map((f) {
      final m = RegExp(r'blur\(([\d.]+)').firstMatch(f.imageFilter.toString());
      return m == null ? 0.0 : double.parse(m.group(1)!);
    })
    .fold<double>(0, math.max);

void main() {
  group('BeuiBloomMenu', () {
    testWidgets('renders the trigger; menu closed by default', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Doc'), findsNothing); // default item hidden
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

    testWidgets('default item set has six entries', (tester) async {
      expect(beuiDefaultBloomMenuItems, hasLength(6));
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
        expect(_maxBlurSigma(tester), lessThan(0.5));
      }
      expect(find.text('Doc'), findsOneWidget);
    });
  });
}
