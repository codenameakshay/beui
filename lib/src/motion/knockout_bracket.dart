import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';

// ── Data model ───────────────────────────────────────────────────────────────
// One-to-one with the source `Team` / `MatchSide` / `Match` / `Round` types.

/// A competing team — the Flutter port of the source `Team`.
@immutable
class BeuiTeam {
  /// Creates a team with a display [name] and optional flag [code].
  const BeuiTeam({required this.name, this.code});

  /// Display name (e.g. `"Morocco"`).
  final String name;

  /// ISO 3166-1 alpha-2 code (source loads `flagcdn.com/w80/{code}.png`;
  /// England is `gb-eng`). Only consumed by a custom [BeuiKnockoutBracket.flagBuilder]
  /// — this package ships no artwork and fetches nothing, so without one the slot
  /// falls back to the team's initials exactly as the source does when a flag
  /// fails to load. May be null.
  final String? code;
}

/// One side of a [BeuiMatch] — the Flutter port of the source `MatchSide`.
@immutable
class BeuiMatchSide {
  /// Creates a match side. A null [team] renders a TBD slot with a shield icon.
  const BeuiMatchSide({this.team, this.score, this.penalties});

  /// The team, or null for an undecided (TBD) slot.
  final BeuiTeam? team;

  /// Regulation score, or null when not yet played.
  final int? score;

  /// Shootout score, rendered Google-style as `1 (3)` when present on a side.
  final int? penalties;
}

/// Whether a match has been played.
enum BeuiMatchStatus {
  /// The match is over (renders scores + an `FT` / `FT (P)` badge).
  finished,

  /// The match is scheduled (renders the date/time, no scores).
  upcoming,
}

/// Which side won a decided match — drives the winner marker and which side dims.
enum BeuiMatchWinner {
  /// The home (top) side won.
  home,

  /// The away (bottom) side won.
  away,
}

/// A single fixture — the Flutter port of the source `Match`.
@immutable
class BeuiMatch {
  /// Creates a match. [id] must be stable across rebuilds/paging so its card
  /// keeps spring identity as the bracket reflows.
  const BeuiMatch({
    required this.id,
    required this.status,
    required this.home,
    required this.away,
    this.date,
    this.time,
    this.winner,
  });

  /// Stable identity (source `id`), used as the card's widget key.
  final String id;

  /// Human date label (e.g. `"Wed, 1 Jul"` or `"Today"`).
  ///
  /// Optional: this model is shared with `BeuiKnockoutWheel`, whose source
  /// `Match` type omits the fields the wheel never draws (date, time, status),
  /// so a wheel-only dataset leaves it null and the card header renders empty.
  final String? date;

  /// Optional kick-off time (e.g. `"4:00 am"`).
  final String? time;

  /// Whether the match is finished or upcoming.
  final BeuiMatchStatus status;

  /// The home (top) side.
  final BeuiMatchSide home;

  /// The away (bottom) side.
  final BeuiMatchSide away;

  /// The winner, or null while undecided. Only meaningful when [status] is
  /// [BeuiMatchStatus.finished].
  final BeuiMatchWinner? winner;
}

/// One ordered round of the bracket — the Flutter port of the source `Round`.
///
/// Each round must hold **half** as many matches as the one before it
/// (16 → 8 → 4 → 2 → 1) so every later match lines up on its two feeders.
@immutable
class BeuiBracketRound {
  /// Creates a round with a [name] header and its [matches].
  const BeuiBracketRound({required this.name, required this.matches});

  /// Column header (e.g. `"Quarter-finals"`).
  final String name;

  /// The matches in this round, ordered top-to-bottom.
  final List<BeuiMatch> matches;
}

// ── Layout geometry (verbatim from the source module constants) ──────────────
// Card geometry drives the whole computed layout — every later match sits at the
// exact vertical midpoint of its two feeders, so pairs line up with connectors.
const double _cardW = 250;
const double _cardH = 124;
// Pocket (20) + stem (20) — matches the `]` connector geometry.
const double _gapX = 40;
const double _gapY = 20;
const double _colW = _cardW + _gapX;
const double _row = _cardH + _gapY;
const int _visibleColsMax = 3;
const double _connectorPocket = 20;
const double _connectorStem = _gapX - _connectorPocket;
// Tall enough for 44px chevron hit areas without clipping the focus ring.
const double _headerH = 44;
// Breathing room so the base column isn't flush against the clip edge and the
// connector nubs aren't shaved off.
const double _padX = 8;
const double _padY = 12;

