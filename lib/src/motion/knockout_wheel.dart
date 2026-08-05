import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'knockout_bracket.dart';

// ── Geometry (verbatim from the source module constants) ─────────────────────
// The source draws into a fixed 760-unit square viewBox and lets the browser
// scale it. The port keeps the same unit system: every mark is laid out in
// viewBox units inside a 760×760 stage that is then scaled to the rendered
// width, so all the constants below transfer with no re-derivation.

const double _size = 760;
const double _center = _size / 2;

/// Solid trophy glyph, drawn in a 24-unit box (source `TROPHY_SIZE`).
const double _trophySize = 24;

/// Clears the hub's top edge. The hub's two feeders sit on the horizontal, so
/// the space directly above it is always free (source `TROPHY_GAP`).
const double _trophyGap = 6;

/// Outermost ring. The remaining 62 units of the box absorb the largest node
/// plus its ring stroke, so nothing clips at the stage edge.
const double _outerR = 318;
const double _hubR = 34;

/// Nodes grow outward so the crowded outer ring still reads at small sizes.
const double _nodeMin = 14.2;
const double _nodeStep = 2.2;

/// Initials floor, in viewBox units. The stage never goes below 32rem against a
/// 760-unit box (scale ~0.674), so 15 units is ~10px on screen — under that,
/// two letters are a smudge. `node.r * 0.8` alone puts the inner ring at 7.6px.
const double _initialsMin = 15;

/// Siblings pull slightly toward their parent, opening a lane between subtrees.
const double _siblingGap = 0.9;

/// Puts the hub's two feeders on the horizontal, where there's room for them.
const double _hubAngle = 90;

/// Stage width floor / ceiling — source `min-w-[32rem] max-w-[34rem]`. Below the
/// floor the rim's marks collapse too small to tell apart or tap, so the wheel
/// holds its size and pans instead. The floor is fixed, not rim-derived: node
/// radius grows with depth, so a shallower draw has *smaller* marks and needs
/// the width more, not less.
const double _stageMin = 512;
const double _stageMax = 544;

// ── Motion windows (source module constants) ─────────────────────────────────

/// Ring-by-ring entrance stagger — source `delay: depth * 0.06`.
const int _ringDelayMs = 60;

/// Mark entrance opacity window — source `opacity: { duration: 0.24 }`. The
/// scale half of the same entrance rides [beuiSpringPanel] (`SPRING_PANEL`).
const int _enterOpacityMs = 240;

/// Link entrance window — source `{ duration: 0.3, delay: depth * 0.06 }`.
const int _linkFadeMs = 300;

/// Isolation cross-fade and caption spawn — source `DIM_TRANSITION
/// { duration: 0.18 }`.
const int _dimMs = 180;

/// Opacity a mark recedes to while another one is isolated (source `0.38`).
const double _dimmedOpacity = 0.38;

// ── Pure geometry helpers ────────────────────────────────────────────────────

/// The source quantizes every polar coordinate because `Math.sin`/`cos` differ
/// in their last digits between its SSR engine and the browser, which trips a
/// React hydration mismatch. Flutter has no such split, but keeping the same
/// rounding means the port's coordinates are byte-identical to the reference
/// implementation's — handy when diffing a golden against beui.dev.
double _quantize(double n) => (n * 1e3).roundToDouble() / 1e3;

double _rad(double deg) => deg * math.pi / 180;

Offset _polar(double radius, double deg) {
  final r = _rad(deg);
  return Offset(
    _quantize(_center + radius * math.cos(r)),
    _quantize(_center + radius * math.sin(r)),
  );
}

/// Names and round labels are single ideas, so they wrap as a unit. Without the
/// non-breaking spaces "Round of 16" strands a lone "16" on the next line of a
/// caption. Ported verbatim — the source applies it to the same strings, and
/// they are both drawn and read out, so the label a screen reader gets matches.
String _keepTogether(String text) => text.replaceAll(' ', ' ');

String _teamName(BeuiMatchSide side) => _keepTogether(side.team?.name ?? 'TBD');

BeuiMatchSide? _winnerSide(BeuiMatch match) => switch (match.winner) {
  BeuiMatchWinner.home => match.home,
  BeuiMatchWinner.away => match.away,
  null => null,
};

/// Teams · score, in the order they were played. The round is prepended by the
/// caller that has it (source `matchLabel`).
String _wheelMatchLabel(BeuiMatch match) {
  final teams = '${_teamName(match.home)} v ${_teamName(match.away)}';
  final home = match.home.score;
  final away = match.away.score;
  if (home == null || away == null) return teams;
  final pens = match.home.penalties != null && match.away.penalties != null
      ? ' (${match.home.penalties}–${match.away.penalties} pens)'
      : '';
  return '$teams · $home–$away$pens';
}

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

