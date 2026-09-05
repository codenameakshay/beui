import 'dart:math' as math;
import 'dart:ui' show FontFeature, ImageFilter, lerpDouble;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';

/// Which looping animation [BeuiLoader] renders. One value per source
/// `LoaderVariant` (`loader.tsx`), names matching the source slugs.
enum BeuiLoaderVariant {
  /// Rotating quarter-arc over a faint track ring.
  spinner,

  /// Three dots bouncing in a staggered wave.
  dots,

  /// Four vertical bars pulsing their height.
  bars,

  /// 3×3 grid lighting on a diagonal wave.
  dotMatrix,

  /// 4×4 grid shimmering in Bayer-ordered dither.
  dither,

  /// Braille spinner glyphs (`⠋⠙⠹…`).
  ascii,

  /// Line spinner glyphs (`| / - \`).
  asciiLine,

  /// Braille orbit glyphs (`⣾⣽⣻…`).
  asciiBraille,

  /// Rising/falling block glyphs (`▁▂▃…█`).
  asciiBlocks,

  /// Single-dot bounce braille glyphs (`⠁⠂⠄⡀…`).
  asciiBounce,

  /// A filled shape morphing circle → square → triangle → hexagon → diamond.
  morph,

  /// A spinning comet head with a fading tail.
  comet,

  /// The word `LOADING` de-scrambling glyph by glyph.
  scramble,

  /// Two blurred blobs merging in a gooey metaball field.
  metaballs,

  /// A Newton's-cradle click: end balls slide out and back.
  newton,

  /// A double-helix column of crossing dots.
  helix,

  /// A numeric percent counter over a progress bar.
  percent,
}

/// Terminal-style frame sets — a one-to-one port of the source `ASCII_SETS`.
const Map<BeuiLoaderVariant, List<String>> _asciiSets = {
  BeuiLoaderVariant.ascii: ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'],
  BeuiLoaderVariant.asciiLine: ['|', '/', '-', r'\'],
  BeuiLoaderVariant.asciiBraille: ['⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷'],
  BeuiLoaderVariant.asciiBlocks: [
    '▁',
    '▂',
    '▃',
    '▄',
    '▅',
    '▆',
    '▇',
    '█',
    '▇',
    '▆',
    '▅',
    '▄',
    '▃',
    '▂',
  ],
  BeuiLoaderVariant.asciiBounce: ['⠁', '⠂', '⠄', '⡀', '⢀', '⠠', '⠐', '⠈'],
};

/// A continuously looping loading indicator — the Flutter port of beUI's
/// `loader`, with all 17 source variants selectable via [BeuiLoaderVariant].
///
/// Every variant is a distinct looping animation driven by a single repeating
/// [AnimationController] (period per variant, mirroring the source's
/// per-variant `duration`). Loaders are pure continuous **tweens**, not springs,
/// so per the porting rules they use `AnimationController.repeat()` (with
/// [beuiEaseInOut] per keyframe segment) rather than a `motor` spring.
///
/// **Reduced motion** (`MediaQuery.disableAnimationsOf`) mirrors the source's
/// heterogeneous `REDUCED` branches — it never spins or translates:
/// * most variants collapse to a static representative frame under a calm
///   opacity pulse (source `{ opacity: [1, 0.4, 1] }`, 1.4s [beuiEaseInOut]);
/// * the ascii glyph spinners keep cycling but 2.5× slower (a glyph swap, not
///   on-screen movement — source `Ascii` slows rather than stops);
/// * [BeuiLoaderVariant.scramble] shows the settled word `LOADING`;
/// * [BeuiLoaderVariant.percent] keeps counting at half speed;
/// * [BeuiLoaderVariant.newton] holds still with no pulse (source `undefined`).
class BeuiLoader extends StatelessWidget {
  /// Creates a loader. Defaults to [BeuiLoaderVariant.spinner] at 32px.
  const BeuiLoader({
    this.variant = BeuiLoaderVariant.spinner,
    this.size = 32,
    this.color,
    this.speed = 1.0,
    this.label = 'Loading',
    super.key,
  });

  /// Which animation to render.
  final BeuiLoaderVariant variant;

  /// Base square size in logical px. Everything scales from this (source
  /// `size`, default 32).
  final double size;

  /// Ink colour. Defaults to the ambient [BeuiColors.foreground] (the source
  /// renders in `text-foreground`).
  final Color? color;

  /// Seconds per animation cycle (source `speed`, default 1). Larger is slower.
  final double speed;

  /// Accessible label announced to screen readers (source `label`).
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final color = this.color ?? colors.foreground;
    final reduce = MediaQuery.disableAnimationsOf(context);

    // No outer square: the base [size] scales the geometry, but some variants
    // are intentionally wider than tall (percent is 1.4× wide, scramble is a
    // word) — matching the source's `inline-flex` that sizes to its content.
    return Semantics(
      label: label,
      liveRegion: true,
      container: true,
      child: _LoaderView(
        // Keyed on variant so a variant swap rebuilds the controller with the
        // new per-variant period.
        key: ValueKey(variant),
        variant: variant,
        size: size,
        color: color,
        speed: speed,
        reduce: reduce,
      ),
    );
  }
}

