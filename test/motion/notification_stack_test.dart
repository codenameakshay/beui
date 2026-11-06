import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:beui/beui.dart';
import 'package:beui/src/motion/_focus_ring.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

Widget _wrap(Widget child, {bool reduce = false}) =>
    beuiTestApp(child, alignment: Alignment.topCenter, reduce: reduce);

FocusNode _stackFocusNode(WidgetTester tester) => tester
    .widget<Focus>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Focus &&
            widget.focusNode?.debugLabel == 'BeuiNotificationStack',
      ),
    )
    .focusNode!;

const List<BeuiNotificationStackItem> _items = [
  BeuiNotificationStackItem(
    id: 'a',
    title: 'Deploy finished',
    description: 'Build 4821 shipped to prod',
    trailing: Text('2m'),
  ),
  BeuiNotificationStackItem(
    id: 'b',
    title: 'New comment',
    description: 'Alex replied to your pull request',
  ),
  BeuiNotificationStackItem(
    id: 'c',
    title: 'Weekly summary',
    description: 'Your activity report is ready',
  ),
];

void main() {
  group('BeuiNotificationStack', () {
    testWidgets('renders items and the collapsed footer label', (tester) async {
      await tester.pumpWidget(
        _wrap(const BeuiNotificationStack(items: _items)),
      );
      await tester.pumpAndSettle();

      // Primary title is rendered (once in the surface, once in the hidden
      // measuring column).
      expect(find.text('Deploy finished'), findsAtLeastNWidgets(1));
      // Footer starts on the collapsed label with the item count badge.
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('View all'), findsNothing);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('tapping expands and rolls the footer label', (tester) async {
      await tester.pumpWidget(
        _wrap(const BeuiNotificationStack(items: _items)),
      );
      await tester.pumpAndSettle();
      final collapsed = tester.getRect(find.byType(BeuiNotificationStack));
      final collapsedFooter = tester.getRect(find.text('Notifications'));

      await tester.tapAt(tester.getCenter(find.byType(BeuiNotificationStack)));
      await tester.pumpAndSettle();

      expect(find.text('View all'), findsOneWidget);
      expect(find.text('Notifications'), findsNothing);

      // The source pins the panel to the host's bottom (`absolute inset-x-0
      // bottom-0`), so the deck fans *upward*: the host keeps its resting box
      // and the footer stays where it was.
      final expanded = tester.getRect(find.byType(BeuiNotificationStack));
      expect(
        expanded,
        collapsed,
        reason: 'expanding must not resize or move the host box',
      );
      expect(
        tester.getRect(find.text('View all')).center.dy,
        moreOrLessEquals(collapsedFooter.center.dy, epsilon: 1),
        reason: 'the footer strip stays anchored while the deck fans up',
      );

      // The fanned deck overflows above the host box. The primary card leads
      // the deck, and its title matches twice — once in the deck, once in the
      // hidden measuring column pinned to the host's top edge — so the higher
      // of the two is the deck's own card.
      final tops = find
          .text('Deploy finished')
          .evaluate()
          .map(
            (e) => (e.renderObject! as RenderBox).localToGlobal(Offset.zero).dy,
          )
          .toList();
      expect(
        tops.reduce(math.min),
        lessThan(collapsed.top),
        reason: 'the fanned deck overflows above the host box',
      );
    });

    testWidgets('Escape collapses an expanded stack', (tester) async {
      await tester.pumpWidget(
        _wrap(const BeuiNotificationStack(items: _items)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BeuiNotificationStack));
      await tester.pumpAndSettle();
      expect(find.text('View all'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('View all'), findsNothing);
    });

    testWidgets('focus ring follows keyboard modality, not touch focus', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const BeuiNotificationStack(items: _items)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BeuiNotificationStack));
      await tester.pumpAndSettle();
      expect(
        tester.widget<BeuiFocusRing>(find.byType(BeuiFocusRing)).focused,
        isFalse,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        tester.widget<BeuiFocusRing>(find.byType(BeuiFocusRing)).focused,
        isTrue,
      );
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets(
      'card fan-out moves before settling and preserves host bounds',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const Padding(
              padding: EdgeInsets.only(top: 240),
              child: BeuiNotificationStack(items: _items),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final host = tester.getRect(find.byType(BeuiNotificationStack));
        double primaryTitleTop() => find
            .text('Deploy finished')
            .evaluate()
            .map((element) => tester.getRect(find.byWidget(element.widget)).top)
            .reduce(math.min);
        final collapsedTop = primaryTitleTop();

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(BeuiNotificationStack)),
          kind: PointerDeviceKind.touch,
        );
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(find.text('View all'), findsOneWidget);
        final intermediateTop = primaryTitleTop();
        expect(intermediateTop, lessThan(collapsedTop));
        expect(intermediateTop, greaterThan(host.top - 200));
        expect(tester.getRect(find.byType(BeuiNotificationStack)), host);

        await tester.pumpAndSettle();
        expect(primaryTitleTop(), lessThan(intermediateTop));
        expect(tester.getRect(find.byType(BeuiNotificationStack)), host);
      },
    );

    testWidgets(
      'Escape keeps focus; Enter reopens before activating View all',
      (tester) async {
        var viewAll = 0;
        await tester.pumpWidget(
          _wrap(
            BeuiNotificationStack(items: _items, onViewAll: () => viewAll++),
          ),
        );
        await tester.pumpAndSettle();

        final triggerFocus = _stackFocusNode(tester);
        triggerFocus.requestFocus();
        await tester.pumpAndSettle();
        expect(find.text('View all'), findsOneWidget);
        expect(triggerFocus.hasFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Notifications'), findsOneWidget);
        expect(triggerFocus.hasFocus, isTrue);
        expect(viewAll, 0);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(viewAll, 0);
        expect(find.text('View all'), findsOneWidget);
        expect(triggerFocus.hasFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(viewAll, 1);
        expect(find.text('View all'), findsOneWidget);
        expect(triggerFocus.hasFocus, isTrue);
      },
    );

    testWidgets('a touch-open outside tap dismisses without activating below', (
      tester,
    ) async {
      var underlyingActivations = 0;
      await tester.pumpWidget(
        _wrap(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BeuiNotificationStack(items: _items),
              TextButton(
                onPressed: () => underlyingActivations++,
                child: const Text('Underlying action'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BeuiNotificationStack));
      await tester.pumpAndSettle();
      expect(find.text('View all'), findsOneWidget);

      await tester.tap(find.text('Underlying action'));
      await tester.pumpAndSettle();

      expect(underlyingActivations, 0);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('View all'), findsNothing);
    });

    testWidgets(
      'the first touch remains an expand gesture if contact focuses',
      (tester) async {
        var viewAll = 0;
        await tester.pumpWidget(
          _wrap(
            BeuiNotificationStack(items: _items, onViewAll: () => viewAll++),
          ),
        );
        await tester.pumpAndSettle();

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(BeuiNotificationStack)),
          kind: PointerDeviceKind.touch,
        );
        _stackFocusNode(tester).requestFocus();
        await tester.pumpAndSettle();
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.text('View all'), findsOneWidget);
        expect(
          viewAll,
          0,
          reason: 'the opening touch must not follow View all',
        );
      },
    );

    testWidgets('pointer cancellation drops the old touch snapshot', (
      tester,
    ) async {
      var viewAll = 0;
      await tester.pumpWidget(
        _wrap(BeuiNotificationStack(items: _items, onViewAll: () => viewAll++)),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(BeuiNotificationStack)),
        kind: PointerDeviceKind.touch,
      );
      _stackFocusNode(tester).requestFocus();
      await tester.pumpAndSettle();
      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(find.text('View all'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(viewAll, 1);
      expect(find.text('View all'), findsOneWidget);
    });

    testWidgets('mouse hover expands, while touch contact waits for tap', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const BeuiNotificationStack(items: _items)),
      );
      await tester.pumpAndSettle();
      final center = tester.getCenter(find.byType(BeuiNotificationStack));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1, 1));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(center);
      await tester.pumpAndSettle();
      expect(find.text('View all'), findsOneWidget);

      await mouse.moveTo(const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);

      final gesture = await tester.startGesture(
        center,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();
      expect(
        find.text('Notifications'),
        findsOneWidget,
        reason: 'touch contact alone is not a hover expansion',
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('View all'), findsOneWidget);
    });

    testWidgets('controlled owner can reject a collapse request', (
      tester,
    ) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        _wrap(
          BeuiNotificationStack(
            items: _items,
            expanded: true,
            onExpandedChange: changes.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      _stackFocusNode(tester).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(changes, contains(false));
      expect(find.text('View all'), findsOneWidget);
      expect(find.text('Notifications'), findsNothing);
    });

    testWidgets(
      'disposing a focused stack leaves no pending interaction work',
      (tester) async {
        var changes = 0;
        await tester.pumpWidget(
          _wrap(
            BeuiNotificationStack(
              items: _items,
              onExpandedChange: (_) => changes++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        _stackFocusNode(tester).requestFocus();
        await tester.pumpAndSettle();
        final changesAtDispose = changes;

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(changes, changesAtDispose);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('fires onViewAll when tapped while already expanded', (
      tester,
    ) async {
      var viewAll = 0;
      await tester.pumpWidget(
        _wrap(
          Padding(
            padding: const EdgeInsets.only(top: 240),
            child: BeuiNotificationStack(
              items: _items,
              defaultExpanded: true,
              onViewAll: () => viewAll++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('View all'), findsOneWidget);

      await tester.tapAt(tester.getCenter(find.byType(BeuiNotificationStack)));
      await tester.pumpAndSettle();
      expect(viewAll, 1);
      // onViewAll took priority, so it stays expanded.
      expect(find.text('View all'), findsOneWidget);
    });

    testWidgets('expanded overflow remains tappable outside the host bounds', (
      tester,
    ) async {
      var viewAll = 0;
      await tester.pumpWidget(
        _wrap(
          Padding(
            padding: const EdgeInsets.only(top: 240),
            child: BeuiNotificationStack(
              items: _items,
              defaultExpanded: true,
              onViewAll: () => viewAll++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final host = tester.getRect(find.byType(BeuiNotificationStack));
      final cardRects = find
          .text('New comment')
          .evaluate()
          .map((element) => tester.getRect(find.byWidget(element.widget)))
          .toList();
      final card = cardRects.firstWhere((rect) => rect.top < host.top);
      await tester.tapAt(card.center);
      await tester.pumpAndSettle();

      expect(viewAll, 1);
      expect(find.text('View all'), findsOneWidget);
    });

    testWidgets('expanded overflow hit target follows parent scrolling', (
      tester,
    ) async {
      var viewAll = 0;
      final scrollController = ScrollController(initialScrollOffset: 200);
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.only(top: 340, bottom: 700),
              child: BeuiNotificationStack(
                items: _items,
                defaultExpanded: true,
                onViewAll: () => viewAll++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final host = tester.getRect(find.byType(BeuiNotificationStack));
      final oldOverflowPoint = find
          .text('New comment')
          .evaluate()
          .map((element) => tester.getRect(find.byWidget(element.widget)))
          .firstWhere((rect) => rect.top < host.top)
          .center;

      // Moving the target down leaves the old overflow coordinates above the
      // new panel; a proxy with a cached global rect would still hit there.
      scrollController.jumpTo(0);
      await tester.pumpAndSettle();
      final scrolledHost = tester.getRect(find.byType(BeuiNotificationStack));
      final newOverflowPoint = find
          .text('New comment')
          .evaluate()
          .map((element) => tester.getRect(find.byWidget(element.widget)))
          .firstWhere((rect) => rect.top < scrolledHost.top)
          .center;
      expect(newOverflowPoint.dy, greaterThan(oldOverflowPoint.dy + 100));

      await tester.tapAt(oldOverflowPoint);
      await tester.pumpAndSettle();
      expect(
        viewAll,
        0,
        reason: 'the previous screen position is no longer hit',
      );

      await tester.tapAt(newOverflowPoint);
      await tester.pumpAndSettle();
      expect(
        viewAll,
        1,
        reason: 'the follower tracks the scrolled target once',
      );
    });

    testWidgets('overflow hit target follows a transformed clipped ancestor', (
      tester,
    ) async {
      var viewAll = 0;
      await tester.pumpWidget(
        _wrap(
          Padding(
            padding: const EdgeInsets.only(top: 180),
            child: SizedBox(
              width: 352,
              height: 300,
              child: ClipRect(
                key: const ValueKey('notification-ancestor-clip'),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Transform.translate(
                    offset: const Offset(24, 0),
                    child: BeuiNotificationStack(
                      items: _items,
                      defaultExpanded: true,
                      onViewAll: () => viewAll++,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final clip = tester.getRect(
        find.byKey(const ValueKey('notification-ancestor-clip')),
      );
      final host = tester.getRect(find.byType(BeuiNotificationStack));
      final visibleOverflow = find
          .text('New comment')
          .evaluate()
          .map((element) => tester.getRect(find.byWidget(element.widget)))
          .firstWhere((rect) => rect.top < host.top && rect.overlaps(clip))
          .intersect(clip);
      expect(visibleOverflow.isEmpty, isFalse);

      await tester.tapAt(visibleOverflow.center);
      await tester.pumpAndSettle();
      expect(viewAll, 1);
    });

    testWidgets('multiple notification overlays keep their hit regions local', (
      tester,
    ) async {
      var firstViews = 0;
      var secondViews = 0;
      await tester.pumpWidget(
        _wrap(
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BeuiNotificationStack(
                items: _items,
                defaultExpanded: true,
                onViewAll: () => firstViews++,
              ),
              const SizedBox(height: 180),
              BeuiNotificationStack(
                items: _items,
                defaultExpanded: true,
                onViewAll: () => secondViews++,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final stacks = find.byType(BeuiNotificationStack);
      await tester.tapAt(tester.getCenter(stacks.at(0)));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(stacks.at(1)));
      await tester.pumpAndSettle();

      expect(firstViews, 1);
      expect(secondViews, 1);
    });

    testWidgets('disposing an expanded stack removes its overlay hit region', (
      tester,
    ) async {
      var viewAll = 0;
      await tester.pumpWidget(
        _wrap(
          Padding(
            padding: const EdgeInsets.only(top: 240),
            child: BeuiNotificationStack(
              items: _items,
              defaultExpanded: true,
              onViewAll: () => viewAll++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final host = tester.getRect(find.byType(BeuiNotificationStack));
      final oldOverflowPoint = find
          .text('New comment')
          .evaluate()
          .map((element) => tester.getRect(find.byWidget(element.widget)))
          .firstWhere((rect) => rect.top < host.top)
          .center;

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tapAt(oldOverflowPoint);
      await tester.pump();

      expect(viewAll, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('controlled tap requests expansion in source callback order', (
      tester,
    ) async {
      final requests = <bool>[];
      await tester.pumpWidget(
        _wrap(
          BeuiNotificationStack(
            items: _items,
            expanded: false,
            onExpandedChange: requests.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BeuiNotificationStack));
      await tester.pumpAndSettle();

      expect(requests, [true, true]);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('View all'), findsNothing);
    });

    testWidgets('rich card slots remeasure after width and content changes', (
      tester,
    ) async {
      Widget stack({required double width, required String detail}) => _wrap(
        SizedBox(
          width: width,
          child: BeuiNotificationStack(
            items: [
              BeuiNotificationStackItem(
                id: 'rich',
                title: 'Plain title for existing API',
                titleWidget: const Text('Rich title slot'),
                description: 'Plain description',
                descriptionWidget: Text(detail),
              ),
              const BeuiNotificationStackItem(
                id: 'other',
                title: 'Second card',
                description: 'A second description',
              ),
            ],
            defaultExpanded: true,
          ),
        ),
      );

      await tester.pumpWidget(stack(width: 320, detail: 'Short detail'));
      await tester.pumpAndSettle();
      expect(find.text('Rich title slot'), findsAtLeastNWidgets(1));
      expect(find.text('Short detail'), findsAtLeastNWidgets(1));

      await tester.pumpWidget(
        stack(
          width: 190,
          detail: List.filled(12, 'A wrapping rich description').join(' '),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Second card'), findsAtLeastNWidgets(1));
      expect(tester.getSize(find.byType(BeuiNotificationStack)).width, 190);
      expect(tester.takeException(), isNull);
    });

    testWidgets('semantics expose button and expanded state', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const BeuiNotificationStack(items: _items)),
      );
      await tester.pumpAndSettle();

      var data = tester
          .getSemantics(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label?.startsWith('3 notifications.') ==
                      true,
            ),
          )
          .getSemanticsData();
      expect(data.label, '3 notifications. Expand notifications.');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isExpanded, Tristate.isFalse);
      await tester.tap(find.byType(BeuiNotificationStack));
      await tester.pumpAndSettle();
      data = tester
          .getSemantics(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.label?.startsWith('3 notifications.') ==
                      true,
            ),
          )
          .getSemanticsData();
      expect(data.label, '3 notifications. View all.');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isExpanded, Tristate.isTrue);
      handle.dispose();
    });

    testWidgets('controlled expansion reports through onExpandedChange', (
      tester,
    ) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        _wrap(
          BeuiNotificationStack(
            items: _items,
            expanded: false,
            onExpandedChange: changes.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BeuiNotificationStack));
      await tester.pumpAndSettle();

      // Requested expansion, but the controlled value stayed false.
      expect(changes, contains(true));
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('View all'), findsNothing);
    });

    testWidgets('renders the empty resting state', (tester) async {
      await tester.pumpWidget(_wrap(const BeuiNotificationStack(items: [])));
      await tester.pumpAndSettle();

      expect(find.text('All caught up'), findsOneWidget);
      expect(find.byIcon(LucideIcons.bell_off), findsOneWidget);
      expect(find.text('Notifications'), findsNothing);
    });

    testWidgets('reduced motion still expands on tap without blur', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const BeuiNotificationStack(items: _items), reduce: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);
      final collapsedFooter = tester.getRect(find.text('Notifications'));
      final host = tester.getRect(find.byType(BeuiNotificationStack));

      await tester.tap(find.byType(BeuiNotificationStack));
      await tester.pump();
      expect(find.text('View all'), findsOneWidget);
      final expandedFooter = tester.getRect(find.text('View all'));
      double primaryTop() => find
          .text('Deploy finished')
          .evaluate()
          .map((element) => tester.getTopLeft(find.byWidget(element.widget)).dy)
          .reduce(math.min);
      final expandedTop = primaryTop();
      expect(expandedTop, lessThan(host.top));
      expect(
        expandedFooter.center.dy,
        moreOrLessEquals(collapsedFooter.center.dy, epsilon: 1),
      );
      await tester.pump(const Duration(milliseconds: 80));
      expect(primaryTop(), expandedTop);
      expect(tester.getRect(find.text('View all')), expandedFooter);
      await tester.pumpAndSettle();
      expect(primaryTop(), expandedTop);
      expect(maxBlurSigma(tester), 0);
    });
  });
}
