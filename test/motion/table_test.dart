import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Row = Map<String, String>;

final List<_Row> _people = [
  {'id': '1', 'name': 'Ava', 'role': 'Owner', 'mrr': '300'},
  {'id': '2', 'name': 'Leo', 'role': 'Admin', 'mrr': '120'},
  {'id': '3', 'name': 'Mia', 'role': 'Member', 'mrr': '210'},
];

List<BeuiTableColumn<_Row>> _columns({bool editable = false}) => [
  BeuiTableColumn(
    key: 'name',
    header: 'Name',
    sortable: true,
    value: (r) => r['name'] ?? '',
    editable: editable,
  ),
  BeuiTableColumn(
    key: 'role',
    header: 'Role',
    value: (r) => r['role'] ?? '',
    editable: editable,
  ),
  BeuiTableColumn(
    key: 'mrr',
    header: 'MRR',
    sortable: true,
    align: BeuiTableAlign.right,
    value: (r) => r['mrr'] ?? '',
    sortValue: (r) => int.parse(r['mrr'] ?? '0'),
  ),
];

Widget _app({
  required List<_Row> data,
  required List<BeuiTableColumn<_Row>> columns,
  bool selectable = false,
  bool resizable = false,
  bool reorderable = false,
  bool loading = false,
  List<String>? selectedRowIds,
  ValueChanged<List<String>>? onSelectionChange,
  ValueChanged<BeuiSortState?>? onSortChange,
  void Function(String, String, String)? onCellEdit,
  void Function(int, BeuiTableInsertPosition)? onInsertRow,
  void Function(String, int)? onDeleteRow,
  VoidCallback? onEndReached,
  bool reduce = false,
}) {
  Widget table = BeuiTable<_Row>(
    data: data,
    columns: columns,
    getRowId: (r, _) => r['id'] ?? '',
    selectable: selectable,
    resizable: resizable,
    reorderable: reorderable,
    loading: loading,
    selectedRowIds: selectedRowIds,
    onSelectionChange: onSelectionChange,
    onSortChange: onSortChange,
    onCellEdit: onCellEdit,
    onInsertRow: onInsertRow,
    onDeleteRow: onDeleteRow,
    onEndReached: onEndReached,
    height: 320,
    rowHeight: 48,
  );
  if (reduce) {
    final inner = table;
    table = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(24), child: table),
    ),
  );
}

