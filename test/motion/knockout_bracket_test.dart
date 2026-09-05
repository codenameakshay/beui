import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A compact 4-round bracket (4 → 2 → 1 ... actually 4 rounds: 8→4→2→1) so paging
// past the initial window is exercised. Each round holds half as many matches as
// the one before it.
const _a = BeuiTeam(name: 'Alpha', code: 'aa');
const _b = BeuiTeam(name: 'Bravo', code: 'bb');

BeuiMatch _m(String id, {BeuiMatchWinner winner = BeuiMatchWinner.home}) =>
    BeuiMatch(
      id: id,
      date: 'Mon, 1 Jan',
      status: BeuiMatchStatus.finished,
      home: const BeuiMatchSide(team: _a, score: 2),
      away: const BeuiMatchSide(team: _b, score: 1),
      winner: winner,
    );

List<BeuiBracketRound> _bracket() => [
  BeuiBracketRound(
    name: 'Quarter-finals',
    matches: [_m('qf1'), _m('qf2'), _m('qf3'), _m('qf4')],
  ),
  BeuiBracketRound(name: 'Semi-finals', matches: [_m('sf1'), _m('sf2')]),
  const BeuiBracketRound(
    name: 'Final',
    matches: [
      BeuiMatch(
        id: 'f1',
        date: 'Sun, 7 Jan',
        time: '3:00 pm',
        status: BeuiMatchStatus.upcoming,
        home: BeuiMatchSide(),
        away: BeuiMatchSide(),
      ),
    ],
  ),
];

