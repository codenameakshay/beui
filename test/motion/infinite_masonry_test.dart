import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

/// Fixed-height card so lane distribution and positions are deterministic.
Widget _card(String item, int index) =>
    SizedBox(height: 100, child: Text(item));

double _estimate(String item, int index) => 100;

Widget _wrap(
  Widget child, {
  double width = 900,
  double height = 600,
  bool reduce = false,
}) => beuiTestApp(
  SizedBox(height: height, child: child),
  width: width,
  reduce: reduce,
);

BeuiInfiniteMasonry<String> _feed({
  required List<String> items,
  required bool hasMore,
  required Future<void> Function() onLoadMore,
  bool loading = false,
  Widget? error,
  VoidCallback? onRetry,
  Widget? endState,
  Widget Function(int index)? renderLoadingItem,
  bool animateItems = true,
  ScrollController? controller,
}) {
  return BeuiInfiniteMasonry<String>(
    items: items,
    getItemKey: (item, index) => item,
    renderItem: _card,
    onLoadMore: onLoadMore,
    hasMore: hasMore,
    loading: loading,
    error: error,
    onRetry: onRetry,
    endState: endState,
    renderLoadingItem: renderLoadingItem,
    estimateSize: _estimate,
    animateItems: animateItems,
    controller: controller,
  );
}

