import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'loader.dart';
import 'text_shimmer.dart';

// ---------------------------------------------------------------------------
// Thinking shimmer
// ---------------------------------------------------------------------------

/// A quiet shimmer on status copy — the Flutter port of beUI's
/// `ThinkingShimmer`.
///
/// Thin wrapper over [BeuiTextShimmer] with the source defaults
/// (`"Thinking…"`, 1.8s pass, medium weight). Pure color effect; reduced
/// motion holds a static highlight (see [BeuiTextShimmer]).
class BeuiThinkingShimmer extends StatelessWidget {
  /// Creates a thinking shimmer over [text].
  const BeuiThinkingShimmer({
    this.text = 'Thinking…',
    this.duration = const Duration(milliseconds: 1800),
    this.style,
    super.key,
  });

  /// Loading message shown to the user (source `children`, default
  /// `"Thinking…"`).
  final String text;

  /// One full shimmer pass (source `duration`, default 1.8s).
  final Duration duration;

  /// Text style. Merged with medium weight; falls back to the ambient
  /// [DefaultTextStyle].
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    return BeuiTextShimmer(
      text,
      duration: duration,
      style: base.copyWith(fontWeight: FontWeight.w500),
    );
  }
}

// ---------------------------------------------------------------------------
// Agent progress
// ---------------------------------------------------------------------------

/// Grid cell delays (seconds) — source `GRID_CELLS` diagonal wave.
const List<double> _kAgentProgressDelays = [
  0.0, // top-left
  0.14, // top-center
  0.28, // top-right
  0.42, // middle-left
  0.56, // middle-center
  0.70, // middle-right
  0.84, // bottom-left
  0.98, // bottom-center
  1.12, // bottom-right
];

/// Formats elapsed seconds as `12.3s` or `2m 3.4s` (source `formatElapsed`).
String beuiFormatAgentElapsed(double totalSeconds) {
  final safe = math.max(0.0, totalSeconds);
  final minutes = safe.floor() ~/ 60;
  final seconds = safe % 60;
  final secStr = seconds.toStringAsFixed(1);
  return minutes > 0 ? '${minutes}m ${secStr}s' : '${secStr}s';
}

/// Compact activity glyph + verb + live timer — the Flutter port of beUI's
/// `AgentProgress`.
///
/// A 3×3 cell matrix pulses on a diagonal wave (opacity + scale, 1.55s
/// [beuiEaseInOut] loop, per-cell delay). The timer is controlled via
/// [elapsedSeconds] or driven internally from [initialSeconds] while
/// [running] is true (100ms tick). Reduced motion drops scale and keeps a
/// calmer opacity pulse.
class BeuiAgentProgress extends StatefulWidget {
  /// Creates an agent progress indicator.
  const BeuiAgentProgress({
    this.label = 'Churning',
    this.elapsedSeconds,
    this.initialSeconds = 0,
    this.running = true,
    this.style,
    super.key,
  });

  /// Verb describing the agent's current activity (source `label`).
  final String label;

  /// Controlled elapsed time in seconds. When set, the internal timer is
  /// ignored (source `elapsedSeconds`).
  final double? elapsedSeconds;

  /// Starting time for the internal timer, in seconds (source
  /// `initialSeconds`).
  final double initialSeconds;

  /// Whether the internal timer advances. Ignored when [elapsedSeconds] is
  /// provided (source `running`).
  final bool running;

  /// Text style for the label/timer row. Defaults to mono 14 / medium label.
  final TextStyle? style;

  @override
  State<BeuiAgentProgress> createState() => _BeuiAgentProgressState();
}

