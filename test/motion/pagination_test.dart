import 'package:beui/src/motion/pagination.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

AnimatedOpacity _opacityFor(WidgetTester tester, String pageText) =>
    tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.text(pageText),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );

double _renderedOpacityFor(WidgetTester tester, String pageText) {
  final animated = find
      .ancestor(of: find.text(pageText), matching: find.byType(AnimatedOpacity))
      .first;
  final fade = find.descendant(
    of: animated,
    matching: find.byType(FadeTransition),
  );
  return tester.widget<FadeTransition>(fade).opacity.value;
}

String _range(List<BeuiPaginationItem> items) => items
    .map((item) {
      return switch (item) {
        BeuiPaginationPage(:final page) => '$page',
        BeuiPaginationEllipsis(gap: BeuiPaginationGap.start) =>
          'ellipsis-start',
        BeuiPaginationEllipsis(gap: BeuiPaginationGap.end) => 'ellipsis-end',
      };
    })
    .join(',');

bool _hasAccessibleLabel(WidgetTester tester, String label) {
  bool contains(SemanticsNode node) {
    if (node.label == label) return true;
    var found = false;
    node.visitChildren((child) {
      found = contains(child);
      return !found;
    });
    return found;
  }

  return contains(tester.getSemantics(find.bySemanticsLabel('Pagination')));
}

