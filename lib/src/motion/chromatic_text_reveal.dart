import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_scroll_geometry.dart';

/// Half-width of the chromatic trail as a fraction of the active word's width
/// (source `TRAIL_HALF_WIDTH = 14`, expressed in CSS `%`).
const double _trailHalfWidth = 0.14;

/// Sweep travel — source `REVEAL_START` (`-14%`) → `REVEAL_FINISH` (`114%`).
/// The trail starts fully off the left edge and finishes fully off the right.
const double _sweepStart = -_trailHalfWidth;
const double _sweepFinish = 1 + _trailHalfWidth;

/// Enter-transition windows (source, seconds → ms): opacity 0.28s, blur 0.36s,
/// translateY 0.36s — all on [beuiEaseOut].
const int _opacityMs = 280;
const int _enterMs = 360;

/// Source enter rest state: `opacity: 0.56`, `filter: blur(6px)`,
/// `transform: translateY(5px)`.
const double _enterOpacity = 0.56;
const double _enterBlurPx = 6;
const double _enterOffsetY = 5;

/// The colour ramp + stop positions of the chromatic edge at a given [sweep].
typedef BeuiChromaticGradient = ({List<Color> colors, List<double> stops});

/// Builds the swept gradient for one frame — the direct port of the source's
/// `composeChromaticGradient()` + its animated `--chromatic-sweep` variable.
///
/// The source CSS is
///
/// ```css
/// linear-gradient(90deg,
///   fg          0%,
///   fg          calc(sweep - 14%),
///   c0          calc(sweep - 14%),   /* palette ramp, evenly spread    */
///   …                                /* across the 28%-wide trail      */
///   cN          calc(sweep + 14%),
///   transparent calc(sweep + 14%),
///   transparent 100%)
/// ```
///
/// so the line reads, left to right: **already-revealed foreground**, then the
/// **chromatic trail** (the palette spread evenly over `±14%` around the sweep
/// head), then **nothing** — the glyphs ahead of the edge are unpainted. Driving
/// `sweep` from [_sweepStart] to [_sweepFinish] walks that edge across the word.
///
/// Two adaptations, both required to land the same pixels in Flutter:
///
/// * **Clamping + monotonicity.** CSS lets stops fall outside `0%..100%` and
///   fixes up any stop that regresses ("set its position to the largest
///   specified position of any color stop before it"). Flutter hands stops
///   straight to Skia, so the same normalisation is applied here explicitly.
/// * **`transparent`.** CSS interpolates in premultiplied space, so a fade to
///   `transparent` never darkens; Flutter's gradients lerp unpremultiplied, so
///   the terminator uses the last palette colour at `alpha: 0` instead of
///   `Colors.transparent` (which would drag a black fringe into the ramp).
///
/// Exposed for the fidelity test that checks the stop layout against the source
/// formula; it is not part of the package's public surface.
@visibleForTesting
BeuiChromaticGradient chromaticGradient({
  required double sweep,
  required List<Color> palette,
  required Color foreground,
}) {
  final ramp = palette.isEmpty
      ? BeuiChromaticTextReveal.defaultColors
      : palette;
  // Source `transparent`, hue-matched so the terminator cannot tint the ramp.
  final trailEnd = ramp.last.withValues(alpha: 0);

  final colors = <Color>[foreground, foreground];
  final stops = <double>[0, sweep - _trailHalfWidth];
  for (var i = 0; i < ramp.length; i++) {
    final offset = ramp.length == 1
        ? 0.0
        : -_trailHalfWidth + (i / (ramp.length - 1)) * _trailHalfWidth * 2;
    colors.add(ramp[i]);
    stops.add(sweep + offset);
  }
  colors
    ..add(trailEnd)
    ..add(trailEnd);
  stops
    ..add(sweep + _trailHalfWidth)
    ..add(1);

  var last = 0.0;
  for (var i = 0; i < stops.length; i++) {
    last = math.max(last, stops[i].clamp(0.0, 1.0));
    stops[i] = last;
  }
  return (colors: colors, stops: stops);
}

