import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';

/// A continuous gradient shimmer swept across text — the Flutter port of beUI's
/// `text-shimmer`.
///
/// A bright highlight band sweeps through the text on an endless loop. Mirrors
/// the source's `linear-gradient(110deg, muted-foreground 30%, foreground 50%,
/// muted-foreground 70%)` painted over a `200%`-wide background tile
/// (`bg-[length:200%_100%]`) whose `background-position` runs from `200% 0` to
/// `-200% 0` — so the highlight band is 0.8× the text width and, because the
/// tile repeats (the source leaves `background-repeat` at its `repeat`
/// default), two highlights pass through the glyphs per cycle with no gap
/// between them. The resting text is [BeuiColors.mutedForeground] and the moving
/// highlight is [BeuiColors.foreground].
///
/// This is a pure opacity/color effect (no movement), so it is **not** gated on
/// reduced motion — but it honours the platform setting by holding the band
/// centred (a static highlight) when animations are disabled, rather than
/// looping. [ShaderMask] paints the text with the animated gradient via
/// [BlendMode.srcIn].
class BeuiTextShimmer extends StatefulWidget {
  /// Creates a text shimmer over [text].
  const BeuiTextShimmer(
    this.text, {
    this.duration = const Duration(milliseconds: 2500),
    this.style,
    this.textAlign,
    this.baseColor,
    this.highlightColor,
    super.key,
  });

  /// The text to shimmer.
  final String text;

  /// One full sweep duration (source `duration`, default 2.5s).
  final Duration duration;

  /// Text style. Falls back to the ambient [DefaultTextStyle].
  final TextStyle? style;

  /// Horizontal alignment.
  final TextAlign? textAlign;

  /// Resting / trough color. Defaults to [BeuiColors.mutedForeground].
  final Color? baseColor;

  /// Highlight / crest color. Defaults to [BeuiColors.foreground].
  final Color? highlightColor;

  @override
  State<BeuiTextShimmer> createState() => _BeuiTextShimmerState();
}

class _BeuiTextShimmerState extends State<BeuiTextShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(BeuiTextShimmer old) {
    super.didUpdateWidget(old);
    if (widget.duration != old.duration) _controller.duration = widget.duration;
  }

  void _sync() {
    // Movement-free effect: keep looping under reduced motion is unnecessary —
    // hold a static centred highlight instead.
    if (_reduce) {
      if (_controller.isAnimating) _controller.stop();
      // t = 0.375 puts the highlight band's crest at the middle of the text
      // (tile left edge at -W/2 → the 50% stop lands at W/2).
      _controller.value = 0.375;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final base = widget.baseColor ?? colors.mutedForeground;
    final highlight = widget.highlightColor ?? colors.foreground;
    final style = widget.style ?? DefaultTextStyle.of(context).style;

    final text = Text(widget.text, style: style, textAlign: widget.textAlign);

    // RepaintBoundary: the shimmer repaints every frame forever — isolate it so
    // the loop never dirties ancestor layers.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: text,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (rect) => _shimmerShader(rect, base, highlight),
            child: child,
          );
        },
      ),
    );
  }

  /// Builds the swept gradient for [rect] (the text bounds, width `W`).
  ///
  /// The gradient tile is `2W` wide (source `bg-[length:200%_100%]`) with the
  /// band at stops 30% / 50% / 70% of that tile — a highlight `0.8W` wide. The
  /// tile's left edge travels from `-2W` to `+2W` over one cycle (CSS
  /// `background-position: 200% 0 → -200% 0`). The `110deg` CSS angle is the
  /// gradient axis rotated 20° past horizontal ([GradientRotation]).
  ///
  /// [TileMode.repeated] is the source's `background-repeat`, which it never
  /// overrides and which therefore defaults to `repeat`: the `2W` tile repeats
  /// across the text, so a `4W` travel puts **two** highlights through the
  /// glyphs per cycle, back to back. Clamping instead ran a single pass and left
  /// the text flat for half of every cycle — a visible stall the source does not
  /// have. Tiling is seamless because the ramp rests at [base] on both sides of
  /// the band (stops 30% and 70%).
  Shader _shimmerShader(Rect rect, Color base, Color highlight) {
    final t = _controller.value; // 0..1
    final w = rect.width;
    // Tile left edge: lerp(-2W, +2W, t).
    final left = rect.left + (4 * t - 2) * w;
    final tile = Rect.fromLTWH(left, rect.top, 2 * w, rect.height);
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [base, highlight, base],
      stops: const [0.30, 0.50, 0.70],
      tileMode: TileMode.repeated,
      transform: const GradientRotation(20 * math.pi / 180),
    ).createShader(tile);
  }
}