class _BeuiAgentProgressState extends State<BeuiAgentProgress>
    with SingleTickerProviderStateMixin {
  static const _cycle = Duration(milliseconds: 1550);
  static const _gridSize = 20.0; // size-5
  static const _gap = 2.0;
  static const _cell = (_gridSize - 2 * _gap) / 3;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: _cycle,
  )..repeat();

  late double _internalSeconds = widget.initialSeconds;
  Timer? _timer;

  /// Instant the current running span began, back-dated by the seconds already
  /// on the clock. Re-anchored by [_syncTimer] on every (re)start, so it is
  /// only meaningful while [_timer] is live.
  late DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(BeuiAgentProgress old) {
    super.didUpdateWidget(old);
    if (widget.elapsedSeconds != old.elapsedSeconds ||
        widget.running != old.running ||
        widget.initialSeconds != old.initialSeconds) {
      if (widget.elapsedSeconds == null &&
          widget.initialSeconds != old.initialSeconds) {
        _internalSeconds = widget.initialSeconds;
      }
      _syncTimer();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      // Still loop — reduced branch is opacity-only, not movement-free halt.
      if (!_pulse.isAnimating) _pulse.repeat();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (widget.elapsedSeconds != null || !widget.running) return;
    // Anchor to now less the seconds already counted, rather than to a single
    // fixed start instant: a paused span then contributes nothing when
    // [running] flips back on, and resuming picks up where it stopped.
    //
    // `clock.now()`, not `DateTime.now()` — the timer below ticks on the zone's
    // event loop, so the value it reports has to come off the same clock the
    // zone is running. They are the same instant in production; under
    // `flutter_test`'s fake async only `clock.now()` advances, so the counter
    // stays truthful in tests instead of freezing at its starting value.
    _startedAt = clock.now().subtract(
      Duration(microseconds: (_internalSeconds * 1e6).round()),
    );
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _internalSeconds =
            clock.now().difference(_startedAt).inMicroseconds / 1e6;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final elapsed = widget.elapsedSeconds ?? _internalSeconds;
    final base =
        widget.style ??
        TextStyle(
          fontSize: 14,
          height: 1.25,
          color: colors.mutedForeground,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final labelStyle = base.copyWith(
      fontWeight: FontWeight.w500,
      fontFamily: null, // sans for the verb (source font-sans font-medium)
    );
    final timerStyle = base.copyWith(
      color: colors.mutedForeground.withValues(alpha: 0.7),
      fontFamily: 'monospace',
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Semantics(
      label: '${widget.label}, in progress',
      liveRegion: true,
      container: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _gridSize,
              height: _gridSize,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  return CustomPaint(
                    size: const Size(_gridSize, _gridSize),
                    painter: _AgentGridPainter(
                      t: _pulse.value,
                      color: colors.mutedForeground,
                      reduce: reduce,
                      cell: _cell,
                      gap: _gap,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12), // gap-3
            Text(widget.label, style: labelStyle),
            const SizedBox(width: 12),
            Text(beuiFormatAgentElapsed(elapsed), style: timerStyle),
          ],
        ),
      ),
    );
  }
}

/// Paints the 3×3 pulsing grid for [BeuiAgentProgress].
///
/// Each cell rides a 1.55s ease-in-out loop with a per-cell delay
/// (`GRID_CELLS`). Full motion: opacity 0.28→1→0.28 and scale 0.72→1→0.72.
/// Reduced: opacity 0.35→0.8→0.35, no scale.
class _AgentGridPainter extends CustomPainter {
  _AgentGridPainter({
    required this.t,
    required this.color,
    required this.reduce,
    required this.cell,
    required this.gap,
  });

  final double t;
  final Color color;
  final bool reduce;
  final double cell;
  final double gap;

  static const _cycleSec = 1.55;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 9; i++) {
      final col = i % 3;
      final row = i ~/ 3;
      final delay = _kAgentProgressDelays[i];
      // Progress in [0, 1) for this cell's delayed cycle.
      final local =
          ((t * _cycleSec - delay) % _cycleSec + _cycleSec) % _cycleSec;
      final p = beuiEaseInOut.transform(local / _cycleSec);
      // Triangle wave peaking at mid-cycle: 0 → 1 → 0.
      final wave = p < 0.5 ? p * 2 : (1 - p) * 2;

      final opacity = reduce
          ? 0.35 + wave * (0.8 - 0.35)
          : 0.28 + wave * (1.0 - 0.28);
      final scale = reduce ? 1.0 : 0.72 + wave * (1.0 - 0.72);

      final cx = col * (cell + gap) + cell / 2;
      final cy = row * (cell + gap) + cell / 2;
      final half = (cell * scale) / 2;

      paint.color = color.withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: half * 2,
            height: half * 2,
          ),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AgentGridPainter old) =>
      old.t != t ||
      old.color != color ||
      old.reduce != reduce ||
      old.cell != cell ||
      old.gap != gap;
}

// ---------------------------------------------------------------------------
// Reasoning text
// ---------------------------------------------------------------------------

/// Animation used when the active phrase changes (source
/// `ReasoningTextVariant`).
enum BeuiReasoningTextVariant {
  /// Per-letter slot roll with [beuiSpringSwap] enter.
  cascade,

  /// Whole-phrase fade / 3px vertical slide.
  swap,

  /// Glyph scramble that settles left-to-right into the target phrase.
  scramble,
}