// ── Wheel model ──────────────────────────────────────────────────────────────

@immutable
class _WheelNode {
  const _WheelNode({
    required this.id,
    required this.parentId,
    required this.depth,
    required this.angle,
    required this.center,
    required this.r,
    required this.team,
    required this.label,
    required this.round,
  });

  final String id;
  final String? parentId;
  final int depth;

  /// Position around the wheel, in degrees. Orders arrow-key navigation.
  final double angle;
  final Offset center;
  final double r;
  final BeuiTeam? team;
  final String label;

  /// Round the node's match belongs to; null on the rim, which holds teams.
  final String? round;
}

@immutable
class _WheelLink {
  const _WheelLink({required this.path, required this.depth});
  final Path path;
  final int depth;
}

@immutable
class _Wheel {
  const _Wheel({
    required this.nodes,
    required this.links,
    required this.champion,
  });
  const _Wheel.empty() : nodes = const [], links = const [], champion = null;

  final List<_WheelNode> nodes;
  final List<_WheelLink> links;
  final BeuiTeam? champion;
}

/// Walks the match tree from the final outward, laying every node on a ring and
/// splitting each parent's wedge between its two feeders — the port of the
/// source `buildWheel`.
_Wheel _buildWheel(List<BeuiBracketRound> rounds) {
  final layers = rounds.length;
  // An empty or malformed catalog renders nothing rather than throwing on the
  // way to the hub.
  if (layers == 0 || rounds[layers - 1].matches.isEmpty) {
    return const _Wheel.empty();
  }

  double ringR(int depth) => (depth / layers) * _outerR;
  double nodeR(int depth) => _nodeMin + (depth - 1) * _nodeStep;

  final nodes = <_WheelNode>[];
  final links = <_WheelLink>[];

  final finalMatch = rounds[layers - 1].matches[0];
  final champion = _winnerSide(finalMatch)?.team;
  nodes.add(
    _WheelNode(
      id: finalMatch.id,
      parentId: null,
      depth: 0,
      angle: _hubAngle,
      center: const Offset(_center, _center),
      r: _hubR,
      team: champion,
      label: _wheelMatchLabel(finalMatch),
      round: rounds[layers - 1].name,
    ),
  );

  // `roundIndex` is the round `match` belongs to; its two feeders live one round
  // out, or, past the first round, are the two teams that played it.
  void walk(
    BeuiMatch match,
    int roundIndex,
    int index,
    _WheelNode parent,
    double angle,
    double wedge,
  ) {
    final depth = parent.depth + 1;
    final radius = ringR(depth);
    final r = nodeR(depth);
    // The hub's two feeders sit opposite each other, so they get plain radial
    // lines; an arc between them would be a half circle.
    final offset = (wedge / 4) * (parent.depth == 0 ? 1 : _siblingGap);
    final angles = [angle - offset, angle + offset];

    final children = <_WheelNode>[];
    final feeders = <BeuiMatch?>[];
    for (var side = 0; side < 2; side++) {
      final childAngle = angles[side];
      final feederIndex = 2 * index + side;
      final feederRound = roundIndex > 0 ? rounds[roundIndex - 1] : null;
      final feeder =
          feederRound != null && feederIndex < feederRound.matches.length
          ? feederRound.matches[feederIndex]
          : null;
      final node = feeder != null
          ? _WheelNode(
              id: feeder.id,
              parentId: parent.id,
              depth: depth,
              angle: childAngle,
              center: _polar(radius, childAngle),
              r: r,
              team: _winnerSide(feeder)?.team,
              label: _wheelMatchLabel(feeder),
              round: feederRound!.name,
            )
          : _WheelNode(
              id: '${match.id}-${side == 0 ? 'home' : 'away'}',
              parentId: parent.id,
              depth: depth,
              angle: childAngle,
              center: _polar(radius, childAngle),
              r: r,
              team: (side == 0 ? match.home : match.away).team,
              label: (side == 0 ? match.home : match.away).team?.name ?? 'TBD',
              round: null,
            );
      nodes.add(node);
      children.add(node);
      feeders.add(feeder);
    }

    if (parent.depth == 0) {
      for (final child in children) {
        links.add(
          _WheelLink(
            path: Path()
              ..moveTo(child.center.dx, child.center.dy)
              ..lineTo(_center, _center),
            depth: depth,
          ),
        );
      }
    } else {
      final midR = (ringR(parent.depth) + radius) / 2;
      final start = _polar(radius, angles[0]);
      final arcStart = _polar(midR, angles[0]);
      final end = _polar(radius, angles[1]);
      links.add(
        _WheelLink(
          // `M outer(a0) L mid(a0) A mid mid 0 0 1 mid(a1) L outer(a1)` — the
          // SVG sweep flag 1 is Flutter's positive sweep, since both measure
          // angles clockwise from +x on a y-down canvas.
          path: Path()
            ..moveTo(start.dx, start.dy)
            ..lineTo(arcStart.dx, arcStart.dy)
            ..arcTo(
              Rect.fromCircle(
                center: const Offset(_center, _center),
                radius: midR,
              ),
              _rad(angles[0]),
              _rad(angles[1] - angles[0]),
              false,
            )
            ..lineTo(end.dx, end.dy),
          depth: depth,
        ),
      );
      final stemOuter = _polar(midR, angle);
      final stemInner = _polar(ringR(parent.depth), angle);
      links.add(
        _WheelLink(
          path: Path()
            ..moveTo(stemOuter.dx, stemOuter.dy)
            ..lineTo(stemInner.dx, stemInner.dy),
          depth: depth,
        ),
      );
    }

    for (var side = 0; side < 2; side++) {
      final feeder = feeders[side];
      if (feeder != null) {
        walk(
          feeder,
          roundIndex - 1,
          2 * index + side,
          children[side],
          angles[side],
          wedge / 2,
        );
      }
    }
  }

  walk(finalMatch, layers - 1, 0, nodes[0], _hubAngle, 360);
  return _Wheel(nodes: nodes, links: links, champion: champion);
}

