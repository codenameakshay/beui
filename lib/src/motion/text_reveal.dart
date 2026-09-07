import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../tokens/motion.dart';
import '_engine.dart';
import '_scroll_geometry.dart';

/// How [BeuiTextReveal] splits its text into independently-animated units.
enum BeuiTextRevealSplit {
  /// Animate one unit per whitespace-separated word (the source default).
  word,

  /// Animate one unit per character.
  char,
}

/// A staggered slide-up + blur reveal for text — the Flutter port of beUI's
/// `text-reveal`.
///
/// Each unit (a [BeuiTextRevealSplit.word] or [BeuiTextRevealSplit.char]) rises
/// from [yOffset] below its slot, fading and de-blurring into place, staggered
/// left-to-right by [stagger]. The vertical rise rides a soft spring (source
/// `DEFAULT_SPRING` — stiffness 140 · damping 26 · mass 1.2, overridable via
/// [spring]); the opacity and blur are eased with [beuiEaseOut] over their own
/// (longer) windows, exactly as the source drives `y` / `opacity` / `filter`
/// on separate transitions.
///
/// By default the reveal plays once on mount (source `whileInView: false`).
/// With [whileInView] the units hold hidden until [amount] of the widget is
/// visible in the nearest enclosing scrollable, then play; [once] `false`
/// resets and replays on every re-entry. Reduced motion drops the rise and
/// blur, keeping only a short staggered fade — the source's reduce branch
/// verbatim.
class BeuiTextReveal extends StatefulWidget {
  /// Creates a text reveal.
  ///
  /// Pass [text] as a single string, or as a list to render each entry on its
  /// own line (mirroring the source's `string | string[]`).
  const BeuiTextReveal(
    this.text, {
    this.split = BeuiTextRevealSplit.word,
    this.stagger = const Duration(milliseconds: 90),
    this.delay = Duration.zero,
    this.blur = 12,
    this.yOffset = 0.4,
    this.spring,
    this.whileInView = false,
    this.once = true,
    this.amount = 0.4,
    this.style,
    this.textAlign,
    super.key,
  });

  /// The text to reveal. A single-element list and a bare string are
  /// equivalent; multiple list entries each render on their own line.
  final Object text;

  /// Split granularity — per word (default) or per character.
  final BeuiTextRevealSplit split;

  /// Delay between consecutive units (source `stagger`, default 0.09s).
  final Duration stagger;

  /// Delay before the first unit starts (source `delay`).
  final Duration delay;

  /// Initial blur in CSS pixels (source `blur`, default 12). Applied as a
  /// Gaussian sigma of `blur / 2` (CSS `blur(Npx)` ≈ sigma N/2), capped at
  /// sigma 5 per the library's motion-blur budget.
  final double blur;

  /// Initial vertical offset as a fraction of the unit's line height (source
  /// `yOffset`, default `"40%"` → 0.4). Positive offsets start below.
  final double yOffset;

  /// Overrides the rise spring (source `spring?: {stiffness, damping, mass}`).
  /// Defaults to the source `DEFAULT_SPRING` — stiffness 140 · damping 26 ·
  /// mass 1.2.
  final SpringDescription? spring;

  /// Hold the reveal until [amount] of the widget is visible in the nearest
  /// enclosing scrollable (source `whileInView`). Off (default) plays once on
  /// mount. Without an enclosing scrollable the widget counts as visible and
  /// plays on first layout.
  final bool whileInView;

  /// With [whileInView]: play only on the first entry (default), or reset and
  /// replay on every re-entry when `false` (source `once`).
  final bool once;

  /// Fraction of the widget that must be visible to trigger [whileInView]
  /// (source `amount`, default 0.4).
  final double amount;

  /// Text style for every unit. Falls back to the ambient [DefaultTextStyle].
  final TextStyle? style;

  /// Horizontal alignment of the lines.
  final TextAlign? textAlign;

  @override
  State<BeuiTextReveal> createState() => _BeuiTextRevealState();
}

