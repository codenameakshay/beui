import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../tokens/motion.dart';
import '_engine.dart';
import 'button/base.dart';

/// The transition used when an [BeuiActionSwapText] / [BeuiActionSwapIcon] /
/// [BeuiActionSwapButton] swaps its content — the Flutter port of the source's
/// `ActionSwapAnimation` (`blur` / `roll` / `cascade`).
///
/// All three ship; none is a subset. Each maps to a distinct mechanic:
///
/// * [blur] — a blurred cross-fade. The outgoing content fades + scales down
///   under a `blur(8px)` while the incoming content fades + scales up from a
///   blur. Framer's built-in `easeInOut` (cubic-bezier(0.42, 0, 0.58, 1)) over
///   200ms (source `BLUR_TRANSITION`).
/// * [roll] — the old content rolls up and out while the new rolls up from
///   below into place, each under a `blur(6px)`. 240ms `beuiEaseOut` enter,
///   180ms Framer-`easeInOut` exit (source `ROLL_TRANSITION`).
/// * [cascade] — a per-letter slot roll (text only): each glyph rides the
///   [beuiSpringSwap] token, released staggered left-to-right, reusing the
///   StatefulButton's `_CascadeText` mechanic. Non-text content (icons) and
///   reduced motion fall back to [roll], matching the source.
enum BeuiActionSwapVariant {
  /// Blurred cross-fade (source `blur`).
  blur,

  /// Old rolls out, new rolls in (source `roll`).
  roll,

  /// Per-letter slot roll (text only; falls back to [roll] elsewhere).
  cascade,
}

// Source timing tokens (action-swap.tsx).
const _blurDuration = Duration(milliseconds: 200); // BLUR_TRANSITION 0.2s
const _rollEnterDuration = Duration(milliseconds: 240); // ROLL_TRANSITION 0.24s
const _rollExitDuration = Duration(milliseconds: 180); // roll exit 0.18s
const _widthDuration = Duration(milliseconds: 220); // inline `width 220ms`

// Blur radii. Framer `blur(Npx)` ≈ sigma N/2 in Flutter's ImageFilter.
const _swapBlurSigma = 4.0; // SWAP_BLUR blur(8px)
const _rollBlurSigma = 3.0; // ROLL_BLUR blur(6px)

/// Framer Motion's built-in `"easeInOut"` — cubic-bezier(0.42, 0, 0.58, 1).
/// The source's `BLUR_TRANSITION.ease` and the roll variant's exit ease use
/// this built-in, NOT the design-token `EASE_IN_OUT` ([beuiEaseInOut]).
const _framerEaseInOut = Cubic(0.42, 0, 0.58, 1);

/// The [BeuiActionSwapVariant] that drives single-element content (icons, and
/// the non-cascade text path). [BeuiActionSwapVariant.cascade] has no
/// single-element form, so it collapses to [BeuiActionSwapVariant.roll] —
/// mirroring the source's `coreAnimation` fallback.
BeuiActionSwapVariant _core(BeuiActionSwapVariant v) =>
    v == BeuiActionSwapVariant.cascade ? BeuiActionSwapVariant.roll : v;

/// A single swappable action — the Flutter port of the source's
/// `ActionSwapItem`.
@immutable
class BeuiActionSwapItem {
  /// Creates a swap item.
  const BeuiActionSwapItem({
    required this.id,
    required this.label,
    this.icon,
    this.semanticLabel,
  });

  /// Stable identity used to key the transition (the swap fires when [id]
  /// changes).
  final String id;

  /// The text shown for this item.
  final String label;

  /// Optional leading glyph for this item.
  final IconData? icon;

  /// Accessibility label — falls back to [label] for icon-only buttons.
  final String? semanticLabel;
}

// ---------------------------------------------------------------------------
// Text swap
// ---------------------------------------------------------------------------

/// Swaps a single line of text with a [BeuiActionSwapVariant] transition,
/// animating its width over ~220ms so the swap never snaps in size — the
/// Flutter port of the source's `ActionSwapText`.
///
/// The width animation is an eased width tween ([AnimatedSize] with
/// [beuiEaseOut]), matching the source's inline `transition: width 220ms
/// EASE_OUT_CSS`; it is deliberately *not* a spring (the spec calls this out).
class BeuiActionSwapText extends StatelessWidget {
  /// Creates a text swap.
  const BeuiActionSwapText({
    required this.value,
    required this.text,
    this.variant = BeuiActionSwapVariant.blur,
    this.style,
    super.key,
  });

  /// Identity of the current [text]; changing it triggers the transition.
  final String value;

  /// The text to show.
  final String text;

  /// How to animate the swap.
  final BeuiActionSwapVariant variant;

  /// Optional text style override; defaults to the ambient [DefaultTextStyle].
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final style = this.style ?? DefaultTextStyle.of(context).style;