/// Firmer than [beuiSpringLayout] so the many cards, connectors and stage
/// height glide as one piece — source `REFLOW { stiffness: 260, damping: 32,
/// mass: 0.9 }`. Damping just over critical (~1.05) settles with no bounce and
/// no lazy overdamped tail.
const _reflowSpring = SpringMotion(
  SpringDescription(mass: 0.9, stiffness: 260, damping: 32),
);

/// Opacity cross-fades a touch ahead of the position spring so columns don't
/// ghost while sliding — source `REFLOW_OPACITY { duration: 0.28, ease:
/// EASE_OUT }`.
const _reflowOpacityMs = 280;

int _clampInt(int n, int lo, int hi) => n < lo ? lo : (n > hi ? hi : n);

// Column x-offset and window test — shared by the layout pass and the render
// pass so the two can't drift.
double _colX(int r, int page) => _padX + (r - page) * _colW;
bool _isInWindow(int r, int page, int visibleCols) =>
    r >= page && r < page + visibleCols;

/// A tournament knockout bracket that pages between rounds — the Flutter port of
/// beUI's `knockout-bracket`.
///
/// The layout is **computed, not scrolled**: the leftmost visible round (`page`)
/// is the base and stacks at a fixed rhythm; every later match centers on its
/// two feeders, and behind rounds keep their natural (halving) spread so paging
/// back slides a formed column in from the left just as paging forward does.
/// Cards, `]` connectors, round titles and the stage height all derive from one
/// pass and page together under a single shared transition.
///
/// **Motion.** Positions and the stage height ride the bespoke `REFLOW` spring
/// (stiffness 260 · damping 32 · mass 0.9) — firmer than [beuiSpringLayout] so
/// everything moves as one piece; opacity cross-fades over a 280ms `EASE_OUT`
/// window (`REFLOW_OPACITY`) a touch ahead of the glide so columns never ghost
/// while sliding. Connectors are drawn with [CustomPaint] (transform/opacity
/// only — no path morph) so paging stays flicker-free.
///
/// **Reduced motion** drops movement (positions and the stage height snap to
/// their targets) while keeping the 280ms opacity fade, per the library rule —
/// the source snaps everything, but the house convention preserves opacity.
///
/// **Uncontrolled paging** (mirroring the source): [initialRound] seeds the
/// leftmost column, clamped to the valid range; [onRoundChanged] reports each
/// chevron step.
///
/// An optional [thirdPlace] play-off sits below the tree under its own rule,
/// headed by [thirdPlaceLabel] — it feeds off the semi-finals rather than into
/// the final, so it is not part of the paging window.
///
/// The `rounds` array is the same one `BeuiKnockoutWheel` takes: one dataset
/// draws either fixture style.
class BeuiKnockoutBracket extends StatefulWidget {
  /// Creates a bracket from ordered [rounds] (16 → 8 → 4 → 2 → 1 matches).
  const BeuiKnockoutBracket({
    required this.rounds,
    this.initialRound = 1,
    this.thirdPlace,
    this.thirdPlaceLabel = 'Third place play-off',
    this.onRoundChanged,
    this.flagBuilder,
    super.key,
  });

  /// Ordered rounds; each must hold half as many matches as the one before.
  final List<BeuiBracketRound> rounds;

  /// Round shown as the leftmost column on mount. Defaults to 1, clamped to the
  /// valid paging range (source `initialRound`).
  final int initialRound;

  /// Third place play-off, rendered under the bracket instead of inside it.
  ///
  /// It feeds off the semi-finals rather than into the final, so it gets its own
  /// rule below the stage instead of a column — it never pages, and it is
  /// unaffected by [initialRound].
  final BeuiMatch? thirdPlace;

  /// Heading over [thirdPlace]. Defaults to `"Third place play-off"`; rename it
  /// when a tournament calls the fixture something else ("Bronze match").
  final String thirdPlaceLabel;

  /// Called with the new leftmost-round index whenever the user pages.
  final ValueChanged<int>? onRoundChanged;

  /// Builds the 28×20 flag slot for a team. Defaults to the team's initials on a
  /// `foreground/10` disc — the source's own on-error fallback. The package ships
  /// no assets and fetches nothing, which keeps goldens deterministic, so real
  /// flags are opt-in, e.g.
  /// `flagBuilder: (ctx, team) => Image.network('https://flagcdn.com/w80/${team.code}.png')`.
  /// An undecided (null team) slot always draws the shield, never initials.
  final Widget Function(BuildContext context, BeuiTeam team)? flagBuilder;

