import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

List<BeuiTodoItem> _sample({
  BeuiTodoItemStatus a = BeuiTodoItemStatus.pending,
  BeuiTodoItemStatus b = BeuiTodoItemStatus.pending,
  BeuiTodoItemStatus c = BeuiTodoItemStatus.pending,
  double? aProgress,
}) {
  return [
    BeuiTodoItem(
      id: 'a',
      title: const Text('Inspect the current data flow'),
      status: a,
      progress: aProgress,
      detail: aProgress != null ? Text('${aProgress.round()}%') : null,
    ),
    BeuiTodoItem(
      id: 'b',
      title: const Text('Update the response schema'),
      status: b,
    ),
    BeuiTodoItem(
      id: 'c',
      title: const Text('Add coverage for edge cases'),
      status: c,
    ),
  ];
}

Widget _host({
  required List<BeuiTodoItem> items,
  Widget? title,
  bool? open,
  bool defaultOpen = true,
  ValueChanged<bool>? onOpenChange,
  bool collapseOnComplete = true,
  bool reduce = false,
}) {
  Widget child = Center(
    child: SizedBox(
      width: 360,
      child: BeuiTodoList(
        items: items,
        title: title,
        open: open,
        defaultOpen: defaultOpen,
        onOpenChange: onOpenChange,
        collapseOnComplete: collapseOnComplete,
      ),
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

void main() {
  group('BeuiTodoList', () {
    testWidgets('renders title, count, and task rows', (tester) async {
      await tester.pumpWidget(
        _host(
          items: _sample(a: BeuiTodoItemStatus.completed),
          title: const Text('Implementation plan'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Implementation plan'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // completed numerator
      expect(find.text('/3'), findsOneWidget);
      expect(find.text('Inspect the current data flow'), findsOneWidget);
      expect(find.text('Update the response schema'), findsOneWidget);
      expect(find.text('Add coverage for edge cases'), findsOneWidget);
    });

    testWidgets('empty state shows "No tasks yet"', (tester) async {
      await tester.pumpWidget(_host(items: const []));
      await tester.pumpAndSettle();
      expect(find.text('No tasks yet'), findsOneWidget);
      expect(find.text('/0'), findsOneWidget);
    });

    testWidgets('tapping header toggles open state (uncontrolled)', (
      tester,
    ) async {
      await tester.pumpWidget(_host(items: _sample(), defaultOpen: true));
      await tester.pumpAndSettle();
      expect(find.text('Inspect the current data flow'), findsOneWidget);

      await tester.tap(find.text('To-dos'));
      await tester.pumpAndSettle();
      // Collapsed disclosure clips content out of hit-test / visibility.
      expect(find.text('Inspect the current data flow'), findsNothing);

      await tester.tap(find.text('To-dos'));
      await tester.pumpAndSettle();
      expect(find.text('Inspect the current data flow'), findsOneWidget);
    });

    testWidgets('controlled open reports onOpenChange', (tester) async {
      var open = true;
      final calls = <bool>[];

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _host(
              items: _sample(),
              open: open,
              onOpenChange: (v) {
                calls.add(v);
                setState(() => open = v);
              },
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('To-dos'));
      await tester.pumpAndSettle();
      expect(calls, [false]);
      expect(find.text('Inspect the current data flow'), findsNothing);

      await tester.tap(find.text('To-dos'));
      await tester.pumpAndSettle();
      expect(calls, [false, true]);
    });

    testWidgets('collapseOnComplete auto-collapses when all done', (
      tester,
    ) async {
      // Determinate progress avoids an infinite spin (which hangs pumpAndSettle).
      var items = const [
        BeuiTodoItem(
          id: 'a',
          title: Text('Inspect the current data flow'),
          status: BeuiTodoItemStatus.completed,
        ),
        BeuiTodoItem(
          id: 'b',
          title: Text('Update the response schema'),
          status: BeuiTodoItemStatus.completed,
        ),
        BeuiTodoItem(
          id: 'c',
          title: Text('Add coverage for edge cases'),
          status: BeuiTodoItemStatus.inProgress,
          progress: 75,
        ),
      ];

      await tester.pumpWidget(_host(items: items, collapseOnComplete: true));
      await tester.pumpAndSettle();
      expect(find.text('Add coverage for edge cases'), findsOneWidget);

      // Complete the last task — list should auto-collapse.
      items = _sample(
        a: BeuiTodoItemStatus.completed,
        b: BeuiTodoItemStatus.completed,
        c: BeuiTodoItemStatus.completed,
      );
      await tester.pumpWidget(_host(items: items, collapseOnComplete: true));
      await tester.pumpAndSettle();
      expect(find.text('Add coverage for edge cases'), findsNothing);
    });

    testWidgets('collapseOnComplete: false keeps panel open when done', (
      tester,
    ) async {
      final items = _sample(
        a: BeuiTodoItemStatus.completed,
        b: BeuiTodoItemStatus.completed,
        c: BeuiTodoItemStatus.completed,
      );
      await tester.pumpWidget(
        _host(items: items, collapseOnComplete: false, defaultOpen: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inspect the current data flow'), findsOneWidget);
    });

    testWidgets('completion count updates as status changes', (tester) async {
      var items = _sample();
      await tester.pumpWidget(
        StatefulBuilder(builder: (context, setState) => _host(items: items)),
      );
      await tester.pumpAndSettle();
      expect(find.text('0'), findsOneWidget);
      expect(find.text('/3'), findsOneWidget);

      items = _sample(
        a: BeuiTodoItemStatus.completed,
        b: BeuiTodoItemStatus.completed,
      );
      await tester.pumpWidget(_host(items: items));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(find.text('/3'), findsOneWidget);
    });

    testWidgets('in-progress detail metadata is shown', (tester) async {
      await tester.pumpWidget(
        _host(items: _sample(a: BeuiTodoItemStatus.inProgress, aProgress: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('reduced motion still toggles and shows content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(items: _sample(), reduce: true, defaultOpen: true),
      );
      await tester.pump(); // no settle — reduced snaps
      expect(find.text('Inspect the current data flow'), findsOneWidget);

      await tester.tap(find.text('To-dos'));
      await tester.pump();
      expect(find.text('Inspect the current data flow'), findsNothing);
    });

    testWidgets('keyboard ActivateIntent toggles the header', (tester) async {
      await tester.pumpWidget(_host(items: _sample(), defaultOpen: true));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Inspect the current data flow'), findsNothing);
    });

    testWidgets('status morph keeps the same row identity', (tester) async {
      var items = _sample(a: BeuiTodoItemStatus.pending);
      await tester.pumpWidget(_host(items: items));
      await tester.pumpAndSettle();

      items = _sample(a: BeuiTodoItemStatus.inProgress, aProgress: 25);
      await tester.pumpWidget(_host(items: items));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Inspect the current data flow'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);

      items = _sample(a: BeuiTodoItemStatus.completed);
      await tester.pumpWidget(_host(items: items));
      await tester.pumpAndSettle();
      expect(find.text('Inspect the current data flow'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('cancelled status is accepted without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          items: [
            const BeuiTodoItem(
              id: 'x',
              title: Text('Skipped task'),
              status: BeuiTodoItemStatus.cancelled,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Skipped task'), findsOneWidget);
    });

    testWidgets('the completion strike spans the title, not the whole row', (
      tester,
    ) async {
      // A deliberately short title: the test font is far wider than Geist, so
      // a realistic sentence would fill the row and ellipsize, making the
      // strike legitimately full-width and the assertion meaningless.
      await tester.pumpWidget(
        _host(
          items: const [
            BeuiTodoItem(
              id: 'a',
              title: Text('Done'),
              status: BeuiTodoItemStatus.completed,
            ),
          ],
          collapseOnComplete: false,
        ),
      );
      await tester.pumpAndSettle();

      // The rule is drawn with `Positioned.fill` over the title's Stack, so
      // that Stack must shrink-wrap the glyphs. Under a bare Expanded the
      // Stack was handed a tight full-row width and the rule ran well past the
      // end of the text; beui.dev strikes only the title.
      final strike = tester
          .getSize(
            find
                .ancestor(of: find.text('Done'), matching: find.byType(Stack))
                .first,
          )
          .width;
      final row = tester.getSize(find.byType(BeuiTodoList)).width;

      expect(strike, lessThan(row / 2));
    });
  });
}