    // Cascade needs per-letter splitting; reduced motion drops it to a
    // movement-free crossfade via the roll path's reduce branch.
    if (variant == BeuiActionSwapVariant.cascade && !reduce) {
      return _AnimatedWidth(
        child: ClipRect(child: _CascadeText(text, style: style)),
      );
    }

    return _AnimatedWidth(
      child: ClipRect(
        child: AnimatedSwitcher(
          duration: _core(variant) == BeuiActionSwapVariant.blur
              ? _blurDuration
              : _rollEnterDuration,
          reverseDuration: _core(variant) == BeuiActionSwapVariant.blur
              ? _blurDuration
              : _rollExitDuration,
          switchInCurve: Curves.linear,
          switchOutCurve: Curves.linear,
          // popLayout-style: the two strings overlap rather than reflow, so the
          // outgoing text doesn't shove the incoming one sideways.
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.centerLeft,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) => _swapTransition(
            child,
            animation,
            _core(variant),
            reduce,
            // ≈115% of the line box, so the text clears the slot as it rolls.
            textTravel: (style.fontSize ?? 14) * 1.35,
          ),
          child: Text(
            text,
            key: ValueKey(value),
            style: style,
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Icon swap
// ---------------------------------------------------------------------------

/// Swaps a single icon with a [BeuiActionSwapVariant] transition — the Flutter
/// port of the source's `ActionSwapIcon`. Icons are single elements, so
/// [BeuiActionSwapVariant.cascade] collapses to [BeuiActionSwapVariant.roll].
class BeuiActionSwapIcon extends StatelessWidget {
  /// Creates an icon swap.
  const BeuiActionSwapIcon({
    required this.value,
    required this.icon,
    this.variant = BeuiActionSwapVariant.blur,
    this.size = 16,
    super.key,
  });

  /// Identity of the current [icon]; changing it triggers the transition.
  final String value;

  /// The glyph to show.
  final IconData icon;

  /// How to animate the swap.
  final BeuiActionSwapVariant variant;

  /// Icon size in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final core = _core(variant);
    // Clipped like the source's `overflow-hidden` cell, so a rolling icon never
    // paints outside its slot.
    return ClipRect(
      child: AnimatedSwitcher(
        duration: core == BeuiActionSwapVariant.blur
            ? _blurDuration
            : _rollEnterDuration,
        reverseDuration: core == BeuiActionSwapVariant.blur
            ? _blurDuration
            : _rollExitDuration,
        switchInCurve: Curves.linear,
        switchOutCurve: Curves.linear,
        // popLayout: outgoing + incoming icons share one cell.
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.center,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) =>
            _swapTransition(child, animation, core, reduce, isIcon: true),
        child: Icon(icon, key: ValueKey(value), size: size),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Button
// ---------------------------------------------------------------------------

/// A button that cycles through [items], swapping its label and icon with a
/// [BeuiActionSwapVariant] transition on each tap — the Flutter port of the
/// source's `ActionSwapButton`.
///
/// Controlled + uncontrolled, mirroring the source: pass [value] + [onChanged]
/// to control it, or omit [value] for internal state seeded from
/// [defaultValue]. With [cycle] on (default) each tap advances to the next item
/// and wraps. Press feedback uses [beuiSpringPress] via the underlying
/// [BeuiButton].
class BeuiActionSwapButton extends StatefulWidget {
  /// Creates an action-swap button.
  const BeuiActionSwapButton({
    required this.items,
    this.value,
    this.defaultValue,
    this.onChanged,
    this.variant = BeuiButtonVariant.secondary,
    this.size = BeuiButtonSize.md,
    this.animation = BeuiActionSwapVariant.blur,
    this.iconOnly = false,
    this.cycle = true,
    this.onPressed,
    super.key,
  });

  /// The items to cycle through. Must be non-empty.
  final List<BeuiActionSwapItem> items;

  /// Active item id (controlled). When null the button is uncontrolled.
  final String? value;

  /// Initial active id when uncontrolled. Defaults to the first item.
  final String? defaultValue;

  /// Called with the next id (and item) when the button advances.
  final void Function(String id, BeuiActionSwapItem item)? onChanged;

  /// Visual style of the underlying [BeuiButton].
  final BeuiButtonVariant variant;

  /// Size of the underlying [BeuiButton].
  final BeuiButtonSize size;

  /// The swap transition.
  final BeuiActionSwapVariant animation;

  /// Show only the icon (no label). Defaults to true for [BeuiButtonSize.icon].
  final bool iconOnly;

  /// Advance to the next item on tap and wrap around. Off makes the button a
  /// pure display surface (drive it via [value] instead).
  final bool cycle;

  /// Extra tap callback, fired in addition to the cycle advance.
  final VoidCallback? onPressed;

  @override
  State<BeuiActionSwapButton> createState() => _BeuiActionSwapButtonState();
}

class _BeuiActionSwapButtonState extends State<BeuiActionSwapButton> {
  late String _internal = widget.defaultValue ?? widget.items.first.id;

  String get _current => widget.value ?? _internal;

  bool get _iconOnly => widget.iconOnly || widget.size == BeuiButtonSize.icon;

  int get _activeIndex {
    final i = widget.items.indexWhere((it) => it.id == _current);
    return i < 0 ? 0 : i;
  }

  void _advance() {
    widget.onPressed?.call();
    if (!widget.cycle || widget.items.isEmpty) return;
    final next = widget.items[(_activeIndex + 1) % widget.items.length];
    if (widget.value == null) setState(() => _internal = next.id);
    widget.onChanged?.call(next.id, next);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final active = widget.items[_activeIndex];
    final hasIcon = widget.items.any((it) => it.icon != null);

    final accessibleLabel =
        active.semanticLabel ?? (_iconOnly ? active.label : null);

    final children = <Widget>[
      if (hasIcon && active.icon != null)
        BeuiActionSwapIcon(
          value: active.id,
          icon: active.icon!,
          variant: widget.animation,
        ),
      if (hasIcon && active.icon != null && !_iconOnly)
        const SizedBox(width: 8),
      if (!_iconOnly)
        BeuiActionSwapText(
          value: active.id,
          text: active.label,
          variant: widget.animation,
        ),
    ];

    Widget content = Row(mainAxisSize: MainAxisSize.min, children: children);
    if (accessibleLabel != null) {
      content = Semantics(
        label: accessibleLabel,
        excludeSemantics: true,
        child: content,
      );
    }

    return BeuiButton(
      onPressed: _advance,
      variant: widget.variant,
      size: widget.size,
      child: content,
    );
  }
}

// ---------------------------------------------------------------------------
// Width wrapper
// ---------------------------------------------------------------------------

/// Animates the content's *width* over [_widthDuration] with [beuiEaseOut] so
/// swaps that change label length don't snap. Height hugs the content; this is
/// the analogue of the source's inline `transition: width 220ms EASE_OUT_CSS`.
/// Under reduced motion the width change is a movement, so it snaps instead of
/// animating.
class _AnimatedWidth extends StatelessWidget {
  const _AnimatedWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Reduced motion: the width change is a movement, so it snaps. No
    // AnimatedSize at all — a zero-duration AnimatedSize re-dirties itself
    // during its own layout pass and asserts.
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSize(
      duration: _widthDuration,
      curve: beuiEaseOut,
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared single-element transition (blur / roll)
// ---------------------------------------------------------------------------

/// The per-child transition for the single-element paths. Driven by a *linear*
/// [AnimatedSwitcher] animation (so the blur stays visible across the whole
/// motion); the fade/scale/translate are eased internally. Under reduced
/// motion it collapses to a movement-free crossfade (source's `reduce` branch).
///
/// [AnimatedSwitcher] runs the same builder for entering (animation 0→1) and
/// exiting (1→0) children. Direction is read off the status **inside** the
/// builder, per frame — capturing it once is unreliable: when the exiting
/// child's transition is first built its controller can still report
/// `completed` (the reverse hasn't started), which would mis-detect the old
/// child as entering and roll it the wrong way (out the bottom instead of the
/// top). During the visible motion the status is reliably forward / reverse.
Widget _swapTransition(
  Widget child,
  Animation<double> animation,
  BeuiActionSwapVariant core,
  bool reduce, {
  bool isIcon = false,
  double textTravel = 18,
}) {
  if (reduce) return FadeTransition(opacity: animation, child: child);

  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final entering = animation.status != AnimationStatus.reverse;
      final t = animation.value; // linear 0..1
      late final double opacity;
      late final double blur;
      var dy = 0.0;
      var scale = 1.0;

      if (core == BeuiActionSwapVariant.blur) {
        // Source BLUR_TRANSITION ease: Framer's built-in easeInOut.
        final eased = _framerEaseInOut.transform(t);
        opacity = eased;
        blur = (1 - t) * _swapBlurSigma;
        // text scales 0.94→1; icon scales 0.25→1 (source ICON_VARIANTS).
        final from = isIcon ? 0.25 : 0.94;
        scale = from + (1 - from) * eased;
      } else {
        // roll
        opacity = entering
            ? beuiEaseOut.transform(t)
            : t; // exit fade is linear-ish under easeInOut switcher
        blur = (1 - t) * _rollBlurSigma;
        // text: enter from +115%, exit to -115% of the line box (source
        // TEXT_VARIANTS.roll, scaled by font size); icon: ±16px.
        final travel = isIcon ? 16.0 : textTravel;
        // Enter eases EASE_OUT; exit eases Framer's built-in easeInOut.
        final eased = entering
            ? beuiEaseOut.transform(t)
            : _framerEaseInOut.transform(t);
        // entering rises from below (+); exiting rises up and out the top (−).
        dy = entering ? (1 - eased) * travel : (1 - eased) * -travel;
      }

      Widget result = child;
      if (blur > 0.05) {
        result = ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: blur,
            sigmaY: blur,
            tileMode: TileMode.decal,
          ),
          child: result,
        );
      }
      if (scale != 1.0) {
        result = Transform.scale(scale: scale, child: result);
      }
      if (dy != 0.0) {
        result = Transform.translate(offset: Offset(0, dy), child: result);
      }
      return Opacity(opacity: opacity.clamp(0.0, 1.0), child: result);
    },
  );
}

// ---------------------------------------------------------------------------
// Cascade text (per-letter slot roll)
// ---------------------------------------------------------------------------

/// Per-letter slot cascade — the same mechanic as the StatefulButton's
/// `_CascadeText` (source `CASCADE_LETTER_VARIANTS`). On a text change the old
/// letters roll up and out (blurring) while the new letters roll up from below
/// into place, staggered left-to-right and clipped to one line.
class _CascadeText extends StatefulWidget {
  const _CascadeText(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_CascadeText> createState() => _CascadeTextState();
}

class _CascadeTextState extends State<_CascadeText>
    with SingleTickerProviderStateMixin {
  static const int _staggerMs = 25; // source CASCADE_STAGGER 0.025s
  static const int _enterMs = 360; // covers the SPRING_SWAP settle
  static const int _exitMs = 160; // source exit 0.16s
  static const double _blur = 3; // source ROLL_BLUR blur(6px) → sigma 3

  late final AnimationController _controller;
  late String _current = widget.text;
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
  void didUpdateWidget(_CascadeText old) {
    super.didUpdateWidget(old);
    if (widget.text != _current) {
      _previous = _current;
      _current = widget.text;
      _controller
        ..duration = Duration(milliseconds: _durationMs(_current))
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;

    // At rest: plain crisp text, no per-letter overhead.
    if (_previous == null) {
      return Text(_current, style: style, maxLines: 1, softWrap: false);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final totalMs = _controller.duration!.inMilliseconds;
        final roll = (style.fontSize ?? 14) * 1.15; // ~105% of a line
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerLeft,
          children: [
            // Exiting text — positioned, so it doesn't drive the slot width.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: _letters(
                _previous!,
                t,
                totalMs,
                roll,
                style,
                exiting: true,
              ),
            ),
            // Entering text — sizes the slot to the new label immediately.
            _letters(_current, t, totalMs, roll, style, exiting: false),
          ],
        );
      },
    );
  }

  Widget _letters(
    String text,
    double t,
    int totalMs,
    double roll,
    TextStyle style, {
    required bool exiting,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < text.length; i++)
          _letter(text[i], i, t, totalMs, roll, style, exiting: exiting),
      ],
    );
  }

