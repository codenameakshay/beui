import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart' show CurvedMotion, NoMotion, SingleMotionController;
import 'action_swap.dart' show BeuiActionSwapIcon, BeuiActionSwapVariant;
import 'button/base.dart';
import 'plinko_model.dart'
    show PlinkoRenderedHitTracker, PlinkoTrajectory, generatePlinkoSlots;
import 'tooltip.dart';

/// Slot values accepted by [BeuiPlinko]. Use numbers for payouts or strings for
/// custom labels. Other object types are intentionally unsupported.
typedef BeuiPlinkoValue = Object;

/// Generates the symmetric geometric payouts for a Plinko board.
///
/// [rows] is clamped to at least one. [center] defaults to 1 and [edge] to
/// 100. Values from 1 (inclusive) to 10 (exclusive) round to whole numbers;
/// other values round to one significant digit.
List<num> beuiPlinkoSlots(int rows, {num center = 1, num edge = 100}) =>
    generatePlinkoSlots(rows, center: center, edge: edge);

/// A responsive Plinko board with source-shaped peg bounces and payouts.
///
/// [slots] overrides [rows]. It must contain at least two values to render;
/// otherwise the board is empty. Without custom [slots], [rows] is clamped to
/// at least one and payouts come from [beuiPlinkoSlots].
///
/// Drops can overlap up to [maxBalls]. [onLand] is called once for every ball
/// that lands. [pegFlash] and [sound] each support controlled and uncontrolled
/// ownership. Sound controls only its preference and callback here; audible
/// playback awaits the shared audio capability.
class BeuiPlinko extends StatefulWidget {
  /// Creates a responsive board. The default board has 12 peg rows.
  const BeuiPlinko({
    this.rows = 12,
    this.slots,
    this.onLand,
    this.maxBalls = 12,
    this.dropLabel = 'Drop ball',
    this.pegFlash,
    this.defaultPegFlash = true,
    this.onPegFlashChange,
    this.pegFlashLabel = 'Peg flash',
    this.sound,
    this.defaultSound = false,
    this.onSoundChange,
    this.soundLabel = 'Sound',
    this.semanticLabel = 'Plinko board',
    super.key,
  }) : assert(maxBalls >= 0);

  /// Peg rows when [slots] is omitted. Defaults to 12.
  final int rows;

  /// Left-to-right labels or payouts. The count determines rows as count - 1.
  final List<BeuiPlinkoValue>? slots;

  /// Called once with the slot index and value when a ball lands.
  final void Function(int slot, BeuiPlinkoValue value)? onLand;

  /// Maximum number of simultaneous flights. Defaults to 12.
  final int maxBalls;

  /// Drop-button label. Defaults to "Drop ball".
  final String dropLabel;

  /// Controlled peg-flash state. Null uses [defaultPegFlash].
  final bool? pegFlash;

  /// Initial peg-flash state when uncontrolled. Defaults to true.
  final bool defaultPegFlash;

  /// Called when peg-flash preference changes.
  final ValueChanged<bool>? onPegFlashChange;

  /// Tooltip and accessible name of the peg-flash control.
  final String pegFlashLabel;

  /// Controlled sound preference. Null uses [defaultSound].
  final bool? sound;

  /// Initial sound preference when uncontrolled. Defaults to false.
  final bool defaultSound;

  /// Called when sound preference changes. It does not play audio.
  final ValueChanged<bool>? onSoundChange;

  /// Tooltip and accessible name of the sound control.
  final String soundLabel;

  /// Accessible name of the board. Defaults to "Plinko board".
  final String semanticLabel;

  @override
  State<BeuiPlinko> createState() => _BeuiPlinkoState();
}

const double _boardGap = 32;
const double _boardRow = 30;
const double _boardPegRadius = 3.5;
const double _boardBallRadius = 7;
const double _boardTop = 48;
const double _boardSlotHeight = 34;
const Duration _ballExitDuration = Duration(milliseconds: 120);
const Duration _pegFlashDuration = Duration(milliseconds: 300);
const Duration _slotPulseDuration = Duration(milliseconds: 300);

class _BallFlight {
  _BallFlight({
    required this.trajectory,
    required this.controller,
    required TickerProvider vsync,
  }) : exitController = SingleMotionController(
         motion: const CurvedMotion(_ballExitDuration, beuiEaseOut),
         vsync: vsync,
         initialValue: 1,
       ),
       hitTracker = PlinkoRenderedHitTracker(trajectory);

  final PlinkoTrajectory trajectory;
  final SingleMotionController controller;
  late final SingleMotionController exitController;
  final PlinkoRenderedHitTracker hitTracker;
  bool landed = false;
}