void main() {
  group('BeuiInfiniteMasonry layout', () {
    testWidgets('distributes items across columns on a wide viewport', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          width: 900,
          _feed(
            items: const ['Item 0', 'Item 1', 'Item 2', 'Item 3'],
            hasMore: false,
            onLoadMore: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 900px → 4 columns: item 0 and item 1 sit in the same row, side by side.
      final top0 = tester.getTopLeft(find.text('Item 0'));
      final top1 = tester.getTopLeft(find.text('Item 1'));
      expect(top0.dy, moreOrLessEquals(top1.dy, epsilon: 0.5));
      expect(top1.dx, greaterThan(top0.dx));
    });

    testWidgets('collapses to a single column on a narrow viewport', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          width: 240,
          _feed(
            items: const ['Item 0', 'Item 1', 'Item 2'],
            hasMore: false,
            onLoadMore: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 240px → 1 column: items stack vertically at the same left edge.
      final top0 = tester.getTopLeft(find.text('Item 0'));
      final top1 = tester.getTopLeft(find.text('Item 1'));
      expect(top0.dx, moreOrLessEquals(top1.dx, epsilon: 0.5));
      expect(top1.dy, greaterThan(top0.dy));
    });
  });

  group('BeuiInfiniteMasonry load-more', () {
    testWidgets('fires onLoadMore when content underfills the viewport', (
      tester,
    ) async {
      var calls = 0;
      var hasMore = true;
      await tester.pumpWidget(
        _wrap(
          height: 800,
          StatefulBuilder(
            builder: (context, setState) => _feed(
              items: const ['Item 0', 'Item 1'],
              hasMore: hasMore,
              onLoadMore: () async {
                calls++;
                setState(() => hasMore = false);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, greaterThanOrEqualTo(1));
    });

    testWidgets('fires onLoadMore when scrolled near the end', (tester) async {
      var calls = 0;
      var hasMore = true;
      final items = List<String>.generate(20, (i) => 'Item $i');
      await tester.pumpWidget(
        _wrap(
          width: 240, // single column → tall, scrollable content
          height: 300,
          StatefulBuilder(
            builder: (context, setState) => _feed(
              items: items,
              hasMore: hasMore,
              onLoadMore: () async {
                calls++;
                setState(() => hasMore = false);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0, reason: 'full viewport should not trigger on mount');

      await tester.drag(find.text('Item 0'), const Offset(0, -2500));
      await tester.pumpAndSettle();
      expect(calls, greaterThanOrEqualTo(1));
    });
  });

  group('BeuiInfiniteMasonry states', () {
    testWidgets('shows the empty state when there is nothing to load', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_feed(items: const [], hasMore: false, onLoadMore: () async {})),
      );
      await tester.pumpAndSettle();
      expect(find.text('No items yet'), findsOneWidget);
    });

    testWidgets('renders one loading skeleton per column in the tail', (
      tester,
    ) async {
      // The default 800px test window would clamp the 900px SizedBox; widen the
      // view so the feed actually gets 900px → 4 columns.
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _wrap(
          width: 900, // 4 columns
          _feed(
            items: const ['Item 0'],
            hasMore: true,
            loading: true,
            onLoadMore: () async {},
            renderLoadingItem: (index) => Text('skeleton-$index'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('skeleton-'), findsNWidgets(4));
    });

    testWidgets('shows the end state below the grid', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _feed(
            items: const ['Item 0', 'Item 1'],
            hasMore: false,
            onLoadMore: () async {},
            endState: const Text('You are all caught up'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('You are all caught up'), findsOneWidget);
    });

    testWidgets('shows the error tail and retry fires onRetry', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _wrap(
          _feed(
            items: const ['Item 0'],
            hasMore: true,
            onLoadMore: () async {},
            error: const Text('Network error'),
            onRetry: () => retries++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load more"), findsOneWidget);
      expect(find.text('Network error'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets('error tail takes precedence over loading skeletons', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _feed(
            items: const ['Item 0'],
            hasMore: true,
            loading: true,
            onLoadMore: () async {},
            error: const Text('Network error'),
            renderLoadingItem: (index) => Text('skeleton-$index'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Couldn't load more"), findsOneWidget);
      expect(find.textContaining('skeleton-'), findsNothing);
    });
  });

  group('BeuiInfiniteMasonry motion', () {
    /// Both tests append a third item after the initial mount, since only
    /// items arriving after `items.length at mount` are eligible to reveal.
    Future<StateSetter> pumpAppendable(
      WidgetTester tester, {
      required bool reduce,
    }) async {
      var items = const ['Item 0', 'Item 1'];
      late StateSetter setOuter;
      await tester.pumpWidget(
        _wrap(
          reduce: reduce,
          StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return _feed(
                items: items,
                hasMore: false,
                onLoadMore: () async {},
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      setOuter(() => items = const ['Item 0', 'Item 1', 'Item 2']);
      return setOuter;
    }

    // `_MasonryItemReveal` is keyed on the item's own key, so it can be found
    // directly rather than walking up from its rendered content — which also
    // dodges any unrelated Transform elsewhere in the tree.
    // ValueKey<Object>, matching how _MasonryItemReveal is keyed
    // (BeuiInfiniteMasonryKey = Object) — ValueKey equality checks
    // runtimeType too, so a bare ValueKey<String> would never match.
    Finder itemReveal() => find.byKey(const ValueKey<Object>('Item 2'));

    testWidgets('reduced motion mounts a newly appended item with no offset', (
      tester,
    ) async {
      await pumpAppendable(tester, reduce: true);
      await tester.pump(); // mount the new item
      expect(find.text('Item 2'), findsOneWidget);
      // No reveal machinery under reduced motion: no Transform driving the
      // item in from a y offset.
      expect(
        find.descendant(of: itemReveal(), matching: find.byType(Transform)),
        findsNothing,
      );
    });

    testWidgets('a newly appended item reveals: offset and opacity settle', (
      tester,
    ) async {
      await pumpAppendable(tester, reduce: false);
      await tester.pump(); // mount the new item (reveal starts, y = 12)

      Transform translateOf() => tester.widget<Transform>(
        find.descendant(of: itemReveal(), matching: find.byType(Transform)),
      );
      double opacityOf() => tester
          .widget<AnimatedOpacity>(
            find.descendant(
              of: itemReveal(),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;

      expect(translateOf().transform.getTranslation().y, moreOrLessEquals(12));
      expect(opacityOf(), 0.0);

      await tester.pumpAndSettle(); // spring + fade settle
      expect(
        translateOf().transform.getTranslation().y,
        moreOrLessEquals(0, epsilon: 0.01),
      );
      expect(opacityOf(), 1.0);
    });
  });
}
