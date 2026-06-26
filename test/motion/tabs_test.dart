import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _indicator = ValueKey<String>('beui_tabs_indicator');

Widget _app({
  String? value,
  String? defaultValue,
  ValueChanged<String>? onChanged,
  BeuiTabsVariant variant = BeuiTabsVariant.pill,
  bool reduce = false,
  bool withContent = false,
}) {
  Widget child = Align(
    alignment: Alignment.topLeft,
    child: BeuiTabs<String>(
      key: const ValueKey('tabs'),
      value: value,
      defaultValue: defaultValue,
      onChanged: onChanged,
      variant: variant,
      tabs: [
        BeuiTab(
          value: 'one',
          label: const Text('One'),
          content: withContent ? const Text('content One') : null,
        ),
        BeuiTab(
          value: 'two',
          label: const Text('Two'),
          content: withContent ? const Text('content Two') : null,
        ),
        BeuiTab(
          value: 'three',
          label: const Text('Three'),
          content: withContent ? const Text('content Three') : null,
        ),
      ],
    ),
  );
  if (reduce) {
    final inner = child;
    child = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: child),
  );
}

double _indicatorX(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(_indicator)).dx;

void main() {
  group('BeuiTabs interaction', () {
    testWidgets('tap selects via onChanged (controlled)', (tester) async {
      String? changed;
      await tester.pumpWidget(_app(value: 'one', onChanged: (v) => changed = v));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Two'));
      await tester.pump();
      expect(changed, 'two');
    });

    testWidgets('Enter activates the focused tab', (tester) async {
      String? changed;
      await tester.pumpWidget(_app(value: 'one', onChanged: (v) => changed = v));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(changed, isNotNull);
    });

    testWidgets('arrow key moves selection to the next tab', (tester) async {
      String? changed;
      await tester.pumpWidget(_app(value: 'one', onChanged: (v) => changed = v));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(changed, 'two');
    });

    testWidgets('arrow-left from the first tab wraps to the last', (tester) async {
      String? changed;
      await tester.pumpWidget(_app(value: 'one', onChanged: (v) => changed = v));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(changed, 'three');
    });
  });

  group('BeuiTabs content', () {
    testWidgets('shows the active panel and swaps on selection', (tester) async {
      await tester.pumpWidget(_app(defaultValue: 'one', withContent: true));
      await tester.pumpAndSettle();
      expect(find.text('content One'), findsOneWidget);
      expect(find.text('content Two'), findsNothing);

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(find.text('content Two'), findsOneWidget);
      expect(find.text('content One'), findsNothing);
    });
  });

  group('BeuiTabs semantics', () {
    testWidgets('active tab is selected, others are not', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(value: 'two'));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.text('Two')),
          isSemantics(isSelected: true, isButton: true));
      expect(tester.getSemantics(find.text('One')),
          isSemantics(isSelected: false));
      handle.dispose();
    });
  });

  group('BeuiTabs variants', () {
    for (final variant in BeuiTabsVariant.values) {
      testWidgets('renders an indicator for $variant', (tester) async {
        await tester.pumpWidget(_app(value: 'one', variant: variant));
        await tester.pumpAndSettle();
        expect(find.byKey(_indicator), findsOneWidget);
      });
    }
  });

  group('BeuiTabs motion fidelity', () {
    testWidgets('indicator glides between tabs under normal motion',
        (tester) async {
      await tester.pumpWidget(_app(value: 'one'));
      await tester.pumpAndSettle();
      final x1 = _indicatorX(tester);

      await tester.pumpWidget(_app(value: 'three'));
      await tester.pump(); // post-frame measure retargets
      await tester.pump(const Duration(milliseconds: 40));
      final xMid = _indicatorX(tester);
      await tester.pumpAndSettle();
      final x3 = _indicatorX(tester);

      expect(xMid, greaterThan(x1));
      expect(xMid, lessThan(x3));
      expect(x3, greaterThan(x1));
    });

    testWidgets('indicator snaps under reduced motion', (tester) async {
      await tester.pumpWidget(_app(value: 'one', reduce: true));
      await tester.pumpAndSettle();
      final x1 = _indicatorX(tester);

      await tester.pumpWidget(_app(value: 'three', reduce: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      final xImmediate = _indicatorX(tester);
      await tester.pumpAndSettle();
      final x3 = _indicatorX(tester);

      expect(x3, greaterThan(x1));
      expect(xImmediate, closeTo(x3, 0.5));
    });
  });

  testWidgets('rest-state golden (all three variants)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VariantRow(BeuiTabsVariant.pill),
                SizedBox(height: 20),
                _VariantRow(BeuiTabsVariant.segment),
                SizedBox(height: 20),
                _VariantRow(BeuiTabsVariant.underline),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Column).first,
      matchesGoldenFile('goldens/beui_tabs.png'),
    );
  });
}

class _VariantRow extends StatelessWidget {
  const _VariantRow(this.variant);
  final BeuiTabsVariant variant;

  @override
  Widget build(BuildContext context) {
    return BeuiTabs<String>(
      defaultValue: 'two',
      variant: variant,
      tabs: const [
        BeuiTab(value: 'one', label: Text('Overview')),
        BeuiTab(value: 'two', label: Text('Activity')),
        BeuiTab(value: 'three', label: Text('Settings')),
      ],
    );
  }
}