/// Source `DEFAULT_SPRING` for the vertical rise — stiffness 140 · damping 26 ·
/// mass 1.2. A component-local spring (not one of the five shared tokens), so it
/// is constructed by name here, exactly as `stateful.dart`'s heavy springs are.
/// [BeuiTextReveal.spring] overrides it wholesale.
const _defaultRevealSpring = SpringDescription(
  mass: 1.2,
  stiffness: 140,
  damping: 26,
);

// Source per-transition windows (seconds → ms): opacity 0.7s, blur 0.9s, both
// eased with EASE_OUT; the spring window is governed by physics, not a duration.
const int _opacityMs = 700;
const int _blurMs = 900;

class _BeuiTextRevealState extends State<BeuiTextReveal>
    with SingleTickerProviderStateMixin, ScrollGeometryMixin {
  late final AnimationController _controller;
  late List<String> _lines;
  late List<List<String>> _units; // units per line
  late List<List<int>> _delaysMs; // start delay per unit, flattened by line

  // Whether the reveal has been triggered (mount, or in-view arming). A reset
  // (whileInView + once: false, element left view) bumps the generation so the
  // units remount at their hidden rest state.
  bool _played = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _split();
    _controller = AnimationController(vsync: this, duration: _totalDuration());
    if (!widget.whileInView) {
      // Play once on mount (source `whileInView: false` default).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_played) _play();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // whileInView needs an enclosing scrollable to measure against; without
    // one the widget counts as fully visible — play on the first layout.
    if (widget.whileInView && Scrollable.maybeOf(context) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_played) _play();
      });
    }
  }

  @override
  void onScrollGeometryChanged() {
    if (!widget.whileInView) return;
    final fraction = visibleFraction;
    if (fraction == null) return;
    final inView = fraction >= widget.amount;
    if (inView && !_played) {
      _play();
    } else if (!inView && _played && !widget.once) {
      // Left view with once: false — reset to hidden and re-arm for replay.
      _controller
        ..stop()
        ..value = 0;
      setState(() {
        _played = false;
        _generation++;
      });
    }
  }

  void _play() {
    _played = true;
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(BeuiTextReveal old) {
    super.didUpdateWidget(old);
    if (_textChanged(old) ||
        old.split != widget.split ||
        old.stagger != widget.stagger ||
        old.delay != widget.delay) {
      _split();
      _controller.duration = _totalDuration();
      // New text replays immediately unless it is still waiting to enter view.
      if (!widget.whileInView || _played) {
        _played = true;
        _controller.forward(from: 0);
      }
    }
  }

  bool _textChanged(BeuiTextReveal old) {
    final a = old.text, b = widget.text;
    if (a is List && b is List) {
      if (a.length != b.length) return true;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return true;
      }
      return false;
    }
    return a != b;
  }

  void _split() {
    final raw = widget.text;
    _lines = raw is List ? raw.map((e) => '$e').toList() : <String>['$raw'];
    _units = [
      for (final line in _lines)
        widget.split == BeuiTextRevealSplit.word
            ? line.split(' ')
            : line.split(''),
    ];
    var i = 0;
    final stagger = widget.stagger.inMilliseconds;
    final delay = widget.delay.inMilliseconds;
    _delaysMs = [
      for (final lineUnits in _units)
        [for (var u = 0; u < lineUnits.length; u++) delay + (i++) * stagger],
    ];
  }

  int get _unitCount => _units.fold(0, (n, l) => n + l.length);

  Duration _totalDuration() {
    final stagger = widget.stagger.inMilliseconds;
    final delay = widget.delay.inMilliseconds;
    final lastDelay = delay + (_unitCount - 1).clamp(0, 1 << 30) * stagger;
    // Cover the slowest tail (blur 0.9s); the spring settles within it.
    return Duration(milliseconds: lastDelay + _blurMs + 200);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final lineHeightPx = (baseStyle.fontSize ?? 16) * (baseStyle.height ?? 1.2);
    final motion = SpringMotion(widget.spring ?? _defaultRevealSpring);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _crossAxis(widget.textAlign),
      children: [
        for (var l = 0; l < _units.length; l++)
          Wrap(
            alignment: _wrapAlign(widget.textAlign),
            children: [
              for (var u = 0; u < _units[l].length; u++)
                _Unit(
                  // Generation-keyed so an in-view replay remounts the units
                  // at their hidden rest state.
                  key: ValueKey('r$_generation-$l-$u'),
                  controller: _controller,
                  text: widget.split == BeuiTextRevealSplit.word
                      ? (u < _units[l].length - 1
                            ? '${_units[l][u]} '
                            : _units[l][u])
                      : _units[l][u],
                  style: baseStyle,
                  startMs: _delaysMs[l][u],
                  yOffsetPx: widget.yOffset * lineHeightPx,
                  blur: widget.blur,
                  motion: motion,
                  reduce: reduce,
                ),
            ],
          ),
      ],
    );
  }

  CrossAxisAlignment _crossAxis(TextAlign? a) => switch (a) {
    TextAlign.center => CrossAxisAlignment.center,
    TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
    _ => CrossAxisAlignment.start,
  };

  WrapAlignment _wrapAlign(TextAlign? a) => switch (a) {
    TextAlign.center => WrapAlignment.center,
    TextAlign.right || TextAlign.end => WrapAlignment.end,
    _ => WrapAlignment.start,
  };
}

