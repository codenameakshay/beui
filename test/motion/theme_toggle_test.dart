import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The switcher's surface in [_host] — the coordinate space the reveal clipper
/// is asked about below.
const _surface = Size(200, 200);

Widget _host({
  bool reduce = false,
  BeuiThemeRevealVariant variant = BeuiThemeRevealVariant.rectangle,
  BeuiThemeRevealStart start = BeuiThemeRevealStart.bottomUp,
}) {
  Widget switcher = BeuiThemeSwitcher(
    initialBrightness: Brightness.light,
    builder: (context, brightness) => ColoredBox(
      color: brightness == Brightness.dark ? Colors.black : Colors.white,
      child: Center(
        child: BeuiThemeToggle(variant: variant, start: start),
      ),
    ),
  );
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: _surface.width,
          height: _surface.height,
          child: reduce
              ? MediaQuery(
                  data: const MediaQueryData(disableAnimations: true),
                  child: switcher,
                )
              : switcher,
        ),
      ),
    ),
  );
}

/// Whether the **outgoing** snapshot still covers [point].
///
/// The overlay clips the old-theme snapshot to everything EXCEPT the reveal
/// shape, so `false` means "the reveal has opened here and the new theme is
/// showing through".
bool _stillCovered(WidgetTester tester, Offset point) {
  final clip = tester.widget<ClipPath>(find.byType(ClipPath).first);
  return clip.clipper!.getClip(_surface).contains(point);
}

/// Runs a blinds reveal to its mid-point and samples the clip across the full
/// 200px surface (three 72px tiles), then lets it settle.
Future<List<bool>> _blindsProfile(
  WidgetTester tester,
  BeuiThemeRevealStart start,
) async {
  await tester.pumpWidget(
    _host(variant: BeuiThemeRevealVariant.blinds, start: start),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(BeuiThemeToggle));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120)); // mid-reveal
  final profile = [
    for (var x = 4.0; x < _surface.width; x += 8)
      _stillCovered(tester, Offset(x, 100)),
  ];
  await tester.pumpAndSettle();
  return profile;
}

