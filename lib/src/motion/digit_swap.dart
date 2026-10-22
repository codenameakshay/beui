import 'package:flutter/widgets.dart';

import '../tokens/motion.dart';

/// Direction the next glyph enters from in a [BeuiDigitSwap].
enum BeuiDigitSwapDirection {
  /// New glyphs rise from below (source `"up"`).
  up,

  /// New glyphs drop from above (source `"down"`).
  down,
}

/// Fixed-slot digits and mask glyphs that roll on change — the Flutter port of
/// beUI's `digit-swap`.
///
/// Each character sits in its own slot. Digits use a fixed `1ch` width so rolls
/// never jitter; other glyphs keep their natural width. Changing [value]
/// (or [animationKey]) rolls only the glyphs that change. Reduced motion
/// replaces the vertical roll with a short fade.
///
/// Screen readers hear the full [value] string, never the rolling columns.
class BeuiDigitSwap extends StatelessWidget {
  /// Creates a digit-swap readout for [value].
  const BeuiDigitSwap({
    required this.value,
    this.animationKey,
    this.direction = BeuiDigitSwapDirection.up,
    this.duration = const Duration(milliseconds: 180),
    this.stagger = const Duration(milliseconds: 6),
    this.suffixLength = 0,
    this.style,
    this.glyphStyle,
    this.suffixStyle,
    super.key,
  });

  /// Numeric or masked value rendered in fixed character slots.
  final Object value;

  /// Replays every glyph when the printed value itself contains unchanged
  /// characters (source `animationKey`).
  final Object? animationKey;

  /// Direction the next glyph enters from.
  final BeuiDigitSwapDirection direction;

  /// Per-glyph transition duration (source default `0.18s`).
  final Duration duration;

  /// Delay between neighbouring glyphs (source default `0.006s`).
  final Duration stagger;

  /// Number of final characters that receive [suffixStyle].
  final int suffixLength;

  /// Base text style. Falls back to the ambient [DefaultTextStyle].
  final TextStyle? style;

  /// Style applied to every visible glyph.
  final TextStyle? glyphStyle;

  /// Style applied to the last [suffixLength] characters, on top of [glyphStyle].
  final TextStyle? suffixStyle;

  @override
  Widget build(BuildContext context) {
    final text = value.toString();
    final reduce = MediaQuery.disableAnimationsOf(context);
    final base = (style ?? DefaultTextStyle.of(context).style).merge(
      glyphStyle,
    );
    final suffixStart = (text.length - suffixLength.clamp(0, text.length))
        .clamp(0, text.length);
    final fadeDuration = reduce
        ? Duration(milliseconds: duration.inMilliseconds.clamp(0, 120))
        : duration;
    final enterDy = direction == BeuiDigitSwapDirection.up ? 0.45 : -0.45;

    return Semantics(
      label: text,
      excludeSemantics: true,
      child: DefaultTextStyle(
        style: base,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            for (var i = 0; i < text.length; i++)
              _GlyphSlot(
                character: text[i],
                replayKey: animationKey,
                delay: reduce ? Duration.zero : stagger * i,
                duration: fadeDuration,
                enterDy: reduce ? 0 : enterDy,
                style: i >= suffixStart ? base.merge(suffixStyle) : base,
              ),
          ],
        ),
      ),
    );
  }
}

class _GlyphSlot extends StatelessWidget {
  const _GlyphSlot({
    required this.character,
    required this.replayKey,
    required this.delay,
    required this.duration,
    required this.enterDy,
    required this.style,
  });

  final String character;
  final Object? replayKey;
  final Duration delay;
  final Duration duration;
  final double enterDy;
  final TextStyle style;

  bool get _isDigit =>
      character.codeUnitAt(0) >= 48 && character.codeUnitAt(0) <= 57;

  @override
  Widget build(BuildContext context) {
    final fontSize =
        style.fontSize ?? DefaultTextStyle.of(context).style.fontSize ?? 14;
    if (character == ' ') {
      return SizedBox(width: fontSize * 0.42); // ~0.7ch
    }
    final slotWidth = _isDigit ? fontSize * 0.6 : null; // ~1ch
    final slotHeight = fontSize * 1.1;
    final switcher = AnimatedSwitcher(
      duration: duration,
      switchInCurve: beuiEaseOut,
      switchOutCurve: beuiEaseOut,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: Offset(0, enterDy),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: enterDy == 0
              ? child
              : SlideTransition(position: offset, child: child),
        );
      },
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        children: [...previous, ?current],
      ),
      child: Text(
        character,
        key: ValueKey<Object?>('${replayKey ?? ''}-$character'),
        style: style.copyWith(
          height: 1.1,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      ),
    );

    return SizedBox(
      width: slotWidth,
      height: slotHeight,
      child: ClipRect(
        child: delay == Duration.zero
            ? switcher
            : _Delayed(delay: delay, child: switcher),
      ),
    );
  }
}

/// Holds the previous glyph until [delay] elapses, matching source stagger.
class _Delayed extends StatefulWidget {
  const _Delayed({required this.delay, required this.child});
  final Duration delay;
  final Widget child;

  @override
  State<_Delayed> createState() => _DelayedState();
}

class _DelayedState extends State<_Delayed> {
  Widget? _shown;

  @override
  void initState() {
    super.initState();
    _shown = widget.child;
  }

  @override
  void didUpdateWidget(_Delayed old) {
    super.didUpdateWidget(old);
    if (old.child.key != widget.child.key) {
      Future<void>.delayed(widget.delay, () {
        if (mounted) setState(() => _shown = widget.child);
      });
    }
  }

  @override
  Widget build(BuildContext context) => _shown ?? widget.child;
}
