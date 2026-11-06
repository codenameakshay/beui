import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '_engine.dart' show SingleMotionController, SpringMotion;
import '_focus_ring.dart';

/// The table area that currently owns a card.
enum BeuiCardDealerZone {
  /// Face-down cards waiting to be dealt.
  deck,

  /// Face-up cards held in the fan.
  hand,

  /// Face-up cards already played to the discard stack.
  pile,
}

/// The stable identity and accessible name required by [BeuiCardDealer].
abstract interface class BeuiCardDealerCard {
  /// Stable identity used to preserve a card's mounted face during a move.
  String get id;

  /// The table area currently owning this card.
  BeuiCardDealerZone get zone;

  /// Accessible name used when this card is a selectable hand button.
  String get label;
}

/// A face-down deck, fanned hand, and played-card pile.
///
/// [cards] is the complete table state. Keep card IDs stable while changing a
/// card's [BeuiCardDealerCard.zone] or its position within a zone. Moving a
/// card between zones flies the existing card frame along a raised arc and
/// flips its face. Reordering cards in the hand uses a shorter hop. A hand card
/// becomes a button only when [onCardSelect] is provided.
///
/// The face renderers remain mounted for every zone. The default back uses the
/// active [BeuiColors] palette. [cardWidth], [cardHeight], [spread], and
/// [angle] control the table geometry.
class BeuiCardDealer<T extends BeuiCardDealerCard> extends StatefulWidget {
  /// Creates a card table from the full ordered [cards] state.
  const BeuiCardDealer({
    required this.cards,
    required this.renderFace,
    this.renderBack,
    this.onCardSelect,
    this.cardWidth = 84,
    this.cardHeight = 120,
    this.spread = 46,
    this.angle = 5,
    this.semanticLabel = 'Card table',
    super.key,
  }) : assert(cardWidth > 0),
       assert(cardHeight > 0),
       assert(spread >= 0),
       assert(angle >= 0);

  /// Every card on the table. Order within a zone is its stacking and fan order.
  final List<T> cards;

  /// Builds the face-up content. It remains mounted while the card is face-down.
  final Widget Function(T card) renderFace;

  /// Builds a custom card back. Omit it for the palette-striped default.
  final Widget Function(T card)? renderBack;

  /// Makes hand cards buttons and reports the selected card ID.
  final ValueChanged<String>? onCardSelect;

  /// Card width in logical pixels. Defaults to 84.
  final double cardWidth;

  /// Card height in logical pixels. Defaults to 120.
  final double cardHeight;

  /// Maximum horizontal gap between neighboring hand cards. Defaults to 46.
  final double spread;

  /// Rotation in degrees between neighboring hand cards. Defaults to 5.
  final double angle;

  /// Accessible name for the table. Defaults to "Card table".
  final String semanticLabel;

  @override
  State<BeuiCardDealer<T>> createState() => _BeuiCardDealerState<T>();
}

// Table-crossing flights and shorter hand hops have distinct source timing,
// so shared UI springs cannot preserve them. Motion resolves both at unit mass.
const double _flightVisualDuration = 0.55;
const double _flightBounce = 0.18;
const double _hopVisualDuration = 0.4;
const double _hopBounce = 0.2;
const double _flightStrength = -0.35;
const double _hopStrength = -0.3;
const double _staggerSeconds = 0.045;
const double _maxStaggerWindow = 0.6;
const double _edge = 16;
const double _hoverLift = 18;
const double _hoverPush = 14;
const double _maxFanAngle = 40;
const double _maxFanDrop = 26;
const double _fanDrop = 2.2;
const double _stageHeight = 320;
const double _facePerspective = 0.00125;
const double _cardRadius = 12;

final SpringMotion _flightSpring = _visualSpring(
  _flightVisualDuration,
  _flightBounce,
);
final SpringMotion _hopSpring = _visualSpring(_hopVisualDuration, _hopBounce);

SpringMotion _visualSpring(double visualDuration, double bounce) {
  final root = 2 * math.pi / (visualDuration * 1.2);
  final dampingRatio = (1 - bounce).clamp(0.05, 1.0).toDouble();
  return SpringMotion(
    SpringDescription(
      mass: 1,
      stiffness: root * root,
      damping: 2 * dampingRatio * root,
    ),
  );
}

class _CardPosition {
  const _CardPosition(this.zone, this.slot);

