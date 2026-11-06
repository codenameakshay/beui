import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

class _MasonryItem {
  const _MasonryItem(this.id, this.height);

  final String id;
  final double height;
}

Widget _host(Widget child, {double width = 240, double height = 260}) =>
    beuiTestApp(SizedBox(width: width, height: height, child: child));

BeuiInfiniteMasonry<_MasonryItem> _feed({
  required List<_MasonryItem> items,
  bool hasMore = false,
  FutureOr<void> Function()? onLoadMore,
  int overscan = 4,
  int prefetch = 3,
  double minColumnWidth = 208,
  int maxColumns = 4,
  double gap = 12,
  bool animateItems = false,
  ScrollController? controller,
  bool loading = false,
  Widget? error,
  VoidCallback? onRetry,
  Widget Function(int index)? renderLoadingItem,
  String Function(_MasonryItem item, int index)? label,
}) => BeuiInfiniteMasonry<_MasonryItem>(
  items: items,
  getItemKey: (item, index) => item.id,
  renderItem: (item, index) => SizedBox(
    height: item.height,
    child: Text(label?.call(item, index) ?? item.id),
  ),
  estimateSize: (item, index) => item.height,
  onLoadMore: onLoadMore ?? () {},
  hasMore: hasMore,
  overscan: overscan,
  prefetch: prefetch,
  minColumnWidth: minColumnWidth,
  maxColumns: maxColumns,
  gap: gap,
  animateItems: animateItems,
  controller: controller,
  loading: loading,
  error: error,
  onRetry: onRetry,
  renderLoadingItem: renderLoadingItem,
);

List<_MasonryItem> _items(int count, {double height = 80}) =>
    List<_MasonryItem>.generate(
      count,
      (index) => _MasonryItem('item-$index', height),
    );

int _mountedItemCount(WidgetTester tester, List<_MasonryItem> items) =>
    items.where((item) => find.text(item.id).evaluate().isNotEmpty).length;