class _BallPaint {
  const _BallPaint({
    required this.position,
    required this.scale,
    required this.opacity,
  });

  final Offset position;
  final double scale;
  final double opacity;
}

class _BeuiPlinkoState extends State<BeuiPlinko> with TickerProviderStateMixin {
  final _random = math.Random();
  final List<_BallFlight> _flights = [];
  final Map<int, SingleMotionController> _slotPulses = {};
  final Map<String, SingleMotionController> _pegPulses = {};
  int _landingCount = 0;
  int? _lastSlot;
  String _announcement = '';
  late bool _internalPegFlash;
  late bool _internalSound;

  List<BeuiPlinkoValue> get _labels =>
      widget.slots ?? beuiPlinkoSlots(widget.rows);

  int get _rows => _labels.length - 1;

  int get _activeFlights => _flights.where((flight) => !flight.landed).length;

  bool get _flashOn => widget.pegFlash ?? _internalPegFlash;

  bool get _soundOn => widget.sound ?? _internalSound;

  bool _reducedMotion(BuildContext context) =>
      motionFor(context, beuiSpringLayout, isMovement: true) is NoMotion;

  @override
  void initState() {
    super.initState();
    _internalPegFlash = widget.defaultPegFlash;
    _internalSound = widget.defaultSound;
  }

  @override
  void didUpdateWidget(covariant BeuiPlinko oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldRows =
        (oldWidget.slots?.length ?? beuiPlinkoSlots(oldWidget.rows).length) - 1;
    if (oldRows != _rows) {
      _discardFlights();
      _disposePulses(_slotPulses);
      _disposePulses(_pegPulses);
      _lastSlot = null;
      _announcement = '';
    }
  }

  @override
  void dispose() {
    _discardFlights();
    _disposePulses(_slotPulses);
    _disposePulses(_pegPulses);
    super.dispose();
  }

  void _disposePulses<K>(Map<K, SingleMotionController> pulses) {
    for (final pulse in pulses.values) {
      pulse.dispose();
    }
    pulses.clear();
  }

  void _discardFlights() {
    for (final flight in _flights) {
      flight.controller.dispose();
      flight.exitController.dispose();
    }
    _flights.clear();
  }

  void _onFlightTick(_BallFlight flight) {
    if (!mounted || !_flights.contains(flight) || flight.landed) return;
    final y = flight.trajectory.positionAt(flight.controller.value).dy;
    final hitRow = flight.hitTracker.observe(y);
    if (_flashOn && hitRow != null) {
      _pulsePeg(flight.trajectory.pegIds[hitRow]);
    }
    setState(() {});
  }

