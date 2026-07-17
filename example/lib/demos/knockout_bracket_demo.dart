import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiKnockoutBracket] — a full World Cup knockout stage
/// (Round of 32 → Final) that pages between rounds with the REFLOW glide.
Widget knockoutBracketDemo(BuildContext context) =>
    const _KnockoutBracketDemo();

class _KnockoutBracketDemo extends StatelessWidget {
  const _KnockoutBracketDemo();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Use the chevrons to page between rounds — cards, connectors and the '
          'stage height glide as one piece.',
          style: TextStyle(fontSize: 14, color: colors.mutedForeground),
        ),
        const SizedBox(height: 24),
        BeuiKnockoutBracket(rounds: _rounds),
      ],
    );
  }
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
