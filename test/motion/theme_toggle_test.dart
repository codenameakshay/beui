import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  bool reduce = false,
  BeuiThemeRevealVariant variant = BeuiThemeRevealVariant.rectangle,
}) {
  Widget switcher = BeuiThemeSwitcher(
    initialBrightness: Brightness.light,
    builder: (context, brightness) => ColoredBox(
      color: brightness == Brightness.dark ? Colors.black : Colors.white,
      child: Center(child: BeuiThemeToggle(variant: variant)),
    ),
  );
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 200,
          height: 200,
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
}