/// Match ids from the hub down to the champion's first-round win (source
/// `championPath`) — the run that stays lit while the wheel is at rest.
Set<String> _championPath(List<BeuiBracketRound> rounds) {
  final path = <String>{};
  var index = 0;
  for (var r = rounds.length - 1; r >= 0; r--) {
    final matches = rounds[r].matches;
    if (index >= matches.length) return path;
    final match = matches[index];
    final winner = match.winner;
    if (winner == null) return path;
    path.add(match.id);
    final side = winner == BeuiMatchWinner.home ? 'home' : 'away';
    if (r == 0) path.add('${match.id}-$side');
    index = 2 * index + (winner == BeuiMatchWinner.home ? 0 : 1);
  }
  return path;
}

/// Which way an arrow key walks the wheel.
enum _Arrow { up, down, left, right }

class _ArrowIntent extends Intent {
  const _ArrowIntent(this.arrow);
  final _Arrow arrow;
}

/// A tournament drawn radially — the Flutter port of beUI's `knockout-wheel`,
/// the second fixture style on the source's `knockout-bracket` page.
///
/// The champion holds the hub, each round is a ring further out, and the teams
/// themselves form the rim. It reads the **same** `rounds` array as
/// [BeuiKnockoutBracket] — one dataset draws either fixture style — walking the
/// tree from the final outward and splitting each parent's wedge between its two
/// feeders, so a deeper draw simply grows another ring.
///
/// **Motion.** Marks spring in ring by ring: scale 0.6 → 1 on
/// [beuiSpringPanel] (source `SPRING_PANEL`) with a 60ms-per-ring stagger, while
/// opacity rides its own 240ms window and the connectors fade over 300ms on the
/// same stagger. Pointing at a mark isolates it — that node lights (2px
/// foreground ring) and every other recedes to 38% over 180ms; at rest the
/// isolation falls back to the champion's whole run.
///
/// **Reduced motion** drops the scale-in and the ring-by-ring stagger (marks are
/// laid out at their final size immediately) while keeping the opacity
/// cross-fades, per the library rule — the source snaps everything, but the
/// house convention preserves opacity.
///
/// **Input.** Hover is [MouseRegion]-driven so it never fires on touch, where a
/// tap pins a mark instead. Every mark is a focus stop with an arrow-key
/// contract that follows the geometry: ↑ walks toward the hub, ↓ walks out to a
/// feeder, ←/→ go round the ring and wrap. Only the active mark is a tab stop
/// (roving tabindex), so Tab enters and leaves the wheel in one step.
///
/// The stage holds a 32rem floor at every size and pans rather than shrinking
/// its marks, matching the source: node radius *grows* with depth, so a
/// shallower draw has smaller marks and needs the width more, not less.
class BeuiKnockoutWheel extends StatefulWidget {
  /// Creates a wheel from ordered [rounds] (16 → 8 → 4 → 2 → 1 matches).
  const BeuiKnockoutWheel({
    required this.rounds,
    this.initialRound = 0,
    this.flagBuilder,
    super.key,
  });

  /// The whole draw, ordered widest round first — the same array
  /// [BeuiKnockoutBracket] takes. Each round holds half the matches of the one
  /// before it (16 → 8 → 4 → 2 → 1) and `rounds[r].matches[k]` is fed by matches
  /// `2k` and `2k + 1` of the round before it. Two rounds are enough; the wheel
  /// grows a ring per round and sizes itself to the rim.
  final List<BeuiBracketRound> rounds;