void main() {
  group('beuiPaginationRange', () {
    test('uses exact source range outcomes and typed gap identity', () {
      expect(_range(beuiPaginationRange(4, 5)), '1,2,3,4,5');
      expect(_range(beuiPaginationRange(2, 20)), '1,2,3,4,5,ellipsis-end,20');
      expect(
        _range(beuiPaginationRange(19, 20)),
        '1,ellipsis-start,16,17,18,19,20',
      );
      expect(
        _range(beuiPaginationRange(6, 20)),
        '1,ellipsis-start,5,6,7,ellipsis-end,20',
      );
      final entries = beuiPaginationRange(6, 20);
      expect(entries[1], isA<BeuiPaginationEllipsis>());
      expect(
        (entries[1] as BeuiPaginationEllipsis).gap,
        BeuiPaginationGap.start,
      );
      expect((entries[5] as BeuiPaginationEllipsis).gap, BeuiPaginationGap.end);
    });

    test('uses source slot threshold and keeps integer parameters literal', () {
      expect(_range(beuiPaginationRange(4, 7)), '1,2,3,4,5,6,7');
      expect(
        _range(beuiPaginationRange(10, 20, siblings: 2, boundaries: 2)),
        '1,2,ellipsis-start,8,9,10,11,12,ellipsis-end,19,20',
      );
      expect(_range(beuiPaginationRange(1, 0)), isEmpty);
      expect(
        _range(beuiPaginationRange(1, 10, siblings: 0, boundaries: 1)),
        '1,2,3,ellipsis-end,10',
      );
    });
  });

  testWidgets('default preview starts settled before interaction', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [BeuiPagination(totalPages: 20, defaultPage: 6)],
        ),
      ),
    );
    await tester.pump(Duration.zero);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Previous page'), findsNothing);
    expect(find.bySemanticsLabel('Pagination'), findsOneWidget);
    expect(find.bySemanticsLabel('Page 6'), findsOneWidget);
    expect(find.bySemanticsLabel('Back 5 pages'), findsOneWidget);
    expect(find.bySemanticsLabel('Forward 5 pages'), findsOneWidget);
    final initialOpacity = _opacityFor(tester, '5');
    expect(initialOpacity.opacity, 1);
    expect(_renderedOpacityFor(tester, '5'), 1);
  });

  testWidgets('uncontrolled actions clamp, notify once, and respect bounds', (
    tester,
  ) async {
    final changes = <int>[];
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        beuiTestApp(
          BeuiPagination(
            totalPages: 5,
            defaultPage: 50,
            onPageChange: changes.add,
          ),
        ),
      );
      await tester.pump(Duration.zero);
      expect(find.text('5'), findsOneWidget);
      expect(find.bySemanticsLabel('Next page'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Next page')),
        isSemantics(isButton: true, isEnabled: false),
      );
      await tester.tap(find.bySemanticsLabel('Page 5'));
      await tester.pump(Duration.zero);
      expect(changes, isEmpty);
      await tester.tap(find.bySemanticsLabel('Previous page'));
      await tester.pump(Duration.zero);
      expect(changes, [4]);
      expect(find.text('4'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Page 4'));
      await tester.pump(Duration.zero);
      expect(changes, [4]);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('controlled mode calls back and waits for the owner', (
    tester,
  ) async {
    final changes = <int>[];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiPagination(totalPages: 10, page: 3, onPageChange: changes.add),
      ),
    );
    await tester.pump(Duration.zero);
    await tester.tap(find.bySemanticsLabel('Page 4'));
    await tester.pump(Duration.zero);
    expect(changes, [4]);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('effective total has a one-page minimum and bounded actions', (
    tester,
  ) async {
    final changes = <int>[];
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        beuiTestApp(
          BeuiPagination(totalPages: 0, page: -4, onPageChange: changes.add),
        ),
      );
      await tester.pump(Duration.zero);
      expect(find.bySemanticsLabel('Page 1'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Previous page')),
        isSemantics(isButton: true, isEnabled: false),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Next page')),
        isSemantics(isButton: true, isEnabled: false),
      );
      await tester.tap(find.bySemanticsLabel('Page 1'));
      await tester.pump(Duration.zero);
      expect(changes, isEmpty);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('ellipsis jumps by its direction and jump value', (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(
      beuiTestApp(
        BeuiPagination(
          totalPages: 40,
          page: 20,
          jump: 7,
          onPageChange: changes.add,
        ),
      ),
    );
    await tester.pump(Duration.zero);
    await tester.tap(find.bySemanticsLabel('Back 7 pages'));
    await tester.pump(Duration.zero);
    expect(changes, [13]);
  });

  testWidgets('shrinking the total does not replace the uncontrolled page', (
    tester,
  ) async {
    Widget pager(int total) =>
        beuiTestApp(BeuiPagination(totalPages: total, defaultPage: 5));
    await tester.pumpWidget(pager(8));
    await tester.pump(Duration.zero);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Page 5')),
      isSemantics(isButton: true, isSelected: true, isEnabled: true),
    );
    await tester.pumpWidget(pager(2));
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 160));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Page 2')),
      isSemantics(isButton: true, isSelected: true, isEnabled: true),
    );
    await tester.pumpWidget(pager(8));
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 160));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Page 5')),
      isSemantics(isButton: true, isSelected: true, isEnabled: true),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keyboard focus remains exposed on the labelled control', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiPagination(totalPages: 20, defaultPage: 6)),
    );
    await tester.pump(Duration.zero);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(Duration.zero);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Previous page')),
      matchesSemantics(
        label: 'Previous page',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasSelectedState: true,
        isFocusable: true,
        isFocused: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
  });

  testWidgets(
    'router metadata keeps modified and prevented activation external',
    (tester) async {
      final changes = <int>[];
      BeuiPaginationLinkProps? seen;
      await tester.pumpWidget(
        beuiTestApp(
          BeuiPagination(
            totalPages: 8,
            page: 3,
            getHref: (page) => '/items?page=$page',
            onPageChange: changes.add,
            linkBuilder: (context, props) {
              if (props.page == 4) seen = props;
              return TextButton(
                onPressed: () => props.activate(defaultPrevented: true),
                child: props.child,
              );
            },
          ),
        ),
      );
      await tester.pump(Duration.zero);
      expect(seen?.href, '/items?page=4');
      expect(seen?.current, isFalse);
      await tester.tap(find.text('4'));
      await tester.pump(Duration.zero);
      expect(changes, isEmpty);
      seen!.activate(metaKey: true);
      seen!.activate(ctrlKey: true);
      seen!.activate(shiftKey: true);
      seen!.activate(altKey: true);
      expect(changes, isEmpty);
      seen!.activate();
      expect(changes, [4]);
    },
  );

  testWidgets('disabled edge controls stay buttons when hrefs are provided', (
    tester,
  ) async {
    final builtLinks = <int>{};
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        beuiTestApp(
          BeuiPagination(
            totalPages: 1,
            page: 1,
            getHref: (page) => '/items?page=$page',
            linkBuilder: (context, props) {
              builtLinks.add(props.page);
              return TextButton(
                onPressed: () => props.activate(),
                child: Text(props.label),
              );
            },
          ),
        ),
      );
      await tester.pump(Duration.zero);
      expect(builtLinks, {1});
      for (final label in ['Previous page', 'Next page']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          matchesSemantics(
            label: label,
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasSelectedState: true,
            isFocusable: false,
            hasFocusAction: false,
          ),
        );
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('tab and Enter activate ordinary controls without arrow paging', (
    tester,
  ) async {
    final changes = <int>[];
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        beuiTestApp(
          BeuiPagination(totalPages: 8, page: 3, onPageChange: changes.add),
        ),
      );
      await tester.pump(Duration.zero);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(Duration.zero);
      expect(changes, [2]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(Duration.zero);
      expect(changes, [2]);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Page 3')),
        isSemantics(isButton: true, isSelected: true, isEnabled: true),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'new entries animate, while exiting controls go inert immediately',
    (tester) async {
      final changes = <int>[];
      Widget pager(int page) => beuiTestApp(
        BeuiPagination(totalPages: 20, page: page, onPageChange: changes.add),
      );
      await tester.pumpWidget(pager(6));
      await tester.pump(Duration.zero);
      await tester.tap(find.bySemanticsLabel('Page 7'));
      await tester.pump(Duration.zero);
      expect(changes, [7]);
      await tester.pumpWidget(pager(7));
      await tester.pump(Duration.zero);

      expect(_opacityFor(tester, '8').opacity, 1);
      expect(_renderedOpacityFor(tester, '8'), 0);
      expect(_renderedOpacityFor(tester, '5'), 1);
      final entering = tester.widgetList<Transform>(
        find.ancestor(of: find.text('8'), matching: find.byType(Transform)),
      );
      expect(
        entering.any((transform) => transform.transform.entry(0, 0) < 1),
        isTrue,
      );
      final positionTransforms = tester.widgetList<Transform>(
        find.ancestor(of: find.text('6'), matching: find.byType(Transform)),
      );
      final rowGlide = positionTransforms
          .map((transform) => transform.transform.getTranslation().x)
          .firstWhere((offset) => offset > 0);
      expect(rowGlide, closeTo(40, 0.1));
      expect(_hasAccessibleLabel(tester, 'Page 6'), isTrue);
      expect(_hasAccessibleLabel(tester, 'Page 5'), isFalse);
      expect(
        find.text('5'),
        findsOneWidget,
      ); // retained only for its exit paint
      await tester.tap(find.text('5'), warnIfMissed: false);
      await tester.pump(Duration.zero);
      expect(changes.contains(5), isFalse);
      await tester.pump(const Duration(milliseconds: 80));
      final glidingTransforms = tester.widgetList<Transform>(
        find.ancestor(of: find.text('6'), matching: find.byType(Transform)),
      );
      final glidingOffset = glidingTransforms
          .map((transform) => transform.transform.getTranslation().x)
          .firstWhere((offset) => offset > 0);
      expect(glidingOffset, lessThan(rowGlide));
      expect(_renderedOpacityFor(tester, '8'), greaterThan(0));
      expect(_renderedOpacityFor(tester, '8'), lessThan(1));
      expect(_renderedOpacityFor(tester, '5'), lessThan(1));
      expect(_renderedOpacityFor(tester, '5'), greaterThan(0));
      // Let the 360/32/0.6 layout spring reach its actual completion callback;
      // removal is not tied to the shorter opacity clock.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('5'), findsNothing);
    },
  );

  testWidgets('controls use 32/36 geometry and reduced motion snaps scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      beuiTestApp(const BeuiPagination(totalPages: 20, defaultPage: 6)),
    );
    await tester.pump(Duration.zero);
    expect(tester.getSize(find.bySemanticsLabel('Page 6')), const Size(32, 32));

    tester.view.physicalSize = const Size(800, 844);
    await tester.pumpWidget(
      beuiTestApp(const BeuiPagination(totalPages: 20, defaultPage: 6)),
    );
    await tester.pump(Duration.zero);
    expect(tester.getSize(find.bySemanticsLabel('Page 6')), const Size(36, 36));

    await tester.pumpWidget(
      beuiTestApp(
        const BeuiPagination(totalPages: 20, defaultPage: 6),
        reduce: true,
      ),
    );
    await tester.pump(Duration.zero);
    await tester.tap(find.bySemanticsLabel('Page 7'));
    await tester.pump(Duration.zero);
    final scales = tester.widgetList<Transform>(
      find.ancestor(of: find.text('8'), matching: find.byType(Transform)),
    );
    expect(
      scales.every((transform) => transform.transform.entry(0, 0) == 1),
      isTrue,
    );
    final snappedTransforms = tester.widgetList<Transform>(
      find.ancestor(of: find.text('6'), matching: find.byType(Transform)),
    );
    expect(
      snappedTransforms.every(
        (transform) => transform.transform.getTranslation().x == 0,
      ),
      isTrue,
    );
    expect(_renderedOpacityFor(tester, '8'), 0);
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 60));
    expect(_renderedOpacityFor(tester, '8'), greaterThan(0));
    expect(_renderedOpacityFor(tester, '8'), lessThan(1));
  });
}
