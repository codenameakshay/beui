import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motor/motor.dart';

// A finished 3-round draw (4 → 2 → 1), so the hub carries a champion and the
// winning run is lit at rest. Node count is 1 + 2 + 4 + 8 = 15: the hub, a ring
// per round, and the quarter-finalists themselves on the rim.
const _alpha = BeuiTeam(name: 'Alpha');
const _bravo = BeuiTeam(name: 'Bravo');
const _delta = BeuiTeam(name: 'Delta');
const _echo = BeuiTeam(name: 'Echo');
const _foxtrot = BeuiTeam(name: 'Foxtrot');
const _golf = BeuiTeam(name: 'Golf');
const _hotel = BeuiTeam(name: 'Hotel');
const _india = BeuiTeam(name: 'India');

BeuiMatch _m(
  String id,
  BeuiTeam home,
  int homeScore,
  BeuiTeam away,
  int awayScore,
) => BeuiMatch(
  id: id,
  status: BeuiMatchStatus.finished,
  home: BeuiMatchSide(team: home, score: homeScore),
  away: BeuiMatchSide(team: away, score: awayScore),
  winner: homeScore > awayScore ? BeuiMatchWinner.home : BeuiMatchWinner.away,
);

List<BeuiBracketRound> _draw() => [
  BeuiBracketRound(
    name: 'Quarter-finals',
    matches: [
      _m('qf1', _alpha, 2, _bravo, 1),
      _m('qf2', _delta, 0, _echo, 3),
      _m('qf3', _foxtrot, 1, _golf, 0),
      _m('qf4', _hotel, 2, _india, 4),
    ],
  ),
  BeuiBracketRound(
    name: 'Semi-finals',
    matches: [
      _m('sf1', _alpha, 1, _echo, 0),
      _m('sf2', _foxtrot, 2, _india, 3),
    ],
  ),
  BeuiBracketRound(name: 'Final', matches: [_m('f1', _alpha, 2, _india, 1)]),
];

const _hubCaption = 'Final · Alpha v India · 2–1';
const _sf1Caption = 'Semi-finals · Alpha v Echo · 1–0';
const _sf2Caption = 'Semi-finals · Foxtrot v India · 2–3';