  void _pulsePeg(String pegId) {
    _pegPulses.remove(pegId)?.dispose();
    final pulse = SingleMotionController(
      motion: const CurvedMotion(_pegFlashDuration, Curves.linear),
      vsync: this,
    );
    _pegPulses[pegId] = pulse;
    pulse
      ..addListener(_onPulseTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed &&
            identical(_pegPulses[pegId], pulse)) {
          _pegPulses.remove(pegId);
          pulse.dispose();
          _onPulseTick();
        }
      })
      ..animateTo(1);
  }

  void _onPulseTick() {
    if (mounted) setState(() {});
  }

  void _onFlightStatus(_BallFlight flight, AnimationStatus status) {
    if (status != AnimationStatus.completed ||
        !mounted ||
        !_flights.contains(flight) ||
        flight.landed) {
      return;
    }
    flight.landed = true;
    _land(flight.trajectory.slot);
    flight.exitController.addStatusListener((exitStatus) {
      if (exitStatus == AnimationStatus.completed) _removeFlight(flight);
    });
    flight.exitController.animateTo(0);
  }

  void _removeFlight(_BallFlight flight) {
    if (!_flights.remove(flight)) return;
    flight.controller.dispose();
    flight.exitController.dispose();
    if (mounted) setState(() {});
  }

  void _land(int slot) {
    final labels = _labels;
    if (slot < 0 || slot >= labels.length) return;
    setState(() {
      _lastSlot = slot;
      _landingCount++;
      _announcement =
          'Ball $_landingCount landed in slot ${slot + 1}: ${labels[slot]}';
    });
    _slotPulses.remove(slot)?.dispose();
    final pulse = SingleMotionController(
      motion: const CurvedMotion(_slotPulseDuration, Curves.linear),
      vsync: this,
    );
    _slotPulses[slot] = pulse;
    pulse
      ..addListener(_onPulseTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed &&
            identical(_slotPulses[slot], pulse)) {
          _slotPulses.remove(slot);
          pulse.dispose();
          _onPulseTick();
        }
      })
      ..animateTo(1);
    widget.onLand?.call(slot, labels[slot]);
  }

  void _drop() {
    if (_activeFlights >= widget.maxBalls) return;
    final rows = _rows;
    final width = (rows + 2) * _boardGap;
    final trajectory = PlinkoTrajectory(
      rows: rows,
      width: width,
      nextRight: () => _random.nextBool(),
    );
    if (_reducedMotion(context)) {
      _land(trajectory.slot);
      return;
    }

    final controller = SingleMotionController(
      motion: CurvedMotion(
        Duration(microseconds: (trajectory.durationSeconds * 1000000).round()),
        Curves.linear,
      ),
      vsync: this,
    );
    final flight = _BallFlight(
      trajectory: trajectory,
      controller: controller,
      vsync: this,
    );
    controller.addListener(() => _onFlightTick(flight));
    controller.addStatusListener((status) => _onFlightStatus(flight, status));
    flight.exitController.addListener(() {
      if (mounted && _flights.contains(flight)) setState(() {});
    });
    setState(() => _flights.add(flight));
    controller.animateTo(1);
  }

  void _togglePegFlash() {
    final next = !_flashOn;
    if (widget.pegFlash == null) setState(() => _internalPegFlash = next);
    widget.onPegFlashChange?.call(next);
  }

  void _toggleSound() {
    final next = !_soundOn;
    if (widget.sound == null) setState(() => _internalSound = next);
    widget.onSoundChange?.call(next);
  }

  List<_BallPaint> _ballPaints() => [
    for (final flight in _flights) _ballPaint(flight),
  ];

  _BallPaint _ballPaint(_BallFlight flight) {
    final progress = flight.controller.value;
    final enter = (progress * flight.trajectory.durationSeconds / 0.15)
        .clamp(0.0, 1.0)
        .toDouble();
    final exit = flight.exitController.value;
    return _BallPaint(
      position:
          flight.trajectory.positionAt(progress) + Offset(0, 4 * (1 - exit)),
      scale: 0.9 + 0.1 * beuiEaseOut.transform(enter),
      opacity: beuiEaseOut.transform(enter) * exit,
    );
  }

  Map<String, _PegFlash> _pegFlashes() => {
    for (final entry in _pegPulses.entries)
      entry.key: _pegFlashAt(entry.value.value),
  };

  _PegFlash _pegFlashAt(double progress) {
    final firstPhase = (progress / 0.3).clamp(0.0, 1.0).toDouble();
    final secondPhase = ((progress - 0.3) / 0.7).clamp(0.0, 1.0).toDouble();
    final attack = beuiEaseOut.transform(firstPhase);
    final decay = beuiEaseOut.transform(secondPhase);
    return _PegFlash(
      progress < 0.3 ? 1 + 0.8 * attack : 1.8 - 0.8 * decay,
      progress < 0.3 ? 0.4 + 0.6 * attack : 1 - 0.6 * decay,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_labels.length < 2) return const SizedBox.shrink();
    final colors = BeuiColors.resolve(context);
    final reduce = _reducedMotion(context);
    final rows = _rows;
    final designWidth = (rows + 2) * _boardGap;
    final designHeight = _boardTop + rows * _boardRow + _boardSlotHeight;
    final board = LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : designWidth * 1.4;
        final width = math.min(maxWidth, designWidth * 1.4).toDouble();
        return Center(
          child: Semantics(
            container: true,
            label: widget.semanticLabel,
            child: ExcludeSemantics(
              child: CustomPaint(
                size: Size(width, width * designHeight / designWidth),
                painter: _PlinkoPainter(
                  rows: rows,
                  width: designWidth,
                  labels: _labels,
                  colors: colors,
                  lastSlot: _lastSlot,
                  slotPulses: {
                    for (final entry in _slotPulses.entries)
                      entry.key:
                          0.9 * (1 - beuiEaseOut.transform(entry.value.value)),
                  },
                  balls: _ballPaints(),
                  pegFlashes: _pegFlashes(),
                  textDirection: Directionality.of(context),
                  inheritedTextStyle: DefaultTextStyle.of(context).style,
                ),
              ),
            ),
          ),
        );
      },
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        board,
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Semantics(
              container: true,
              button: true,
              enabled: _activeFlights < widget.maxBalls,
              label: widget.dropLabel,
              onTap: _drop,
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: _activeFlights >= widget.maxBalls ? 0.5 : 1,
                  child: BeuiButton(
                    onPressed: _drop,
                    pressScale: 0.96,
                    child: Text(widget.dropLabel),
                  ),
                ),
              ),
            ),
            if (!reduce)
              _PlinkoToggle(
                on: _flashOn,
                label: widget.pegFlashLabel,
                onIcon: LucideIcons.zap,
                offIcon: LucideIcons.zap_off,
                onToggle: _togglePegFlash,
              ),
            _PlinkoToggle(
              on: _soundOn,
              label: widget.soundLabel,
              onIcon: LucideIcons.volume_2,
              offIcon: LucideIcons.volume_x,
              onToggle: _toggleSound,
            ),
          ],
        ),
        Semantics(
          liveRegion: true,
          label: _announcement,
          child: const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _PlinkoToggle extends StatelessWidget {
  const _PlinkoToggle({
    required this.on,
    required this.label,
    required this.onIcon,
    required this.offIcon,
    required this.onToggle,
  });

  final bool on;
  final String label;
  final IconData onIcon;
  final IconData offIcon;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    return Semantics(
      container: true,
      button: true,
      toggled: on,
      label: label,
      onTap: onToggle,
      child: ExcludeSemantics(
        child: BeuiTooltip(
          content: Text(label),
          child: BeuiButton(
            variant: BeuiButtonVariant.secondary,
            size: BeuiButtonSize.icon,
            onPressed: onToggle,
            pressScale: 0.96,
            child: IconTheme.merge(
              data: IconThemeData(
                color: on ? colors.foreground : colors.mutedForeground,
              ),
              child: BeuiActionSwapIcon(
                value: on ? 'on' : 'off',
                icon: on ? onIcon : offIcon,
                variant: BeuiActionSwapVariant.cascade,
                size: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlinkoPainter extends CustomPainter {
  const _PlinkoPainter({
    required this.rows,
    required this.width,
    required this.labels,
    required this.colors,
    required this.lastSlot,
    required this.slotPulses,
    required this.balls,
    required this.pegFlashes,
    required this.textDirection,
    required this.inheritedTextStyle,
  });

  final int rows;
  final double width;
  final List<BeuiPlinkoValue> labels;
  final BeuiColors colors;
  final int? lastSlot;
  final Map<int, double> slotPulses;
  final List<_BallPaint> balls;
  final Map<String, _PegFlash> pegFlashes;
  final TextDirection textDirection;
  final TextStyle inheritedTextStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / width;
    canvas.save();
    canvas.scale(scale);
    final basePaint = Paint()..style = PaintingStyle.fill;
    for (var row = 0; row < rows; row++) {
      for (var index = 0; index < row + 3; index++) {
        final id = '$row-${index - 1}';
        final x = width / 2 + (index - 1 - row / 2) * _boardGap;
        final y = _boardTop + row * _boardRow;
        final flash = pegFlashes[id];
        final radius = _boardPegRadius * (flash?.scale ?? 1);
        basePaint.color = colors.foreground.withValues(
          alpha: flash?.opacity ?? 0.4,
        );
        canvas.drawCircle(Offset(x, y), radius, basePaint);
      }
    }

    final slotTop = _boardTop + rows * _boardRow;
    for (var slot = 0; slot < labels.length; slot++) {
      final left = width / 2 + (slot - rows / 2) * _boardGap - _boardGap / 2;
      final rect = Rect.fromLTWH(
        left + 2,
        slotTop,
        _boardGap - 4,
        _boardSlotHeight - 4,
      );
      basePaint.color = slot == lastSlot
          ? colors.primary.withValues(alpha: 0.2)
          : colors.muted;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        basePaint,
      );
      final pulse = slotPulses[slot] ?? 0;
      if (pulse > 0) {
        basePaint.color = colors.primary.withValues(alpha: pulse);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          basePaint,
        );
      }
      final label = labels[slot].toString();
      final fontSize = math.min(9.0, (_boardGap - 8) / (label.length * 0.6));
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: inheritedTextStyle.fontFamily,
            fontFamilyFallback: inheritedTextStyle.fontFamilyFallback,
            color: colors.foreground,
            fontSize: fontSize,
            fontWeight: slot == lastSlot ? FontWeight.w600 : FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: textDirection,
        maxLines: 1,
      )..layout(maxWidth: _boardGap - 8);
      painter.paint(
        canvas,
        Offset(
          rect.center.dx - painter.width / 2,
          rect.center.dy - painter.height / 2,
        ),
      );
    }

    for (final ball in balls) {
      basePaint.color = colors.primary.withValues(alpha: ball.opacity);
      canvas.drawCircle(
        ball.position,
        _boardBallRadius * ball.scale,
        basePaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlinkoPainter oldDelegate) => true;
}

class _PegFlash {
  const _PegFlash(this.scale, this.opacity);

  final double scale;
  final double opacity;
}