  final BeuiCardDealerZone zone;
  final int slot;
}

enum _CardMove { none, straight, flight, hop }

class _CardPose {
  const _CardPose({
    required this.x,
    required this.y,
    required this.rotate,
    required this.faceDown,
    required this.z,
    required this.zone,
  });

  final double x;
  final double y;
  final double rotate;
  final bool faceDown;
  final int z;
  final BeuiCardDealerZone zone;
}

class _BeuiCardDealerState<T extends BeuiCardDealerCard>
    extends State<BeuiCardDealer<T>> {
  final Map<String, _CardPosition> _previous = {};
  String? _hoveredId;
  Size? _previousSize;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final deck = widget.cards
        .where((card) => card.zone == BeuiCardDealerZone.deck)
        .toList(growable: false);
    final hand = widget.cards
        .where((card) => card.zone == BeuiCardDealerZone.hand)
        .toList(growable: false);
    final pile = widget.cards
        .where((card) => card.zone == BeuiCardDealerZone.pile)
        .toList(growable: false);

    assert(
      widget.cards.map((card) => card.id).toSet().length == widget.cards.length,
      'BeuiCardDealer card IDs must be unique.',
    );

    return SelectionContainer.disabled(
      child: Semantics(
        container: true,
        label: widget.semanticLabel,
        explicitChildNodes: true,
        child: SizedBox(
          height: _stageHeight,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(
                constraints.maxWidth.isFinite ? constraints.maxWidth : 0,
                constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : _stageHeight,
              );
              final resized = _previousSize != null && _previousSize != size;
              _previousSize = size;

              final movers = widget.cards.where((card) {
                final old = _previous[card.id];
                return old != null && old.zone != card.zone;
              }).length;
              final stagger = movers > 1
                  ? math.min(_staggerSeconds, _maxStaggerWindow / (movers - 1))
                  : 0.0;
              var moving = 0;

              final entries =
                  <(T, _CardPose, int, _CardMove, Duration, bool, bool)>[];
              for (final zone in [deck, hand, pile]) {
                for (var slot = 0; slot < zone.length; slot++) {
                  final card = zone[slot];
                  final old = _previous[card.id];
                  final pose = _poseFor(card, slot, hand, size);
                  var move = _CardMove.straight;
                  var delay = Duration.zero;
                  if (old == null) {
                    move = _CardMove.none;
                  } else if (old.zone != card.zone) {
                    move = _CardMove.flight;
                    delay = Duration(
                      microseconds: (moving * stagger * 1000000).round(),
                    );
                    moving++;
                  } else if (card.zone == BeuiCardDealerZone.hand &&
                      old.slot != slot) {
                    move = _CardMove.hop;
                  }
                  entries.add((card, pose, slot, move, delay, resized, reduce));
                }
              }

              _previous
                ..clear()
                ..addEntries([
                  for (final zone in [deck, hand, pile])
                    for (var slot = 0; slot < zone.length; slot++)
                      MapEntry(
                        zone[slot].id,
                        _CardPosition(zone[slot].zone, slot),
                      ),
                ]);

              entries.sort((a, b) => a.$2.z.compareTo(b.$2.z));
              return FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final entry in entries)
                      _BeuiCardDealerItem<T>(
                        key: ValueKey(entry.$1.id),
                        card: entry.$1,
                        pose: entry.$2,
                        move: entry.$4,
                        delay: entry.$5,
                        resized: entry.$6,
                        reduceMotion: entry.$7,
                        width: widget.cardWidth,
                        height: widget.cardHeight,
                        renderFace: widget.renderFace,
                        renderBack: widget.renderBack,
                        colors: colors,
                        tabOrder: entry.$1.zone == BeuiCardDealerZone.hand
                            ? entry.$3
                            : 0,
                        selectable:
                            entry.$1.zone == BeuiCardDealerZone.hand &&
                            widget.onCardSelect != null,
                        focusable:
                            entry.$1.zone == BeuiCardDealerZone.hand &&
                            widget.onCardSelect != null,
                        onSelect: widget.onCardSelect == null
                            ? null
                            : () => widget.onCardSelect!(entry.$1.id),
                        onHoverChanged: (hovered) =>
                            _setHovered(entry.$1.id, hovered),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _setHovered(String id, bool hovered) {
    final next = hovered ? id : (_hoveredId == id ? null : _hoveredId);
    if (next == _hoveredId) return;
    setState(() => _hoveredId = next);
  }

  _CardPose _poseFor(T card, int slot, List<T> hand, Size size) {
    if (card.zone == BeuiCardDealerZone.deck) {
      final depth = math.min(slot, 6) * 0.6;
      return _CardPose(
        x: _edge - depth,
        y: _edge - depth,
        rotate: 0,
        faceDown: true,
        z: slot,
        zone: card.zone,
      );
    }
    if (card.zone == BeuiCardDealerZone.pile) {
      return _CardPose(
        x: size.width - widget.cardWidth - _edge,
        y: _edge,
        rotate: _pileTilt(card.id),
        faceDown: false,
        z: 400 + slot,
        zone: card.zone,
      );
    }

    final count = hand.length;
    final offset = slot - (count - 1) / 2;
    final edge = math.max((count - 1) / 2, 1.0);
    final reach = offset / edge;
    final tilt = math.min(widget.angle * edge, _maxFanAngle);
    final drop = math.min(_fanDrop * edge * edge, _maxFanDrop);
    final room = size.width - widget.cardWidth - _edge * 2;
    final step = count > 1 ? math.min(widget.spread, room / (count - 1)) : 0.0;
    final hoveredSlot = _hoveredId == null
        ? -1
        : hand.indexWhere((item) => item.id == _hoveredId);
    final push = hoveredSlot < 0 || slot == hoveredSlot
        ? 0.0
        : (slot > hoveredSlot ? 1.0 : -1.0) * _hoverPush;
    return _CardPose(
      x: size.width / 2 - widget.cardWidth / 2 + offset * step + push,
      y:
          size.height -
          widget.cardHeight -
          _edge +
          reach * reach * drop -
          (slot == hoveredSlot ? _hoverLift : 0),
      rotate: reach * tilt,
      faceDown: false,
      z: slot == hoveredSlot ? 300 : 100 + slot,
      zone: card.zone,
    );
  }
}

double _pileTilt(String id) {
  var hash = 0;
  for (final code in id.codeUnits) {
    hash = (hash * 31 + code) & 0xFFFFFFFF;
    if (hash >= 0x80000000) hash -= 0x100000000;
  }
  return ((hash.abs() % 17) - 8) * 1.1;
}

class _BeuiCardDealerItem<T extends BeuiCardDealerCard> extends StatefulWidget {
  const _BeuiCardDealerItem({
    required super.key,
    required this.card,
    required this.pose,
    required this.move,
    required this.delay,
    required this.resized,
    required this.reduceMotion,
    required this.width,
    required this.height,
    required this.renderFace,
    required this.renderBack,
    required this.colors,
    required this.tabOrder,
    required this.selectable,
    required this.focusable,
    required this.onSelect,
    required this.onHoverChanged,
  });

  final T card;
  final _CardPose pose;
  final _CardMove move;
  final Duration delay;
  final bool resized;
  final bool reduceMotion;
  final double width;
  final double height;
  final Widget Function(T card) renderFace;
  final Widget Function(T card)? renderBack;
  final BeuiColors colors;
  final int tabOrder;
  final bool selectable;
  final bool focusable;
  final VoidCallback? onSelect;
  final ValueChanged<bool> onHoverChanged;

  @override
  State<_BeuiCardDealerItem<T>> createState() => _BeuiCardDealerItemState<T>();
}

class _BeuiCardDealerItemState<T extends BeuiCardDealerCard>
    extends State<_BeuiCardDealerItem<T>>
    with TickerProviderStateMixin {
  late final SingleMotionController _flight;
  late final SingleMotionController _hop;
  late final SingleMotionController _face;
  Timer? _pendingStart;
  int _motionGeneration = 0;
  int _faceGeneration = 0;
  late _CardPose _from;
  late _CardPose _to;
  _CardPose? _painted;
  _CardMove _activeMove = _CardMove.none;
  late double _faceFrom;
  late double _faceTo;
  double _paintedFaceAngle = 0;
  bool _focusVisible = false;

  double get _progress => switch (_activeMove) {
    _CardMove.flight => _flight.value,
    _CardMove.straight || _CardMove.hop => _hop.value,
    _CardMove.none => 1,
  };

  double get _currentFaceAngle =>
      _faceFrom + (_faceTo - _faceFrom) * _face.value;

  @override
  void initState() {
    super.initState();
    _from = widget.pose;
    _to = widget.pose;
    _painted = widget.pose;
    _faceFrom = _faceTo = _paintedFaceAngle = widget.pose.faceDown
        ? math.pi
        : 0;
    _flight = SingleMotionController(
      motion: _flightSpring,
      vsync: this,
      initialValue: 1,
    );
    _hop = SingleMotionController(
      motion: _hopSpring,
      vsync: this,
      initialValue: 1,
    );
    _face = SingleMotionController(
      motion: _flightSpring,
      vsync: this,
      initialValue: 1,
    );
  }

  @override
  void didUpdateWidget(covariant _BeuiCardDealerItem<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateFace(oldWidget.pose.faceDown, widget.pose.faceDown);

    if (widget.reduceMotion) {
      _snapFrame(widget.pose);
      _snapFace(widget.pose.faceDown);
      return;
    }
    if (widget.resized) {
      _snapFrame(widget.pose);
      return;
    }
    if (_sameGeometry(oldWidget.pose, widget.pose)) return;

    _cancelFrameMotion();
    _from = _painted ?? oldWidget.pose;
    _to = widget.pose;

    _activeMove = widget.move == _CardMove.none
        ? _CardMove.straight
        : widget.move;
    final controller = _activeMove == _CardMove.flight ? _flight : _hop;
    controller.value = 0;
    final generation = _motionGeneration;
    if (widget.delay == Duration.zero) {
      _startFrameMotion(controller, generation);
    } else {
      _pendingStart = Timer(widget.delay, () {
        if (mounted && generation == _motionGeneration) {
          _pendingStart = null;
          _startFrameMotion(controller, generation);
        }
      });
    }
  }

  void _updateFace(bool oldFaceDown, bool nextFaceDown) {
    if (widget.reduceMotion) return;
    if (oldFaceDown == nextFaceDown) return;

    _paintedFaceAngle = _currentFaceAngle;
    final generation = ++_faceGeneration;
    _face.stop(canceled: true);
    _faceFrom = _paintedFaceAngle;
    _faceTo = nextFaceDown ? math.pi : 0;
    _face.value = 0;
    _face.animateTo(1).whenCompleteOrCancel(() {
      if (mounted && generation == _faceGeneration) _face.value = 1;
    });
  }

  void _startFrameMotion(SingleMotionController controller, int generation) {
    controller.animateTo(1).whenCompleteOrCancel(() {
      if (mounted && generation == _motionGeneration) controller.value = 1;
    });
  }

  void _cancelFrameMotion() {
    _motionGeneration++;
    _pendingStart?.cancel();
    _pendingStart = null;
    _flight.stop(canceled: true);
    _hop.stop(canceled: true);
  }

  void _snapFrame(_CardPose pose) {
    _cancelFrameMotion();
    _from = _to = pose;
    _painted = pose;
    _activeMove = _CardMove.none;
    _flight.value = 1;
    _hop.value = 1;
  }

  void _snapFace(bool faceDown) {
    _faceGeneration++;
    _face.stop(canceled: true);
    _faceFrom = _faceTo = _paintedFaceAngle = faceDown ? math.pi : 0;
    _face.value = 1;
  }

  @override
  void dispose() {
    _cancelFrameMotion();
    _faceGeneration++;
    _face.stop(canceled: true);
    _flight.dispose();
    _hop.dispose();
    _face.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_flight, _hop, _face]),
      builder: (context, _) {
        final progress = _progress;
        final pose = _interpolatePose(_from, _to, progress, _activeMove);
        _painted = pose;
        final faceAngle = _currentFaceAngle;
        _paintedFaceAngle = faceAngle;
        final cardWidth = widget.width;
        final cardHeight = widget.height;
        final showBack = faceAngle >= math.pi / 2;
        final front = ClipRRect(
          borderRadius: BorderRadius.circular(_cardRadius),
          child: widget.renderFace(widget.card),
        );
        final back = ClipRRect(
          borderRadius: BorderRadius.circular(_cardRadius),
          child:
              widget.renderBack?.call(widget.card) ??
              _DefaultCardBack(colors: widget.colors),
        );

        final surface = SizedBox(
          key: ValueKey('card-frame-${widget.card.id}'),
          width: cardWidth,
          height: cardHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Transform(
                key: ValueKey('card-face-turn-${widget.card.id}'),
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, _facePerspective)
                  ..rotateY(faceAngle),
                child: ExcludeSemantics(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Opacity(opacity: showBack ? 0 : 1, child: front),
                      Opacity(
                        opacity: showBack ? 1 : 0,
                        child: Transform(
                          key: ValueKey(
                            'card-back-orientation-${widget.card.id}',
                          ),
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: back,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.selectable) _selectionOverlay(),
            ],
          ),
        );

        return Positioned(
          left: 0,
          top: 0,
          width: cardWidth,
          height: cardHeight,
          child: Transform.translate(
            offset: Offset(pose.x, pose.y),
            child: Transform.rotate(
              angle: pose.rotate * math.pi / 180,
              alignment: Alignment.center,
              child: surface,
            ),
          ),
        );
      },
    );
  }

  Widget _selectionOverlay() {
    final callback = widget.onSelect;
    if (callback == null) return const SizedBox.expand();
    return FocusTraversalOrder(
      order: NumericFocusOrder(widget.tabOrder.toDouble()),
      child: FocusableActionDetector(
        enabled: widget.focusable,
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (show) => setState(() => _focusVisible = show),
        onFocusChange: widget.onHoverChanged,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              callback();
              return null;
            },
          ),
        },
        child: Semantics(
          button: true,
          label: widget.card.label,
          enabled: true,
          onTap: callback,
          child: MouseRegion(
            onEnter: (_) => widget.onHoverChanged(true),
            onExit: (_) => widget.onHoverChanged(false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: callback,
              child: BeuiFocusRing(
                focused: _focusVisible,
                borderRadius: BorderRadius.circular(_cardRadius),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _sameGeometry(_CardPose a, _CardPose b) =>
    a.x == b.x && a.y == b.y && a.rotate == b.rotate;

double _lerp(double a, double b, double t) => a + (b - a) * t;

_CardPose _interpolatePose(
  _CardPose from,
  _CardPose to,
  double progress,
  _CardMove move,
) {
  final strength = switch (move) {
    _CardMove.flight => _flightStrength,
    _CardMove.hop => _hopStrength,
    _CardMove.none || _CardMove.straight => 0.0,
  };
  final control = _arcControlPoint(from.x, from.y, to.x, to.y, strength);
  return _CardPose(
    x: _bezier(from.x, control.dx, to.x, progress),
    y: _bezier(from.y, control.dy, to.y, progress),
    rotate: _lerp(from.rotate, to.rotate, progress),
    faceDown: progress < 0.5 ? from.faceDown : to.faceDown,
    z: to.z,
    zone: to.zone,
  );
}

Offset _arcControlPoint(
  double fromX,
  double fromY,
  double toX,
  double toY,
  double strength,
) {
  final dx = toX - fromX;
  final dy = toY - fromY;
  final distance = math.sqrt(dx * dx + dy * dy);
  if (distance == 0) return Offset(fromX, fromY);

  final dominant = dx.abs() >= dy.abs() ? dx : dy;
  final signedStrength = dominant < 0 ? -strength : strength;
  return Offset(
    fromX + dx * 0.5 + -dy / distance * signedStrength * distance,
    fromY + dy * 0.5 + dx / distance * signedStrength * distance,
  );
}

double _bezier(double from, double control, double to, double progress) {
  final inverse = 1 - progress;
  return inverse * inverse * from +
      2 * inverse * progress * control +
      progress * progress * to;
}

class _DefaultCardBack extends StatelessWidget {
  const _DefaultCardBack({required this.colors});

  final BeuiColors colors;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: colors.muted,
      border: Border.all(color: colors.border),
      borderRadius: BorderRadius.circular(_cardRadius),
    ),
    child: CustomPaint(
      painter: _CardBackStripePainter(colors.background.withValues(alpha: 0.8)),
    ),
  );
}

class _CardBackStripePainter extends CustomPainter {
  const _CardBackStripePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final clip = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_cardRadius),
    );
    canvas
      ..save()
      ..clipRRect(clip);
    final paint = Paint()..color = color;
    for (var x = -size.height; x < size.width; x += 12) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint..strokeWidth = 6,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CardBackStripePainter oldDelegate) =>
      oldDelegate.color != color;
}
