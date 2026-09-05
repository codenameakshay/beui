import 'package:beui/beui.dart';
// The shared live-edge affordance is package-internal — it is an implementation
// detail of BeuiCodeBlock / BeuiFileDiff / BeuiToolResult, but its *contract*
// is what these tests pin.
import 'package:beui/src/motion/_focus_ring.dart' show BeuiFocusRing;
import 'package:beui/src/motion/_viewport_follow.dart'
    show BeuiHiddenContentFooter, BeuiJumpToLatest;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {BeuiAgentTheme? agent, bool reduce = false}) {
  Widget body = Center(child: SizedBox(width: 400, child: child));
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
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light(), ?agent]),
    ),
    home: Scaffold(body: body),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BeuiJumpToLatest copy resolves through the theme', () {
    testWidgets('defaults to strings.jumpToLatest', (tester) async {
      await tester.pumpWidget(
        _host(BeuiJumpToLatest(visible: true, onTap: () {})),
      );
      await tester.pumpAndSettle();
      expect(find.text(const BeuiAgentStrings().jumpToLatest), findsOneWidget);
    });

    testWidgets('a theme override reaches the visible text and the tooltip', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          BeuiJumpToLatest(visible: true, onTap: () {}),
          agent: const BeuiAgentTheme(
            strings: BeuiAgentStrings(jumpToLatest: 'Aller au plus récent'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Aller au plus récent'), findsOneWidget);
      expect(find.text('Jump to latest'), findsNothing);
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Aller au plus récent');
      // The Semantics label already names the control; the tooltip must not
      // make a reader say it twice.
      expect(tooltip.excludeFromSemantics, isTrue);
    });

    testWidgets('an explicit label still wins over the theme', (tester) async {
      await tester.pumpWidget(
        _host(
          BeuiJumpToLatest(
            visible: true,
            label: 'Back to the live edge',
            onTap: () {},
          ),
          agent: const BeuiAgentTheme(
            strings: BeuiAgentStrings(jumpToLatest: 'Aller au plus récent'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Back to the live edge'), findsOneWidget);
    });
  });

  group('BeuiJumpToLatest is operable from the keyboard', () {
    testWidgets('Enter activates it', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(BeuiJumpToLatest(visible: true, onTap: () => taps++)),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('Space activates it too', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(BeuiJumpToLatest(visible: true, onTap: () => taps++)),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('focusing it raises the library focus ring', (tester) async {
      await tester.pumpWidget(
        _host(BeuiJumpToLatest(visible: true, onTap: () {})),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<BeuiFocusRing>(find.byType(BeuiFocusRing)).focused,
        isFalse,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        tester.widget<BeuiFocusRing>(find.byType(BeuiFocusRing)).focused,
        isTrue,
      );
    });
  });

  group('BeuiJumpToLatest goes quiet when hidden', () {
    testWidgets(
      'a pill on its way out is neither tappable nor offered to a reader',
      (tester) async {
        var taps = 0;
        bool excluding() => tester
            .widget<ExcludeSemantics>(
              find
                  .descendant(
                    of: find.byType(BeuiJumpToLatest),
                    matching: find.byType(ExcludeSemantics),
                  )
                  .first,
            )
            .excluding;
        bool ignoring() => tester
            .widget<IgnorePointer>(
              find
                  .descendant(
                    of: find.byType(BeuiJumpToLatest),
                    matching: find.byType(IgnorePointer),
                  )
                  .first,
            )
            .ignoring;

        await tester.pumpWidget(
          _host(BeuiJumpToLatest(visible: true, onTap: () => taps++)),
        );
        await tester.pumpAndSettle();
        expect(excluding(), isFalse);
        expect(ignoring(), isFalse);

        await tester.pumpWidget(
          _host(BeuiJumpToLatest(visible: false, onTap: () => taps++)),
        );
        // One frame into the exit: still painted, already silent and inert, so
        // a reader is never offered a control on its way out.
        await tester.pump(const Duration(milliseconds: 20));
        expect(
          find.text(const BeuiAgentStrings().jumpToLatest),
          findsOneWidget,
        );
        expect(excluding(), isTrue);
        expect(ignoring(), isTrue);

        await tester.pumpAndSettle();
        expect(taps, 0);
      },
    );
  });

  group('BeuiHiddenContentFooter copy resolves through the theme', () {
    testWidgets('a theme override reaches the count', (tester) async {
      final extent = ValueNotifier<double>(60);
      addTearDown(extent.dispose);
      await tester.pumpWidget(
        _host(
          SizedBox(
            height: 40,
            child: BeuiHiddenContentFooter(
              extentBelow: extent,
              rowExtent: 20,
              surface: const Color(0xFFFFFFFF),
            ),
          ),
          agent: BeuiAgentTheme(
            strings: BeuiAgentStrings(hiddenLines: (n) => 'encore $n lignes'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('encore 3 lignes'), findsOneWidget);
    });

    testWidgets('the count sits inside the fade, occluding no extra row', (
      tester,
    ) async {
      final extent = ValueNotifier<double>(60);
      addTearDown(extent.dispose);
      await tester.pumpWidget(
        _host(
          SizedBox(
            height: 100,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: BeuiHiddenContentFooter(
                extentBelow: extent,
                rowExtent: 20,
                surface: const Color(0xFFFFFFFF),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The whole cue is the fade band and nothing more — it used to add an
      // opaque strip below it, over a still-legible last row.
      expect(tester.getSize(find.byType(BeuiHiddenContentFooter)).height, 32);
    });
  });
}