/// A fixed prefix followed by cycling words, each painted in by a moving
/// chromatic edge — the Flutter port of beUI's `chromatic-text-reveal`.
///
/// A colour trail sweeps left-to-right across the glyphs of the active word,
/// leaving [foregroundColor] behind it and nothing ahead of it, pauses for
/// [pauseDuration], then hands over to the next entry in [words]. Each word also
/// enters with the source's short blur/rise/fade (`opacity 0.56 → 1`,
/// `blur(6px) → 0`, `translateY(5px) → 0`), which runs *while* the sweep travels.
///
/// **Gradient.** The trail is a [ShaderMask] over the word: a horizontal
/// [LinearGradient] whose stops move every frame, ported stop-for-stop from the
/// source's `--chromatic-sweep` CSS variable — see [chromaticGradient] for the
/// formula and the two CSS→Skia adaptations it makes. The default palette is the
/// source's (`#60a5fa #818cf8 #c084fc #fb7185 #fbbf24`, see [defaultColors]) with
/// a 14%-of-word-width half-trail. The sweep itself rides [beuiEaseInOut] over
/// [duration]; the enter properties ride [beuiEaseOut] over their own shorter
/// windows — the source's four independent transitions.
///
/// **No spring, so no `motor`.** Every property here is a source
/// `duration` + `cubic-bezier` transition; there is no spring token to route
/// through the motion facade. The timeline is therefore a plain controller with
/// the [beuiEaseInOut] / [beuiEaseOut] tokens applied analytically — identical to
/// the sibling `text-shimmer` and `text-reveal` ports.
///
/// **Layout.** The word slot is sized to the widest entry in [words] (the
/// source's invisible sizing grid), so cycling never reflows the line. Words are
/// never wrapped (source `whitespace-nowrap`).
///
/// **Reduced motion** drops the travel entirely: the first word renders settled
/// in [foregroundColor], with no sweep, no blur, no rise — and no cycling, since
/// the cycle exists only to show the sweep (the source's `reduceMotion` branch
/// verbatim). Colour is preserved; only movement is dropped.
///
/// **Accessibility.** The animated glyphs are decorative; the full resolved
/// string (`prefix` + active word) is exposed as a single semantics label, so a
/// screen reader always reads the sentence rather than the paint.
///
/// **RTL.** The sweep follows the reading direction — it runs start → end
/// resolved against [Directionality], where the source hardcodes a physical
/// `90deg` (the spec's RTL rule).
class BeuiChromaticTextReveal extends StatefulWidget {
  /// Creates a chromatic reveal of [words] after the fixed [prefix].
  const BeuiChromaticTextReveal({
    required this.prefix,
    required this.words,
    this.colors,
    this.foregroundColor,
    this.duration = const Duration(milliseconds: 1200),
    this.delay = Duration.zero,
    this.pauseDuration = const Duration(milliseconds: 800),
    this.loop = true,
    this.startOnView = true,
    this.once = true,
    this.amount = 0.4,
    this.style,
    super.key,
  });

  /// The source palette used along the moving chromatic edge — `#60a5fa`,
  /// `#818cf8`, `#c084fc`, `#fb7185`, `#fbbf24`. Used when [colors] is null.
  ///
  /// This is a deliberate literal, not a theme lookup: it is the component's
  /// subject matter (the caller-facing artwork), exactly as in the source. Every
  /// *theme* colour here — the settled [foregroundColor] — still comes from
  /// [BeuiColors].
  static const List<Color> defaultColors = <Color>[
    Color(0xFF60A5FA),
    Color(0xFF818CF8),
    Color(0xFFC084FC),
    Color(0xFFFB7185),
    Color(0xFFFBBF24),
  ];

  /// Sentence fragment that stays fixed while the final word changes.
  final String prefix;

  /// Words revealed one after another after [prefix]. Empty renders the prefix
  /// alone.
  final List<String> words;

  /// Colours along the moving chromatic edge (source `colors`). Defaults to
  /// [defaultColors]. A single-entry list collapses the trail to one hue.
  final List<Color>? colors;

  /// Final text colour left behind the sweep (source `foregroundColor`,
  /// defaulting to `var(--foreground)`). Defaults to [BeuiColors.foreground].
  final Color? foregroundColor;

  /// One sweep, edge to edge (source `duration`, default 1.2s).
  final Duration duration;

  /// Delay before each word's sweep starts (source `delay`). The enter
  /// blur/rise/fade is not delayed, matching the source's per-property split.
  final Duration delay;

  /// Rest after a word finishes revealing, before the next one (source
  /// `pauseDuration`, default 0.8s).
  final Duration pauseDuration;

  /// Return to the first word after the last one (source `loop`). When false the
  /// final word stays revealed.
  final bool loop;

  /// Hold until the widget scrolls into view (source `startOnView`). Without an
  /// enclosing scrollable the widget counts as visible and starts on first
  /// layout.
  final bool startOnView;