/// Sizes the test window large enough for the 3-column bracket (≈846×624) so
/// the chevrons stay on-screen and hittable and nothing overflows the frame.
/// Mirrors the gallery, which hosts each demo in a scrollable, roomy surface.
void _sizeView(WidgetTester tester, {Size size = const Size(1400, 1000)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// A card's own key resolves to the `_ReflowSlot`, whose nearest render
/// object is the `Transform.translate` it wraps its content in — measuring
/// that key directly reports the pre-translate (0, 0) origin, not the
/// animated position. A `Text` descendant sits below the transform, so it
/// reports the real, animated position.
Finder _cardText(String matchId) => find
    .descendant(
      of: find.byKey(ValueKey('card-$matchId')),
      matching: find.byType(Text),
    )
    .first;

/// The source `THIRD_PLACE`: both slots stay TBD until the semi-finals resolve.
const _thirdPlace = BeuiMatch(
  id: 'tp1',
  date: 'Sun, 6 Jan',
  time: '3:00 pm',
  status: BeuiMatchStatus.upcoming,
  home: BeuiMatchSide(),
  away: BeuiMatchSide(),
);

Widget _app({
  required List<BeuiBracketRound> rounds,
  int initialRound = 0,
  ValueChanged<int>? onRoundChanged,
  bool reduce = false,
  BeuiMatch? thirdPlace,
  String? thirdPlaceLabel,
  Widget Function(BuildContext, BeuiTeam)? flagBuilder,
}) {
  Widget child = BeuiKnockoutBracket(
    rounds: rounds,
    initialRound: initialRound,
    onRoundChanged: onRoundChanged,
    thirdPlace: thirdPlace,
    thirdPlaceLabel: thirdPlaceLabel ?? 'Third place play-off',
    flagBuilder: flagBuilder,
  );
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
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  group('BeuiKnockoutBracket paging', () {
    testWidgets('next chevron advances the leftmost round', (tester) async {
      _sizeView(tester);
      int? changed;
      await tester.pumpWidget(
        _app(rounds: _bracket(), onRoundChanged: (v) => changed = v),
      );
      await tester.pumpAndSettle();

      // initialRound 0 → maxPage = 3 - 2 = 1, so a Next chevron is present.
      final next = find.bySemanticsLabel('Next round');
      expect(next, findsOneWidget);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(changed, 1);

      // At the last page the Next chevron is gone; Previous is shown.
      expect(find.bySemanticsLabel('Next round'), findsNothing);
      expect(find.bySemanticsLabel('Previous round'), findsOneWidget);
    });

    testWidgets('previous chevron steps back', (tester) async {
      _sizeView(tester);
      int? changed;
      await tester.pumpWidget(
        _app(
          rounds: _bracket(),
          initialRound: 1,
          onRoundChanged: (v) => changed = v,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Previous round'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Previous round'));
      await tester.pumpAndSettle();
      expect(changed, 0);
    });

    testWidgets('round titles render for every round', (tester) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _bracket()));
      await tester.pumpAndSettle();
      expect(find.text('Quarter-finals'), findsOneWidget);
      expect(find.text('Semi-finals'), findsOneWidget);
      expect(find.text('Final'), findsOneWidget);
    });
  });

  group('BeuiKnockoutBracket content', () {
    testWidgets('finished match shows FT badge and scores', (tester) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _bracket()));
      await tester.pumpAndSettle();
      expect(find.text('FT'), findsWidgets);
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('shootout renders penalties and an FT (P) badge', (
      tester,
    ) async {
      _sizeView(tester);
      final rounds = [
        BeuiBracketRound(
          name: 'Round of 2',
          matches: const [
            BeuiMatch(
              id: 'p1',
              date: 'Mon, 1 Jan',
              status: BeuiMatchStatus.finished,
              home: BeuiMatchSide(team: _a, score: 1, penalties: 4),
              away: BeuiMatchSide(team: _b, score: 1, penalties: 3),
              winner: BeuiMatchWinner.home,
            ),
          ],
        ),
      ];
      await tester.pumpWidget(_app(rounds: rounds));
      await tester.pumpAndSettle();
      expect(find.text('FT (P)'), findsOneWidget);
      expect(find.text('1 (4)'), findsOneWidget);
      expect(find.text('1 (3)'), findsOneWidget);
    });

    testWidgets('upcoming TBD slot renders TBD label', (tester) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _bracket(), initialRound: 1));
      await tester.pumpAndSettle();
      expect(find.text('TBD'), findsWidgets);
    });
  });

  // Source `TeamCrest`: artwork if there is any, the team's initials if there is
  // not, and the shield only for an undecided slot. The package ships no artwork,
  // so a team always lands on the initials branch unless a flagBuilder is given.
  group('BeuiKnockoutBracket team crest', () {
    testWidgets('a team with no flagBuilder falls back to its initials', (
      tester,
    ) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _bracket()));
      await tester.pumpAndSettle();
      expect(find.text('A'), findsWidgets); // Alpha
      expect(find.text('B'), findsWidgets); // Bravo
    });

    testWidgets('the shield is reserved for an undecided slot', (tester) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _bracket()));
      await tester.pumpAndSettle();
      // Fourteen sides are on stage (4 QF + 2 SF + 1 Final, two sides each) but
      // only the Final's two are undecided, so exactly two shields are drawn —
      // the other twelve carry a team and get initials.
      expect(find.byIcon(LucideIcons.shield), findsNWidgets(2));

      await tester.pumpWidget(
        _app(rounds: _bracket(), thirdPlace: _thirdPlace),
      );
      await tester.pumpAndSettle();
      // The third-place fixture is TBD v TBD as well, adding two more.
      expect(find.byIcon(LucideIcons.shield), findsNWidgets(4));
    });

    testWidgets('a flagBuilder wins over the initials fallback', (
      tester,
    ) async {
      _sizeView(tester);
      await tester.pumpWidget(
        _app(
          rounds: _bracket(),
          flagBuilder: (context, team) =>
              ColoredBox(key: ValueKey('flag-${team.name}'), color: Colors.red),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('flag-Alpha')), findsWidgets);
      expect(find.text('A'), findsNothing);
    });
  });

  group('BeuiKnockoutBracket third place play-off', () {
    testWidgets('is absent unless a thirdPlace fixture is passed', (
      tester,
    ) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _bracket()));
      await tester.pumpAndSettle();
      expect(find.text('Third place play-off'), findsNothing);
    });

    testWidgets('renders its heading and card under the tree', (tester) async {
      _sizeView(tester);
      await tester.pumpWidget(
        _app(rounds: _bracket(), thirdPlace: _thirdPlace),
      );
      await tester.pumpAndSettle();

      expect(find.text('Third place play-off'), findsOneWidget);
      // The play-off's own card — its date/time header is unique to it.
      expect(find.text('Sun, 6 Jan, 3:00 pm'), findsOneWidget);
      // …and it sits below the bracket stage, not inside a column of it.
      expect(
        tester.getTopLeft(find.text('Third place play-off')).dy,
        greaterThan(tester.getBottomLeft(find.text('Quarter-finals')).dy),
      );
    });

    testWidgets('thirdPlaceLabel renames the fixture', (tester) async {
      _sizeView(tester);
      await tester.pumpWidget(
        _app(
          rounds: _bracket(),
          thirdPlace: _thirdPlace,
          thirdPlaceLabel: 'Bronze match',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bronze match'), findsOneWidget);
      expect(find.text('Third place play-off'), findsNothing);
    });

    testWidgets('does not page with the tree', (tester) async {
      _sizeView(tester);
      await tester.pumpWidget(
        _app(rounds: _bracket(), thirdPlace: _thirdPlace),
      );
      await tester.pumpAndSettle();
      final before = tester.getTopLeft(find.text('Sun, 6 Jan, 3:00 pm'));

      await tester.tap(find.bySemanticsLabel('Next round'));
      await tester.pumpAndSettle();

      // It feeds off the semi-finals rather than into the final, so it stays put
      // below the rule while the columns page behind it — it only rides up with
      // the stage as the shorter round collapses the bracket's height.
      expect(find.text('Third place play-off'), findsOneWidget);
      final after = tester.getTopLeft(find.text('Sun, 6 Jan, 3:00 pm'));
      expect(after.dx, before.dx);
      expect(after.dy, lessThan(before.dy));
    });
  });

  group('BeuiKnockoutBracket motion fidelity', () {
    testWidgets('cards glide to their new column under normal motion', (
      tester,
    ) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _bracket()));
      await tester.pumpAndSettle();
      // sf1 moves from a secondary column to the new base column when paging
      // from the quarter-finals — the REFLOW spring's x offset is exercised.
      final card = _cardText('sf1');
      final before = tester.getTopLeft(card);

      await tester.tap(find.bySemanticsLabel('Next round'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90)); // mid-spring
      final mid = tester.getTopLeft(card);
      await tester.pumpAndSettle();
      final settled = tester.getTopLeft(card);

      expect(settled.dx, lessThan(before.dx));
      expect(mid.dx, lessThan(before.dx));
      expect(mid.dx, greaterThan(settled.dx));
    });

    testWidgets('reduced motion snaps cards straight to their new column', (
      tester,
    ) async {
      _sizeView(tester);
      await tester.pumpWidget(_app(rounds: _bracket(), reduce: true));
      await tester.pumpAndSettle();
      final card = _cardText('sf1');
      final before = tester.getTopLeft(card);

      await tester.tap(find.bySemanticsLabel('Next round'));
      await tester.pump();
      final justAfterTap = tester.getTopLeft(card);
      await tester.pumpAndSettle();
      final settled = tester.getTopLeft(card);

      expect(settled.dx, lessThan(before.dx));
      // No position spring under reduced motion: it lands immediately,
      // ahead of the opacity cross-fade (which reduced motion still keeps).
      expect(justAfterTap.dx, settled.dx);
    });
  });

  testWidgets('rest-state golden', (tester) async {
    _sizeView(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: BeuiTextTheme.trackingNormal(
          ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
        ),
        home: Scaffold(
          body: Center(child: BeuiKnockoutBracket(rounds: _bracket())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiKnockoutBracket),
      matchesGoldenFile('goldens/beui_knockout_bracket.png'),
    );
  });
}