  /// Index of the outermost round to draw. Earlier rounds are dropped and the
  /// kept round's own teams become the rim, so `1` on a 32-team draw opens at
  /// the Round of 16. Defaults to 0 (the whole tree); clamped to the valid
  /// range.
  final int initialRound;

  /// Builds a team's crest, drawn on the node's disc and clipped to a circle.
  /// The slot is the full disc (`2 · r` on a side), so pass
  /// `BoxFit.cover` for a 4:3 flag (the source crops it to fill) and
  /// `BoxFit.contain` for a square logo (the source fits it whole, since a crest
  /// cropped to a circle loses its shape), e.g.
  /// `flagBuilder: (ctx, team) => Image.network('https://flagcdn.com/w80/${team.code}.png', fit: BoxFit.cover)`.
  ///
  /// Defaults to the source's own no-artwork fallback — the team's initials —
  /// so the package ships no assets and goldens stay deterministic. An
  /// undecided slot always draws the same shield [BeuiKnockoutBracket] uses for
  /// a TBD side, so an unresolved place reads identically across both fixture
  /// styles.
  final Widget Function(BuildContext context, BeuiTeam team)? flagBuilder;

  @override
  State<BeuiKnockoutWheel> createState() => _BeuiKnockoutWheelState();
}

class _BeuiKnockoutWheelState extends State<BeuiKnockoutWheel> {
  late _Wheel _wheel;
  late Set<String> _winners;
  final _byId = <String, _WheelNode>{};
  final _focusNodes = <String, FocusNode>{};

  /// Nodes of each ring, ordered by angle — ←/→ walk this list.
  final _ring = <int, List<_WheelNode>>{};

  /// First child of each node — ↓ walks to this.
  final _firstChild = <String, _WheelNode>{};

  // Hover and focus are tracked apart: sharing one slot lets a stray pointer
  // move clear the isolation while a mark still holds focus. Tap toggles the
  // pointer slot, matching the source's `onToggle`.
  String? _pointed;
  String? _focused;