  /// With [startOnView]: reveal only on the first entry (default), or un-reveal
  /// on exit and replay on every re-entry when false (source `once`).
  final bool once;

  /// Fraction of the widget that must be visible to trigger [startOnView]
  /// (the source's fixed `useInView({amount: 0.4})`).
  ///
  /// This is the port of the source's `inViewMargin` knob as well: an
  /// `IntersectionObserver` `rootMargin` has no Flutter analog, and the repo
  /// already resolves in-view through one visible-fraction mechanism shared with
  /// `text-reveal` / `scroll-reveal`, so the threshold is expressed here as a
  /// fraction rather than as a margin.
  final double amount;

  /// Text style for the prefix and the words. Falls back to the ambient
  /// [DefaultTextStyle]. Only the swept word is recoloured to
  /// [foregroundColor]; the prefix keeps the style's own colour, as in the
  /// source.
  final TextStyle? style;

  @override
  State<BeuiChromaticTextReveal> createState() =>
      _BeuiChromaticTextRevealState();
}

class _BeuiChromaticTextRevealState extends State<BeuiChromaticTextReveal>
    with TickerProviderStateMixin, ScrollGeometryMixin {
  /// The sweep: `delay` then `duration`, walking the chromatic edge across the
  /// word. Reversible — an `once: false` widget leaving the viewport un-reveals.
  late final AnimationController _sweep;

  /// The per-word enter: opacity / blur / rise, all [beuiEaseOut].
  late final AnimationController _enter;

  Timer? _pause;
  int _index = 0;
  bool _armed = false;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(vsync: this, duration: _sweepWindow)
      ..addStatusListener(_onSweepStatus);
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _enterMs),
    );
    if (!widget.startOnView) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _arm());
    }
  }

  Duration get _sweepWindow => widget.delay + widget.duration;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    // startOnView needs an enclosing scrollable to measure against; without one
    // the widget counts as fully visible — start on the first layout.
    if (widget.startOnView && Scrollable.maybeOf(context) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _arm());
    }
  }

  @override
  void didUpdateWidget(BeuiChromaticTextReveal old) {
    super.didUpdateWidget(old);
    if (widget.delay != old.delay || widget.duration != old.duration) {
      _sweep.duration = _sweepWindow;
    }
    if (widget.words.length != old.words.length && _index >= _wordCount) {
      _index = 0;
    }
  }

  @override
  void dispose() {
    _pause?.cancel();
    _sweep.dispose();
    _enter.dispose();
    super.dispose();
  }

  int get _wordCount => widget.words.length;

  /// Arms the reveal: the sweep continues from wherever it stands (so a
  /// re-entry with `once: false` resumes rather than restarting), and the enter
  /// only plays if it has not already settled for this word.
  void _arm() {
    if (!mounted || _armed || _reduce) return;
    _armed = true;
    _enter.forward();
    _sweep.forward();
  }

  void _onSweepStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _scheduleNextWord();
  }

  /// Source `scheduleNextWord`: after the sweep lands, rest for [pauseDuration]
  /// and hand over to the next word. Never fires under reduced motion, with a
  /// single word, or on the last word when [BeuiChromaticTextReveal.loop] is off.
  void _scheduleNextWord() {
    _pause?.cancel();
    final isLast = _index == _wordCount - 1;
    if (_reduce || !_armed || _wordCount < 2 || (isLast && !widget.loop)) {
      return;
    }
    _pause = Timer(widget.pauseDuration, () {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _wordCount);
      _enter.forward(from: 0);
      _sweep.forward(from: 0);
    });
  }

  @override
  void onScrollGeometryChanged() {
    if (!widget.startOnView || _reduce) return;
    final fraction = visibleFraction;
    if (fraction == null) return;
    final inView = fraction >= widget.amount;
    if (inView && !_armed) {
      _arm();
    } else if (!inView && _armed && !widget.once) {
      // Left view with once: false — the source retargets the sweep back to
      // REVEAL_START, un-painting the word so re-entry replays it.
      _pause?.cancel();
      _armed = false;
      _sweep.reverse();
    }
  }

  /// Sweep head position, in fractions of the word's width. Runs the source's
  /// `delay` as dead time at the head of the window, then [beuiEaseInOut] across
  /// [BeuiChromaticTextReveal.duration].
  double get _sweepValue {
    final totalMs = _sweepWindow.inMilliseconds;
    final delayMs = widget.delay.inMilliseconds;
    final durationMs = widget.duration.inMilliseconds;
    if (durationMs <= 0) return _sweepFinish;
    final elapsed = _sweep.value * totalMs;
    final t = ((elapsed - delayMs) / durationMs).clamp(0.0, 1.0);
    return _sweepStart +
        (_sweepFinish - _sweepStart) * beuiEaseInOut.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final foreground = widget.foregroundColor ?? colors.foreground;
    final palette = widget.colors?.isNotEmpty ?? false
        ? widget.colors!
        : BeuiChromaticTextReveal.defaultColors;

    final hasWords = _wordCount > 0;
    final word = hasWords ? widget.words[_index % _wordCount] : '';
    final label = <String>[
      widget.prefix.trim(),
      if (hasWords) word,
    ].where((s) => s.isNotEmpty).join(' ');

    // Prefix and word share one style, so their line boxes match — bottom
    // alignment is the baseline alignment the source asks for (`items-baseline`)
    // without depending on a Stack reporting a baseline.
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Source: prefix + a trailing space, so the gap is painted width and
        // never collapses at the end of the run.
        Text(
          hasWords ? '${widget.prefix} ' : widget.prefix,
          style: style,
          softWrap: false,
          maxLines: 1,
        ),
        if (hasWords)
          Stack(
            alignment: AlignmentDirectional.topStart,
            children: [
              // Source's invisible sizing grid: the slot is as wide as the
              // widest word, so cycling never reflows the surrounding line.
              for (final sizing in widget.words.toSet())
                Visibility(
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Text(
                    sizing,
                    style: style,
                    softWrap: false,
                    maxLines: 1,
                  ),
                ),
              _SweptWord(
                word: word,
                style: style,
                foreground: foreground,
                palette: palette,
                sweep: _sweep,
                enter: _enter,
                sweepValueOf: () => _sweepValue,
                reduce: _reduce,
                textDirection: Directionality.of(context),
              ),
            ],
          ),
      ],
    );

    // The glyphs are painted decoration; the sentence is what gets announced.
    return Semantics(
      label: label,
      container: true,
      child: ExcludeSemantics(child: row),
    );
  }
}