void main() {
  group('BeuiInfiniteMasonry source window behavior', () {
    testWidgets('an existing initial scroll offset mounts its destination', (
      tester,
    ) async {
      final controller = ScrollController(initialScrollOffset: 6000);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(_feed(items: _items(200), controller: controller), height: 300),
      );
      await tester.pumpAndSettle();

      expect(controller.offset, 6000);
      expect(find.text('item-70'), findsOneWidget);
      expect(find.text('item-0'), findsNothing);
    });

    testWidgets('a replacement controller updates the attached scroll window', (
      tester,
    ) async {
      var controller = ScrollController();
      final restoredController = ScrollController(
        initialScrollOffset: 6000,
        keepScrollOffset: false,
      );
      addTearDown(controller.dispose);
      addTearDown(restoredController.dispose);
      late StateSetter replaceController;

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              replaceController = setState;
              return _feed(items: _items(200), controller: controller);
            },
          ),
          height: 300,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('item-0'), findsOneWidget);

      replaceController(() => controller = restoredController);
      await tester.pumpAndSettle();

      expect(restoredController.offset, 0);
      restoredController.jumpTo(6000);
      await tester.pumpAndSettle();

      expect(restoredController.offset, 6000);
      expect(find.text('item-70'), findsOneWidget);
      expect(find.text('item-0'), findsNothing);
    });

    testWidgets('a loading tail remains mounted when it alone is visible', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        beuiTestApp(
          SizedBox(
            width: 240,
            height: 80,
            child: _feed(
              items: _items(20),
              controller: controller,
              loading: true,
              hasMore: true,
              overscan: 0,
            ),
          ),
          reduce: true,
        ),
      );
      await tester.pumpAndSettle();
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('masonry-tail-loading-0')),
        findsOneWidget,
      );
      expect(find.text('item-0'), findsNothing);
    });

    testWidgets('a custom loading tail retains its measured natural height', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          _feed(
            items: _items(20),
            controller: controller,
            loading: true,
            hasMore: true,
            overscan: 0,
            renderLoadingItem: (index) => SizedBox(
              key: ValueKey('custom-loading-tail-$index'),
              height: 310,
              child: Text('custom loading $index'),
            ),
          ),
          height: 80,
        ),
      );
      await tester.pumpAndSettle();
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('custom-loading-tail-0')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('custom-loading-tail-0')))
            .height,
        310,
      );
      expect(controller.position.maxScrollExtent, closeTo(2094, 0.5));
    });

    testWidgets('an expanded error tail height contributes to scroll extent', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          _feed(
            items: _items(20),
            controller: controller,
            hasMore: true,
            overscan: 0,
            error: const SizedBox(
              height: 320,
              child: Text('large failure details'),
            ),
          ),
          height: 80,
        ),
      );
      await tester.pumpAndSettle();
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(find.text('large failure details'), findsOneWidget);
      expect(controller.position.maxScrollExtent, greaterThan(2060));
    });

    testWidgets('keeps a large preloaded feed bounded to its visible window', (
      tester,
    ) async {
      final items = _items(1000);
      await tester.pumpWidget(_host(_feed(items: items)));
      await tester.pumpAndSettle();

      // The 260px host leaves 236px inside the scroll view after 12px padding
      // on both ends. At an 80px estimate plus the 12px item gap, at most four
      // items intersect that viewport. TanStack's four-item overscan on each
      // side adds at most eight more in this single-column fixture.
      expect(
        _mountedItemCount(tester, items),
        lessThanOrEqualTo(12),
        reason: 'only the viewport and its source overscan should be mounted',
      );
      expect(find.text('item-0'), findsOneWidget);
      expect(find.text('item-999'), findsNothing);
    });

    testWidgets(
      'overscan widens the mounted render window independently of loading',
      (tester) async {
        final items = _items(1000, height: 60);

        await tester.pumpWidget(
          _host(_feed(items: items, overscan: 0, prefetch: 0)),
        );
        await tester.pumpAndSettle();
        final withoutOverscan = _mountedItemCount(tester, items);

        await tester.pumpWidget(
          _host(_feed(items: items, overscan: 4, prefetch: 0)),
        );
        await tester.pumpAndSettle();
        final withOverscan = _mountedItemCount(tester, items);

        expect(withOverscan, greaterThan(withoutOverscan));
        expect(find.text('item-999'), findsNothing);
      },
    );

    testWidgets(
      'scrolling mounts the identified destination and releases old items',
      (tester) async {
        final items = _items(200);
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _host(_feed(items: items, controller: controller), height: 300),
        );
        await tester.pumpAndSettle();
        expect(find.text('item-0'), findsOneWidget);

        controller.jumpTo(6000);
        await tester.pumpAndSettle();

        expect(find.text('item-70'), findsOneWidget);
        expect(find.text('item-0'), findsNothing);
      },
    );

    testWidgets('render overscan does not advance the load-more threshold', (
      tester,
    ) async {
      final items = _items(100);
      var loadCalls = 0;
      await tester.pumpWidget(
        _host(
          _feed(
            items: items,
            hasMore: true,
            overscan: 100,
            prefetch: 0,
            onLoadMore: () {
              loadCalls++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('item-99'), findsOneWidget);
      expect(loadCalls, 0);
    });
  });

  testWidgets('measured heights update shortest-lane assignment', (
    tester,
  ) async {
    const items = <_MasonryItem>[
      _MasonryItem('tall', 180),
      _MasonryItem('short', 80),
      _MasonryItem('medium', 120),
    ];
    await tester.pumpWidget(
      beuiTestApp(
        SizedBox(
          width: 450,
          height: 320,
          child: BeuiInfiniteMasonry<_MasonryItem>(
            items: items,
            getItemKey: (item, _) => item.id,
            renderItem: (item, _) =>
                SizedBox(height: item.height, child: Text(item.id)),
            estimateSize: (item, _) => 80,
            hasMore: false,
            onLoadMore: () {},
            minColumnWidth: 200,
            gap: 10,
            animateItems: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('medium')).dx,
      tester.getTopLeft(find.text('short')).dx,
    );
  });

  testWidgets('lays out variable heights and recomputes columns after resize', (
    tester,
  ) async {
    const items = <_MasonryItem>[
      _MasonryItem('tall', 180),
      _MasonryItem('short', 80),
      _MasonryItem('medium', 120),
      _MasonryItem('small', 60),
    ];
    var width = 450.0;
    late StateSetter setWidth;

    await tester.pumpWidget(
      beuiTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            setWidth = setState;
            return SizedBox(
              width: width,
              height: 320,
              child: _feed(items: items, minColumnWidth: 200, gap: 10),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tallBefore = tester.getTopLeft(find.text('tall'));
    final shortBefore = tester.getTopLeft(find.text('short'));
    final mediumBefore = tester.getTopLeft(find.text('medium'));
    final smallBefore = tester.getTopLeft(find.text('small'));
    expect(shortBefore.dx, greaterThan(tallBefore.dx));
    expect(mediumBefore.dy - shortBefore.dy, 90);
    expect(smallBefore.dy - tallBefore.dy, 190);

    setWidth(() => width = 220);
    await tester.pumpAndSettle();

    final positions = {
      for (final item in items) item.id: tester.getTopLeft(find.text(item.id)),
    };
    expect(positions['short']!.dx, positions['tall']!.dx);
    expect(positions['medium']!.dx, positions['tall']!.dx);
    expect(positions['small']!.dx, positions['tall']!.dx);
    expect(positions['short']!.dy, greaterThan(positions['tall']!.dy));
    expect(positions['medium']!.dy, greaterThan(positions['short']!.dy));
  });

  testWidgets(
    'reflects appended controlled data with stable IDs and new indices',
    (tester) async {
      var items = const <_MasonryItem>[
        _MasonryItem('alpha', 80),
        _MasonryItem('beta', 100),
      ];
      late StateSetter setItems;

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              setItems = setState;
              return _feed(
                items: items,
                label: (item, index) => '$index:${item.id}',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0:alpha'), findsOneWidget);
      expect(find.text('1:beta'), findsOneWidget);

      setItems(
        () => items = [
          ...items,
          const _MasonryItem('gamma', 120),
          const _MasonryItem('delta', 60),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('0:alpha'), findsOneWidget);
      expect(find.text('1:beta'), findsOneWidget);
      expect(find.text('2:gamma'), findsOneWidget);
      expect(find.text('3:delta'), findsOneWidget);
    },
  );

  testWidgets(
    'holds one load in flight, surfaces failure, and retries via its callback',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      var retries = 0;
      var failed = false;
      late StateSetter setFailed;

      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setState) {
              setFailed = setState;
              return _feed(
                items: const [_MasonryItem('only-item', 80)],
                hasMore: true,
                onLoadMore: () {
                  calls++;
                  if (calls == 1) {
                    return pending.future.then((_) {
                      setFailed(() => failed = true);
                    });
                  }
                },
                error: failed ? const Text('page failed') : null,
                onRetry: () {
                  retries++;
                  setFailed(() => failed = false);
                },
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(calls, 1);

      await tester.pump(const Duration(milliseconds: 100));
      expect(
        calls,
        1,
        reason: 'an unresolved page request must remain single-flight',
      );

      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('page failed'), findsOneWidget);
      expect(calls, 1);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(retries, 1);
      expect(find.text('page failed'), findsNothing);
      expect(
        calls,
        2,
        reason: 'clearing the error allows the underfilled feed to retry',
      );
    },
  );
}