  String? get _active => _pointed ?? _focused;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  @override
  void didUpdateWidget(BeuiKnockoutWheel old) {
    super.didUpdateWidget(old);
    if (!identical(old.rounds, widget.rounds) ||
        old.initialRound != widget.initialRound) {
      _rebuild();
    }
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// Everything downstream reads the trimmed catalog, so the kept round's own
  /// teams become the rim (source's `visible` memo).
  List<BeuiBracketRound> get _visibleRounds {
    final rounds = widget.rounds;
    final from = widget.initialRound.clamp(
      0,
      rounds.isEmpty ? 0 : rounds.length - 1,
    );
    return from > 0 ? rounds.sublist(from) : rounds;
  }

  void _rebuild() {
    final rounds = _visibleRounds;
    _wheel = _buildWheel(rounds);
    _winners = _championPath(rounds);

    _byId
      ..clear()
      ..addEntries(_wheel.nodes.map((n) => MapEntry(n.id, n)));

    _ring.clear();
    _firstChild.clear();
    for (final node in _wheel.nodes) {
      (_ring[node.depth] ??= <_WheelNode>[]).add(node);
      final parent = node.parentId;
      if (parent != null) _firstChild.putIfAbsent(parent, () => node);
    }
    for (final peers in _ring.values) {
      peers.sort((a, b) => a.angle.compareTo(b.angle));
    }

    // Drop focus nodes for marks that no longer exist; keep the rest so focus
    // survives a data update.
    for (final id in _focusNodes.keys.toList()) {
      if (!_byId.containsKey(id)) _focusNodes.remove(id)!.dispose();
    }
    for (final node in _wheel.nodes) {
      _focusNodes.putIfAbsent(node.id, () => FocusNode(debugLabel: node.id));
    }
    if (_pointed != null && !_byId.containsKey(_pointed)) _pointed = null;
    if (_focused != null && !_byId.containsKey(_focused)) _focused = null;
  }

  /// Arrow keys follow the geometry: up walks toward the hub, down walks out to
  /// a feeder, left/right go round the ring and wrap. Focus moves; the focus
  /// handler lights whatever it lands on (source `onKey`).
  void _move(_WheelNode from, _Arrow arrow) {
    final _WheelNode? target;
    switch (arrow) {
      case _Arrow.up:
        target = from.parentId == null ? null : _byId[from.parentId];
      case _Arrow.down:
        target = _firstChild[from.id];
      case _Arrow.left:
      case _Arrow.right:
        final peers = _ring[from.depth] ?? const <_WheelNode>[];
        if (peers.length < 2) {
          target = null;
        } else {
          final at = peers.indexOf(from);
          final next = arrow == _Arrow.right ? at + 1 : at - 1;
          target = peers[(next + peers.length) % peers.length];
        }
    }
    if (target == null) return;
    _focusNodes[target.id]?.requestFocus();
  }

  // Both slots are claimed and released *by id*: when the pointer or focus moves
  // straight from one mark to the next, the leaving mark's notification can
  // arrive after the arriving one's, and a blind `set null` would clear the mark
  // that just took the slot.
  void _setPointed(String id, {required bool pointed}) {
    if (pointed) {
      if (_pointed != id) setState(() => _pointed = id);
    } else if (_pointed == id) {
      setState(() => _pointed = null);
    }
  }

  void _setFocused(String id, {required bool focused}) {
    if (focused) {
      if (_focused != id) setState(() => _focused = id);
    } else if (_focused == id) {
      setState(() => _focused = null);
    }
  }

  void _toggle(String id) {
    setState(() => _pointed = _pointed == id ? null : id);
    if (_pointed == null) _focusNodes[id]?.unfocus();
  }

  /// Round · teams · score for a decided match; a rim node is just a team. A
  /// slot whose team isn't known yet reads TBD, matching the shield drawn in its
  /// place (source `captions`).
  String _caption(_WheelNode node) {
    final team = node.team;
    if (team == null) return 'TBD';
    final round = node.round;
    return round == null
        ? team.name
        : '${_keepTogether(round)} · ${node.label}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);

    final nodes = _wheel.nodes;
    final champion = _wheel.champion;
    final activeNode = _active == null ? null : _byId[_active];
    // Pointing at one mark isolates it. Only at rest does the wheel fall back to
    // lighting the champion's whole run.
    final lit = activeNode != null ? {activeNode.id} : _winners;
    final tabStop = activeNode?.id ?? (nodes.isEmpty ? null : nodes.first.id);

    final linksByDepth = <int, List<Path>>{};
    for (final link in _wheel.links) {
      (linksByDepth[link.depth] ??= <Path>[]).add(link.path);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _stageMax;
        final side = available.clamp(_stageMin, _stageMax);
        // Marks are laid out in viewBox units and scaled as one piece; the hit
        // areas and the caption sit above in screen units, exactly as the source
        // lays HTML over its SVG.
        final k = side / _size;

        final stage = Stack(
          clipBehavior: Clip.none,
          children: [
            // Painted layer — glow, connectors, marks. Pruned from the
            // accessibility tree behind one image label, like the source's
            // `role="img"` svg; every result is restated on the hit areas below.
            Positioned.fill(
              child: Semantics(
                image: true,
                label:
                    'Tournament wheel${champion != null ? ', won by ${champion.name}' : ''}',
                child: ExcludeSemantics(
                  child: Transform.scale(
                    scale: k,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: _size,
                      height: _size,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (champion != null)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _GlowPainter(color: colors.warning),
                              ),
                            ),
                          for (final entry in linksByDepth.entries)
                            Positioned.fill(
                              child: _DelayedFade(
                                delayMs: reduce ? 0 : entry.key * _ringDelayMs,
                                durationMs: _linkFadeMs,
                                child: CustomPaint(
                                  painter: _LinksPainter(
                                    paths: entry.value,
                                    color: colors.borderStrong,
                                  ),
                                ),
                              ),
                            ),
                          for (final node in nodes)
                            Positioned(
                              left: node.center.dx - node.r,
                              top: node.center.dy - node.r,
                              width: node.r * 2,
                              height: node.r * 2,
                              child: _WheelMark(
                                key: ValueKey(node.id),
                                node: node,
                                colors: colors,
                                lit: lit.contains(node.id),
                                dimmed:
                                    lit.isNotEmpty && !lit.contains(node.id),
                                showTrophy: node.depth == 0 && champion != null,
                                delayMs: reduce ? 0 : node.depth * _ringDelayMs,
                                reduce: reduce,
                                flagBuilder: widget.flagBuilder,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // An invisible hit area per mark, laid over the painted wheel in
            // screen units so it tracks the stage as it scales.
            for (final node in nodes)
              Positioned(
                left: (node.center.dx - node.r) * k,
                top: (node.center.dy - node.r) * k,
                width: node.r * 2 * k,
                height: node.r * 2 * k,
                child: _WheelAnchor(
                  key: ValueKey('anchor-${node.id}'),
                  node: node,
                  caption: _caption(node),
                  colors: colors,
                  focusNode: _focusNodes[node.id]!,
                  isTabStop: node.id == tabStop,
                  isPinned: node.id == _pointed,
                  onHover: _setPointed,
                  onFocusNode: _setFocused,
                  onToggle: _toggle,
                  onArrow: _move,
                ),
              ),
            if (activeNode != null)
              _Caption(
                key: ValueKey('caption-${activeNode.id}'),
                node: activeNode,
                text: _caption(activeNode),
                colors: colors,
                scale: k,
                stageWidth: side,
                reduce: reduce,
              ),
          ],
        );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            // Fills the viewport and centers when there is room; scrolls when
            // the stage is wider than it (source `overflow-x-auto` + `mx-auto`).
            constraints: BoxConstraints(
              minWidth: available.isFinite ? available : 0,
            ),
            child: Center(
              child: SizedBox(width: side, height: side, child: stage),
            ),
          ),
        );
      },
    );
  }
}

// ── Painting ─────────────────────────────────────────────────────────────────

/// Warm halo marking the champion. Kept faint: `--warning` is saturated enough
/// that anything stronger drowns the connectors under it.
class _GlowPainter extends CustomPainter {
  const _GlowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const center = Offset(_center, _center);
    const radius = _outerR * 0.62;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.14),
          color.withValues(alpha: 0.04),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.color != color;
}

/// One ring's worth of connectors — radial spokes at the hub, `arc + stem`
/// elbows further out. Stroked, never filled, and drawn under the marks, whose
/// discs stay opaque so a link can't read through a crest.
class _LinksPainter extends CustomPainter {
  const _LinksPainter({required this.paths, required this.color});

