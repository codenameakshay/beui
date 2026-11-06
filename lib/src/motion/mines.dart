import 'dart:async';
import 'dart:math' as math;
import 'dart:math' show Random;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'action_swap.dart';
import 'adaptive_stepper.dart';
import 'button/base.dart';
import 'mines_round.dart';
import 'number_ticker.dart';
import 'tooltip.dart';

export 'mines_round.dart' show BeuiMinesTile, beuiMinesMultiplier;

// WHY: preserve the source icon's 300ms, bounce-zero spring trajectory; motor
// snaps only after isDone so intermediate physics and overshoot are unchanged.
const _iconSpring = SpringMotion(
  SpringDescription(
    mass: 1,
    stiffness: 947.2880491901974,
    damping: 61.556089843010575,
  ),
  snapToEnd: true,
);
// WHY: the gem tile squash uses its own 350ms bounce-0.4 source spring.
const _gemPopSpring = SpringMotion(
  SpringDescription(
    mass: 1,
    stiffness: 993.772545574175,
    damping: 37.82898975160204,
  ),
);
// WHY: the result ticket has a distinct 400ms bounce-0.15 entrance; motor
// snaps only after isDone so intermediate physics and overshoot are unchanged.
const _cardSpring = SpringMotion(
  SpringDescription(
    mass: 1,
    stiffness: 471.9377376648011,
    damping: 36.931017611910924,
  ),
  snapToEnd: true,
);
// WHY: replay cells pop with the source's short 300ms bounce-0.3 spring; motor
// snaps only after isDone so intermediate physics and overshoot are unchanged.
const _cellSpring = SpringMotion(
  SpringDescription(
    mass: 1,
    stiffness: 1075.7627219872961,
    damping: 45.91835074450192,
  ),
  snapToEnd: true,
);
const _oddsMotion = CurvedMotion(Duration(milliseconds: 200), beuiEaseOut);
const _shakeMotion = CurvedMotion(Duration(milliseconds: 300), Curves.linear);
const _pulseMotion = CurvedMotion(Duration(milliseconds: 350), Curves.linear);
const _rippleMotion = CurvedMotion(Duration(milliseconds: 450), beuiEaseOut);
const _startWaveMotion = CurvedMotion(Duration(milliseconds: 200), beuiEaseOut);
const _sourceEaseOut = _SourceCubic(.16, 1, .3, 1);
const _stageMotion = CurvedMotion(Duration(milliseconds: 250), _sourceEaseOut);
const _pickOrderFade = CurvedMotion(Duration(milliseconds: 150), beuiEaseOut);
const _resultReducedFade = CurvedMotion(
  Duration(milliseconds: 200),
  _SourceCubic(0, 0, .58, 1),
);
const _resultExitFade = CurvedMotion(
  Duration(milliseconds: 150),
  _sourceEaseOut,
);
const _rippleStep = Duration(milliseconds: 25);
const _pulseStep = Duration(milliseconds: 40);
const _pulseDuration = Duration(milliseconds: 350);
const _replayStart = Duration(milliseconds: 300);
const _replayStep = Duration(milliseconds: 50);
const _ticketStageDelays = <Duration>[
  Duration(milliseconds: 50),
  Duration(milliseconds: 100),
  Duration(milliseconds: 180),
  Duration(milliseconds: 240),
];
const _resultExitDuration = Duration(milliseconds: 150);

/// Keeps the source cubic's frame values without Flutter's 0.001 x-error
/// approximation. The physical springs and shared easing tokens are unchanged.
class _SourceCubic extends Curve {
  const _SourceCubic(this.x1, this.y1, this.x2, this.y2);

  final double x1;
  final double y1;
  final double x2;
  final double y2;

  @override
  double transformInternal(double t) {
    var low = 0.0;
    var high = 1.0;
    for (var iteration = 0; iteration < 48; iteration++) {
      final u = (low + high) / 2;
      final inverse = 1 - u;
      final x =
          3 * inverse * inverse * u * x1 + 3 * inverse * u * u * x2 + u * u * u;
      if (x < t) {
        low = u;
      } else {
        high = u;
      }
    }
    final u = (low + high) / 2;
    final inverse = 1 - u;
    return 3 * inverse * inverse * u * y1 +
        3 * inverse * u * u * y2 +
        u * u * u;
  }
}

/// A Mines board. Find gems to raise the multiplier, then cash out before a
/// mine ends the round.
class BeuiMines extends StatefulWidget {
  /// Creates a Mines game with a square [size] × [size] board.
  const BeuiMines({
    this.size = 5,
    this.mines,
    this.defaultMines = 3,
    this.onMinesChange,
    this.onReveal,
    this.onCashOut,
    this.sound,
    this.defaultSound = false,
    this.onSoundChange,
    this.showResult = true,
    this.semanticLabel = 'Mines',
    super.key,
  });

  /// Tiles on each side of the square board. Values below 2 use 2.
  final int size;

  /// Controlled mine count. Changes apply to the next round.
  final int? mines;

  /// Initial mine count when [mines] is uncontrolled.
  final int defaultMines;

  /// Called after the mine count changes.
  final ValueChanged<int>? onMinesChange;

  /// Called for each unique pick. A mine reports multiplier zero.
  final void Function(int tile, BeuiMinesTile result, double multiplier)?
  onReveal;

  /// Called when the player cashes out or clears every safe tile.
  final void Function(double multiplier, int gems)? onCashOut;

  /// Controlled sound preference. Playback is gated on the shared Components
  /// sound service and is not produced by this widget yet.
  final bool? sound;

  /// Initial sound preference when [sound] is uncontrolled.
  final bool defaultSound;

  /// Called after the sound preference changes.
  final ValueChanged<bool>? onSoundChange;

  /// Whether to show the round ticket after its reveal sequence.
  final bool showResult;

  /// Accessible name for the game.
  final String semanticLabel;

  @override
  State<BeuiMines> createState() => _BeuiMinesState();
}

class _BeuiMinesState extends State<BeuiMines> {
  late MinesRound _round;
  late int _internalMines;
  late bool _internalSound;
  late List<FocusNode> _tileFocus;
  final FocusScopeNode _sectionFocus = FocusScopeNode(debugLabel: 'Mines game');
  final FocusNode _mainButtonFocus = FocusNode(debugLabel: 'Mines main action');
  final Set<int> _closingReveals = <int>{};
  final Set<int> _celebrating = <int>{};
  final Set<int> _startWaveTiles = <int>{};
  final List<Timer> _timers = <Timer>[];
  Timer? _resultTimer;
  int _cursor = 0;
  int? _focusVisibleTile;
  int _roundSerial = 0;
  int _shakeSerial = 0;
  bool _resultOpen = false;
  String _announcement = '';

