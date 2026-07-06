import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';

/// A continuous gradient shimmer swept across text — the Flutter port of beUI's
/// `text-shimmer`.
///
/// A bright highlight band slides through the text from right to left, on an
/// endless loop. Mirrors the source's `linear-gradient(110deg,
/// muted-foreground 30%, foreground 50%, muted-foreground 70%)` over a `200%`
/// background swept from `200% 0` to `-200% 0` — so the resting text is
/// [BeuiColors.mutedForeground] and the moving highlight is
/// [BeuiColors.foreground].
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
      _controller.value = 0.5;
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

    return AnimatedBuilder(
      animation: _controller,
      child: text,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => _shimmerShader(rect, base, highlight),
          child: child,
        );
      },
    );
  }

  /// Builds the swept gradient for [rect]. The gradient tile is `200%` of the
  /// text width (source `bg-[length:200%_100%]`) and its position runs from
  /// `200% 0` to `-200% 0` — a 4×-width travel — at a `110deg` angle. The band
  /// is `muted-foreground 30% → foreground 50% → muted-foreground 70%`.
  Shader _shimmerShader(Rect rect, Color base, Color highlight) {
    final t = _controller.value; // 0..1
    // background-position 200% → -200% across the 200%-wide tile: translate the
    // gradient by [+2w .. -2w] in CSS terms. Map to [begin/end] offsets.
    final w = rect.width;
    final shift = (2 - 4 * t) * w; // +2w → -2w
    // 110deg: mostly horizontal with a slight downward slope.
    const angle = 110 * math.pi / 180;
    final dx = math.cos(angle);
    final dy = math.sin(angle);
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [base, base, highlight, base, base],
      stops: const [0.0, 0.30, 0.50, 0.70, 1.0],
      transform: _ShimmerTransform(shift, dx, dy),
    ).createShader(rect);
  }
}

/// Translates the shimmer gradient horizontally (with a slight vertical slope to
/// approximate the source's 110deg angle) by [shift] logical pixels.
class _ShimmerTransform extends GradientTransform {
  const _ShimmerTransform(this.shift, this.dx, this.dy);

  final double shift;
  final double dx;
  final double dy;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    // Slope component is gentle — scale the vertical translate down so tall
    // glyphs don't push the band off the line.
    return Matrix4.translationValues(shift * dx, shift * dy * 0.15, 0);
  }
}
