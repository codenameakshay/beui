import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: body),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Create'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 700));
}

double _maxBlurSigma(WidgetTester tester) => tester
    .widgetList<ImageFiltered>(find.byType(ImageFiltered))
    .map((f) {
      final m = RegExp(r'blur\(([\d.]+)').firstMatch(f.imageFilter.toString());
      return m == null ? 0.0 : double.parse(m.group(1)!);
    })
    .fold<double>(0, math.max);

void main() {
  group('BeuiCreateMenu', () {
    testWidgets('renders the trigger; menu closed by default', (tester) async {
      await tester.pumpWidget(_wrap(const BeuiCreateMenu()));
      await tester.pumpAndSettle();
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Doc'), findsNothing); // default item hidden
    });

    testWidgets('tapping the trigger blooms the grid menu', (tester) async {
      await tester.pumpWidget(_wrap(const BeuiCreateMenu()));
      await tester.pumpAndSettle();
      await _open(tester);
      // Default items (source ITEMS).
      expect(find.text('Doc'), findsOneWidget);
      expect(find.text('Board'), findsOneWidget);
      expect(find.text('Reminder'), findsOneWidget);
      expect(find.byIcon(LucideIcons.x), findsOneWidget); // header close
    });

    testWidgets('selecting an item reports and closes', (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(_wrap(BeuiCreateMenu(onSelect: selected.add)));
      await tester.pumpAndSettle();
      await _open(tester);
      await tester.tap(find.text('Table'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(selected, ['Table']);
      expect(find.text('Doc'), findsNothing);
    });

    testWidgets('the header close button folds the menu', (tester) async {
      await tester.pumpWidget(_wrap(const BeuiCreateMenu()));
      await tester.pumpAndSettle();
      await _open(tester);
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Doc'), findsNothing);
    });

    testWidgets('Escape closes', (tester) async {
      await tester.pumpWidget(_wrap(const BeuiCreateMenu()));
      await tester.pumpAndSettle();
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Doc'), findsNothing);
    });

    testWidgets('tapping outside closes', (tester) async {
      await tester.pumpWidget(_wrap(const BeuiCreateMenu()));
      await tester.pumpAndSettle();
      await _open(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Doc'), findsNothing);
    });

    testWidgets('custom items replace the defaults', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BeuiCreateMenu(
            items: [
              BeuiCreateMenuItem(label: 'Note', icon: LucideIcons.file_text),
              BeuiCreateMenuItem(label: 'Event', icon: LucideIcons.bell),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _open(tester);
      expect(find.text('Note'), findsOneWidget);
      expect(find.text('Event'), findsOneWidget);
      expect(find.text('Doc'), findsNothing);
    });

    testWidgets('reduced motion opens with no blur', (tester) async {
      await tester.pumpWidget(_wrap(const BeuiCreateMenu(), reduce: true));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Create'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        expect(_maxBlurSigma(tester), lessThan(0.5));
      }
      expect(find.text('Doc'), findsOneWidget);
    });
  });
}