void main() {
  testWidgets('tapping the toggle flips the brightness', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    // Light → its job is to switch to dark.
    expect(find.bySemanticsLabel('Switch to dark mode'), findsOneWidget);

    await tester.tap(find.byType(BeuiThemeToggle));
    await tester.pumpAndSettle();

    // Now dark → its job is to switch back to light.
    expect(find.bySemanticsLabel('Switch to light mode'), findsOneWidget);
  });

  testWidgets('plays a clip-path reveal overlay, then clears it', (
    tester,
  ) async {
    await tester.pumpWidget(_host(variant: BeuiThemeRevealVariant.circle));
    await tester.pumpAndSettle();
    expect(find.byType(ClipPath), findsNothing); // nothing at rest

    await tester.tap(find.byType(BeuiThemeToggle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120)); // mid-reveal

    // The old-theme snapshot is painted under an animated ClipPath.
    expect(find.byType(RawImage), findsOneWidget);
    expect(find.byType(ClipPath), findsOneWidget);

    await tester.pumpAndSettle();
    // Reveal finished → overlay removed.
    expect(find.byType(RawImage), findsNothing);
    expect(find.byType(ClipPath), findsNothing);
  });

  testWidgets('circle-blur snapshots the incoming theme and blurs it (cached, '
      'not a live BackdropFilter)', (tester) async {
    await tester.pumpWidget(_host(variant: BeuiThemeRevealVariant.circleBlur));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Switch to dark mode'), findsOneWidget);

    await tester.tap(find.byType(BeuiThemeToggle));
    await tester.pump(); // toggle frame: outgoing snapshot covers, no blur yet
    await tester.pump(); // post-frame: incoming captured, reveal starts
    await tester.pump(const Duration(milliseconds: 120)); // mid-reveal

    // The live surface has ALREADY flipped to dark mid-reveal — the switch is
    // instant, not deferred to the end (the earlier frozen-snapshot bug).
    expect(find.bySemanticsLabel('Switch to light mode'), findsOneWidget);

    // Two snapshots: the outgoing (outside the circle) and the blurred incoming
    // (inside it). There is deliberately NO sharp frozen snapshot — the live
    // surface shows through the circle so its icon swaps in real time.
    expect(find.byType(RawImage), findsNWidgets(2));
    // The incoming blur is a static ImageFiltered (cached), never a live
    // BackdropFilter — that per-frame blur was the profile-build hang.
    expect(find.byType(ImageFiltered), findsAtLeastNWidgets(1));
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.pumpAndSettle();
    // Reveal finished → every snapshot layer is gone.
    expect(find.byType(RawImage), findsNothing);
  });

  testWidgets('the button is blocked while a reveal plays (View-Transition '
      'parity)', (tester) async {
    await tester.pumpWidget(_host()); // rectangle, starts light
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Switch to dark mode'), findsOneWidget);

    await tester.tap(find.byType(BeuiThemeToggle)); // → dark, reveal starts
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80)); // mid-reveal

    // Taps during the reveal are absorbed by the overlay — no extra flips.
    await tester.tap(find.byType(BeuiThemeToggle), warnIfMissed: false);
    await tester.tap(find.byType(BeuiThemeToggle), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Only the FIRST tap counted: one flip (light → dark). Had the mid-reveal
    // taps registered, an even count would have landed back on light.
    expect(find.bySemanticsLabel('Switch to light mode'), findsOneWidget);
    expect(find.byType(RawImage), findsNothing);
  });

  testWidgets('reduced motion switches instantly (no reveal overlay)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(reduce: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BeuiThemeToggle));
    await tester.pump();
    // No snapshot overlay — the brightness just flips.
    expect(find.byType(RawImage), findsNothing);

    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Switch to light mode'), findsOneWidget);
  });

  testWidgets('blinds opens one widening slat per 72px tile (shutter, not one '
      'connected shape)', (tester) async {
    await tester.pumpWidget(_host(variant: BeuiThemeRevealVariant.blinds));
    await tester.pumpAndSettle();
    expect(find.byType(ClipPath), findsNothing); // nothing at rest

    await tester.tap(find.byType(BeuiThemeToggle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120)); // mid-reveal

    // Same overlay mechanism as the other variants: one clipped snapshot.
    expect(find.byType(RawImage), findsOneWidget);
    expect(find.byType(ClipPath), findsOneWidget);

    // The leading edge of EVERY 72px tile has already opened …
    expect(_stillCovered(tester, const Offset(2, 100)), isFalse);
    expect(_stillCovered(tester, const Offset(74, 100)), isFalse);
    expect(_stillCovered(tester, const Offset(146, 100)), isFalse);
    // … while the trailing edge of every tile is still shut. That alternation
    // is the shutter — a rectangle/circle reveal is one connected shape and
    // could never produce a closed band at x=70 next to an open one at x=74.
    expect(_stillCovered(tester, const Offset(70, 100)), isTrue);
    expect(_stillCovered(tester, const Offset(142, 100)), isTrue);

    await tester.pumpAndSettle();
    // Fully open (each slat reaches its full tile) → overlay torn down.
    expect(find.byType(RawImage), findsNothing);
    expect(find.byType(ClipPath), findsNothing);
    expect(find.bySemanticsLabel('Switch to light mode'), findsOneWidget);
  });

  testWidgets('blinds slats repeat per tile and ignore `start` (source sets no '
      '--beui-vt-origin for it)', (tester) async {
    final fromBottom = await _blindsProfile(
      tester,
      BeuiThemeRevealStart.bottomUp,
    );
    final fromTopLeft = await _blindsProfile(
      tester,
      BeuiThemeRevealStart.topLeft,
    );

    // The origin prop is inert for blinds.
    expect(fromTopLeft, fromBottom);
    // Sanity: the sample really did catch a partly-open reveal.
    expect(fromBottom, contains(true));
    expect(fromBottom, contains(false));
    // Tile-periodic: x and x+72 behave the same (9 samples of 8px per tile).
    for (var i = 0; i + 9 < fromBottom.length; i++) {
      expect(
        fromBottom[i],
        fromBottom[i + 9],
        reason: 'sample $i differs from the same offset one tile over',
      );
    }
  });

  testWidgets("blinds runs the source 700ms window, not rectangle's 400ms", (
    tester,
  ) async {
    await tester.pumpWidget(_host(variant: BeuiThemeRevealVariant.blinds));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BeuiThemeToggle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 410));
    // A rectangle reveal would already have torn its overlay down by now.
    expect(find.byType(RawImage), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(RawImage), findsNothing);
  });

  testWidgets('reduced motion skips the blinds reveal entirely', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(reduce: true, variant: BeuiThemeRevealVariant.blinds),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BeuiThemeToggle));
    await tester.pump();
    expect(find.byType(RawImage), findsNothing);
    expect(find.byType(ClipPath), findsNothing);

    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Switch to light mode'), findsOneWidget);
  });
}
