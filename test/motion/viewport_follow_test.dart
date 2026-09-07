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

import '../support.dart';

Widget _host(Widget child, {BeuiAgentTheme? agent, bool reduce = false}) =>
    beuiTestApp(child, width: 400, reduce: reduce, extensions: [?agent]);

/// The painted ring inside [BeuiFocusRing]: unlike the pill's own bordered
/// background, it is the only [DecoratedBox] wrapped in an [Opacity] (the
/// ring's fade), so scoping through that ancestor distinguishes it from the
/// pill's own border. Only present while focused.
Finder _ringBorder() => find.descendant(
  of: find.descendant(
    of: find.byType(BeuiFocusRing),
    matching: find.byType(Opacity),
  ),
  matching: find.byType(DecoratedBox),
);

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
      expect(_ringBorder(), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(_ringBorder(), findsOneWidget);
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
