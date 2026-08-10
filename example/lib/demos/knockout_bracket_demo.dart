import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for the two "Fixtures" components: [BeuiKnockoutBracket] — a
/// full World Cup knockout stage (Round of 32 → Final) that pages between
/// rounds with the REFLOW glide, plus its third place play-off — and
/// [BeuiKnockoutWheel], the same tree drawn radially around the champion.
Widget knockoutBracketDemo(BuildContext context) =>
    const _KnockoutBracketDemo();

class _KnockoutBracketDemo extends StatelessWidget {
  const _KnockoutBracketDemo();

  // The site renders these as two bare previews (the prose lives in the page
  // chrome, not the preview), so the route is just the two components: the
  // wheel first, matching the "Fixtures" page order, each in the source
  // preview's own `w-full py-8` wrapper.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 32), // py-8
        child: BeuiKnockoutWheel(rounds: _wheelRounds),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 32), // py-8
        child: BeuiKnockoutBracket(rounds: _rounds, thirdPlace: _thirdPlace),
      ),
    ],
  );
}

// ── Mock data ────────────────────────────────────────────────────────────────
// A full World Cup knockout stage (16 → 8 → 4 → 2 → 1), ported from the source
// `ROUNDS` export.

const _southAfrica = BeuiTeam(name: 'South Africa', code: 'za');
const _canada = BeuiTeam(name: 'Canada', code: 'ca');
const _netherlands = BeuiTeam(name: 'Netherlands', code: 'nl');
const _morocco = BeuiTeam(name: 'Morocco', code: 'ma');
const _germany = BeuiTeam(name: 'Germany', code: 'de');
const _paraguay = BeuiTeam(name: 'Paraguay', code: 'py');
const _france = BeuiTeam(name: 'France', code: 'fr');
const _sweden = BeuiTeam(name: 'Sweden', code: 'se');
const _belgium = BeuiTeam(name: 'Belgium', code: 'be');
const _senegal = BeuiTeam(name: 'Senegal', code: 'sn');
const _usa = BeuiTeam(name: 'USA', code: 'us');
const _bosnia = BeuiTeam(name: 'Bosnia and Herzegovina', code: 'ba');
const _spain = BeuiTeam(name: 'Spain', code: 'es');
const _austria = BeuiTeam(name: 'Austria', code: 'at');
const _portugal = BeuiTeam(name: 'Portugal', code: 'pt');
const _croatia = BeuiTeam(name: 'Croatia', code: 'hr');
const _brazil = BeuiTeam(name: 'Brazil', code: 'br');
const _japan = BeuiTeam(name: 'Japan', code: 'jp');
const _ivoryCoast = BeuiTeam(name: "Côte d'Ivoire", code: 'ci');
const _norway = BeuiTeam(name: 'Norway', code: 'no');
const _mexico = BeuiTeam(name: 'Mexico', code: 'mx');
const _ecuador = BeuiTeam(name: 'Ecuador', code: 'ec');
const _england = BeuiTeam(name: 'England', code: 'gb-eng');
const _drCongo = BeuiTeam(name: 'DR Congo', code: 'cd');
const _switzerland = BeuiTeam(name: 'Switzerland', code: 'ch');
const _algeria = BeuiTeam(name: 'Algeria', code: 'dz');
const _colombia = BeuiTeam(name: 'Colombia', code: 'co');
const _ghana = BeuiTeam(name: 'Ghana', code: 'gh');
const _australia = BeuiTeam(name: 'Australia', code: 'au');
const _egypt = BeuiTeam(name: 'Egypt', code: 'eg');
const _argentina = BeuiTeam(name: 'Argentina', code: 'ar');
const _caboVerde = BeuiTeam(name: 'Cabo Verde', code: 'cv');