/// The stage holds a 32rem floor, so the view has to clear it or the wheel pans.
void _sizeView(WidgetTester tester, {Size size = const Size(1000, 1000)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _app({
  required List<BeuiBracketRound> rounds,
  int initialRound = 0,
  bool reduce = false,
}) {
  Widget child = BeuiKnockoutWheel(rounds: rounds, initialRound: initialRound);
  if (reduce) {
    final inner = child;
    child = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: child),
  );
}

/// Marks and connectors enter ring by ring on a 60ms-per-ring stagger, so a
/// settled wheel is a pump past the deepest ring plus the spring settle.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

void main() {
  group('BeuiKnockoutWheel structure', () {
    testWidgets(
      'lays a mark on the hub, one ring per round, teams on the rim',
      (tester) async {
        _sizeView(tester);
        await tester.pumpWidget(_app(rounds: _draw()));
        await _settle(tester);

        // 1 hub + 2 semis + 4 quarters + 8 rim teams.
        expect(find.byType(FocusableActionDetector), findsNWidgets(15));
        // The hub reads the final; a rim node is just its team.
        expect(find.bySemanticsLabel(_hubCaption), findsOneWidget);
        expect(find.bySemanticsLabel(_sf1Caption), findsOneWidget);
        expect(
          find.bySemanticsLabel('Quarter-finals · Alpha v Bravo · 2–1'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Bravo'), findsOneWidget);
      },
    );

    testWidgets('names the champion on the wheel itself', (tester) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _draw()));
      await _settle(tester);
      expect(
        find.bySemanticsLabel('Tournament wheel, won by Alpha'),
        findsOneWidget,
      );
    });

    testWidgets('an undecided final leaves the hub empty', (tester) async {
      _sizeView(tester);
      final rounds = [
        BeuiBracketRound(
          name: 'Semi-finals',
          matches: [
            _m('sf1', _alpha, 1, _echo, 0),
            _m('sf2', _foxtrot, 2, _india, 3),
          ],
        ),
        const BeuiBracketRound(
          name: 'Final',
          matches: [
            BeuiMatch(
              id: 'f1',
              status: BeuiMatchStatus.upcoming,
              home: BeuiMatchSide(team: _alpha),
              away: BeuiMatchSide(team: _india),
            ),
          ],
        ),
      ];
      await tester.pumpWidget(_app(rounds: rounds));
      await _settle(tester);

      expect(find.bySemanticsLabel('Tournament wheel'), findsOneWidget);
      // No winner on the final, so the hub is a TBD slot with the same shield
      // the bracket draws for an unresolved side.
      expect(find.bySemanticsLabel('TBD'), findsOneWidget);
    });

    testWidgets('renders nothing for an empty draw', (tester) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: const []));
      await _settle(tester);
      expect(find.byType(FocusableActionDetector), findsNothing);
    });
  });

  group('BeuiKnockoutWheel round paging (initialRound)', () {
    testWidgets('drops the outer rounds and re-rims on the kept round', (
      tester,
    ) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _draw(), initialRound: 1));
      await _settle(tester);

      // Semi-finals + Final only: 1 hub + 2 semis + 4 rim teams.
      expect(find.byType(FocusableActionDetector), findsNWidgets(7));
      expect(find.bySemanticsLabel(_sf1Caption), findsOneWidget);
      expect(
        find.bySemanticsLabel('Quarter-finals · Alpha v Bravo · 2–1'),
        findsNothing,
      );
      // The kept round's own teams became the rim.
      expect(find.bySemanticsLabel('Echo'), findsOneWidget);
      expect(find.bySemanticsLabel('Bravo'), findsNothing);
    });

    testWidgets('is clamped to the valid range', (tester) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _draw(), initialRound: 99));
      await _settle(tester);
      // Clamped to the last round: the final plus its two teams.
      expect(find.byType(FocusableActionDetector), findsNWidgets(3));
      expect(find.bySemanticsLabel(_hubCaption), findsOneWidget);
    });

    testWidgets('re-pages when initialRound changes', (tester) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _draw()));
      await _settle(tester);
      expect(find.byType(FocusableActionDetector), findsNWidgets(15));

      await tester.pumpWidget(_app(rounds: _draw(), initialRound: 1));
      await _settle(tester);
      expect(find.byType(FocusableActionDetector), findsNWidgets(7));
    });
  });

  group('BeuiKnockoutWheel keyboard roll', () {
    testWidgets('tab enters the wheel at the hub (roving tab stop)', (
      tester,
    ) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _draw()));
      await _settle(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'f1');
    });

    testWidgets('arrows walk the geometry — out, in, and round the ring', (
      tester,
    ) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _draw()));
      await _settle(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // Down walks out to a feeder…
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'sf1');

      // …right goes round that ring…
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'sf2');

      // …and wraps.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'sf1');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'sf2');

      // Up walks back toward the hub.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'f1');

      // The hub has no parent — up from there is a no-op, not a crash.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'f1');
    });

    testWidgets('focusing a mark isolates it and captions it', (tester) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _draw()));
      await _settle(tester);
      expect(find.text(_hubCaption), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await _settle(tester);
      expect(find.text(_hubCaption), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await _settle(tester);
      // The caption follows focus rather than stacking up.
      expect(find.text(_hubCaption), findsNothing);
      expect(find.text(_sf1Caption), findsOneWidget);
    });
  });

  group('BeuiKnockoutWheel pointer roll', () {
    testWidgets('hover isolates a mark, and leaving clears it', (tester) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _draw()));
      await _settle(tester);

      final target = tester.getCenter(find.bySemanticsLabel(_sf2Caption));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);

      await mouse.moveTo(target);
      await _settle(tester);
      expect(find.text(_sf2Caption), findsOneWidget);

      await mouse.moveTo(Offset.zero);
      await _settle(tester);
      expect(find.text(_sf2Caption), findsNothing);
    });

    testWidgets('a touch tap pins a mark and tapping again releases it', (
      tester,
    ) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _draw()));
      await _settle(tester);

      final target = tester.getCenter(find.bySemanticsLabel(_sf1Caption));
      await tester.tapAt(target);
      await _settle(tester);
      expect(find.text(_sf1Caption), findsOneWidget);

      await tester.tapAt(target);
      await _settle(tester);
      expect(find.text(_sf1Caption), findsNothing);
    });
  });

  group('BeuiKnockoutWheel motion fidelity', () {
    testWidgets('marks scale in on a spring under normal motion', (
      tester,
    ) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _draw()));
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(BeuiKnockoutWheel),
          matching: find.byType(SingleMotionBuilder),
        ),
        findsNWidgets(15),
      );
      await _settle(tester);
    });

    testWidgets('reduced motion drops the scale-in but keeps the fade', (
      tester,
    ) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _draw(), reduce: true));
      await tester.pump();

      // Movement dropped: no spring drives a transform anywhere in the wheel.
      expect(
        find.descendant(
          of: find.byType(BeuiKnockoutWheel),
          matching: find.byType(SingleMotionBuilder),
        ),
        findsNothing,
      );
      // Opacity is preserved, per the library's reduced-motion rule.
      expect(
        find.descendant(
          of: find.byType(BeuiKnockoutWheel),
          matching: find.byType(AnimatedOpacity),
        ),
        findsWidgets,
      );
      await _settle(tester);
    });

    testWidgets('marks reach full size once the rings have entered', (
      tester,
    ) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _draw()));
      await _settle(tester);

      final hub = find.bySemanticsLabel(_hubCaption);
      // The hub's hit area is 2·HUB_R (68 units) scaled to the stage: at the
      // 544 ceiling that is 68 · 544/760 ≈ 48.7.
      expect(tester.getSize(hub).width, closeTo(68 * 544 / 760, 0.5));
    });
  });

  testWidgets('rest-state golden', (tester) async {
    _sizeView(tester);
    await tester.pumpWidget(_app(rounds: _draw()));
    await _settle(tester);
    await expectLater(
      find.byType(BeuiKnockoutWheel),
      matchesGoldenFile('goldens/beui_knockout_wheel.png'),
    );
  });
}