/// One revealed unit. The vertical rise is a spring ([BeuiTextReveal.spring],
/// default 140/26/1.2) re-targeted from its `yOffset` to `0` once the shared
/// sweep crosses its [startMs]; the opacity and blur are computed analytically
/// from the same sweep with [beuiEaseOut], each on its own window — the
/// source's three independent transitions.
///
/// Once the shared controller has completed, the unit short-circuits to a
/// plain static [Text] — a long-settled reveal costs nothing per frame.
class _Unit extends StatelessWidget {
  const _Unit({
    required this.controller,
    required this.text,
    required this.style,
    required this.startMs,
    required this.yOffsetPx,
    required this.blur,
    required this.motion,
    required this.reduce,
    super.key,
  });

  final AnimationController controller;
  final String text;
  final TextStyle style;
  final int startMs;
  final double yOffsetPx;
  final double blur;
  final Motion motion;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    // Settled short-circuit: no per-frame math, no filter, no spring subtree.
    if (controller.isCompleted) return Text(text, style: style);

    final totalMs = controller.duration!.inMilliseconds;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // Re-check per tick: the final tick lands here before the parent
        // rebuilds, and every later external rebuild takes the branch above.
        if (controller.isCompleted) return Text(text, style: style);

        final elapsedMs = controller.value * totalMs;
        // Reduced motion: short staggered fade only, no rise/blur. Source uses a
        // 0.25s opacity with delay scaled by 0.3.
        if (reduce) {
          final p = ((elapsedMs - startMs * 0.3) / 250).clamp(0.0, 1.0);
          return Opacity(
            opacity: beuiEaseOut.transform(p),
            child: Text(text, style: style),
          );
        }

        final op = beuiEaseOut.transform(
          ((elapsedMs - startMs) / _opacityMs).clamp(0.0, 1.0),
        );
        final bp = beuiEaseOut.transform(
          ((elapsedMs - startMs) / _blurMs).clamp(0.0, 1.0),
        );
        // CSS blur(Npx) → sigma N/2, capped at the sigma-5 motion-blur budget.
        final sigma = ((1 - bp) * blur / 2).clamp(0.0, 5.0);

        Widget glyph = Text(text, style: style);
        if (sigma > 0.05) {
          glyph = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: sigma,
              sigmaY: sigma,
              tileMode: TileMode.decal,
            ),
            child: glyph,
          );
        }

        // The vertical rise: spring from yOffset → 0, released at startMs.
        final released = elapsedMs >= startMs;
        return SingleMotionBuilder(
          value: released ? 0.0 : yOffsetPx,
          from: yOffsetPx,
          motion: motion,
          builder: (context, dy, child) => Opacity(
            opacity: op,
            child: Transform.translate(offset: Offset(0, dy), child: child),
          ),
          child: glyph,
        );
      },
    );
  }
}