/// The active word under its chromatic edge.
///
/// Repaints every frame while the sweep travels, so it is isolated behind a
/// [RepaintBoundary] and short-circuits to a plain [Text] the moment both
/// timelines settle — a revealed word costs nothing until the next one arrives.
class _SweptWord extends StatelessWidget {
  const _SweptWord({
    required this.word,
    required this.style,
    required this.foreground,
    required this.palette,
    required this.sweep,
    required this.enter,
    required this.sweepValueOf,
    required this.reduce,
    required this.textDirection,
  });

  final String word;
  final TextStyle style;
  final Color foreground;
  final List<Color> palette;
  final AnimationController sweep;
  final AnimationController enter;
  final double Function() sweepValueOf;
  final bool reduce;
  final TextDirection textDirection;

  Widget _settled() => Text(
    word,
    style: style.copyWith(color: foreground),
    softWrap: false,
    maxLines: 1,
  );

  @override
  Widget build(BuildContext context) {
    // Reduced motion: no travel at all — the word rests in its final colour.
    if (reduce) return _settled();

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([sweep, enter]),
        builder: (context, _) {
          if (sweep.isCompleted && enter.isCompleted) return _settled();

          final gradient = chromaticGradient(
            sweep: sweepValueOf(),
            palette: palette,
            foreground: foreground,
          );

          Widget glyphs = ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (rect) => LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: gradient.colors,
              stops: gradient.stops,
            ).createShader(rect, textDirection: textDirection),
            child: Text(word, style: style, softWrap: false, maxLines: 1),
          );

          // Enter: blur 6px → 0 and rise 5px → 0 over 0.36s, fade 0.56 → 1 over
          // 0.28s, all on EASE_OUT.
          final p = beuiEaseOut.transform(enter.value);
          final op =
              _enterOpacity +
              (1 - _enterOpacity) *
                  beuiEaseOut.transform(
                    (enter.value * _enterMs / _opacityMs).clamp(0.0, 1.0),
                  );
          final sigma = beuiBlurSigma((1 - p) * _enterBlurPx);
          if (sigma > 0.05) {
            glyphs = ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.decal,
              ),
              child: glyphs,
            );
          }

          return Opacity(
            opacity: op.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - p) * _enterOffsetY),
              child: glyphs,
            ),
          );
        },
      ),
    );
  }
}
