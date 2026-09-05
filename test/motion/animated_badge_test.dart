import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

/// The color of the leading [Icon] glyph inside a badge.
Color? _iconColor(WidgetTester tester) {
  final icon = tester.widget<Icon>(
    find.descendant(
      of: find.byType(BeuiAnimatedBadge),
      matching: find.byType(Icon),
    ),
  );
  return icon.color;
}

/// The set of icon codepoints currently rendered in a badge (may be >1 mid
/// swap, since the popLayout switcher stacks the outgoing + incoming glyph).
Set<int> _iconCodePoints(WidgetTester tester) {
  return tester
      .widgetList<Icon>(
        find.descendant(
          of: find.byType(BeuiAnimatedBadge),
          matching: find.byType(Icon),
        ),
      )
      .map((i) => i.icon!.codePoint)
      .toSet();
}

void main() {
  group('BeuiAnimatedBadge', () {
    testWidgets('renders the status default icon and label', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiAnimatedBadge(
            status: BeuiAnimatedBadgeStatus.success,
            label: 'Synced',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Synced'), findsOneWidget);
      expect(
        _iconCodePoints(tester),
        contains(BeuiAnimatedBadgeStatus.success.icon.codePoint),
      );
    });

    testWidgets('status change swaps the icon and the color', (tester) async {
      Widget app(BeuiAnimatedBadgeStatus s) =>
          beuiTestApp(BeuiAnimatedBadge(status: s, label: 'X'));

      await tester.pumpWidget(app(BeuiAnimatedBadgeStatus.neutral));
      await tester.pumpAndSettle();
      final neutralColor = _iconColor(tester);
      expect(
        _iconCodePoints(tester),
        contains(BeuiAnimatedBadgeStatus.neutral.icon.codePoint),
      );

      await tester.pumpWidget(app(BeuiAnimatedBadgeStatus.danger));
      await tester.pumpAndSettle();
      final dangerColor = _iconColor(tester);
      expect(
        _iconCodePoints(tester),
        contains(BeuiAnimatedBadgeStatus.danger.icon.codePoint),
      );

      // Color cross-faded to a different foreground (neutral muted -> danger).
      expect(dangerColor, isNot(neutralColor));
    });

    testWidgets('an override icon replaces the status default', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiAnimatedBadge(
            status: BeuiAnimatedBadgeStatus.info,
            icon: LucideIcons.star,
            label: 'Custom',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_iconCodePoints(tester), contains(LucideIcons.star.codePoint));
      expect(
        _iconCodePoints(tester),
        isNot(contains(BeuiAnimatedBadgeStatus.info.icon.codePoint)),
      );
    });

    testWidgets('loading pulses (a spinning RotationTransition is present)', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiAnimatedBadge(
            status: BeuiAnimatedBadgeStatus.loading,
            label: 'Working',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // Pulse ring breathes via an AnimatedBuilder-driven Opacity; the spinner
      // is a RotationTransition. Both are movement, present only under motion.
      expect(
        find.descendant(
          of: find.byType(BeuiAnimatedBadge),
          matching: find.byType(RotationTransition),
        ),
        findsAtLeastNWidgets(1),
      );
      await tester.pump(const Duration(milliseconds: 800)); // let it spin/pulse
    });

    testWidgets('pulse defaults off for non-loading statuses', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiAnimatedBadge(
            status: BeuiAnimatedBadgeStatus.success,
            label: 'Done',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BeuiAnimatedBadge),
          matching: find.byType(RotationTransition),
        ),
        findsNothing,
      );
    });

    testWidgets('pulse can be forced on for any status', (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiAnimatedBadge(
            status: BeuiAnimatedBadgeStatus.success,
            label: 'Done',
            pulse: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // The pulse ring breathes between opacity 0.08 and 0.16 — the lowest
      // Opacity in the badge. It must change across frames.
      double ringOpacity() => tester
          .widgetList<Opacity>(
            find.descendant(
              of: find.byType(BeuiAnimatedBadge),
              matching: find.byType(Opacity),
            ),
          )
          .map((o) => o.opacity)
          .fold<double>(1, math.min);
      final first = ringOpacity();
      await tester.pump(const Duration(milliseconds: 400));
      final second = ringOpacity();
      expect(first, lessThan(0.5)); // it's the faint pulse ring
      expect(first, isNot(second)); // breathing
    });

    testWidgets('the icon swap applies a visible blur under normal motion', (
      tester,
    ) async {
      Widget app(BeuiAnimatedBadgeStatus s) =>
          beuiTestApp(BeuiAnimatedBadge(status: s, label: 'X'));
      await tester.pumpWidget(app(BeuiAnimatedBadgeStatus.neutral));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(BeuiAnimatedBadgeStatus.success));
      await tester.pump(const Duration(milliseconds: 40)); // mid roll
      final sigmas = tester
          .widgetList<ImageFiltered>(find.byType(ImageFiltered))
          .map((f) {
            final m = RegExp(
              r'blur\(([\d.]+)',
            ).firstMatch(f.imageFilter.toString());
            return m == null ? 0.0 : double.parse(m.group(1)!);
          });
      expect(sigmas.fold<double>(0, math.max), greaterThan(1.0));
    });

    testWidgets('reduced motion drops movement (no roll blur, no pulse)', (
      tester,
    ) async {
      Widget app(BeuiAnimatedBadgeStatus s) =>
          beuiTestApp(BeuiAnimatedBadge(status: s, label: 'X'), reduce: true);
      await tester.pumpWidget(app(BeuiAnimatedBadgeStatus.neutral));
      await tester.pumpAndSettle();

      // Swap the status: under reduced motion the roll/blur must not appear.
      await tester.pumpWidget(app(BeuiAnimatedBadgeStatus.danger));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 30));
        final maxBlur = tester
            .widgetList<ImageFiltered>(find.byType(ImageFiltered))
            .map((f) {
              final m = RegExp(
                r'blur\(([\d.]+)',
              ).firstMatch(f.imageFilter.toString());
              return m == null ? 0.0 : double.parse(m.group(1)!);
            })
            .fold<double>(0, math.max);
        expect(maxBlur, lessThan(0.5)); // no roll blur under reduced motion
      }
      // The color still updated (cross-fade is preserved under reduced motion).
      expect(
        _iconCodePoints(tester),
        contains(BeuiAnimatedBadgeStatus.danger.icon.codePoint),
      );
    });

    testWidgets('reduced motion loading has no spinner movement', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiAnimatedBadge(
            status: BeuiAnimatedBadgeStatus.loading,
            label: 'Working',
          ),
          reduce: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BeuiAnimatedBadge),
          matching: find.byType(RotationTransition),
        ),
        findsNothing,
      );
    });

    testWidgets('exposes a live-region for status announcements', (
      tester,
    ) async {
      await tester.pumpWidget(
        beuiTestApp(
          const BeuiAnimatedBadge(
            status: BeuiAnimatedBadgeStatus.info,
            label: 'Live',
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The badge wraps its content in a liveRegion Semantics so a screen
      // reader announces status changes (source `aria-live="polite"`).
      final live = find.descendant(
        of: find.byType(BeuiAnimatedBadge),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.liveRegion ?? false),
        ),
      );
      expect(live, findsOneWidget);
    });
  });

  group('roll direction (source: old up and out, new from below)', () {
    List<double> badgeTranslateYs(WidgetTester tester) => tester
        .widgetList<Transform>(
          find.descendant(
            of: find.byType(BeuiAnimatedBadge),
            matching: find.byType(Transform),
          ),
        )
        .map((w) => w.transform.getTranslation().y)
        .where((y) => y.abs() > 0.5)
        .toList();

    testWidgets('mid-swap, one layer rolls UP (exit) and one comes from BELOW', (
      tester,
    ) async {
      // Constant non-loading status (no spinner/pulse); only the label changes,
      // so the roll under test is isolated.
      Widget app(String l) => beuiTestApp(
        BeuiAnimatedBadge(status: BeuiAnimatedBadgeStatus.neutral, label: l),
      );
      await tester.pumpWidget(app('Alpha'));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.pumpWidget(app('Bravo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120)); // mid-roll

      expect(find.text('Alpha'), findsOneWidget); // old still present
      expect(find.text('Bravo'), findsOneWidget); // new present
      final ys = badgeTranslateYs(tester);
      // The buggy version rolled BOTH layers down (all positive). The fix rolls
      // the exiting layer UP (negative) and the entering one from BELOW (positive).
      expect(ys.any((y) => y < 0), isTrue, reason: 'a layer rolls up and out');
      expect(ys.any((y) => y > 0), isTrue, reason: 'a layer enters from below');

      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('the exiting layer fades to 0.5, not 0 (source endpoint)', (
      tester,
    ) async {
      Widget app(String l) => beuiTestApp(
        BeuiAnimatedBadge(status: BeuiAnimatedBadgeStatus.neutral, label: l),
      );
      await tester.pumpWidget(app('Alpha'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(app('Bravo'));
      await tester.pump();
      // Late in the 200ms text exit: opacity has bottomed out near its 0.5
      // floor but the ghost is still mounted.
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('Alpha'), findsOneWidget);
      final exitOpacity = tester.widget<Opacity>(
        find
            .ancestor(of: find.text('Alpha'), matching: find.byType(Opacity))
            .first,
      );
      expect(exitOpacity.opacity, greaterThanOrEqualTo(0.5));
      expect(exitOpacity.opacity, lessThan(0.75));

      // The entering layer never starts from 0 either (source: 0.76 → 1).
      final enterOpacity = tester.widget<Opacity>(
        find
            .ancestor(of: find.text('Bravo'), matching: find.byType(Opacity))
            .first,
      );
      expect(enterOpacity.opacity, greaterThanOrEqualTo(0.72));

      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsNothing); // removed after the exit
    });
  });

  group('width morph (source layout spring)', () {
    testWidgets('the container width springs to fit a new label', (
      tester,
    ) async {
      Widget app(String l) => beuiTestApp(
        BeuiAnimatedBadge(status: BeuiAnimatedBadgeStatus.neutral, label: l),
      );
      await tester.pumpWidget(app('Hi'));
      await tester.pumpAndSettle();
      final small = tester.getSize(find.byType(BeuiAnimatedBadge)).width;

      await tester.pumpWidget(app('A much longer label'));
      await tester.pump(); // swap frame (post-frame width measurement lands)
      await tester.pump(); // spring retargets to the measured width
      await tester.pump(const Duration(milliseconds: 60)); // mid-morph
      final mid = tester.getSize(find.byType(BeuiAnimatedBadge)).width;

      await tester.pumpAndSettle();
      final big = tester.getSize(find.byType(BeuiAnimatedBadge)).width;

      expect(big, greaterThan(small + 20)); // longer label → wider badge
      expect(mid, greaterThan(small + 1)); // gliding, not snapped...
      expect(mid, lessThan(big - 1)); // ...and not there yet
    });

    testWidgets('reduced motion snaps the width', (tester) async {
      Widget app(String l) => beuiTestApp(
        BeuiAnimatedBadge(status: BeuiAnimatedBadgeStatus.neutral, label: l),
        reduce: true,
      );
      await tester.pumpWidget(app('Hi'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(app('A much longer label'));
      // The swap frame itself (plus the old label still cross-fading out under
      // reduced motion does not hold the width — exits are lifted from flow).
      await tester.pump(const Duration(milliseconds: 450));
      final after = tester.getSize(find.byType(BeuiAnimatedBadge)).width;
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(BeuiAnimatedBadge)).width,
        closeTo(after, 0.5),
      );
    });
  });
}