  final List<Path> paths;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final path in paths) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_LinksPainter old) =>
      old.color != color || old.paths != paths;
}

/// The node's ring — 1px [BeuiColors.border] at rest, 2px [BeuiColors.foreground]
/// when the mark is lit.
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.color, required this.width});

  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.color != color || old.width != width;
}

/// The source's solid trophy glyph, transcribed command-for-command from its
/// `TROPHY_PATH` into a 24-unit box. A hand-drawn mark, so it is painted rather
/// than pulled from the icon set (the package ships no assets, and Lucide's
/// trophy is an outline, not this solid cup).
class _TrophyPainter extends CustomPainter {
  const _TrophyPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      // M5 1h12v3h3a2 2 0 0 1 2 2c0 3.3-2.2 5.6-5.2 6A6 6 0 0 1 12 15
      // a6 6 0 0 1-4.8-2.9C4.2 11.6 2 9.3 2 6a2 2 0 0 1 2-2h1V1Z
      ..moveTo(5, 1)
      ..relativeLineTo(12, 0)
      ..relativeLineTo(0, 3)
      ..relativeLineTo(3, 0)
      ..relativeArcToPoint(const Offset(2, 2), radius: const Radius.circular(2))
      ..relativeCubicTo(0, 3.3, -2.2, 5.6, -5.2, 6)
      ..arcToPoint(const Offset(12, 15), radius: const Radius.circular(6))
      ..relativeArcToPoint(
        const Offset(-4.8, -2.9),
        radius: const Radius.circular(6),
      )
      ..cubicTo(4.2, 11.6, 2, 9.3, 2, 6)
      ..relativeArcToPoint(
        const Offset(2, -2),
        radius: const Radius.circular(2),
      )
      ..relativeLineTo(1, 0)
      ..lineTo(5, 1)
      ..close()
      // m0 5H4c0 1.9 1.1 3.2 2.6 3.7A12 12 0 0 1 5 6Z — left handle cutout.
      ..moveTo(5, 6)
      ..lineTo(4, 6)
      ..relativeCubicTo(0, 1.9, 1.1, 3.2, 2.6, 3.7)
      ..arcToPoint(const Offset(5, 6), radius: const Radius.circular(12))
      ..close()
      // m14 0h-1a12 12 0 0 1-1.6 3.7C17.9 9.2 19 7.9 19 6Z — right handle.
      ..moveTo(19, 6)
      ..lineTo(18, 6)
      ..relativeArcToPoint(
        const Offset(-1.6, 3.7),
        radius: const Radius.circular(12),
      )
      ..cubicTo(17.9, 9.2, 19, 7.9, 19, 6)
      ..close()
      // M9 16.5h6V19h2.5v2h-11v-2H9v-2.5Z — stem and base.
      ..moveTo(9, 16.5)
      ..relativeLineTo(6, 0)
      ..lineTo(15, 19)
      ..relativeLineTo(2.5, 0)
      ..relativeLineTo(0, 2)
      ..relativeLineTo(-11, 0)
      ..relativeLineTo(0, -2)
      ..lineTo(9, 19)
      ..relativeLineTo(0, -2.5)
      ..close();

    final scale = size.width / _trophySize;
    canvas
      ..save()
      ..scale(scale)
      ..drawPath(path, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_TrophyPainter old) => old.color != color;
}

// ── Marks ────────────────────────────────────────────────────────────────────