  @override
  State<BeuiKnockoutBracket> createState() => _BeuiKnockoutBracketState();
}

class _BeuiKnockoutBracketState extends State<BeuiKnockoutBracket> {
  late int _page;

  int get _maxPage =>
      (widget.rounds.length - (widget.rounds.length < 2 ? 1 : 2)).clamp(
        0,
        1 << 30,
      );

  @override
  void initState() {
    super.initState();
    _page = _clampInt(widget.initialRound, 0, _maxPage);
  }

  @override
  void didUpdateWidget(BeuiKnockoutBracket old) {
    super.didUpdateWidget(old);
    // Keep the page valid if the round list shrinks under us.
    final clamped = _clampInt(_page, 0, _maxPage);
    if (clamped != _page) _page = clamped;
  }

  void _goto(int next) {
    final clamped = _clampInt(next, 0, _maxPage);
    if (clamped == _page) return;
    setState(() => _page = clamped);
    widget.onRoundChanged?.call(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);

    final rounds = widget.rounds;
    final page = _page;
    final visibleCols = rounds.length < _visibleColsMax
        ? rounds.length
        : _visibleColsMax;

    final layout = _computeLayout(rounds, page, visibleCols);
    final containerWidth =
        visibleCols * _cardW + (visibleCols - 1) * _gapX + 2 * _padX;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: containerWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — gliding round titles (clipped at the canvas edge) plus
            // the chevron buttons, which sit outside that clip.
            SizedBox(
              height: _headerH,
              width: containerWidth,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ClipRect(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (var r = 0; r < rounds.length; r++)
                            _ReflowSlot(
                              key: ValueKey('title-${rounds[r].name}'),
                              target: Offset(_colX(r, page), 0),
                              opacity: _isInWindow(r, page, visibleCols)
                                  ? 1
                                  : 0,
                              reduce: reduce,
                              child: SizedBox(
                                width: _cardW,
                                height: _headerH,
                                child: Center(
                                  child: Text(
                                    rounds[r].name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: colors.foreground,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (page > 0)
                    Positioned(
                      left: _padX,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _ChevronButton(
                          colors: colors,
                          icon: LucideIcons.chevron_left,
                          semanticLabel: 'Previous round',
                          onPressed: () => _goto(page - 1),
                        ),
                      ),
                    ),
                  if (page < _maxPage)
                    Positioned(
                      right: _padX,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _ChevronButton(
                          colors: colors,
                          icon: LucideIcons.chevron_right,
                          semanticLabel: 'Next round',
                          onPressed: () => _goto(page + 1),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Stage — height springs with REFLOW so the bracket collapses as one
            // piece with the cards.
            _ReflowHeight(
              height: layout.containerHeight,
              width: containerWidth,
              reduce: reduce,
              child: ClipRect(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Connectors first → drawn behind the cards.
                    for (final c in layout.connectors)
                      _ReflowConnector(
                        key: ValueKey('conn-${c.key}'),
                        connector: c,
                        color: colors.border,
                        reduce: reduce,
                      ),
                    for (var r = 0; r < rounds.length; r++)
                      for (var k = 0; k < rounds[r].matches.length; k++)
                        _ReflowSlot(
                          key: ValueKey('card-${rounds[r].matches[k].id}'),
                          target: Offset(
                            _colX(r, page),
                            layout.centers[r][k] - _cardH / 2,
                          ),
                          opacity: _isInWindow(r, page, visibleCols) ? 1 : 0,
                          reduce: reduce,
                          child: _MatchCard(
                            match: rounds[r].matches[k],
                            colors: colors,
                            flagBuilder: widget.flagBuilder,
                          ),
                        ),
                  ],
                ),
              ),
            ),
            // Outside the bracket stage — the play-off feeds off the
            // semi-finals rather than into the final, so it gets its own rule
            // instead of a column and never pages with the tree.
            if (widget.thirdPlace != null)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Container(
                  width: containerWidth,
                  padding: const EdgeInsets.only(left: _padX, top: 24),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: colors.border)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.thirdPlaceLabel,
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          color: colors.mutedForeground.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _MatchCard(
                        match: widget.thirdPlace!,
                        colors: colors,
                        flagBuilder: widget.flagBuilder,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The computed layout for one `(rounds, page)` pass: per-round match centers,
/// the total stage height, and the connector list.
class _BracketLayout {
  const _BracketLayout({
    required this.centers,
    required this.containerHeight,
    required this.connectors,
  });
  final List<List<double>> centers;
  final double containerHeight;
  final List<_Connector> connectors;
}

_BracketLayout _computeLayout(
  List<BeuiBracketRound> rounds,
  int page,
  int visibleCols,
) {
  final centers = List<List<double>>.filled(rounds.length, const []);
  final base = rounds[page];
  centers[page] = [
    for (var i = 0; i < base.matches.length; i++) _padY + i * _row + _cardH / 2,
  ];
  // Later rounds: each match centers on its two feeders.
  for (var r = page + 1; r < rounds.length; r++) {
    centers[r] = [
      for (var k = 0; k < rounds[r].matches.length; k++)
        (centers[r - 1][2 * k] + centers[r - 1][2 * k + 1]) / 2,
    ];
  }
  // Behind rounds keep their natural spread (spacing halves each step out, each
  // match straddling its parent) instead of collapsing, so paging back slides a
  // formed column in from the left just as paging forward does.
  for (var r = page - 1; r >= 0; r--) {
    final half = _row / (1 << (page - r + 1));
    centers[r] = [
      for (var i = 0; i < rounds[r].matches.length; i++)
        centers[r + 1][i ~/ 2] + (i.isEven ? -half : half),
    ];
  }

  final connectors = <_Connector>[];
  for (var r = 1; r < rounds.length; r++) {
    final feederRight = _colX(r - 1, page) + _cardW;
    final visible =
        _isInWindow(r, page, visibleCols) &&
        _isInWindow(r - 1, page, visibleCols);
    for (var k = 0; k < rounds[r].matches.length; k++) {
      final yTop = centers[r - 1][2 * k];
      final yBot = centers[r - 1][2 * k + 1];
      connectors.add(
        _Connector(
          key: '$r-$k',
          x: feederRight,
          y: yTop,
          height: (yBot - yTop) < 0 ? 0 : (yBot - yTop),
          visible: visible,
        ),
      );
    }
  }

  final baseCount = base.matches.length;
  return _BracketLayout(
    centers: centers,
    containerHeight: (baseCount - 1) * _row + _cardH + 2 * _padY,
    connectors: connectors,
  );
}

/// A `]` connector between a pair of feeders and their child.
class _Connector {
  const _Connector({
    required this.key,
    required this.x,
    required this.y,
    required this.height,
    required this.visible,
  });

  /// Stable identity for widget keying.
  final String key;

  /// Feeder card right edge — left of the `]` pocket.
  final double x;

  /// Top feeder centre Y.
  final double y;

  /// Distance between the two feeder centres.
  final double height;
  final bool visible;
}

/// Positions a child at [target] with the REFLOW position spring and cross-fades
/// [opacity] over the 280ms EASE_OUT window. Under [reduce] the position snaps
/// (movement dropped) while the opacity fade is kept.
class _ReflowSlot extends StatelessWidget {
  const _ReflowSlot({
    required this.target,
    required this.opacity,
    required this.reduce,
    required this.child,
    super.key,
  });

  final Offset target;
  final double opacity;
  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final faded = AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: _reflowOpacityMs),
      curve: beuiEaseOut,
      child: child,
    );
    if (reduce) {
      return Positioned(
        left: 0,
        top: 0,
        child: Transform.translate(offset: target, child: faded),
      );
    }
    return Positioned(
      left: 0,
      top: 0,
      child: MotionBuilder<Offset>(
        value: target,
        motion: _reflowSpring,
        converter: const OffsetMotionConverter(),
        builder: (context, o, inner) =>
            Transform.translate(offset: o, child: inner),
        child: faded,
      ),
    );
  }
}

/// Springs the stage height with REFLOW (snaps under [reduce]).
class _ReflowHeight extends StatelessWidget {
  const _ReflowHeight({
    required this.height,
    required this.width,
    required this.reduce,
    required this.child,
  });

  final double height;
  final double width;
  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduce) {
      return SizedBox(width: width, height: height, child: child);
    }
    return SingleMotionBuilder(
      value: height,
      motion: _reflowSpring,
      builder: (context, h, inner) =>
          SizedBox(width: width, height: h, child: inner),
      child: child,
    );
  }
}

/// Draws a single `]` connector, spring-repositioning it under REFLOW and
/// cross-fading it. Hidden connectors snap (source overrides their x/y/height
/// durations to 0) so only opacity animates.
class _ReflowConnector extends StatelessWidget {
  const _ReflowConnector({
    required this.connector,
    required this.color,
    required this.reduce,
    super.key,
  });

  final _Connector connector;
  final Color color;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final rect = Rect.fromLTWH(
      connector.x,
      connector.y,
      _connectorPocket,
      connector.height,
    );
    Widget paintAt(Rect r) => Transform.translate(
      offset: Offset(r.left, r.top),
      child: CustomPaint(
        size: Size(_connectorPocket + _connectorStem, r.height),
        painter: _ConnectorPainter(color: color),
      ),
    );

    final Widget positioned;
    if (reduce || !connector.visible) {
      // Hidden or reduced → snap to the target geometry; only opacity animates.
      positioned = paintAt(rect);
    } else {
      positioned = MotionBuilder<Rect>(
        value: rect,
        motion: _reflowSpring,
        converter: const RectMotionConverter(),
        builder: (context, r, _) => paintAt(r),
      );
    }

    return Positioned(
      left: 0,
      top: 0,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: connector.visible ? 1 : 0,
          duration: const Duration(milliseconds: _reflowOpacityMs),
          curve: beuiEaseOut,
          child: positioned,
        ),
      ),
    );
  }
}