  int get _size => math.max(2, widget.size).toInt();
  int get _tiles => _size * _size;
  int get _chosenMines =>
      (widget.mines ?? _internalMines).clamp(1, _tiles - 1).toInt();
  bool get _soundOn => widget.sound ?? _internalSound;
  bool get _over =>
      _round.phase == BeuiMinesPhase.busted ||
      _round.phase == BeuiMinesPhase.cashed;
  bool get _resultShown => _resultOpen && widget.showResult && _over;
  int get _mines =>
      _round.phase == BeuiMinesPhase.idle ? _chosenMines : _round.mineCount;
  int get _gems => _round.gemsFound;
  double get _multiplier => beuiMinesMultiplier(_tiles, _mines, _gems);
  double get _nextMultiplier => beuiMinesMultiplier(_tiles, _mines, _gems + 1);
  double get _safeChance => (_tiles - _mines - _gems) / (_tiles - _gems);

  @override
  void initState() {
    super.initState();
    _internalMines = widget.defaultMines;
    _internalSound = widget.defaultSound;
    _round = MinesRound(size: _size, mineCount: _chosenMines);
    _tileFocus = _createTileFocus(_tiles);
  }

  List<FocusNode> _createTileFocus(int count) => List<FocusNode>.generate(
    count,
    (index) => FocusNode(debugLabel: 'Mines tile ${index + 1}'),
  );