/// Fades a child in after [delayMs] over [durationMs]. Opacity only, so it
/// survives reduced motion untouched — only the stagger is dropped there.
class _DelayedFade extends StatefulWidget {
  const _DelayedFade({
    required this.delayMs,
    required this.durationMs,
    required this.child,
  });

  final int delayMs;
  final int durationMs;
  final Widget child;

  @override
  State<_DelayedFade> createState() => _DelayedFadeState();
}

class _DelayedFadeState extends State<_DelayedFade> {
  bool _shown = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _shown ? 1 : 0,
    duration: Duration(milliseconds: widget.durationMs),
    curve: beuiEaseOut,
    child: widget.child,
  );
}

/// One node of the wheel: an opaque disc, the team's crest (or initials, or a
/// TBD shield), and the ring. Springs in on [beuiSpringPanel] after its ring's
/// stagger and recedes to [_dimmedOpacity] while another mark is isolated.
class _WheelMark extends StatefulWidget {
  const _WheelMark({
    required this.node,
    required this.colors,
    required this.lit,
    required this.dimmed,
    required this.showTrophy,
    required this.delayMs,
    required this.reduce,
    required this.flagBuilder,
    super.key,
  });

  final _WheelNode node;
  final BeuiColors colors;
  final bool lit;
  final bool dimmed;
  final bool showTrophy;
  final int delayMs;
  final bool reduce;
  final Widget Function(BuildContext, BeuiTeam)? flagBuilder;

  @override
  State<_WheelMark> createState() => _WheelMarkState();
}

class _WheelMarkState extends State<_WheelMark> {
  bool _entered = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _entered = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _crest(BuildContext context) {
    final node = widget.node;
    final colors = widget.colors;
    final team = node.team;
    if (team == null) {
      // The same shield the knockout bracket uses for a TBD slot, so an
      // undecided place reads identically across both fixture styles.
      return Center(
        child: Icon(
          LucideIcons.shield,
          size: node.r * 1.4,
          color: colors.mutedForeground.withValues(alpha: 0.5),
        ),
      );
    }
    final builder = widget.flagBuilder;
    if (builder != null) {
      return ClipOval(child: builder(context, team));
    }
    // No artwork on this team — initials keep the ring readable.
    return Center(
      child: Text(
        _initials(team.name),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: math.max(node.r * 0.8, _initialsMin),
          fontWeight: FontWeight.w600,
          height: 1,
          color: colors.mutedForeground,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final colors = widget.colors;
    final diameter = node.r * 2;

    Widget mark = Stack(
      clipBehavior: Clip.none,
      children: [
        if (widget.showTrophy)
          Positioned(
            left: (diameter - _trophySize) / 2,
            top: -(_trophyGap + _trophySize),
            width: _trophySize,
            height: _trophySize,
            child: CustomPaint(painter: _TrophyPainter(color: colors.warning)),
          ),
        // Stays opaque at every state: connectors are routed underneath and
        // would otherwise read straight through the crest.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.card,
            ),
          ),
        ),
        // Dimming rides on the mark itself rather than a scrim tinted with the
        // page background, so the wheel recedes correctly on any surface.
        Positioned.fill(
          child: AnimatedOpacity(
            opacity: widget.dimmed ? _dimmedOpacity : 1,
            duration: const Duration(milliseconds: _dimMs),
            curve: beuiEaseOut,
            child: _crest(context),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _RingPainter(
              color: widget.lit ? colors.foreground : colors.border,
              width: widget.lit ? 2 : 1,
            ),
          ),
        ),
      ],
    );

    mark = AnimatedOpacity(
      opacity: _entered ? 1 : 0,
      duration: const Duration(milliseconds: _enterOpacityMs),
      curve: beuiEaseOut,
      child: mark,
    );

    if (widget.reduce) return SizedBox.expand(child: mark);

    // Scale is movement, so it is the half that reduced motion drops. The
    // origin is the box centre, i.e. the node centre (source
    // `transformOrigin: node.x node.y`), which carries the trophy with the hub.
    return SizedBox.expand(
      child: SingleMotionBuilder(
        value: _entered ? 1.0 : 0.6,
        motion: beuiSpringPanel,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: mark,
      ),
    );
  }
}

/// The invisible hit area over one mark: hover, tap, focus and arrow keys.
class _WheelAnchor extends StatefulWidget {
  const _WheelAnchor({
    required this.node,
    required this.caption,
    required this.colors,
    required this.focusNode,
    required this.isTabStop,
    required this.isPinned,
    required this.onHover,
    required this.onFocusNode,
    required this.onToggle,
    required this.onArrow,
    super.key,
  });

  final _WheelNode node;
  final String caption;
  final BeuiColors colors;
  final FocusNode focusNode;
  final bool isTabStop;
  final bool isPinned;
  final void Function(String id, {required bool pointed}) onHover;
  final void Function(String id, {required bool focused}) onFocusNode;
  final ValueChanged<String> onToggle;
  final void Function(_WheelNode node, _Arrow arrow) onArrow;