/// Paints the CSS `]` pocket (`rounded-r-xl border-y border-r`) plus the
/// hairline stem to the child. Transform/opacity only — no path morph, so
/// paging stays flicker-free.
class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    if (h <= 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // rounded-r-xl = 12px, capped by the pocket half-height.
    final radius = h / 2 < 12 ? h / 2 : 12.0;
    const pocket = _connectorPocket;
    final path = Path()
      ..moveTo(0, 0.5)
      ..lineTo(pocket - radius, 0.5)
      ..arcToPoint(
        Offset(pocket - 0.5, radius),
        radius: Radius.circular(radius),
      )
      ..lineTo(pocket - 0.5, h - radius)
      ..arcToPoint(
        Offset(pocket - radius, h - 0.5),
        radius: Radius.circular(radius),
      )
      ..lineTo(0, h - 0.5);
    canvas.drawPath(path, paint);

    // Hairline stem to the child card (source: `left-full`, width CONNECTOR_STEM).
    final midY = h / 2;
    canvas.drawLine(
      Offset(pocket, midY),
      Offset(pocket + _connectorStem, midY),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) => old.color != color;
}

/// A single match card (250×124) — date/badge header over the two team rows.
class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.colors,
    required this.flagBuilder,
  });

  final BeuiMatch match;
  final BeuiColors colors;
  final Widget Function(BuildContext, BeuiTeam)? flagBuilder;

  @override
  Widget build(BuildContext context) {
    final decided =
        match.status == BeuiMatchStatus.finished && match.winner != null;
    final shootout =
        match.home.penalties != null || match.away.penalties != null;
    final badge = match.status == BeuiMatchStatus.finished
        ? (shootout ? 'FT (P)' : 'FT')
        : null;

    return Semantics(
      label: _matchLabel(match),
      container: true,
      child: Container(
        width: _cardW,
        height: _cardH,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      if (match.date != null) match.date!,
                      if (match.time != null) match.time!,
                    ].join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 20 / 14,
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 12,
                        height: 20 / 12,
                        fontWeight: FontWeight.w500,
                        color: colors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _TeamRow(
              side: match.home,
              decided: decided,
              isWinner: decided && match.winner == BeuiMatchWinner.home,
              colors: colors,
              flagBuilder: flagBuilder,
            ),
            const SizedBox(height: 10),
            _TeamRow(
              side: match.away,
              decided: decided,
              isWinner: decided && match.winner == BeuiMatchWinner.away,
              colors: colors,
              flagBuilder: flagBuilder,
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({
    required this.side,
    required this.isWinner,
    required this.decided,
    required this.colors,
    required this.flagBuilder,
  });

  final BeuiMatchSide side;
  final bool isWinner;
  final bool decided;
  final BeuiColors colors;
  final Widget Function(BuildContext, BeuiTeam)? flagBuilder;

  @override
  Widget build(BuildContext context) {
    final dim = decided && !isWinner;
    final textColor = dim ? colors.mutedForeground : colors.foreground;
    final team = side.team;

    // Source `TeamCrest`: artwork when there is any, the team's initials when
    // there is not, and the shield only for an undecided (TBD) slot.
    final Widget flag = team == null
        ? _shieldSlot(colors)
        : flagBuilder != null
        ? SizedBox(width: 28, height: 20, child: flagBuilder!(context, team))
        : _initialsSlot(colors, team.name);

    return Row(
      children: [
        flag,
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            team?.name ?? 'TBD',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
        if (side.score != null) ...[
          const SizedBox(width: 12),
          Text(
            side.penalties != null
                ? '${side.score} (${side.penalties})'
                : '${side.score}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: textColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
        const SizedBox(width: 6),
        // Fixed 6px marker slot keeps every score right-aligned; the winner's
        // triangle fills it, losers reserve it empty.
        SizedBox(
          width: 6,
          child: isWinner
              ? Center(
                  child: CustomPaint(
                    size: const Size(6, 8),
                    painter: _WinnerMarkerPainter(color: colors.foreground),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

Widget _shieldSlot(BeuiColors colors) => SizedBox(
  width: 28,
  height: 20,
  child: Center(
    child: Icon(
      LucideIcons.shield,
      size: 20,
      color: colors.mutedForeground.withValues(alpha: 0.5),
    ),
  ),
);

/// Two-letter stand-in when a team has no artwork — "Real Madrid" → RM. Takes
/// the first *rune*, not the first code unit: an emoji or astral first character
/// is a surrogate pair and indexing it renders a replacement glyph.
String _initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .take(2)
    .map(
      (word) => word.runes.isEmpty ? '' : String.fromCharCode(word.runes.first),
    )
    .join()
    .toUpperCase();

/// The source's no-artwork crest — a 20px `foreground/10` disc carrying the
/// team's initials. `foreground`, not `mutedForeground`: the /10 tint already
/// lifts the disc toward the muted ramp, and muted text on top of it lands
/// under AA in both themes.
Widget _initialsSlot(BeuiColors colors, String name) => SizedBox(
  width: 28,
  height: 20,
  child: Center(
    child: Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.foreground.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials(name),
        style: TextStyle(
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w600,
          color: colors.foreground,
        ),
      ),
    ),
  ),
);

/// The winner triangle — source `M6 0 0 4 6 8Z` in a 6×8 box, pointing left.
class _WinnerMarkerPainter extends CustomPainter {
  _WinnerMarkerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(6, 0)
      ..lineTo(0, 4)
      ..lineTo(6, 8)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_WinnerMarkerPainter old) => old.color != color;
}

/// A 44px chevron hit target wrapping a 36px circular affordance whose fill
/// lights up on hover/focus (source `group-hover:bg-foreground/10`).
class _ChevronButton extends StatefulWidget {
  const _ChevronButton({
    required this.colors,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final BeuiColors colors;
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  State<_ChevronButton> createState() => _ChevronButtonState();
}

class _ChevronButtonState extends State<_ChevronButton> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final active = _hover || _focus;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? colors.foreground.withValues(alpha: 0.1)
                      : Colors.transparent,
                  border: _focus
                      ? Border.all(color: colors.ring, width: 2)
                      : null,
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: active ? colors.foreground : colors.mutedForeground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _sideLabel(BeuiMatchSide side) {
  final name = side.team?.name ?? 'TBD';
  if (side.score == null) return name;
  final pen = side.penalties != null ? ' (${side.penalties} on penalties)' : '';
  return '$name ${side.score}$pen';
}

String _matchLabel(BeuiMatch m) {
  final sides = m.status == BeuiMatchStatus.finished
      ? '${_sideLabel(m.home)}, ${_sideLabel(m.away)}'
      : '${_sideLabel(m.home)} versus ${_sideLabel(m.away)}';
  final schedule = [
    if (m.date != null) m.date!,
    if (m.time != null) m.time!,
  ].join(', ');
  final when = m.status == BeuiMatchStatus.upcoming && schedule.isNotEmpty
      ? ', $schedule'
      : '';
  final winnerName = switch (m.winner) {
    BeuiMatchWinner.home => m.home.team?.name,
    BeuiMatchWinner.away => m.away.team?.name,
    null => null,
  };
  final outcome = winnerName != null ? ', $winnerName won' : '';
  return '$sides$when$outcome';
}