/// Owns the single repeating controller and dispatches each frame to the
/// per-variant painter/builder.
class _LoaderView extends StatefulWidget {
  const _LoaderView({
    required this.variant,
    required this.size,
    required this.color,
    required this.speed,
    required this.reduce,
    super.key,
  });

  final BeuiLoaderVariant variant;
  final double size;
  final Color color;
  final double speed;
  final bool reduce;

  @override
  State<_LoaderView> createState() => _LoaderViewState();
}

class _LoaderViewState extends State<_LoaderView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _period(),
  );

  // Scramble cache — regenerated only when the reveal tick advances so the
  // word doesn't re-randomise every frame.
  int _scrambleTick = -1;
  String _scrambleText = _scrambleTarget;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    if (!_isStaticUnderReduce) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isStaticUnderReduce =>
      widget.reduce && widget.variant == BeuiLoaderVariant.newton;

  Duration _ms(double seconds) =>
      Duration(microseconds: (seconds * 1e6).round());

  /// Per-variant cycle length, mirroring each source `duration`.
  Duration _period() {
    final s = widget.speed;
    if (widget.reduce) {
      switch (widget.variant) {
        case BeuiLoaderVariant.ascii:
        case BeuiLoaderVariant.asciiLine:
        case BeuiLoaderVariant.asciiBraille:
        case BeuiLoaderVariant.asciiBlocks:
        case BeuiLoaderVariant.asciiBounce:
          return _ms(s * 2.5); // source: cycle slows, doesn't stop
        case BeuiLoaderVariant.percent:
          return _ms(s * 2); // source: half-speed count
        case BeuiLoaderVariant.newton:
          return _ms(1); // unused (static)
        default:
          return _ms(1.4); // opacity pulse
      }
    }
    switch (widget.variant) {
      case BeuiLoaderVariant.morph:
        return _ms(s * 5); // source: speed * 5
      case BeuiLoaderVariant.metaballs:
        return _ms(s * 1.6); // source: speed * 1.6
      case BeuiLoaderVariant.newton:
        return _ms(s * 1.5); // source: speed * 1.5
      case BeuiLoaderVariant.scramble:
        // 11 ticks × (speed/7 × 0.55)s per tick — the source interval.
        return _ms(_scrambleTotal * (s / _scrambleTarget.length) * 0.55);
      default:
        return _ms(s); // source: speed
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        if (widget.reduce) {
          // Bespoke reduced-motion branches (no spinning, no translation).
          switch (widget.variant) {
            case BeuiLoaderVariant.ascii:
            case BeuiLoaderVariant.asciiLine:
            case BeuiLoaderVariant.asciiBraille:
            case BeuiLoaderVariant.asciiBlocks:
            case BeuiLoaderVariant.asciiBounce:
              return _ascii(t);
            case BeuiLoaderVariant.scramble:
              return _scramble(0, statik: true);
            case BeuiLoaderVariant.percent:
              return _percent(t);
            case BeuiLoaderVariant.newton:
              return _newton(0, statik: true);
            default:
              // Static frame under a calm opacity pulse.
              final o = _kf(const [1, 0.4, 1], t);
              return Opacity(opacity: o, child: _frame(0, statik: true));
          }
        }
        return _frame(t, statik: false);
      },
    );
  }

  /// Routes a live frame [t] (∈ [0,1)) to the variant builder. [statik] renders
  /// a motionless representative frame (rotation/translation/offsets dropped)
  /// for the reduced-motion pulse.
  Widget _frame(double t, {required bool statik}) {
    switch (widget.variant) {
      case BeuiLoaderVariant.spinner:
        return _spinner(t, statik: statik);
      case BeuiLoaderVariant.dots:
        return _dots(t, statik: statik);
      case BeuiLoaderVariant.bars:
        return _bars(t, statik: statik);
      case BeuiLoaderVariant.dotMatrix:
        return _dotMatrix(t, statik: statik);
      case BeuiLoaderVariant.dither:
        return _dither(t, statik: statik);
      case BeuiLoaderVariant.ascii:
      case BeuiLoaderVariant.asciiLine:
      case BeuiLoaderVariant.asciiBraille:
      case BeuiLoaderVariant.asciiBlocks:
      case BeuiLoaderVariant.asciiBounce:
        return _ascii(t);
      case BeuiLoaderVariant.morph:
        return _morph(t, statik: statik);
      case BeuiLoaderVariant.comet:
        return _comet(t, statik: statik);
      case BeuiLoaderVariant.scramble:
        return _scramble(t, statik: statik);
      case BeuiLoaderVariant.metaballs:
        return _metaballs(t, statik: statik);
      case BeuiLoaderVariant.newton:
        return _newton(t, statik: statik);
      case BeuiLoaderVariant.helix:
        return _helix(t, statik: statik);
      case BeuiLoaderVariant.percent:
        return _percent(t);
    }
  }

  // -- spinner --------------------------------------------------------------
  Widget _spinner(double t, {required bool statik}) {
    return CustomPaint(
      size: Size.square(widget.size),
      painter: _SpinnerPainter(
        color: widget.color,
        turns: statik ? 0 : t,
        size: widget.size,
      ),
    );
  }

  // -- dots -----------------------------------------------------------------
  Widget _dots(double t, {required bool statik}) {
    final size = widget.size;
    final dot = size * 0.24;
    final gap = size * 0.14;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Builder(
            builder: (_) {
              // source: y [0,-0.3size,0], opacity [0.5,1,0.5], delay i*0.16.
              final lt = statik ? 0.5 : _wrap(t - i * 0.16);
              final y = statik ? 0.0 : _kf(const [0, 1, 0], lt) * -size * 0.3;
              final o = statik ? 1.0 : _kf(const [0.5, 1, 0.5], lt);
              return Transform.translate(
                offset: Offset(0, y),
                child: Opacity(opacity: o, child: _circle(dot)),
              );
            },
          ),
        ],
      ],
    );
  }

  // -- bars -----------------------------------------------------------------
  Widget _bars(double t, {required bool statik}) {
    final size = widget.size;
    final bar = size * 0.16;
    final gap = size * 0.1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Builder(
            builder: (_) {
              // source: scaleY [0.3,1,0.3], originY:1 (bottom), delay i*0.12.
              final lt = statik ? 0.5 : _wrap(t - i * 0.12);
              final sy = statik ? 0.7 : _kf(const [0.3, 1, 0.3], lt);
              return Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: bar,
                  height: size * sy,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(bar / 2),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  // -- dot matrix -----------------------------------------------------------
  Widget _dotMatrix(double t, {required bool statik}) {
    const n = 3;
    final size = widget.size;
    final gap = size * 0.14;
    final dot = (size - gap * (n - 1)) / n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var y = 0; y < n; y++) ...[
          if (y > 0) SizedBox(height: gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var x = 0; x < n; x++) ...[
                if (x > 0) SizedBox(width: gap),
                Builder(
                  builder: (_) {
                    // source: diagonal wave, delay (x+y)/4; opacity+scale pulse.
                    final lt = statik
                        ? 0.5
                        : _wrap(t - (x + y) / (2 * (n - 1)));
                    final o = statik ? 1.0 : _kf(const [0.2, 1, 0.2], lt);
                    final sc = statik ? 1.0 : _kf(const [0.7, 1, 0.7], lt);
                    return Opacity(
                      opacity: o,
                      child: Transform.scale(scale: sc, child: _circle(dot)),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  // -- dither ---------------------------------------------------------------
  Widget _dither(double t, {required bool statik}) {
    const n = 4;
    final size = widget.size;
    final gap = math.max(1.0, size * 0.05);
    final cell = (size - gap * (n - 1)) / n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < n; row++) ...[
          if (row > 0) SizedBox(height: gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var col = 0; col < n; col++) ...[
                if (col > 0) SizedBox(width: gap),
                Builder(
                  builder: (_) {
                    final idx = row * n + col;
                    final order = _bayer4[idx];
                    // source: delay order/16, opacity [0.1,1,0.1].
                    final lt = statik ? 0.5 : _wrap(t - order / _bayer4.length);
                    final o = statik ? 1.0 : _kf(const [0.1, 1, 0.1], lt);
                    return Opacity(
                      opacity: o,
                      child: SizedBox(
                        width: cell,
                        height: cell,
                        child: ColoredBox(color: widget.color),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  // -- ascii glyph spinners -------------------------------------------------
  Widget _ascii(double t) {
    final frames = _asciiSets[widget.variant]!;
    final idx = (t * frames.length).floor() % frames.length;
    return Text(
      frames[idx],
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: widget.size,
        height: 1,
        color: widget.color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  // -- morph ----------------------------------------------------------------
  Widget _morph(double t, {required bool statik}) {
    // 10 even segments over MORPH_SEQ; d, rotate, scale interpolate per segment
    // with EASE_IN_OUT (source). A settled shape (statik) holds shape 0.
    double rot;
    double scl;
    List<Offset> pts;
    if (statik) {
      pts = _morphShapes[0];
      rot = 0;
      scl = 1;
    } else {
      const segCount = 11 - 1; // 10 segments
      final segT = t * segCount;
      final i = segT.floor().clamp(0, segCount - 1);
      final local = beuiEaseInOut.transform(segT - i);
      final a = _morphShapes[_morphSeq[i]];
      final b = _morphShapes[_morphSeq[i + 1]];
      pts = [
        for (var k = 0; k < _morphPoints; k++) Offset.lerp(a[k], b[k], local)!,
      ];
      rot = lerpDouble(_morphRot[i], _morphRot[i + 1], local)!;
      scl = lerpDouble(_morphScale[i], _morphScale[i + 1], local)!;
    }
    return CustomPaint(
      size: Size.square(widget.size),
      painter: _MorphPainter(
        color: widget.color,
        points: pts,
        rotationDeg: rot,
        scale: scl,
        size: widget.size,
      ),
    );
  }

  // -- comet ----------------------------------------------------------------
  Widget _comet(double t, {required bool statik}) {
    return CustomPaint(
      size: Size.square(widget.size),
      painter: _CometPainter(
        color: widget.color,
        turns: statik ? 0 : t,
        size: widget.size,
      ),
    );
  }

  // -- scramble -------------------------------------------------------------
  Widget _scramble(double t, {required bool statik}) {
    String text;
    if (statik) {
      text = _scrambleTarget;
    } else {
      final tick = (t * _scrambleTotal).floor();
      if (tick != _scrambleTick) {
        _scrambleTick = tick;
        final reveal = tick % _scrambleTotal;
        final sb = StringBuffer();
        for (var i = 0; i < _scrambleTarget.length; i++) {
          sb.write(
            i < reveal
                ? _scrambleTarget[i]
                : _scrambleGlyphs[_rng.nextInt(_scrambleGlyphs.length)],
          );
        }
        _scrambleText = sb.toString();
      }
      text = _scrambleText;
    }
    final fs = widget.size * 0.42;
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: fs,
        height: 1,
        fontWeight: FontWeight.w500,
        letterSpacing: fs * 0.2,
        color: widget.color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  // -- metaballs ------------------------------------------------------------
  Widget _metaballs(double t, {required bool statik}) {
    final size = widget.size;
    final sf = size / 100.0;
    final cy = 50.0 * sf;
    final r = 15.0 * sf;
    // source: cx1 [30,70,30], cx2 [70,30,70]; reduced holds 40 / 60.
    final cx1 = (statik ? 40.0 : _kf(const [30, 70, 30], t)) * sf;
    final cx2 = (statik ? 60.0 : _kf(const [70, 30, 70], t)) * sf;
    final sigma = 5.0 * sf; // SVG stdDeviation 5 in the 100-unit viewBox
    return ColorFiltered(
      // feColorMatrix alpha threshold `0 0 0 20 -8` (normalised) → 0..255 form
      // (translation column ×255): sharpens the blurred blobs into a goo edge.
      colorFilter: const ColorFilter.matrix(<double>[
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0, //
        0, 0, 1, 0, 0, //
        0, 0, 0, 20, -2040, //
      ]),
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: CustomPaint(
          size: Size.square(size),
          painter: _MetaballsPainter(
            color: widget.color,
            c1: Offset(cx1, cy),
            c2: Offset(cx2, cy),
            radius: r,
          ),
        ),
      ),
    );
  }

  // -- newton ---------------------------------------------------------------
  Widget _newton(double t, {required bool statik}) {
    final d = widget.size * 0.2;
    final out = d * 1.1;
    // Only the end balls move: left out-and-back on the first half, right on
    // the second — the impact appears to jump the three still middle balls.
    final x0 = statik
        ? 0.0
        : _kf(const [0, -1, 0, 0], t, times: const [0, 0.28, 0.5, 1]) * out;
    final x4 = statik
        ? 0.0
        : _kf(const [0, 0, 1, 0], t, times: const [0, 0.5, 0.78, 1]) * out;
    return SizedBox(
      height: d,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            Transform.translate(
              offset: Offset(i == 0 ? x0 : (i == 4 ? x4 : 0), 0),
              child: _circle(d),
            ),
        ],
      ),
    );
  }

  // -- helix ----------------------------------------------------------------
  Widget _helix(double t, {required bool statik}) {
    return CustomPaint(
      size: Size.square(widget.size),
      painter: _HelixPainter(
        color: widget.color,
        t: t,
        size: widget.size,
        statik: statik,
      ),
    );
  }

  // -- percent --------------------------------------------------------------
  Widget _percent(double t) {
    final size = widget.size;
    final p = (t * 100).round().clamp(0, 100);
    final fs = size * 0.42;
    final barH = math.max(3.0, size * 0.1);
    return SizedBox(
      width: size * 1.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$p%',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: fs,
              height: 1,
              fontWeight: FontWeight.w500,
              color: widget.color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: size * 0.14),
          ClipRRect(
            borderRadius: BorderRadius.circular(barH / 2),
            child: SizedBox(
              width: double.infinity,
              height: barH,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: widget.color.withValues(alpha: 0.15),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: p / 100,
                    heightFactor: 1,
                    child: ColoredBox(color: widget.color),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double d) => Container(
    width: d,
    height: d,
    decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
  );
}

// ---------------------------------------------------------------------------
// Keyframe helpers
// ---------------------------------------------------------------------------

/// Wraps [x] into `[0, 1)` (for per-element phase delays).
double _wrap(double x) => (x % 1 + 1) % 1;

/// Evaluates a Framer-style keyframe list [values] at phase [t] ∈ [0,1].
///
/// [times] defaults to even spacing; each segment is eased by [curve] (Framer
/// applies the single transition `ease` per segment). Defaults to
/// [beuiEaseInOut], the source's `EASE_IN_OUT` — the ease every loader keyframe
/// track uses.
double _kf(
  List<double> values,
  double t, {
  List<double>? times,
  Curve curve = beuiEaseInOut,
}) {
  final n = values.length;
  if (n == 1) return values.first;
  final ts =
      times ?? List<double>.generate(n, (i) => i / (n - 1), growable: false);
  if (t <= ts.first) return values.first.toDouble();
  if (t >= ts.last) return values.last.toDouble();
  var i = 0;
  while (i < n - 1 && t > ts[i + 1]) {
    i++;
  }
  final span = ts[i + 1] - ts[i];
  final local = span <= 0 ? 0.0 : (t - ts[i]) / span;
  return lerpDouble(
    values[i].toDouble(),
    values[i + 1].toDouble(),
    curve.transform(local.clamp(0.0, 1.0)),
  )!;
}

// ---------------------------------------------------------------------------
// Scramble constants (source SCRAMBLE_TARGET / SCRAMBLE_GLYPHS)
// ---------------------------------------------------------------------------

const String _scrambleTarget = 'LOADING';
const String _scrambleGlyphs = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<>/*#@';
const int _scrambleTotal = _scrambleTarget.length + 4; // 11

// ---------------------------------------------------------------------------
// Dither: ordered Bayer 4×4 matrix (source BAYER_4)
// ---------------------------------------------------------------------------

const List<int> _bayer4 = [
  0, 8, 2, 10, //
  12, 4, 14, 6, //
  3, 11, 1, 9, //
  15, 7, 13, 5, //
];

// ---------------------------------------------------------------------------
// Morph: 24-point sampled shapes (source MORPH_POINTS / morphPath / ngonRadius)
// ---------------------------------------------------------------------------

const int _morphPoints = 24;

double _ngonRadius(double ang, int n, double phase) {
  final seg = (2 * math.pi) / n;
  final a = ang - phase;
  final local = (((a % seg) + seg) % seg) - seg / 2;
  return math.cos(math.pi / n) / math.cos(local);
}

List<Offset> _morphShape(double Function(double ang) radiusAt) {
  final pts = <Offset>[];
  for (var i = 0; i < _morphPoints; i++) {
    final ang = (i / _morphPoints) * 2 * math.pi - math.pi / 2;
    final r = math.min(1.05, radiusAt(ang));
    pts.add(Offset(50 + math.cos(ang) * 46 * r, 50 + math.sin(ang) * 46 * r));
  }
  return pts;
}

final List<List<Offset>> _morphShapes = [
  _morphShape((_) => 1), // circle
  _morphShape((a) => _ngonRadius(a, 4, math.pi / 4)), // square
  _morphShape((a) => _ngonRadius(a, 3, 0)), // triangle
  _morphShape((a) => _ngonRadius(a, 6, 0)), // hexagon
  _morphShape((a) => _ngonRadius(a, 4, 0)), // diamond
];

// Each shape appears twice (form + hold) then back to the first (source
// MORPH_SEQ). Rotation/scale only change across morph segments.
const List<int> _morphSeq = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 0];
const List<double> _morphRot = [
  0,
  0,
  72,
  72,
  144,
  144,
  216,
  216,
  288,
  288,
  360,
];
const List<double> _morphScale = [1, 1, 0.88, 0.88, 1, 1, 0.88, 0.88, 1, 1, 1];

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter({
    required this.color,
    required this.turns,
    required this.size,
  });

  final Color color;
  final double turns;
  final double size;

  @override
  void paint(Canvas canvas, Size s) {
    // source: stroke max(2, size*0.09), r = (size-stroke)/2.
    final stroke = math.max(2.0, size * 0.09);
    final r = (size - stroke) / 2;
    final center = Offset(size / 2, size / 2);

    // Faint track ring (strokeOpacity 0.2).
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color.withValues(alpha: 0.2),
    );

    // Rotating 90° arc from the top (source path: top → right quarter).
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(turns * 2 * math.pi);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      math.pi / 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) =>
      old.turns != turns || old.color != color || old.size != size;
}

class _CometPainter extends CustomPainter {
  _CometPainter({required this.color, required this.turns, required this.size});

  final Color color;
  final double turns;
  final double size;

  @override
  void paint(Canvas canvas, Size s) {
    // source: 6 trail dots, head = size*0.2, r = size/2 - head/2, each dot
    // scaled 1-0.13i, opacity 1-0.16i, at rotate(-15i°) translateY(-r).
    final head = size * 0.2;
    final r = size / 2 - head / 2;
    final center = Offset(size / 2, size / 2);
    final groupRad = turns * 2 * math.pi;
    for (var i = 0; i < 6; i++) {
      final scale = 1 - i * 0.13;
      final sz = head * scale;
      final o = (1 - i * 0.16).clamp(0.0, 1.0);
      final theta = groupRad - i * 15 * math.pi / 180;
      final c = center + Offset(r * math.sin(theta), -r * math.cos(theta));
      canvas.drawCircle(c, sz / 2, Paint()..color = color.withValues(alpha: o));
    }
  }

  @override
  bool shouldRepaint(_CometPainter old) =>
      old.turns != turns || old.color != color || old.size != size;
}

class _MorphPainter extends CustomPainter {
  _MorphPainter({
    required this.color,
    required this.points,
    required this.rotationDeg,
    required this.scale,
    required this.size,
  });

  final Color color;
  final List<Offset> points;
  final double rotationDeg;
  final double scale;
  final double size;

  @override
  void paint(Canvas canvas, Size s) {
    final sf = size / 100.0; // shapes are in a 100-unit space
    canvas.save();
    canvas.scale(sf);
    // Rotate/scale about the shape centre (50,50) — source transformOrigin.
    canvas.translate(50, 50);
    canvas.rotate(rotationDeg * math.pi / 180);
    canvas.scale(scale);
    canvas.translate(-50, -50);
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MorphPainter old) =>
      old.rotationDeg != rotationDeg ||
      old.scale != scale ||
      old.color != color ||
      old.points != points;
}

class _MetaballsPainter extends CustomPainter {
  _MetaballsPainter({
    required this.color,
    required this.c1,
    required this.c2,
    required this.radius,
  });

  final Color color;
  final Offset c1;
  final Offset c2;
  final double radius;

  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()..color = color;
    canvas.drawCircle(c1, radius, paint);
    canvas.drawCircle(c2, radius, paint);
  }

  @override
  bool shouldRepaint(_MetaballsPainter old) =>
      old.c1 != c1 ||
      old.c2 != c2 ||
      old.radius != radius ||
      old.color != color;
}

class _HelixPainter extends CustomPainter {
  _HelixPainter({
    required this.color,
    required this.t,
    required this.size,
    required this.statik,
  });

  final Color color;
  final double t;
  final double size;
  final bool statik;

  @override
  void paint(Canvas canvas, Size s) {
    // source: 7 rows, dot = size*0.14, amp = size*0.32, two crossing dots per
    // row, per-row delay r/7.
    const rows = 7;
    final dot = size * 0.14;
    final amp = size * 0.32;
    final cx = size / 2;
    for (var r = 0; r < rows; r++) {
      final top = (r / (rows - 1)) * (size - dot);
      final cy = top + dot / 2;
      if (statik) {
        // Static double-helix cross: dots parked at ±amp, dimmed.
        _dot(canvas, Offset(cx + amp, cy), dot / 2, 0.7);
        _dot(canvas, Offset(cx - amp, cy), dot / 2, 0.7);
        continue;
      }
      final lt = _wrap(t - r / rows);
      // dot A
      final ax = _kf(const [1, -1, 1], lt) * amp;
      final asc = _kf(const [1, 0.5, 1], lt);
      final ao = _kf(const [1, 0.45, 1], lt);
      _dot(canvas, Offset(cx + ax, cy), (dot / 2) * asc, ao);
      // dot B (counter-phase)
      final bx = _kf(const [-1, 1, -1], lt) * amp;
      final bsc = _kf(const [0.5, 1, 0.5], lt);
      final bo = _kf(const [0.45, 1, 0.45], lt);
      _dot(canvas, Offset(cx + bx, cy), (dot / 2) * bsc, bo);
    }
  }

  void _dot(Canvas canvas, Offset c, double r, double o) {
    canvas.drawCircle(
      c,
      r,
      Paint()..color = color.withValues(alpha: o.clamp(0.0, 1.0)),
    );
  }

  @override
  bool shouldRepaint(_HelixPainter old) =>
      old.t != t ||
      old.color != color ||
      old.size != size ||
      old.statik != statik;
}