  @override
  void didUpdateWidget(covariant BeuiMines oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_normalizedSize(oldWidget.size) != _size) {
      _cancelTimers();
      for (final node in _tileFocus) {
        node.dispose();
      }
      _tileFocus = _createTileFocus(_tiles);
      _round = MinesRound(size: _size, mineCount: _chosenMines);
      _closingReveals.clear();
      _celebrating.clear();
      _startWaveTiles.clear();
      _cursor = 0;
      _focusVisibleTile = null;
      _resultOpen = false;
      _roundSerial++;
    } else if (oldWidget.mines != widget.mines && _over) {
      _cancelTimers();
      _round = MinesRound(size: _size, mineCount: _chosenMines);
      _resultOpen = false;
      _closingReveals.clear();
      _celebrating.clear();
      _startWaveTiles.clear();
      _cursor = 0;
      _focusVisibleTile = null;
      _roundSerial++;
    } else if (oldWidget.showResult && !widget.showResult) {
      _cancelResultTimer();
      _resultOpen = false;
    } else if (!oldWidget.showResult && widget.showResult && _over) {
      _scheduleResult(
        _closingDuration(MediaQuery.disableAnimationsOf(context)),
      );
    }
  }

  static int _normalizedSize(int value) => math.max(2, value).toInt();

  @override
  void dispose() {
    _cancelTimers();
    for (final node in _tileFocus) {
      node.dispose();
    }
    _sectionFocus.dispose();
    _mainButtonFocus.dispose();
    super.dispose();
  }

  void _cancelTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _cancelResultTimer();
  }

  void _cancelResultTimer() {
    _resultTimer?.cancel();
    _resultTimer = null;
  }

  void _schedule(Duration delay, VoidCallback callback) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      if (mounted) callback();
    });
    _timers.add(timer);
  }

  void _setMines(double value) {
    final count = value.round().clamp(1, _tiles - 1).toInt();
    if (_over) {
      _cancelTimers();
      _round = MinesRound(size: _size, mineCount: count);
      _resultOpen = false;
      _closingReveals.clear();
      _celebrating.clear();
      _startWaveTiles.clear();
      _cursor = 0;
      _focusVisibleTile = null;
      _roundSerial++;
    }
    setState(() {
      if (widget.mines == null) _internalMines = count;
    });
    widget.onMinesChange?.call(count);
  }

  void _start() {
    _cancelTimers();
    _startWaveTiles.clear();
    setState(() {
      _round = MinesRound(size: _size, mineCount: _chosenMines)
        ..start(Random());
      _closingReveals.clear();
      _celebrating.clear();
      _resultOpen = false;
      _announcement =
          'Round started with $_chosenMines ${_chosenMines == 1 ? 'mine' : 'mines'}.';
      _roundSerial++;
    });
    if (!MediaQuery.disableAnimationsOf(context)) {
      for (var tile = 0; tile < _tiles; tile++) {
        final wave = tile ~/ _size + tile % _size;
        _schedule(_rippleStep * wave, () {
          setState(() => _startWaveTiles.add(tile));
        });
      }
    }
  }

  void _pick(int tile) {
    final reveal = _round.reveal(tile);
    if (reveal == null) return;
    setState(() {
      _announcement = reveal.result == BeuiMinesTile.mine
          ? 'Mine. The round is over.'
          : reveal.completedRound
          ? 'Cashed out at ${beuiFormatMinesMultiplier(reveal.multiplier)}.'
          : 'Gem. ${beuiFormatMinesMultiplier(reveal.multiplier)}.';
      if (reveal.result == BeuiMinesTile.mine) _shakeSerial++;
    });
    if (reveal.result == BeuiMinesTile.mine) {
      _finishRound(cashed: false);
      widget.onReveal?.call(reveal.tile, reveal.result, reveal.multiplier);
    } else if (reveal.completedRound) {
      final payout = MinesCashOut(
        multiplier: reveal.multiplier,
        gems: reveal.gems,
      );
      _finishRound(cashed: true);
      widget.onReveal?.call(reveal.tile, reveal.result, reveal.multiplier);
      widget.onCashOut?.call(payout.multiplier, payout.gems);
    } else {
      widget.onReveal?.call(reveal.tile, reveal.result, reveal.multiplier);
    }
  }

  void _cashOut() {
    final payout = _round.cashOut();
    if (payout == null) return;
    setState(() {
      _announcement =
          'Cashed out at ${beuiFormatMinesMultiplier(payout.multiplier)}.';
    });
    _finishRound(cashed: true);
    widget.onCashOut?.call(payout.multiplier, payout.gems);
  }

  void _finishRound({required bool cashed}) {
    _closingReveals.clear();
    _celebrating.clear();
    final reduce = MediaQuery.disableAnimationsOf(context);
    final picked = _round.picked;
    final lastPick = picked.isEmpty ? _tiles ~/ 2 : picked.last;
    final pickedOrder = <int, int>{
      for (var index = 0; index < picked.length; index++) picked[index]: index,
    };
    var closing = Duration.zero;
    for (var tile = 0; tile < _tiles; tile++) {
      if (pickedOrder.containsKey(tile)) continue;
      final delay = _rippleStep * _ringFrom(lastPick, tile, _size);
      final end = delay + const Duration(milliseconds: 300);
      if (end > closing) closing = end;
      _schedule(delay, () => setState(() => _closingReveals.add(tile)));
    }
    if (cashed && !reduce) {
      for (var order = 0; order < picked.length; order++) {
        final tile = picked[order];
        final delay = _pulseStep * order;
        final end = delay + _pulseDuration;
        if (end > closing) closing = end;
        _schedule(delay, () => setState(() => _celebrating.add(tile)));
      }
    }
    setState(() {});
    if (widget.showResult) _scheduleResult(closing);
  }

  Duration _closingDuration(bool reduce) {
    final pickedTiles = _round.picked;
    final lastPick = pickedTiles.isEmpty ? _tiles ~/ 2 : pickedTiles.last;
    var closing = Duration.zero;
    final picked = pickedTiles.toSet();
    for (var tile = 0; tile < _tiles; tile++) {
      if (picked.contains(tile)) continue;
      final end =
          _rippleStep * _ringFrom(lastPick, tile, _size) +
          const Duration(milliseconds: 300);
      if (end > closing) closing = end;
    }
    if (_round.phase == BeuiMinesPhase.cashed && !reduce) {
      final end = _pulseStep * (pickedTiles.length - 1) + _pulseDuration;
      if (end > closing) closing = end;
    }
    return closing;
  }

  void _scheduleResult(Duration delay) {
    _cancelResultTimer();
    _resultTimer = Timer(delay, () {
      _resultTimer = null;
      if (!mounted || !widget.showResult || !_over) return;
      setState(() => _resultOpen = true);
      if (_sectionFocus.hasFocus) _mainButtonFocus.requestFocus();
    });
  }

  void _closeResult() {
    setState(() => _resultOpen = false);
    _mainButtonFocus.requestFocus();
  }

  KeyEventResult _onGameKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _resultShown) {
      _closeResult();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _toggleSound() {
    final next = !_soundOn;
    setState(() {
      if (widget.sound == null) _internalSound = next;
    });
    widget.onSoundChange?.call(next);
  }

  KeyEventResult _onTileKey(int tile, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final row = tile ~/ _size;
    final column = tile % _size;
    final next = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight =>
        row * _size + math.min(_size - 1, column + 1).toInt(),
      LogicalKeyboardKey.arrowLeft =>
        row * _size + math.max(0, column - 1).toInt(),
      LogicalKeyboardKey.arrowDown =>
        math.min(_size - 1, row + 1).toInt() * _size + column,
      LogicalKeyboardKey.arrowUp =>
        math.max(0, row - 1).toInt() * _size + column,
      LogicalKeyboardKey.home => row * _size,
      LogicalKeyboardKey.end => row * _size + _size - 1,
      _ => -1,
    };
    if (next >= 0) {
      setState(() => _cursor = next);
      _tileFocus[next].requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      _pick(tile);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final multiplier = _multiplier;
    final safe = _safeChance;
    final actionEnabled = _round.phase != BeuiMinesPhase.playing || _gems > 0;
    final picked = _round.picked;
    final mineTiles = _round.mines;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 448.0;
        final boardSize = math.min(448.0, available).toDouble();
        final board = SizedBox.square(
          key: const ValueKey('mines-board'),
          dimension: boardSize,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.muted.withValues(alpha: 0.40),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ExcludeSemantics(
                  excluding: _resultShown,
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _tiles,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _size,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (context, tile) => _buildTile(
                      context,
                      tile,
                      picked: picked,
                      mineTiles: mineTiles,
                      colors: colors,
                      reduce: reduce,
                    ),
                  ),
                ),
              ),
              _MinesResultLayer(
                visible: _resultShown,
                phase: _round.phase,
                multiplier: _multiplier,
                gems: _gems,
                safeTiles: _tiles - _mines,
                mines: _mines,
                size: _size,
                picked: picked,
                mineTiles: mineTiles,
                reduce: reduce,
                colors: colors,
                onHide: _closeResult,
              ),
            ],
          ),
        );

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: boardSize,
            child: Focus(
              onKeyEvent: _onGameKey,
              child: FocusScope(
                node: _sectionFocus,
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  label: widget.semanticLabel,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 12,
                        spacing: 12,
                        children: [
                          BeuiAdaptiveStepper(
                            value: _chosenMines.toDouble(),
                            onChanged: _setMines,
                            min: 1,
                            max: (_tiles - 1).toDouble(),
                            disabled: _round.phase == BeuiMinesPhase.playing,
                            formatValueText: (value) =>
                                '${value.round()} ${value.round() == 1 ? 'mine' : 'mines'}',
                            semanticLabel: 'Mine count',
                            children: [
                              const BeuiAdaptiveStepperDecrement(),
                              BeuiAdaptiveStepperValue(
                                builder: (context, value) => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CustomPaint(
                                      size: const Size(16, 16),
                                      painter: _MinesIconPainter(
                                        BeuiColors.resolve(
                                          context,
                                        ).mutedForeground,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      value == value.roundToDouble()
                                          ? value.toInt().toString()
                                          : value.toString(),
                                    ),
                                  ],
                                ),
                              ),
                              const BeuiAdaptiveStepperIncrement(),
                            ],
                          ),
                          _MultiplierReadout(
                            multiplier: multiplier,
                            busted: _round.phase == BeuiMinesPhase.busted,
                            phase: _round.phase,
                            nextMultiplier: _nextMultiplier,
                            safeChance: safe,
                            reduce: reduce,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      board,
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              button: true,
                              enabled: actionEnabled,
                              label: _round.phase == BeuiMinesPhase.playing
                                  ? 'Cash out ${beuiFormatMinesMultiplier(multiplier)}'
                                  : _over
                                  ? 'Play again'
                                  : 'Start',
                              onTap: actionEnabled
                                  ? (_round.phase == BeuiMinesPhase.playing
                                        ? _cashOut
                                        : _start)
                                  : null,
                              child: ExcludeSemantics(
                                child: BeuiButton(
                                  focusNode: _mainButtonFocus,
                                  pressScale: 0.96,
                                  onPressed:
                                      _round.phase == BeuiMinesPhase.playing
                                      ? _cashOut
                                      : _start,
                                  child: Text(
                                    _round.phase == BeuiMinesPhase.playing
                                        ? 'Cash out ${beuiFormatMinesMultiplier(multiplier)}'
                                        : _over
                                        ? 'Play again'
                                        : 'Start',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          BeuiTooltip(
                            content: const Text('Sound'),
                            child: MouseRegion(
                              child: Semantics(
                                label: 'Sound',
                                button: true,
                                toggled: _soundOn,
                                onTap: _toggleSound,
                                child: ExcludeSemantics(
                                  child: BeuiButton(
                                    key: const ValueKey('mines-sound'),
                                    variant: BeuiButtonVariant.secondary,
                                    pressScale: 0.96,
                                    onPressed: _toggleSound,
                                    child: IconTheme(
                                      data: IconThemeData(
                                        color: _soundOn
                                            ? colors.foreground
                                            : colors.mutedForeground,
                                      ),
                                      child: BeuiActionSwapIcon(
                                        value: _soundOn ? 'on' : 'off',
                                        icon: _soundOn
                                            ? LucideIcons.volume_2
                                            : LucideIcons.volume_x,
                                        variant: BeuiActionSwapVariant.cascade,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Semantics(
                        liveRegion: true,
                        label: _announcement,
                        child: const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTile(
    BuildContext context,
    int tile, {
    required List<int> picked,
    required Set<int> mineTiles,
    required BeuiColors colors,
    required bool reduce,
  }) {
    final isPicked = picked.contains(tile);
    final isMine = mineTiles.contains(tile);
    final over = _over;
    final shown = isPicked || over;
    final visualShown = isPicked || !over || _closingReveals.contains(tile);
    final content = shown
        ? (isMine ? BeuiMinesTile.mine : BeuiMinesTile.gem)
        : null;
    final mineColor = _mineColor(context);
    final interactive = _round.phase == BeuiMinesPhase.playing && !isPicked;
    final order = picked.indexOf(tile);
    final hit = isPicked && isMine;
    final row = tile ~/ _size;
    final column = tile % _size;
    final label = !shown
        ? 'hidden'
        : !isPicked
        ? '${content!.name}, not picked'
        : hit
        ? 'mine, hit'
        : 'gem, pick ${order + 1}';

    Widget face = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: beuiEaseOut,
      decoration: BoxDecoration(
        color: !interactive && !shown
            ? colors.card.withValues(alpha: 0.60)
            : content == BeuiMinesTile.gem
            ? isPicked
                  ? colors.primary.withValues(alpha: 0.15)
                  : colors.card.withValues(alpha: 0.40)
            : content == BeuiMinesTile.mine
            ? hit
                  ? mineColor.withValues(alpha: 0.20)
                  : colors.card.withValues(alpha: 0.40)
            : colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focusVisibleTile == tile
              ? colors.ring
              : interactive
              ? colors.border
              : Colors.transparent,
          width: _focusVisibleTile == tile ? 2 : 1,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (content != null && visualShown)
            Center(
              child: _buildTileContent(
                content,
                tile: tile,
                isPicked: isPicked,
                celebrate: _celebrating.contains(tile) && !reduce,
                colors: colors,
                reduce: reduce,
              ),
            ),
          if (isPicked && !isMine)
            Positioned(
              top: 5,
              left: 7,
              child: _MinesPickOrder(
                key: ValueKey('mines-pick-order-$tile'),
                order: order + 1,
                color: colors.primary.withValues(alpha: 0.7),
              ),
            ),
          if (hit && !reduce)
            Positioned.fill(
              child: _MinesRipple(serial: _roundSerial, color: mineColor),
            ),
        ],
      ),
    );

    if (isPicked && content == BeuiMinesTile.gem && !reduce) {
      face = SingleMotionBuilder(
        key: ValueKey('gem-pop-$_roundSerial-$tile'),
        value: 1,
        from: 0.92,
        motion: motionFor(context, _gemPopSpring, isMovement: true),
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: face,
      );
    }
    if (hit && !reduce) {
      face = _MinesShake(
        key: ValueKey('mine-shake-$_roundSerial-$_shakeSerial'),
        child: face,
      );
    }
    face = _MinesStartWave(
      key: ValueKey('start-wave-$_roundSerial-$tile'),
      active: _startWaveTiles.contains(tile) && !reduce,
      child: face,
    );

    return Semantics(
      container: true,
      button: true,
      enabled: interactive,
      label: 'Row ${row + 1}, column ${column + 1}, $label',
      onTap: interactive
          ? () {
              _tileFocus[tile].requestFocus();
              _pick(tile);
            }
          : null,
      child: Focus(
        focusNode: _tileFocus[tile],
        canRequestFocus: !_resultShown,
        skipTraversal: _resultShown || tile != _cursor,
        onFocusChange: (focused) {
          if (focused) {
            setState(() {
              _cursor = tile;
              _focusVisibleTile =
                  FocusManager.instance.highlightMode ==
                      FocusHighlightMode.traditional
                  ? tile
                  : null;
            });
          } else if (_focusVisibleTile == tile) {
            setState(() => _focusVisibleTile = null);
          }
        },
        onKeyEvent: (_, event) => _onTileKey(tile, event),
        child: _MinesTileInteraction(
          key: ValueKey('mines-tile-$tile'),
          enabled: interactive,
          reduce: reduce,
          onActivate: () {
            _tileFocus[tile].requestFocus();
            _pick(tile);
          },
          child: face,
        ),
      ),
    );
  }

  Widget _buildTileContent(
    BeuiMinesTile content, {
    required int tile,
    required bool isPicked,
    required bool celebrate,
    required BeuiColors colors,
    required bool reduce,
  }) {
    final iconColor = content == BeuiMinesTile.gem
        ? colors.primary
        : _mineColor(context);
    final icon = LayoutBuilder(
      builder: (context, constraints) {
        final extent = math
            .max(
              20.0,
              math.min(constraints.maxWidth, constraints.maxHeight) * 0.45,
            )
            .toDouble();
        return content == BeuiMinesTile.gem
            ? Icon(LucideIcons.gem, size: extent, color: iconColor)
            : CustomPaint(
                size: Size.square(extent),
                painter: _MinesIconPainter(iconColor),
              );
      },
    );
    Widget revealed;
    if (reduce) {
      revealed = SingleMotionBuilder(
        key: ValueKey('tile-icon-reduced-$_roundSerial-$tile-${content.name}'),
        value: 1,
        from: 0,
        motion: motionFor(context, _iconSpring, isMovement: false),
        builder: (context, progress, child) => Opacity(
          key: ValueKey('mines-icon-opacity-$tile'),
          opacity: progress * (isPicked ? 1 : 0.4),
          child: child,
        ),
        child: icon,
      );
    } else {
      revealed = SingleMotionBuilder(
        key: ValueKey('tile-icon-$_roundSerial-$tile-${content.name}'),
        value: 1,
        from: 0,
        motion: motionFor(context, _iconSpring, isMovement: true),
        builder: (context, progress, child) => Opacity(
          key: ValueKey('mines-icon-opacity-$tile'),
          opacity: progress * (isPicked ? 1 : 0.4),
          child: ImageFiltered(
            key: ValueKey('mines-icon-blur-$tile'),
            imageFilter: ui.ImageFilter.blur(
              sigmaX: 4 * (1 - progress),
              sigmaY: 4 * (1 - progress),
            ),
            child: Transform.scale(
              key: ValueKey('mines-icon-scale-$tile'),
              scale: 0.25 + 0.75 * progress,
              child: child,
            ),
          ),
        ),
        child: icon,
      );
    }
    return _MinesCashOutPulse(
      key: ValueKey('cashout-pulse-$_roundSerial-$tile'),
      active: celebrate,
      tile: tile,
      child: revealed,
    );
  }
}

class _MinesResultLayer extends StatefulWidget {
  const _MinesResultLayer({
    required this.visible,
    required this.phase,
    required this.multiplier,
    required this.gems,
    required this.safeTiles,
    required this.mines,
    required this.size,
    required this.picked,
    required this.mineTiles,
    required this.reduce,
    required this.colors,
    required this.onHide,
  });

  final bool visible;
  final BeuiMinesPhase phase;
  final double multiplier;
  final int gems;
  final int safeTiles;
  final int mines;
  final int size;
  final List<int> picked;
  final Set<int> mineTiles;
  final bool reduce;
  final BeuiColors colors;
  final VoidCallback onHide;

  @override
  State<_MinesResultLayer> createState() => _MinesResultLayerState();
}

class _MinesResultLayerState extends State<_MinesResultLayer> {
  _MinesResultData? _exitData;
  Timer? _exitTimer;

  _MinesResultData _dataFrom(_MinesResultLayer widget) => _MinesResultData(
    phase: widget.phase,
    multiplier: widget.multiplier,
    gems: widget.gems,
    safeTiles: widget.safeTiles,
    mines: widget.mines,
    size: widget.size,
    picked: List<int>.of(widget.picked),
    mineTiles: Set<int>.of(widget.mineTiles),
    reduce: widget.reduce,
    colors: widget.colors,
  );

  @override
  void initState() {
    super.initState();
    if (widget.visible) _exitData = _dataFrom(widget);
  }

  @override
  void didUpdateWidget(covariant _MinesResultLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible) {
      _exitTimer?.cancel();
      _exitTimer = null;
      _exitData = _dataFrom(widget);
    } else if (oldWidget.visible) {
      _exitData = _dataFrom(oldWidget);
      _exitTimer?.cancel();
      _exitTimer = Timer(_resultExitDuration, () {
        if (mounted) setState(() => _exitData = null);
      });
    }
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.visible ? _dataFrom(widget) : _exitData;
    if (data == null) return const SizedBox.shrink();
    final card = Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ticketWidth = math.min(272.0, constraints.maxWidth).toDouble();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 272),
              child: _MinesResultPresence(
                visible: widget.visible,
                reduce: data.reduce,
                child: _MinesResultCard(
                  key: const ValueKey('mines-result-card'),
                  phase: data.phase,
                  multiplier: data.multiplier,
                  gems: data.gems,
                  safeTiles: data.safeTiles,
                  mines: data.mines,
                  size: data.size,
                  picked: data.picked,
                  mineTiles: data.mineTiles,
                  reduce: data.reduce,
                  colors: data.colors,
                  showMap: ticketWidth > 240,
                ),
              ),
            ),
          );
        },
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: !widget.visible,
            child: ExcludeSemantics(
              excluding: !widget.visible,
              child: TweenAnimationBuilder<double>(
                key: ValueKey('mines-cover-${widget.visible}'),
                tween: Tween<double>(
                  begin: widget.visible ? 0 : 1,
                  end: widget.visible ? 1 : 0,
                ),
                duration: widget.visible
                    ? const Duration(milliseconds: 200)
                    : _resultExitDuration,
                curve: beuiEaseOut,
                builder: (context, opacity, _) => Opacity(
                  opacity: opacity,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: Semantics(
                      button: true,
                      label: 'Hide result and show the board',
                      onTap: widget.visible ? widget.onHide : null,
                      child: ExcludeSemantics(
                        child: TextButton(
                          onPressed: widget.visible ? widget.onHide : null,
                          style: TextButton.styleFrom(
                            backgroundColor: data.colors.background.withValues(
                              alpha: 0.55,
                            ),
                            foregroundColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(24),
                              ),
                            ),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          ExcludeSemantics(
            excluding: !widget.visible,
            child: IgnorePointer(child: card),
          ),
        ],
      ),
    );
  }
}

class _MinesResultData {
  const _MinesResultData({
    required this.phase,
    required this.multiplier,
    required this.gems,
    required this.safeTiles,
    required this.mines,
    required this.size,
    required this.picked,
    required this.mineTiles,
    required this.reduce,
    required this.colors,
  });

  final BeuiMinesPhase phase;
  final double multiplier;
  final int gems;
  final int safeTiles;
  final int mines;
  final int size;
  final List<int> picked;
  final Set<int> mineTiles;
  final bool reduce;
  final BeuiColors colors;
}

class _MinesResultPresence extends StatelessWidget {
  const _MinesResultPresence({
    required this.visible,
    required this.reduce,
    required this.child,
  });

  final bool visible;
  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = visible && !reduce
        ? _cardSpring
        : visible
        ? _resultReducedFade
        : _resultExitFade;
    return SingleMotionBuilder(
      key: const ValueKey('mines-result-opacity-transition'),
      value: visible ? 1 : 0,
      from: visible ? 0 : 1,
      motion: motionFor(context, motion, isMovement: false),
      builder: (context, opacity, child) => Opacity(
        key: const ValueKey('mines-result-enter-opacity'),
        opacity: opacity.clamp(0.0, 1.0).toDouble(),
        child: SingleMotionBuilder(
          key: const ValueKey('mines-result-y-transition'),
          value: reduce
              ? 0
              : visible
              ? 0
              : 8,
          from: reduce
              ? 0
              : visible
              ? 16
              : 0,
          motion: motionFor(context, motion, isMovement: true),
          builder: (context, y, child) => Transform.translate(
            key: const ValueKey('mines-result-enter-transform'),
            offset: Offset(0, y),
            child: SingleMotionBuilder(
              key: const ValueKey('mines-result-scale-transition'),
              value: reduce
                  ? 1
                  : visible
                  ? 1
                  : 0.98,
              from: reduce
                  ? 1
                  : visible
                  ? 0.96
                  : 1,
              motion: motionFor(context, motion, isMovement: true),
              builder: (context, scale, child) => Transform.scale(
                key: const ValueKey('mines-result-enter-scale'),
                scale: scale,
                child: child,
              ),
              child: child,
            ),
          ),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _MinesTileInteraction extends StatefulWidget {
  const _MinesTileInteraction({
    required this.enabled,
    required this.reduce,
    required this.onActivate,
    required this.child,
    super.key,
  });

  final bool enabled;
  final bool reduce;
  final VoidCallback onActivate;
  final Widget child;

  @override
  State<_MinesTileInteraction> createState() => _MinesTileInteractionState();
}

class _MinesStartWave extends StatelessWidget {
  const _MinesStartWave({required this.active, required this.child, super.key});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleMotionBuilder(
    value: active ? 1 : 0,
    from: 0,
    motion: motionFor(context, _startWaveMotion, isMovement: true),
    builder: (context, progress, child) => Opacity(
      opacity: active ? 0.5 + 0.5 * progress : 1,
      child: Transform.scale(
        scale: active ? 0.94 + 0.06 * progress : 1,
        child: child,
      ),
    ),
    child: child,
  );
}

class _MinesPickOrder extends StatefulWidget {
  const _MinesPickOrder({required this.order, required this.color, super.key});

  final int order;
  final Color color;

  @override
  State<_MinesPickOrder> createState() => _MinesPickOrderState();
}

class _MinesPickOrderState extends State<_MinesPickOrder> {
  Timer? _timer;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = Text(
      '${widget.order}',
      style: TextStyle(
        color: widget.color,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        fontFeatures: const [ui.FontFeature.tabularFigures()],
      ),
    );
    return SingleMotionBuilder(
      value: _ready ? 1 : 0,
      from: 0,
      motion: motionFor(context, _pickOrderFade, isMovement: false),
      builder: (context, opacity, child) => Opacity(
        key: ValueKey('mines-pick-order-opacity-${widget.order}'),
        opacity: opacity.clamp(0.0, 1.0).toDouble(),
        child: child,
      ),
      child: label,
    );
  }
}

class _MinesTileInteractionState extends State<_MinesTileInteraction> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: widget.enabled ? (_) => setState(() => _hovered = true) : null,
    onExit: widget.enabled ? (_) => setState(() => _hovered = false) : null,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onActivate : null,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: widget.enabled
          ? () => setState(() => _pressed = false)
          : null,
      child: TweenAnimationBuilder<Offset>(
        tween: Tween<Offset>(
          end: widget.enabled && !widget.reduce && _hovered
              ? const Offset(0, -2)
              : Offset.zero,
        ),
        duration: const Duration(milliseconds: 150),
        curve: beuiEaseOut,
        builder: (context, offset, child) => Transform.translate(
          offset: offset,
          child: AnimatedScale(
            scale: !widget.enabled || widget.reduce || !_pressed ? 1 : 0.96,
            duration: const Duration(milliseconds: 120),
            curve: beuiEaseOut,
            child: child,
          ),
        ),
        child: widget.child,
      ),
    ),
  );
}

class _MultiplierReadout extends StatelessWidget {
  const _MultiplierReadout({
    required this.multiplier,
    required this.busted,
    required this.phase,
    required this.nextMultiplier,
    required this.safeChance,
    required this.reduce,
  });

  final double multiplier;
  final bool busted;
  final BeuiMinesPhase phase;
  final double nextMultiplier;
  final double safeChance;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final multiplierText = busted
        ? Text(
            beuiFormatMinesMultiplier(multiplier),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: colors.mutedForeground,
              decoration: TextDecoration.lineThrough,
              decorationThickness: 2,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          )
        : BeuiNumberTicker(
            value: multiplier,
            decimals: 2,
            formatNumber: (value) => _compact(value.toDouble()),
            suffix: '×',
            startOnView: false,
            duration: const Duration(milliseconds: 350),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        multiplierText,
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (phase == BeuiMinesPhase.playing || phase == BeuiMinesPhase.idle)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _OddsRing(safe: safeChance, reduce: reduce),
              ),
            Flexible(
              child: Text(
                phase == BeuiMinesPhase.busted
                    ? 'Multiplier lost'
                    : phase == BeuiMinesPhase.cashed
                    ? 'Multiplier'
                    : phase == BeuiMinesPhase.playing
                    ? '${(safeChance * 100).round()}% safe · next ${beuiFormatMinesMultiplier(nextMultiplier)}'
                    : 'First pick ${(safeChance * 100).round()}% safe',
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: colors.mutedForeground,
                  fontSize: 12,
                  fontFeatures: const [ui.FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OddsRing extends StatelessWidget {
  const _OddsRing({required this.safe, required this.reduce});

  final double safe;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final color = safe < 0.5 ? _mineColor(context) : colors.primary;
    final ring = CustomPaint(
      size: const Size.square(14),
      painter: _OddsPainter(
        progress: safe.clamp(0.0, 1.0).toDouble(),
        color: color,
        track: colors.foreground.withValues(alpha: 0.10),
      ),
    );
    if (reduce) return ring;
    return SingleMotionBuilder(
      value: safe.clamp(0.0, 1.0).toDouble(),
      motion: motionFor(context, _oddsMotion, isMovement: true),
      builder: (context, progress, child) => CustomPaint(
        size: const Size.square(14),
        painter: _OddsPainter(
          progress: progress,
          color: color,
          track: colors.foreground.withValues(alpha: 0.10),
        ),
      ),
      child: ring,
    );
  }
}

class _OddsPainter extends CustomPainter {
  const _OddsPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.0;
    const radius = 5.5;
    final center = Offset(size.width / 2, size.height / 2);
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0).toDouble(),
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _OddsPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      color != oldDelegate.color ||
      track != oldDelegate.track;
}

class _MinesShake extends StatelessWidget {
  const _MinesShake({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleMotionBuilder(
    value: 1,
    from: 0,
    motion: motionFor(context, _shakeMotion, isMovement: true),
    builder: (context, progress, child) => Transform.translate(
      key: const ValueKey('mines-shake-offset'),
      offset: Offset(_shakeOffset(progress), 0),
      child: child,
    ),
    child: child,
  );

  double _shakeOffset(double progress) {
    const stops = <double>[0, -5, 5, -3, 3, 0];
    final scaled = progress.clamp(0.0, 1.0).toDouble() * (stops.length - 1);
    final index = math.min(scaled.floor(), stops.length - 2).toInt();
    final t = beuiEaseOut.transform(scaled - index);
    return stops[index] + (stops[index + 1] - stops[index]) * t;
  }
}

class _MinesCashOutPulse extends StatelessWidget {
  const _MinesCashOutPulse({
    required this.active,
    required this.tile,
    required this.child,
    super.key,
  });

  final bool active;
  final int tile;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleMotionBuilder(
    value: active ? 1 : 0,
    from: 0,
    motion: motionFor(context, _pulseMotion, isMovement: true),
    builder: (context, progress, child) {
      final firstHalf = progress <= 0.5;
      final segment = firstHalf ? progress * 2 : (progress - 0.5) * 2;
      final eased = beuiEaseOut.transform(segment);
      final scale = firstHalf ? 1 + 0.2 * eased : 1.2 - 0.2 * eased;
      return Transform.scale(
        key: ValueKey('mines-cashout-pulse-scale-$tile'),
        scale: scale,
        child: child,
      );
    },
    child: child,
  );
}

class _MinesRipple extends StatelessWidget {
  const _MinesRipple({required this.serial, required this.color});

  final int serial;
  final Color color;

  @override
  Widget build(BuildContext context) => SingleMotionBuilder(
    key: ValueKey('ripple-$serial'),
    value: 1,
    from: 0,
    motion: motionFor(context, _rippleMotion, isMovement: true),
    builder: (context, progress, _) => Transform.scale(
      scale: 1 + 0.7 * progress,
      child: Opacity(
        opacity: 0.7 * (1 - progress),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ),
  );
}

class _MinesStage extends StatefulWidget {
  const _MinesStage({
    required this.delay,
    required this.reduce,
    required this.child,
    super.key,
  });

  final Duration delay;
  final bool reduce;
  final Widget child;

  @override
  State<_MinesStage> createState() => _MinesStageState();
}

class _MinesStageState extends State<_MinesStage> {
  Timer? _timer;
  late bool _ready;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void didUpdateWidget(covariant _MinesStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.delay != widget.delay || oldWidget.reduce != widget.reduce) {
      _timer?.cancel();
      _begin();
    }
  }

  void _begin() {
    _ready = widget.reduce || widget.delay == Duration.zero;
    if (_ready) return;
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stage = (widget.key! as ValueKey<String>).value;
    final opacityKey = ValueKey('$stage-opacity');
    return SingleMotionBuilder(
      value: _ready ? 1 : 0,
      from: 0,
      motion: motionFor(context, _stageMotion, isMovement: false),
      builder: (context, progress, child) => Opacity(
        key: opacityKey,
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, widget.reduce ? 0 : 6 * (1 - progress)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

class _MinesCellReplay extends StatefulWidget {
  const _MinesCellReplay({
    required this.tile,
    required this.delay,
    required this.reduce,
    required this.child,
    super.key,
  });

  final int tile;
  final Duration delay;
  final bool reduce;
  final Widget child;

  @override
  State<_MinesCellReplay> createState() => _MinesCellReplayState();
}

class _MinesCellReplayState extends State<_MinesCellReplay> {
  Timer? _timer;
  late bool _ready;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void didUpdateWidget(covariant _MinesCellReplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.delay != widget.delay || oldWidget.reduce != widget.reduce) {
      _timer?.cancel();
      _begin();
    }
  }

  void _begin() {
    _ready = widget.reduce || widget.delay == Duration.zero;
    if (_ready) return;
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleMotionBuilder(
      value: _ready ? 1 : 0,
      from: widget.reduce ? 1 : 0,
      motion: motionFor(context, _cellSpring, isMovement: true),
      builder: (context, scale, child) => Opacity(
        key: ValueKey('mines-map-cell-opacity-${widget.tile}'),
        opacity: widget.reduce ? 1 : scale.clamp(0.0, 1.0).toDouble(),
        child: Transform.scale(
          scale: widget.reduce ? 1 : 0.4 + 0.6 * scale,
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

class _MinesResultCard extends StatelessWidget {
  const _MinesResultCard({
    required this.phase,
    required this.multiplier,
    required this.gems,
    required this.safeTiles,
    required this.mines,
    required this.size,
    required this.picked,
    required this.mineTiles,
    required this.reduce,
    required this.colors,
    required this.showMap,
    super.key,
  });

  final BeuiMinesPhase phase;
  final double multiplier;
  final int gems;
  final int safeTiles;
  final int mines;
  final int size;
  final List<int> picked;
  final Set<int> mineTiles;
  final bool reduce;
  final BeuiColors colors;
  final bool showMap;

  @override
  Widget build(BuildContext context) {
    final cashed = phase == BeuiMinesPhase.cashed;
    final mineColor = _mineColor(context);
    final card = Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Round result',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 272),
        child: ClipPath(
          clipper: const _TicketClipper(),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 40,
                  spreadRadius: -12,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 104,
                  child: ColoredBox(
                    color: (cashed ? colors.primary : mineColor).withValues(
                      alpha: 0.10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _MinesStage(
                          key: const ValueKey('mines-ticket-stage-0'),
                          delay: _ticketStageDelays[0],
                          reduce: reduce,
                          child: Text(
                            cashed ? 'CASHED OUT' : 'MINE HIT',
                            style: TextStyle(
                              color: cashed
                                  ? colors.primary
                                  : _mineHeadingColor(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        _MinesStage(
                          key: const ValueKey('mines-ticket-stage-1'),
                          delay: _ticketStageDelays[1],
                          reduce: reduce,
                          child: cashed
                              ? BeuiNumberTicker(
                                  value: multiplier,
                                  decimals: 2,
                                  formatNumber: (value) =>
                                      _compact(value.toDouble()),
                                  suffix: '×',
                                  startOnView: false,
                                  duration: const Duration(milliseconds: 600),
                                  stagger: const Duration(milliseconds: 50),
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : Text(
                                  beuiFormatMinesMultiplier(multiplier),
                                  style: TextStyle(
                                    color: colors.mutedForeground,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.lineThrough,
                                    decorationThickness: 2,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CustomPaint(
                    painter: _DashedLinePainter(colors.border),
                    child: const SizedBox(height: 1, width: double.infinity),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MinesStage(
                          key: const ValueKey('mines-ticket-stage-2'),
                          delay: _ticketStageDelays[2],
                          reduce: reduce,
                          child: Column(
                            children: [
                              _ResultRow(
                                label: 'Gems',
                                value: '$gems of $safeTiles',
                                colors: colors,
                              ),
                              _ResultRow(
                                label: 'Mines',
                                value: '$mines',
                                colors: colors,
                              ),
                              _ResultRow(
                                label: cashed ? 'Odds beaten' : 'Lost on pick',
                                value: cashed
                                    ? '1 in ${_compact(multiplier)}'
                                    : '${picked.length}',
                                colors: colors,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (showMap) ...[
                        const SizedBox(width: 16),
                        _MinesStage(
                          key: const ValueKey('mines-ticket-stage-3'),
                          delay: _ticketStageDelays[3],
                          reduce: reduce,
                          child: _MiniMap(
                            size: size,
                            picked: picked,
                            mineTiles: mineTiles,
                            colors: colors,
                            reduce: reduce,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return card;
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(color: colors.mutedForeground, fontSize: 12),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    ),
  );
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({
    required this.size,
    required this.picked,
    required this.mineTiles,
    required this.colors,
    required this.reduce,
  });

  final int size;
  final List<int> picked;
  final Set<int> mineTiles;
  final BeuiColors colors;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final gap = size > 10 ? 1.0 : 3.0;
    final width = math.min(88.0, size * 8.0 + (size - 1) * gap).toDouble();
    return SizedBox(
      key: const ValueKey('mines-mini-map'),
      width: width,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: size * size,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: size,
          crossAxisSpacing: gap,
          mainAxisSpacing: gap,
        ),
        itemBuilder: (context, tile) {
          final selected = picked.contains(tile);
          final mine = mineTiles.contains(tile);
          final hit = tile == (picked.isEmpty ? -1 : picked.last) && mine;
          final mineColor = _mineColor(context);
          final color = selected && !mine
              ? colors.primary
              : selected && hit
              ? mineColor
              : mine
              ? mineColor.withValues(alpha: 0.60)
              : colors.foreground.withValues(alpha: 0.10);
          Widget cell = DecoratedBox(
            decoration: BoxDecoration(
              color: mine && !selected ? Colors.transparent : color,
              borderRadius: BorderRadius.circular(2),
              border: mine && !selected
                  ? Border.all(color: mineColor.withValues(alpha: 0.60))
                  : null,
            ),
          );
          if (selected) {
            cell = _MinesCellReplay(
              key: ValueKey('map-$tile-${picked.indexOf(tile)}'),
              tile: tile,
              delay: _replayStart + _replayStep * picked.indexOf(tile),
              reduce: reduce,
              child: cell,
            );
          }
          return cell;
        },
      ),
    );
  }
}

class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper();

  @override
  Path getClip(Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      )
      ..addOval(Rect.fromCircle(center: Offset(0, 104), radius: 9))
      ..addOval(Rect.fromCircle(center: Offset(size.width, 104), radius: 9))
      ..fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  bool shouldReclip(covariant _TicketClipper oldClipper) => false;
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, 0.5),
        Offset(math.min(x + 4, size.width).toDouble(), 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      color != oldDelegate.color;
}

class _MinesIconPainter extends CustomPainter {
  const _MinesIconPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final unit = size.width / 24;
    final axialPaint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5 * unit;
    final diagonalPaint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2 * unit;
    for (var index = 0; index < 8; index++) {
      final angle = index * math.pi / 4;
      final reach = index.isEven ? 10.5 : 9.0;
      final start =
          center + Offset(math.cos(angle), math.sin(angle)) * (6 * unit);
      final end =
          center + Offset(math.cos(angle), math.sin(angle)) * (reach * unit);
      canvas.drawLine(start, end, index.isEven ? axialPaint : diagonalPaint);
    }
    canvas.drawCircle(center, 6.5 * unit, Paint()..color = color);
    canvas.drawCircle(
      center + Offset(-2.25 * unit, -2.25 * unit),
      1.6 * unit,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(covariant _MinesIconPainter oldDelegate) =>
      color != oldDelegate.color;
}

int _ringFrom(int from, int tile, int size) => math
    .max((tile ~/ size - from ~/ size).abs(), (tile % size - from % size).abs())
    .toInt();

Color _mineColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFFB7185)
    : const Color(0xFFF43F5E);

Color _mineHeadingColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFFB7185)
    : const Color(0xFFE11D48);

String _compact(double value) {
  if (value < 10000) return value.toStringAsFixed(2);
  if (value >= 1e15) {
    return value
        .toStringAsExponential(1)
        .replaceAll('.0e', 'E')
        .replaceAll('E+', 'E')
        .replaceAll('e+', 'E')
        .replaceAll('e', 'E');
  }
  const suffixes = <String>['', 'K', 'M', 'B', 'T'];
  var tier = (math.log(value) / math.ln10 / 3)
      .floor()
      .clamp(1, suffixes.length - 1)
      .toInt();
  var scaled = value / math.pow(1000, tier);
  if (scaled.toStringAsFixed(1) == '1000.0' && tier < suffixes.length - 1) {
    tier++;
    scaled = value / math.pow(1000, tier);
  }
  final rounded = scaled.toStringAsFixed(1);
  return '${rounded.endsWith('.0') ? rounded.substring(0, rounded.length - 2) : rounded}${suffixes[tier]}';
}

/// Formats a multiplier as Mines displays it, including compact large values.
String beuiFormatMinesMultiplier(double value) => '${_compact(value)}×';