final List<BeuiBracketRound> _rounds = [
  const BeuiBracketRound(
    name: 'Round of 32',
    matches: [
      BeuiMatch(
        id: 'r32-1',
        date: 'Mon, 29 Jun',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _southAfrica, score: 0),
        away: BeuiMatchSide(team: _canada, score: 1),
        winner: BeuiMatchWinner.away,
      ),
      BeuiMatch(
        id: 'r32-2',
        date: 'Tue, 30 Jun',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _netherlands, score: 1, penalties: 2),
        away: BeuiMatchSide(team: _morocco, score: 1, penalties: 3),
        winner: BeuiMatchWinner.away,
      ),
      BeuiMatch(
        id: 'r32-3',
        date: 'Tue, 30 Jun',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _germany, score: 1, penalties: 3),
        away: BeuiMatchSide(team: _paraguay, score: 1, penalties: 4),
        winner: BeuiMatchWinner.away,
      ),
      BeuiMatch(
        id: 'r32-4',
        date: 'Wed, 1 Jul',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _france, score: 3),
        away: BeuiMatchSide(team: _sweden, score: 0),
        winner: BeuiMatchWinner.home,
      ),
      BeuiMatch(
        id: 'r32-5',
        date: 'Thu, 2 Jul',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _belgium, score: 3),
        away: BeuiMatchSide(team: _senegal, score: 2),
        winner: BeuiMatchWinner.home,
      ),
      BeuiMatch(
        id: 'r32-6',
        date: 'Thu, 2 Jul',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _usa, score: 2),
        away: BeuiMatchSide(team: _bosnia, score: 0),
        winner: BeuiMatchWinner.home,
      ),
      BeuiMatch(
        id: 'r32-7',
        date: 'Fri, 3 Jul',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _spain, score: 3),
        away: BeuiMatchSide(team: _austria, score: 0),
        winner: BeuiMatchWinner.home,
      ),
      BeuiMatch(
        id: 'r32-8',
        date: 'Fri, 3 Jul',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _portugal, score: 2),
        away: BeuiMatchSide(team: _croatia, score: 1),
        winner: BeuiMatchWinner.home,
      ),
      BeuiMatch(
        id: 'r32-9',
        date: 'Mon, 29 Jun',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _brazil, score: 2),
        away: BeuiMatchSide(team: _japan, score: 1),
        winner: BeuiMatchWinner.home,
      ),
      BeuiMatch(
        id: 'r32-10',
        date: 'Tue, 30 Jun',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _ivoryCoast, score: 1),
        away: BeuiMatchSide(team: _norway, score: 2),
        winner: BeuiMatchWinner.away,
      ),
      BeuiMatch(
        id: 'r32-11',
        date: 'Wed, 1 Jul',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _mexico, score: 2),
        away: BeuiMatchSide(team: _ecuador, score: 0),
        winner: BeuiMatchWinner.home,
      ),
      BeuiMatch(
        id: 'r32-12',
        date: 'Wed, 1 Jul',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _england, score: 2),
        away: BeuiMatchSide(team: _drCongo, score: 1),
        winner: BeuiMatchWinner.home,
      ),
      BeuiMatch(
        id: 'r32-13',
        date: 'Fri, 3 Jul',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _switzerland, score: 2),
        away: BeuiMatchSide(team: _algeria, score: 0),
        winner: BeuiMatchWinner.home,
      ),
      BeuiMatch(
        id: 'r32-14',
        date: 'Sat, 4 Jul',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _colombia, score: 1),
        away: BeuiMatchSide(team: _ghana, score: 0),
        winner: BeuiMatchWinner.home,
      ),
      BeuiMatch(
        id: 'r32-15',
        date: 'Fri, 3 Jul',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _australia, score: 1, penalties: 2),
        away: BeuiMatchSide(team: _egypt, score: 1, penalties: 4),
        winner: BeuiMatchWinner.away,
      ),
      BeuiMatch(
        id: 'r32-16',
        date: 'Sat, 4 Jul',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _argentina, score: 3),
        away: BeuiMatchSide(team: _caboVerde, score: 2),
        winner: BeuiMatchWinner.home,
      ),
    ],
  ),
  const BeuiBracketRound(
    name: 'Round of 16',
    matches: [
      BeuiMatch(
        id: 'r16-1',
        date: 'Sat, 4 Jul',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _canada, score: 0),
        away: BeuiMatchSide(team: _morocco, score: 3),
        winner: BeuiMatchWinner.away,
      ),
      BeuiMatch(
        id: 'r16-2',
        date: 'Sun, 5 Jul',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _paraguay, score: 0),
        away: BeuiMatchSide(team: _france, score: 1),
        winner: BeuiMatchWinner.away,
      ),
      BeuiMatch(
        id: 'r16-3',
        date: 'Mon, 6 Jul',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _usa, score: 1),
        away: BeuiMatchSide(team: _belgium, score: 4),
        winner: BeuiMatchWinner.away,
      ),
      BeuiMatch(
        id: 'r16-4',
        date: 'Mon, 6 Jul',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _portugal, score: 0),
        away: BeuiMatchSide(team: _spain, score: 1),
        winner: BeuiMatchWinner.away,
      ),
      BeuiMatch(
        id: 'r16-5',
        date: 'Mon, 6 Jul',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _brazil, score: 1),
        away: BeuiMatchSide(team: _norway, score: 2),
        winner: BeuiMatchWinner.away,
      ),
      BeuiMatch(
        id: 'r16-6',
        date: 'Mon, 6 Jul',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _mexico, score: 2),
        away: BeuiMatchSide(team: _england, score: 3),
        winner: BeuiMatchWinner.away,
      ),
      BeuiMatch(
        id: 'r16-7',
        date: 'Tue, 7 Jul',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _switzerland, score: 0, penalties: 4),
        away: BeuiMatchSide(team: _colombia, score: 0, penalties: 3),
        winner: BeuiMatchWinner.home,
      ),
      BeuiMatch(
        id: 'r16-8',
        date: 'Tue, 7 Jul',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _argentina, score: 3),
        away: BeuiMatchSide(team: _egypt, score: 2),
        winner: BeuiMatchWinner.home,
      ),
    ],
  ),
  const BeuiBracketRound(
    name: 'Quarter-finals',
    matches: [
      BeuiMatch(
        id: 'qf-1',
        date: 'Fri, 10 Jul',
        time: '4:00 am',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _france, score: 2),
        away: BeuiMatchSide(team: _morocco, score: 0),
        winner: BeuiMatchWinner.home,
      ),
      BeuiMatch(
        id: 'qf-2',
        date: 'Sat, 11 Jul',
        time: '3:00 am',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _spain, score: 2),
        away: BeuiMatchSide(team: _belgium, score: 1),
        winner: BeuiMatchWinner.home,
      ),
      BeuiMatch(
        id: 'qf-3',
        date: 'Today',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _norway, score: 1),
        away: BeuiMatchSide(team: _england, score: 2),
        winner: BeuiMatchWinner.away,
      ),
      BeuiMatch(
        id: 'qf-4',
        date: 'Today',
        status: BeuiMatchStatus.finished,
        home: BeuiMatchSide(team: _argentina, score: 3),
        away: BeuiMatchSide(team: _switzerland, score: 1),
        winner: BeuiMatchWinner.home,
      ),
    ],
  ),
  const BeuiBracketRound(
    name: 'Semi-finals',
    matches: [
      BeuiMatch(
        id: 'sf-1',
        date: 'Wed, 15 Jul',
        time: '4:00 am',
        status: BeuiMatchStatus.upcoming,
        home: BeuiMatchSide(team: _france),
        away: BeuiMatchSide(team: _spain),
      ),
      BeuiMatch(
        id: 'sf-2',
        date: 'Thu, 16 Jul',
        time: '3:00 am',
        status: BeuiMatchStatus.upcoming,
        home: BeuiMatchSide(team: _england),
        away: BeuiMatchSide(team: _argentina),
      ),
    ],
  ),
  const BeuiBracketRound(
    name: 'Final',
    matches: [
      BeuiMatch(
        id: 'f-1',
        date: 'Mon, 20 Jul',
        time: '3:00 am',
        status: BeuiMatchStatus.upcoming,
        home: BeuiMatchSide(),
        away: BeuiMatchSide(),
      ),
    ],
  ),
];