  @override
  State<_WheelAnchor> createState() => _WheelAnchorState();
}

class _WheelAnchorState extends State<_WheelAnchor> {
  bool _focusVisible = false;
  PointerDeviceKind? _lastKind;

  void _handleTap() {
    // Click, not pointer-down: a tap pins the mark, and unpinning has to also
    // drop focus or it stays lit. Mice never take this path — they already
    // isolate on hover, matching the source's `useHoverCapable()` gate.
    if (_lastKind == PointerDeviceKind.mouse) return;
    widget.onToggle(widget.node.id);
  }

  @override
  Widget build(BuildContext context) {
    // Roving tab stop: only the active mark is reachable with Tab, so the wheel
    // is one stop in the page's tab order rather than 63.
    widget.focusNode.skipTraversal = !widget.isTabStop;

    return Semantics(
      button: true,
      label: widget.caption,
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (focused) {
          if (_focusVisible != focused) setState(() => _focusVisible = focused);
        },
        onFocusChange: (focused) =>
            widget.onFocusNode(widget.node.id, focused: focused),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowUp): _ArrowIntent(_Arrow.up),
          SingleActivator(LogicalKeyboardKey.arrowDown): _ArrowIntent(
            _Arrow.down,
          ),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _ArrowIntent(
            _Arrow.left,
          ),
          SingleActivator(LogicalKeyboardKey.arrowRight): _ArrowIntent(
            _Arrow.right,
          ),
        },
        actions: {
          _ArrowIntent: CallbackAction<_ArrowIntent>(
            onInvoke: (intent) {
              widget.onArrow(widget.node, intent.arrow);
              return null;
            },
          ),
        },
        // Isolation is a decorative hover effect, so it hangs off a
        // [MouseRegion] and never fires on touch — the port of the source's
        // `useHoverCapable()` gate. (Not `FocusableActionDetector`'s own
        // hover-highlight hook: that one is additionally gated on Flutter's
        // focus-highlight mode, which is about rendering focus rings, not about
        // whether a pointer is over the mark.)
        child: MouseRegion(
          onEnter: (_) => widget.onHover(widget.node.id, pointed: true),
          onExit: (_) => widget.onHover(widget.node.id, pointed: false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _lastKind = details.kind,
            onTap: _handleTap,
            child: _focusVisible
                // ring-foreground with a background-colored offset, not the ring
                // token: `--ring` is a 10% hairline that disappears over a flag.
                // Focus has to be obvious.
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.colors.background,
                        width: 2,
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.colors.foreground,
                          width: 2,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// The label for the active mark, anchored to it and flipped to the far side
/// near the rim so it stays on stage.
///
/// The source mounts a `Tooltip` per mark on hover-capable devices and falls
/// back to this in-stage caption on touch. The port draws the caption for every
/// input path — hover, focus and tap — rather than mounting one `BeuiOverlay`
/// per mark (63 on a 32-team draw) for the same string in the same place.
class _Caption extends StatefulWidget {
  const _Caption({
    required this.node,
    required this.text,
    required this.colors,
    required this.scale,
    required this.stageWidth,
    required this.reduce,
    super.key,
  });

  final _WheelNode node;
  final String text;
  final BeuiColors colors;
  final double scale;
  final double stageWidth;
  final bool reduce;

  @override
  State<_Caption> createState() => _CaptionState();
}

class _CaptionState extends State<_Caption> {
  bool _shown = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(Duration.zero, () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final colors = widget.colors;
    // Lower half → the caption goes above the mark, so it never runs off stage.
    final above = node.center.dy > _center;
    final k = widget.scale;

    Widget bubble = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.min(288, widget.stageWidth * 0.8),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: colors.foreground.withValues(alpha: 0.12),
              blurRadius: 15,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w500,
              color: colors.foreground,
            ),
          ),
        ),
      ),
    );

    bubble = AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: const Duration(milliseconds: _dimMs),
      curve: beuiEaseOut,
      child: bubble,
    );

    if (!widget.reduce) {
      bubble = SingleMotionBuilder(
        value: _shown ? 1.0 : 0.94,
        motion: const CurvedMotion(Duration(milliseconds: _dimMs), beuiEaseOut),
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: bubble,
      );
    }

    return Positioned(
      left: node.center.dx * k,
      top: (node.center.dy + (above ? -node.r : node.r)) * k,
      child: IgnorePointer(
        child: Transform.translate(
          offset: Offset(0, above ? -8 : 8),
          child: FractionalTranslation(
            translation: Offset(-0.5, above ? -1 : 0),
            child: bubble,
          ),
        ),
      ),
    );
  }
}
