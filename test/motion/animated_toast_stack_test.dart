import 'package:beui/beui.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

Widget _wrap(Widget child, {bool reduce = false}) =>
    beuiTestApp(child, alignment: Alignment.bottomRight, reduce: reduce);

BeuiToast _toast(
  String id, {
  String? title,
  String? description,
  BeuiToastStatus status = BeuiToastStatus.neutral,
  BeuiToastAction? action,
  bool dismissible = true,
}) => BeuiToast(
  id: id,
  title: title ?? 'Toast $id',
  description: description,
  status: status,
  action: action,
  dismissible: dismissible,
);

final Finder _closeButton = find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == 'Dismiss toast',
);

void main() {
  group('BeuiToastController', () {
    test('show adds a toast and returns its id', () {
      final c = BeuiToastController();
      final id = c.show(title: 'Saved');
      expect(c.toasts, hasLength(1));
      expect(c.toasts.single.id, id);
      expect(c.toasts.single.title, 'Saved');
      c.dispose();
    });

    test('dismiss removes and clear empties', () {
      final c = BeuiToastController();
      final a = c.show(title: 'A');
      c.show(title: 'B');
      c.dismiss(a);
      expect(c.toasts.map((t) => t.title), ['B']);
      c.clear();
      expect(c.toasts, isEmpty);
      c.dispose();
    });

    test('limit drops the oldest toasts (source slice(-limit))', () {
      final c = BeuiToastController(limit: 2);
      c.show(title: 'A');
      c.show(title: 'B');
      c.show(title: 'C');
      expect(c.toasts.map((t) => t.title), ['B', 'C']);
      c.dispose();
    });

    test('update patches fields in place', () {
      final c = BeuiToastController();
      final id = c.show(title: 'Working', status: BeuiToastStatus.loading);
      c.update(id, title: 'Done', status: BeuiToastStatus.success);
      expect(c.toasts.single.title, 'Done');
      expect(c.toasts.single.status, BeuiToastStatus.success);
      c.dispose();
    });

    test('auto-dismisses after its duration (default 4200ms)', () {
      fakeAsync((async) {
        final c = BeuiToastController();
        c.show(title: 'Bye');
        async.elapse(const Duration(milliseconds: 4100));
        expect(c.toasts, hasLength(1));
        async.elapse(const Duration(milliseconds: 200));
        expect(c.toasts, isEmpty);
        c.dispose();
      });
    });

    test('Duration.zero means sticky (no auto-dismiss)', () {
      fakeAsync((async) {
        final c = BeuiToastController();
        c.show(title: 'Pinned', duration: Duration.zero);
        async.elapse(const Duration(seconds: 30));
        expect(c.toasts, hasLength(1));
        c.dispose();
      });
    });

    test('updating duration re-arms the timer (source resets createdAt)', () {
      fakeAsync((async) {
        final c = BeuiToastController(
          defaultDuration: const Duration(seconds: 2),
        );
        final id = c.show(title: 'Long job');
        async.elapse(const Duration(milliseconds: 1500));
        c.update(id, duration: const Duration(seconds: 2));
        async.elapse(const Duration(milliseconds: 1900));
        expect(c.toasts, hasLength(1), reason: 'timer restarted on update');
        async.elapse(const Duration(milliseconds: 200));
        expect(c.toasts, isEmpty);
        c.dispose();
      });
    });

    test('notifies listeners on show/update/dismiss', () {
      final c = BeuiToastController();
      var ticks = 0;
      c.addListener(() => ticks++);
      final id = c.show(title: 'A');
      c.update(id, title: 'B');
      c.dismiss(id);
      expect(ticks, 3);
      c.dispose();
    });
  });

  group('BeuiAnimatedToastStack', () {
    testWidgets('renders title, description and the status default icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedToastStack(
            toasts: [
              _toast(
                'a',
                title: 'Payment sent',
                description: 'It may take a minute.',
                status: BeuiToastStatus.success,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Payment sent'), findsOneWidget);
      expect(find.text('It may take a minute.'), findsOneWidget);
      final icons = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((i) => i.icon)
          .toList();
      expect(icons, contains(BeuiToastStatus.success.icon));
    });

    testWidgets('maxVisible caps the rendered toasts to the newest', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedToastStack(
            maxVisible: 2,
            toasts: [for (var i = 0; i < 4; i++) _toast('$i')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Toast 0'), findsNothing);
      expect(find.text('Toast 1'), findsNothing);
      expect(find.text('Toast 2'), findsOneWidget);
      expect(find.text('Toast 3'), findsOneWidget);
    });

    testWidgets('close button reports onDismiss with the toast id', (
      tester,
    ) async {
      final dismissed = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedToastStack(
            toasts: [_toast('a')],
            onDismiss: dismissed.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(_closeButton);
      expect(dismissed, ['a']);
    });

    testWidgets('non-dismissible toasts render no close button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedToastStack(
            toasts: [_toast('a', dismissible: false)],
            onDismiss: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_closeButton, findsNothing);
    });

    testWidgets('action button fires with the toast', (tester) async {
      BeuiToast? acted;
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedToastStack(
            toasts: [
              _toast(
                'a',
                action: BeuiToastAction(
                  label: 'Undo',
                  onPressed: (t) {
                    acted = t;
                  },
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      expect(acted?.id, 'a');
    });

    testWidgets('a new toast enters with a blur that settles away', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(BeuiAnimatedToastStack(toasts: [])));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _wrap(BeuiAnimatedToastStack(toasts: [_toast('a')])),
      );
      await tester.pump(const Duration(milliseconds: 30)); // mid-enter
      expect(maxBlurSigma(tester), greaterThan(1.0));

      await tester.pumpAndSettle();
      expect(maxBlurSigma(tester), lessThan(0.5));
      expect(find.text('Toast a'), findsOneWidget);
    });

    testWidgets('a removed toast animates out before unmounting', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(BeuiAnimatedToastStack(toasts: [_toast('a'), _toast('b')])),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _wrap(BeuiAnimatedToastStack(toasts: [_toast('b')])),
      );
      await tester.pump(const Duration(milliseconds: 60)); // mid-exit
      expect(find.text('Toast a'), findsOneWidget, reason: 'still exiting');

      await tester.pumpAndSettle();
      expect(find.text('Toast a'), findsNothing);
      expect(find.text('Toast b'), findsOneWidget);
    });

    testWidgets('a status update swaps the slot icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedToastStack(
            toasts: [_toast('a', status: BeuiToastStatus.loading)],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedToastStack(
            toasts: [_toast('a', status: BeuiToastStatus.success)],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final icons = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((i) => i.icon)
          .toList();
      expect(icons, contains(BeuiToastStatus.success.icon));
      expect(icons, isNot(contains(BeuiToastStatus.loading.icon)));
    });

    testWidgets('swiping past the threshold dismisses', (tester) async {
      final dismissed = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedToastStack(
            toasts: [_toast('a')],
            onDismiss: dismissed.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.text('Toast a'), const Offset(140, 0));
      await tester.pump();
      expect(dismissed, ['a']);
    });

    testWidgets('a short swipe springs back without dismissing', (
      tester,
    ) async {
      final dismissed = <String>[];
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedToastStack(
            toasts: [_toast('a')],
            onDismiss: dismissed.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Toast a')),
      );
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(dismissed, isEmpty);
      expect(find.text('Toast a'), findsOneWidget);
    });

    testWidgets('bottom positions stack the oldest toast nearest the edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(BeuiAnimatedToastStack(toasts: [_toast('old'), _toast('new')])),
      );
      await tester.pumpAndSettle();
      final oldY = tester.getCenter(find.text('Toast old')).dy;
      final newY = tester.getCenter(find.text('Toast new')).dy;
      // Source: flex-col-reverse — first (oldest) item sits at the bottom edge,
      // new toasts stack upward above it.
      expect(oldY, greaterThan(newY));
    });

    testWidgets('top positions stack the oldest toast at the top', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedToastStack(
            position: BeuiToastPosition.topRight,
            toasts: [_toast('old'), _toast('new')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final oldY = tester.getCenter(find.text('Toast old')).dy;
      final newY = tester.getCenter(find.text('Toast new')).dy;
      expect(oldY, lessThan(newY));
    });

    testWidgets('reduced motion enters with a plain fade (no blur)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(BeuiAnimatedToastStack(toasts: []), reduce: true),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _wrap(BeuiAnimatedToastStack(toasts: [_toast('a')]), reduce: true),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        expect(maxBlurSigma(tester), lessThan(0.5));
      }
      await tester.pumpAndSettle();
      expect(find.text('Toast a'), findsOneWidget);
    });

    testWidgets(
      'reduced motion disables swipe-to-dismiss (source drag=false)',
      (tester) async {
        final dismissed = <String>[];
        await tester.pumpWidget(
          _wrap(
            BeuiAnimatedToastStack(
              toasts: [_toast('a')],
              onDismiss: dismissed.add,
            ),
            reduce: true,
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(
          find.text('Toast a'),
          const Offset(140, 0),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        expect(dismissed, isEmpty);
      },
    );

    testWidgets('exposes a polite live region', (tester) async {
      await tester.pumpWidget(
        _wrap(BeuiAnimatedToastStack(toasts: [_toast('a')])),
      );
      await tester.pumpAndSettle();
      final live = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.liveRegion ?? false),
      );
      expect(live, findsAtLeastNWidgets(1));
    });
  });
}
