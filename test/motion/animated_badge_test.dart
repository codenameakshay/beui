import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
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
        _wrap(
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

    testWidgets('renders every status', (tester) async {
      for (final status in BeuiAnimatedBadgeStatus.values) {
        await tester.pumpWidget(
          _wrap(BeuiAnimatedBadge(status: status, label: status.name)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(BeuiAnimatedBadge), findsOneWidget);
      }
    });

    testWidgets('status change swaps the icon and the color', (tester) async {
      Widget app(BeuiAnimatedBadgeStatus s) =>
          _wrap(BeuiAnimatedBadge(status: s, label: 'X'));

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
        _wrap(
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
        _wrap(
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
        _wrap(
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
        _wrap(
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
          _wrap(BeuiAnimatedBadge(status: s, label: 'X'));
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
          _wrap(BeuiAnimatedBadge(status: s, label: 'X'), reduce: true);
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
        _wrap(
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
        _wrap(
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
      Widget app(String l) => _wrap(
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
  });
}
