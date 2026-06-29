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