/// Both slots stay TBD until the semi-finals resolve, same as the final
/// (source `THIRD_PLACE`).
const _thirdPlace = BeuiMatch(
  id: 'tp-1',
  date: 'Sun, 19 Jul',
  time: '3:00 am',
  status: BeuiMatchStatus.upcoming,
  home: BeuiMatchSide(),
  away: BeuiMatchSide(),
);

// ── Wheel data ───────────────────────────────────────────────────────────────
// The source's own wheel `ROUNDS` export: a *finished* 32-team cup, so the hub
// carries a champion, the trophy and glow render, and the winning run stays lit
// at rest. It is an ordinary `BeuiBracketRound` list — the wheel just ignores
// the fields it never draws (date, time, status), which is why those are
// optional on the shared model.

const _uruguay = BeuiTeam(name: 'Uruguay', code: 'uy');
const _italy = BeuiTeam(name: 'Italy', code: 'it');
const _costaRica = BeuiTeam(name: 'Costa Rica', code: 'cr');
const _serbia = BeuiTeam(name: 'Serbia', code: 'rs');
const _wales = BeuiTeam(name: 'Wales', code: 'gb-wls');
const _denmark = BeuiTeam(name: 'Denmark', code: 'dk');
const _cameroon = BeuiTeam(name: 'Cameroon', code: 'cm');
const _poland = BeuiTeam(name: 'Poland', code: 'pl');
const _tunisia = BeuiTeam(name: 'Tunisia', code: 'tn');
const _peru = BeuiTeam(name: 'Peru', code: 'pe');
const _qatar = BeuiTeam(name: 'Qatar', code: 'qa');