const List<String> _kDefaultReasoningPhrases = [
  'Thinking',
  'Reading the context',
  'Connecting the details',
  'Forming a response',
];

const String _kScrambleGlyphs = r'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789#%&@$?/';

/// Cycling reasoning phrases with shimmer — the Flutter port of beUI's
/// `ReasoningText`.
///
/// Cycles [phrases] on [interval] (≥ 600ms). Leading indicator defaults to a
/// 14px [BeuiLoaderVariant.asciiLine] at speed 0.8. Phrase transitions use
/// [variant]:
/// * [BeuiReasoningTextVariant.cascade] — per-letter spring enter / 140ms exit
/// * [BeuiReasoningTextVariant.swap] — whole-phrase 200ms [beuiEaseOut] slide
/// * [BeuiReasoningTextVariant.scramble] — random glyphs settling L→R
///
/// Reduced motion keeps the shimmer and drops letter movement (cascade
/// collapses to a plain phrase; swap is opacity-only; scramble snaps).
class BeuiReasoningText extends StatefulWidget {
  /// Creates a cycling reasoning indicator.
  const BeuiReasoningText({
    this.phrases = _kDefaultReasoningPhrases,
    this.variant = BeuiReasoningTextVariant.cascade,
    this.interval = const Duration(milliseconds: 1800),
    this.shimmerDuration = const Duration(milliseconds: 2200),
    this.indicator,
    this.style,
    super.key,
  });

  /// Phrases cycled while the agent works. Empty falls back to the source
  /// defaults.
  final List<String> phrases;

  /// Animation used when the active phrase changes.
  final BeuiReasoningTextVariant variant;

  /// How long each phrase remains visible (source `interval`, default 1800ms).
  /// Clamped to ≥ 600ms.
  final Duration interval;

  /// One full shimmer pass (source `shimmerDuration`, default 2.2s).
  final Duration shimmerDuration;

  /// Optional leading visual. Defaults to a terminal-style ASCII line loader.
  final Widget? indicator;

  /// Text style for the phrases. Defaults to 14 / medium / muted.
  final TextStyle? style;

  @override
  State<BeuiReasoningText> createState() => _BeuiReasoningTextState();
}

class _BeuiReasoningTextState extends State<BeuiReasoningText> {
  int _index = 0;
  Timer? _cycle;

  List<String> get _safePhrases =>
      widget.phrases.isEmpty ? _kDefaultReasoningPhrases : widget.phrases;

  String get _phrase => _safePhrases[_index % _safePhrases.length];

  String get _longest {
    return _safePhrases.reduce((a, b) => a.length >= b.length ? a : b);
  }

  @override
  void initState() {
    super.initState();
    _startCycle();
  }

  @override
  void didUpdateWidget(BeuiReasoningText old) {
    super.didUpdateWidget(old);
    if (old.interval != widget.interval ||
        old.phrases.length != widget.phrases.length) {
      _startCycle();
    }
  }

  void _startCycle() {
    _cycle?.cancel();
    final phrases = _safePhrases;
    if (phrases.length < 2) return;
    final ms = math.max(600, widget.interval.inMilliseconds);
    _cycle = Timer.periodic(Duration(milliseconds: ms), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % phrases.length);
    });
  }

  @override
  void dispose() {
    _cycle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final style =
        (widget.style ??
                TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                  color: colors.mutedForeground,
                ))
            .copyWith(fontWeight: FontWeight.w500);

    final indicator =
        widget.indicator ??
        BeuiLoader(
          variant: BeuiLoaderVariant.asciiLine,
          size: 14,
          speed: 0.8,
          label: 'Reasoning',
          color: colors.mutedForeground,
        );

    return Semantics(
      label: _phrase,
      liveRegion: true,
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: SizedBox(
              width: 12, // size-3
              height: 12,
              child: Center(child: indicator),
            ),
          ),
          const SizedBox(width: 8), // gap-2
          ExcludeSemantics(
            child: _PhraseSlot(
              phrase: '$_phrase…',
              longest: '$_longest…',
              variant: widget.variant,
              reduce: reduce,
              shimmerDuration: widget.shimmerDuration,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reserves width from the longest phrase and hosts the active variant.
class _PhraseSlot extends StatelessWidget {
  const _PhraseSlot({
    required this.phrase,
    required this.longest,
    required this.variant,
    required this.reduce,
    required this.shimmerDuration,
    required this.style,
  });

  final String phrase;
  final String longest;
  final BeuiReasoningTextVariant variant;
  final bool reduce;
  final Duration shimmerDuration;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        // Invisible sizer so the slot never collapses between phrases.
        Opacity(
          opacity: 0,
          child: Text(longest, style: style, maxLines: 1, softWrap: false),
        ),
        switch (variant) {
          BeuiReasoningTextVariant.cascade => _CascadePhrase(
            phrase: phrase,
            reduce: reduce,
            shimmerDuration: shimmerDuration,
            style: style,
          ),
          BeuiReasoningTextVariant.swap => _SwapPhrase(
            phrase: phrase,
            reduce: reduce,
            shimmerDuration: shimmerDuration,
            style: style,
          ),
          BeuiReasoningTextVariant.scramble => _ScramblePhrase(
            phrase: phrase,
            reduce: reduce,
            shimmerDuration: shimmerDuration,
            style: style,
          ),
        },
      ],
    );
  }
}