void main() {
  group('BeuiTable rendering', () {
    testWidgets('renders headers and cells', (tester) async {
      await tester.pumpWidget(_app(data: _people, columns: _columns()));
      await tester.pumpAndSettle();
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Role'), findsOneWidget);
      expect(find.text('Ava'), findsOneWidget);
      expect(find.text('Leo'), findsOneWidget);
    });

    testWidgets('empty state shows when no rows and not loading', (
      tester,
    ) async {
      await tester.pumpWidget(_app(data: const [], columns: _columns()));
      await tester.pumpAndSettle();
      expect(find.text('No data'), findsOneWidget);
    });
  });

  group('BeuiTable selection', () {
    testWidgets('row checkbox toggles via onSelectionChange', (tester) async {
      List<String>? changed;
      await tester.pumpWidget(
        _app(
          data: _people,
          columns: _columns(),
          selectable: true,
          selectedRowIds: const [],
          onSelectionChange: (ids) => changed = ids,
        ),
      );
      await tester.pumpAndSettle();
      // 3 rows + 1 header select-all = 4 checkboxes.
      expect(find.byType(BeuiCheckbox), findsNWidgets(4));
      await tester.tap(find.byType(BeuiCheckbox).at(1));
      await tester.pump();
      expect(changed, isNotNull);
      expect(changed, contains('1'));
    });

    testWidgets('select-all header selects every row', (tester) async {
      List<String>? changed;
      await tester.pumpWidget(
        _app(
          data: _people,
          columns: _columns(),
          selectable: true,
          selectedRowIds: const [],
          onSelectionChange: (ids) => changed = ids,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BeuiCheckbox).first);
      await tester.pump();
      expect(changed, containsAll(<String>['1', '2', '3']));
    });
  });

  group('BeuiTable sort', () {
    testWidgets('tapping a sortable header cycles asc -> desc -> clear', (
      tester,
    ) async {
      final events = <BeuiSortState?>[];
      await tester.pumpWidget(
        _app(data: _people, columns: _columns(), onSortChange: events.add),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('MRR'));
      await tester.pumpAndSettle();
      expect(events.last?.direction, BeuiSortDirection.asc);

      await tester.tap(find.text('MRR'));
      await tester.pumpAndSettle();
      expect(events.last?.direction, BeuiSortDirection.desc);

      await tester.tap(find.text('MRR'));
      await tester.pumpAndSettle();
      expect(events.last, isNull);
    });

    testWidgets('ascending sort reorders rows (Leo 120 first)', (tester) async {
      await tester.pumpWidget(_app(data: _people, columns: _columns()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MRR'));
      await tester.pumpAndSettle();

      final ava = tester.getTopLeft(find.text('Ava')).dy;
      final leo = tester.getTopLeft(find.text('Leo')).dy;
      // Leo (120) should sort above Ava (300) ascending.
      expect(leo, lessThan(ava));
    });

    testWidgets('string sort folds case like localeCompare (apple < Zebra)', (
      tester,
    ) async {
      final data = <_Row>[
        {'id': '1', 'name': 'Zebra', 'role': 'x', 'mrr': '0'},
        {'id': '2', 'name': 'apple', 'role': 'y', 'mrr': '0'},
      ];
      await tester.pumpWidget(_app(data: data, columns: _columns()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();

      final apple = tester.getTopLeft(find.text('apple')).dy;
      final zebra = tester.getTopLeft(find.text('Zebra')).dy;
      // Case-insensitive ascending: 'apple' above 'Zebra'. A raw code-unit
      // compare would wrongly put 'Zebra' (Z=85) before 'apple' (a=97).
      expect(apple, lessThan(zebra));
    });

    testWidgets('sort is stable: ties keep their original order', (
      tester,
    ) async {
      // Every row shares an MRR, so a stable sort must preserve input order —
      // Dart's `List.sort` is an unstable introsort and would shuffle these.
      final tied = [
        for (var i = 0; i < 24; i++)
          {'id': '$i', 'name': 'P$i', 'role': 'Member', 'mrr': '100'},
      ];
      await tester.pumpWidget(
        _app(data: tied, columns: _columns(), onSortChange: (_) {}),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('MRR'));
      await tester.pumpAndSettle();

      final names = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where((s) => s.startsWith('P'))
          .toList();
      expect(names.take(3).toList(), ['P0', 'P1', 'P2']);
    });
  });

  group('BeuiTable editable', () {
    testWidgets('editable cell edits fire onCellEdit', (tester) async {
      final edits = <String>[];
      await tester.pumpWidget(
        _app(
          data: _people,
          columns: _columns(editable: true),
          onCellEdit: (rowId, key, value) => edits.add('$rowId.$key=$value'),
        ),
      );
      await tester.pumpAndSettle();
      // Editable columns render inline text fields.
      expect(find.byType(TextField), findsWidgets);
      await tester.enterText(find.byType(TextField).first, 'Zed');
      await tester.pump();
      expect(edits.any((e) => e.endsWith('=Zed')), isTrue);
    });
  });

  group('BeuiTable async / skeleton', () {
    testWidgets('loading with no rows shows pulsing skeletons', (tester) async {
      await tester.pumpWidget(
        _app(data: const [], columns: _columns(), loading: true),
      );
      await tester.pump();
      // Skeletons pulse via an opacity AnimatedBuilder; no empty-state text.
      expect(find.text('No data'), findsNothing);
      expect(find.byType(FractionallySizedBox), findsWidgets);
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('BeuiTable motion fidelity', () {
    testWidgets('reorder drag lifts the header cell on a spring (scale)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(data: _people, columns: _columns(), reorderable: true),
      );
      await tester.pumpAndSettle();

      final grip = find.byIcon(LucideIcons.grip_vertical).first;
      final gesture = await tester.startGesture(tester.getCenter(grip));
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0));
      // Mid-spring: SPRING_PRESS is still easing the dragged header toward
      // its 1.04 lift target.
      await tester.pump(const Duration(milliseconds: 40));

      final scales = tester
          .widgetList<Transform>(
            find.descendant(
              of: find.byType(BeuiTable<_Row>),
              matching: find.byType(Transform),
            ),
          )
          .map((t) => t.transform.entry(0, 0));
      expect(
        scales,
        anyElement(greaterThan(1.0)),
        reason: 'the dragged header must lift on a scale spring',
      );

      await gesture.up();
      await tester.pumpAndSettle();

      // Released and settled: nothing stays scaled up.
      for (final s
          in tester
              .widgetList<Transform>(
                find.descendant(
                  of: find.byType(BeuiTable<_Row>),
                  matching: find.byType(Transform),
                ),
              )
              .map((t) => t.transform.entry(0, 0))) {
        expect(s, closeTo(1.0, 0.01));
      }
    });

    testWidgets('sort arrow animates with a rotation under normal motion', (
      tester,
    ) async {
      await tester.pumpWidget(_app(data: _people, columns: _columns()));
      await tester.pumpAndSettle();

      final before = tester
          .widgetList<AnimatedRotation>(find.byType(AnimatedRotation))
          .map((r) => r.turns)
          .toList();
      expect(before, everyElement(0.0), reason: 'no column is sorted yet');

      // asc, then desc — the arrow rotates to 0.5 turns only when desc.
      await tester.tap(find.text('MRR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MRR'));
      await tester.pumpAndSettle();

      final after = tester
          .widgetList<AnimatedRotation>(find.byType(AnimatedRotation))
          .map((r) => r.turns);
      expect(after.where((t) => t == 0.5), hasLength(1));
    });

    testWidgets('reduced motion drops the reorder scale animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          data: _people,
          columns: _columns(),
          reorderable: true,
          reduce: true,
        ),
      );
      await tester.pumpAndSettle();

      final grip = find.byIcon(LucideIcons.grip_vertical).first;
      final gesture = await tester.startGesture(tester.getCenter(grip));
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();

      // No scaling component (identity on the diagonal) under reduced motion —
      // the lift is opacity-only.
      for (final s
          in tester
              .widgetList<Transform>(
                find.descendant(
                  of: find.byType(BeuiTable<_Row>),
                  matching: find.byType(Transform),
                ),
              )
              .map((t) => t.transform.entry(0, 0))) {
        expect(s, 1.0);
      }

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('BeuiTable row handle', () {
    testWidgets('handle appears on row hover and survives the 100ms grace', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          data: _people,
          columns: _columns(),
          onInsertRow: (_, _) {},
          onDeleteRow: (_, _) {},
        ),
      );
      await tester.pumpAndSettle();

      final handleIcon = find.byIcon(LucideIcons.ellipsis_vertical);
      expect(handleIcon, findsNothing);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      // Hover a data row: the left-edge handle mounts.
      await gesture.moveTo(tester.getCenter(find.text('Ava')));
      await tester.pump();
      expect(handleIcon, findsOneWidget);

      // Leave the row entirely: within the 100ms grace the handle stays
      // reachable (the bug was it unmounting the instant the row was left).
      await gesture.moveTo(const Offset(2, 2));
      await tester.pump();
      expect(handleIcon, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      expect(handleIcon, findsOneWidget);

      // Past the grace window it finally unmounts.
      await tester.pump(const Duration(milliseconds: 80));
      expect(handleIcon, findsNothing);
    });
  });

  group('BeuiTable chrome', () {
    testWidgets('row rule scales the border token alpha, never replaces it', (
      tester,
    ) async {
      await tester.pumpWidget(_app(data: _people, columns: _columns()));
      await tester.pumpAndSettle();

      final border = BeuiColors.light().border;
      // `border-border/60` == 60% *of* the token's own alpha.
      final expected = border.a * 0.6;

      final rules = <double>[
        for (final c in tester.widgetList<Container>(find.byType(Container)))
          if (c.decoration case final BoxDecoration d)
            if (d.border case final Border b)
              if (b.bottom.style == BorderStyle.solid &&
                  b.bottom.color.a > 0 &&
                  b.bottom.color.a < border.a)
                b.bottom.color.a,
      ];
      expect(rules, isNotEmpty);
      for (final a in rules) {
        expect(a, closeTo(expected, 0.001));
      }
    });
  });

  testWidgets('rest-state golden (data table with selection + sort)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        data: _people,
        columns: _columns(),
        selectable: true,
        resizable: true,
        reorderable: true,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiTable<_Row>),
      matchesGoldenFile('goldens/beui_table.png'),
    );
  });
}