  Widget _letter(
    String char,
    int i,
    double t,
    int totalMs,
    double roll,
    TextStyle style, {
    required bool exiting,
  }) {
    if (exiting) {
      // Exit: 160ms EASE_OUT tween at half the enter stagger (source
      // `delay * 0.5`) — rolls up and out, fading and blurring.
      final start = (i * _staggerMs * 0.5) / totalMs;
      final p = ((t - start) / (_exitMs / totalMs)).clamp(0.0, 1.0);
      final e = beuiEaseOut.transform(p);
      return _glyph(
        char,
        style,
        dy: -e * roll, // roll up and out
        opacity: 1 - e,
        blur: e * _blur,
      );
    }

    // Enter: the SPRING_SWAP token (source CASCADE_LETTER_VARIANTS), released
    // once the shared clock crosses the letter's `index × 25ms` stagger —
    // opacity and blur ride the spring's own progress.
    final released = t * totalMs >= i * _staggerMs;
    return SingleMotionBuilder(
      value: released ? 0.0 : roll,
      from: roll,
      motion: beuiSpringSwap,
      builder: (context, dy, child) {
        final p = (1 - dy / roll).clamp(0.0, 1.0);
        Widget glyph = child!;
        final sigma = (1 - p) * _blur;
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
        return Opacity(
          opacity: p,
          child: Transform.translate(offset: Offset(0, dy), child: glyph),
        );
      },
      child: Text(char, style: style, maxLines: 1, softWrap: false),
    );
  }

  Widget _glyph(
    String char,
    TextStyle style, {
    required double dy,
    required double opacity,
    required double blur,
  }) {
    Widget glyph = Text(char, style: style, maxLines: 1, softWrap: false);
    if (blur > 0.05) {
      glyph = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
          tileMode: TileMode.decal,
        ),
        child: glyph,
      );
    }
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(offset: Offset(0, dy), child: glyph),
    );
  }
}