// ---- Cascade ---------------------------------------------------------------

class _CascadePhrase extends StatefulWidget {
  const _CascadePhrase({
    required this.phrase,
    required this.reduce,
    required this.shimmerDuration,
    required this.style,
  });

  final String phrase;
  final bool reduce;
  final Duration shimmerDuration;
  final TextStyle style;

  @override
  State<_CascadePhrase> createState() => _CascadePhraseState();
}

class _CascadePhraseState extends State<_CascadePhrase>
    with SingleTickerProviderStateMixin {
  // Source CASCADE_STAGGER 0.025s; enter rides SPRING_SWAP; exit 0.14s EASE_OUT
  // at delay × 0.45 (reasoning-text — *not* the 0.5 of action-swap cascade).
  static const int _staggerMs = 25;
  static const int _enterMs = 360;
  static const int _exitMs = 140;

  late final AnimationController _controller;
  late String _current = widget.phrase;
  String? _previous;

  int _durationMs(String t) =>
      _enterMs + _staggerMs * (t.length - 1).clamp(0, 80);

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: Duration(milliseconds: _durationMs(_current)),
          value: 1,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && _previous != null) {
            setState(() => _previous = null);
          }
        });
  }

  @override
  void didUpdateWidget(_CascadePhrase old) {
    super.didUpdateWidget(old);
    if (widget.phrase != _current) {
      _previous = _current;
      _current = widget.phrase;
      if (widget.reduce) {
        _previous = null;
        _controller.value = 1;
      } else {
        _controller
          ..duration = Duration(milliseconds: _durationMs(_current))
          ..forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduce || _previous == null) {
      return BeuiTextShimmer(
        _current,
        duration: widget.shimmerDuration,
        style: widget.style,
      );
    }

    final roll = (widget.style.fontSize ?? 14) * 1.0; // y: 100% of line
    final clipH = (widget.style.fontSize ?? 14) * 1.35;

    return ClipRect(
      child: SizedBox(
        height: clipH,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final totalMs = _controller.duration!.inMilliseconds;
            return Stack(
              clipBehavior: Clip.hardEdge,
              alignment: Alignment.centerLeft,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: _letters(_previous!, t, totalMs, roll, exiting: true),
                ),
                _letters(_current, t, totalMs, roll, exiting: false),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _letters(
    String text,
    double t,
    int totalMs,
    double roll, {
    required bool exiting,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < text.length; i++)
          _letter(text[i], i, t, totalMs, roll, exiting: exiting),
      ],
    );
  }

  Widget _letter(
    String char,
    int i,
    double t,
    int totalMs,
    double roll, {
    required bool exiting,
  }) {
    // Space still occupies a slot (source whitespace-pre).
    final glyph = BeuiTextShimmer(
      char == ' ' ? '\u00A0' : char,
      duration: widget.shimmerDuration,
      style: widget.style,
    );

    if (exiting) {
      // delay = i × CASCADE_STAGGER; exit delay = delay × 0.45
      final start = (i * _staggerMs * 0.45) / totalMs;
      final p = ((t - start) / (_exitMs / totalMs)).clamp(0.0, 1.0);
      final e = beuiEaseOut.transform(p);
      return Opacity(
        opacity: 1 - e,
        child: Transform.translate(offset: Offset(0, -e * roll), child: glyph),
      );
    }

    final motion = motionFor(context, beuiSpringSwap, isMovement: true);
    final released = t * totalMs >= i * _staggerMs;
    return SingleMotionBuilder(
      value: released ? 0.0 : roll,
      from: roll,
      motion: motion,
      builder: (context, dy, child) {
        final p = roll == 0 ? 1.0 : (1 - dy / roll).clamp(0.0, 1.0);
        return Opacity(
          opacity: p,
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
      child: glyph,
    );
  }
}

// ---- Swap ------------------------------------------------------------------

class _SwapPhrase extends StatefulWidget {
  const _SwapPhrase({
    required this.phrase,
    required this.reduce,
    required this.shimmerDuration,
    required this.style,
  });

  final String phrase;
  final bool reduce;
  final Duration shimmerDuration;
  final TextStyle style;

  @override
  State<_SwapPhrase> createState() => _SwapPhraseState();
}

class _SwapPhraseState extends State<_SwapPhrase>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late String _current = widget.phrase;
  String? _previous;

  Duration get _dur => Duration(milliseconds: widget.reduce ? 120 : 200);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _dur, value: 1)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && _previous != null) {
          setState(() => _previous = null);
        }
      });
  }

  @override
  void didUpdateWidget(_SwapPhrase old) {
    super.didUpdateWidget(old);
    if (widget.phrase != _current) {
      _previous = _current;
      _current = widget.phrase;
      _controller
        ..duration = _dur
        ..forward(from: 0);
    } else if (widget.reduce != old.reduce) {
      _controller.duration = _dur;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_previous == null) {
      return BeuiTextShimmer(
        _current,
        duration: widget.shimmerDuration,
        style: widget.style,
      );
    }

    final slide = widget.reduce ? 0.0 : 3.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = beuiEaseOut.transform(_controller.value);
        // Outgoing: opacity 1→0, y 0→-3
        final outOp = 1 - t;
        final outY = -slide * t;
        // Incoming: opacity 0→1, y 3→0
        final inOp = t;
        final inY = slide * (1 - t);
        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            Opacity(
              opacity: outOp.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, outY),
                child: BeuiTextShimmer(
                  _previous!,
                  duration: widget.shimmerDuration,
                  style: widget.style,
                ),
              ),
            ),
            Opacity(
              opacity: inOp.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, inY),
                child: BeuiTextShimmer(
                  _current,
                  duration: widget.shimmerDuration,
                  style: widget.style,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---- Scramble --------------------------------------------------------------

class _ScramblePhrase extends StatefulWidget {
  const _ScramblePhrase({
    required this.phrase,
    required this.reduce,
    required this.shimmerDuration,
    required this.style,
  });

  final String phrase;
  final bool reduce;
  final Duration shimmerDuration;
  final TextStyle style;

  @override
  State<_ScramblePhrase> createState() => _ScramblePhraseState();
}

class _ScramblePhraseState extends State<_ScramblePhrase> {
  late String _display = widget.phrase;
  Ticker? _ticker;
  final _rng = math.Random();

  @override
  void didUpdateWidget(_ScramblePhrase old) {
    super.didUpdateWidget(old);
    if (widget.phrase != old.phrase) {
      // Source skips scramble on the initial mount effect; Flutter's first
      // paint already shows the settled phrase, so every subsequent phrase
      // change (the only path through didUpdateWidget) runs the scramble.
      if (widget.reduce) {
        setState(() => _display = widget.phrase);
        return;
      }
      _runScramble(widget.phrase);
    }
  }

  void _runScramble(String target) {
    _ticker?.dispose();
    final characters = target.split('');
    final durationMs = math
        .min(760, math.max(420, characters.length * 32))
        .toDouble();
    var lastUpdate = Duration.zero;

    _ticker = Ticker((elapsed) {
      if (elapsed - lastUpdate < const Duration(milliseconds: 40)) return;
      lastUpdate = elapsed;
      final progress = math.min(elapsed.inMilliseconds / durationMs, 1.0);
      final settled = (progress * characters.length).floor();
      final next = StringBuffer();
      for (var i = 0; i < characters.length; i++) {
        final ch = characters[i];
        if (i < settled || ch == ' ') {
          next.write(ch);
        } else {
          next.write(_kScrambleGlyphs[_rng.nextInt(_kScrambleGlyphs.length)]);
        }
      }
      if (!mounted) return;
      setState(() => _display = next.toString());
      // Completion runs off the ticker's own clock, not the wall clock, so the
      // ticker actually stops (and disposes) under fake async in tests.
      if (elapsed.inMilliseconds >= durationMs) {
        _ticker?.dispose();
        _ticker = null;
        if (mounted) setState(() => _display = target);
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mono = widget.style.copyWith(
      fontFamily: 'monospace',
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return BeuiTextShimmer(
      _display,
      duration: widget.shimmerDuration,
      style: mono,
    );
  }
}