/// A played fixture, scores only — the winner follows the shootout when there
/// is one.
BeuiMatch _played(
  String id,
  BeuiTeam home,
  int homeScore,
  BeuiTeam away,
  int awayScore, {
  int? homePens,
  int? awayPens,
}) {
  final homeWon = homePens != null && awayPens != null
      ? homePens > awayPens
      : homeScore > awayScore;
  return BeuiMatch(
    id: id,
    status: BeuiMatchStatus.finished,
    home: BeuiMatchSide(team: home, score: homeScore, penalties: homePens),
    away: BeuiMatchSide(team: away, score: awayScore, penalties: awayPens),
    winner: homeWon ? BeuiMatchWinner.home : BeuiMatchWinner.away,
  );
}

final List<BeuiBracketRound> _wheelRounds = [
  BeuiBracketRound(
    name: 'Round of 32',
    matches: [
      _played('w-r32-1', _spain, 3, _costaRica, 0),
      _played('w-r32-2', _japan, 2, _serbia, 1),
      _played('w-r32-3', _netherlands, 2, _ecuador, 0),
      _played('w-r32-4', _ghana, 2, _portugal, 3),
      _played('w-r32-5', _england, 4, _wales, 0),
      _played('w-r32-6', _canada, 0, _uruguay, 2),
      _played('w-r32-7', _croatia, 1, _denmark, 0),
      _played('w-r32-8', _brazil, 3, _cameroon, 1),
      _played('w-r32-9', _france, 2, _poland, 1),
      _played('w-r32-10', _senegal, 0, _morocco, 1),
      _played('w-r32-11', _belgium, 2, _tunisia, 0),
      _played('w-r32-12', _switzerland, 1, _italy, 3),
      _played('w-r32-13', _argentina, 2, _peru, 0),
      _played('w-r32-14', _qatar, 0, _mexico, 1),
      _played('w-r32-15', _germany, 4, _sweden, 2),
      _played('w-r32-16', _austria, 1, _norway, 2),
    ],
  ),
  BeuiBracketRound(
    name: 'Round of 16',
    matches: [
      _played('w-r16-1', _spain, 2, _japan, 0),
      _played('w-r16-2', _netherlands, 1, _portugal, 3),
      _played('w-r16-3', _england, 2, _uruguay, 1),
      _played('w-r16-4', _croatia, 0, _brazil, 1),
      _played('w-r16-5', _france, 3, _morocco, 1),
      _played('w-r16-6', _belgium, 1, _italy, 2),
      _played('w-r16-7', _argentina, 2, _mexico, 0),
      _played('w-r16-8', _germany, 1, _norway, 1, homePens: 4, awayPens: 2),
    ],
  ),
  BeuiBracketRound(
    name: 'Quarter-finals',
    matches: [
      _played('w-qf-1', _spain, 1, _portugal, 0),
      _played('w-qf-2', _england, 2, _brazil, 3),
      _played('w-qf-3', _france, 2, _italy, 1),
      _played('w-qf-4', _argentina, 3, _germany, 1),
    ],
  ),
  BeuiBracketRound(
    name: 'Semi-finals',
    matches: [
      _played('w-sf-1', _spain, 2, _brazil, 1),
      _played('w-sf-2', _france, 0, _argentina, 0, homePens: 3, awayPens: 4),
    ],
  ),
  BeuiBracketRound(
    name: 'Final',
    matches: [_played('w-f-1', _spain, 2, _argentina, 1)],
  ),
];
