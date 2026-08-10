import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'button/base.dart'; // BeuiButtonVariant / BeuiButtonSize (public API)

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
///   below into place, each under a `blur(3px)`. The enter rides the
///   [beuiSpringSwap] spring token (source `ROLL_TRANSITION = SPRING_SWAP`);
///   the exit is a 140ms `beuiEaseOut` tween (source `ROLL_EXIT_TRANSITION =
///   {duration: 0.14, ease: EASE_OUT}`).
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
// The roll ENTER rides the [beuiSpringSwap] spring (source `ROLL_TRANSITION =
// SPRING_SWAP`), not this linear window — this is just the AnimatedSwitcher
// forward duration that keeps the entering child mounted while the spring
// settles; the visible enter motion is spring-driven.
const _rollEnterDuration = Duration(milliseconds: 240);
const _rollExitDuration = Duration(
  milliseconds: 140,
); // ROLL_EXIT_TRANSITION 0.14s
const _widthDuration = Duration(milliseconds: 220); // inline `width 220ms`

// Blur radii. Framer `blur(Npx)` → sigma N/2 in Flutter's ImageFilter.
const _swapBlurSigma = 4.0; // SWAP_BLUR blur(8px)
const _rollBlurSigma = 1.5; // ROLL_BLUR blur(3px)

/// Framer Motion's built-in `"easeInOut"` — cubic-bezier(0.42, 0, 0.58, 1).
/// The source's `BLUR_TRANSITION.ease` uses this built-in, NOT the design-token
/// `EASE_IN_OUT` ([beuiEaseInOut]). (The roll variant's exit uses the
/// design-token `EASE_OUT` / [beuiEaseOut] per `ROLL_EXIT_TRANSITION`.)
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
/// and wraps. It is a standalone pressable (the source's `ActionSwapButton` is
/// its own `motion.button`, not the base button): press feedback scales to 0.97
/// on the [beuiSpringPress] token (source `whileTap={{ scale: 0.97 }}`) with no
/// hover lift, and its geometry mirrors the source `SIZE_CLASS` (icon = 40px).
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

  /// Visual style ([BeuiButtonVariant]).
  final BeuiButtonVariant variant;

  /// Size ([BeuiButtonSize]). Drives the source `SIZE_CLASS` geometry.
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
  bool _pressed = false;
  bool _hovered = false;
  bool _focusVisible = false;

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
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final spec = _ActionButtonSizeSpec.of(widget.size);
    final square = widget.size == BeuiButtonSize.icon;
    final palette = _actionButtonPalette(widget.variant, colors, _hovered);

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
        SizedBox(width: spec.gap),
      if (!_iconOnly)
        BeuiActionSwapText(
          value: active.id,
          text: active.label,
          variant: widget.animation,
        ),
    ];

    // Source: `font-medium`, icon `h-4 w-4` (16px), `transition-colors`.
    // The family is carried over from the ambient style: AnimatedDefaultTextStyle
    // *replaces* rather than merges, so a bare TextStyle would silently reset the
    // label to the platform default face.
    final inherited = DefaultTextStyle.of(context).style;
    Widget content = AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 150),
      style: TextStyle(
        fontFamily: inherited.fontFamily,
        fontFamilyFallback: inherited.fontFamilyFallback,
        fontSize: spec.textSize,
        fontWeight: FontWeight.w500,
        color: palette.text,
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: palette.text, size: 16),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
    if (accessibleLabel != null) {
      content = Semantics(
        label: accessibleLabel,
        excludeSemantics: true,
        child: content,
      );
    }

    final radius = BorderRadius.circular(spec.height / 2); // rounded-full

    Widget box = SizedBox(
      height: spec.height,
      width: square ? spec.height : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.ease, // transition-colors
        padding: square ? null : EdgeInsets.symmetric(horizontal: spec.padX),
        decoration: BoxDecoration(
          color: palette.background,
          border: palette.border == null
              ? null
              : Border.all(color: palette.border!),
          borderRadius: radius,
        ),
        child: Center(widthFactor: 1, child: content),
      ),
    );

    // Keyboard focus ring (a11y), matching the base button — the shadow is
    // toggled, not the widget, so focus changes never restructure the subtree.
    box = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: _focusVisible
            ? [
                BoxShadow(color: colors.ring, spreadRadius: 3),
                BoxShadow(color: colors.background, spreadRadius: 1),
              ]
            : null,
      ),
      child: box,
    );

    // Press feedback: scale to 0.97 on the beuiSpringPress token (source
    // `whileTap={{ scale: 0.97 }}` + `transition={SPRING_PRESS}`). No hover
    // lift — the source button never scales up on hover.
    final scaleTarget = reduce ? 1.0 : (_pressed ? 0.97 : 1.0);

    Widget scaled = SingleMotionBuilder(
      value: scaleTarget,
      motion: beuiSpringPress,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) {
          if (_pressed) setState(() => _pressed = false);
        },
        onPointerCancel: (_) {
          if (_pressed) setState(() => _pressed = false);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _advance,
          child: box,
        ),
      ),
    );

    return Semantics(
      button: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _advance();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        child: scaled,
      ),
    );
  }
}

/// Colours for the standalone action-swap button — the port of the source's
/// `VARIANT_CLASS`. No hover *lift*, but the `transition-colors` hover tints are
/// kept.
class _ActionButtonPalette {
  const _ActionButtonPalette({
    required this.background,
    required this.text,
    this.border,
  });
  final Color background;
  final Color text;
  final Color? border;
}

_ActionButtonPalette _actionButtonPalette(
  BeuiButtonVariant variant,
  BeuiColors c,
  bool hovered,
) {
  switch (variant) {
    case BeuiButtonVariant.primary:
      return _ActionButtonPalette(
        background: hovered ? c.primary.withValues(alpha: 0.9) : c.primary,
        text: c.primaryForeground,
      );
    case BeuiButtonVariant.secondary:
      return _ActionButtonPalette(
        background: c.card,
        text: c.foreground,
        border: c.border,
      );
    case BeuiButtonVariant.ghost:
      return _ActionButtonPalette(
        background: hovered
            ? c.primary.withValues(alpha: 0.05)
            : Colors.transparent,
        text: hovered ? c.foreground : c.mutedForeground,
      );
    case BeuiButtonVariant.outline:
      return _ActionButtonPalette(
        background: hovered
            ? c.primary.withValues(alpha: 0.05)
            : Colors.transparent,
        text: c.foreground,
        border: c.border,
      );
  }
}

/// Geometry for the standalone action-swap button — the port of the source's
/// `SIZE_CLASS`. Note `icon` is a 40px square (`h-10 w-10`), NOT the base
/// button's 32px icon.
class _ActionButtonSizeSpec {
  const _ActionButtonSizeSpec({
    required this.height,
    required this.gap,
    required this.padX,
    required this.textSize,
  });
  final double height;
  final double gap;
  final double padX;
  final double textSize;

  static _ActionButtonSizeSpec of(BeuiButtonSize size) => switch (size) {
    BeuiButtonSize.sm => const _ActionButtonSizeSpec(
      height: 32,
      gap: 6,
      padX: 12,
      textSize: 12,
    ),
    BeuiButtonSize.md => const _ActionButtonSizeSpec(
      height: 40,
      gap: 8,
      padX: 16,
      textSize: 14,
    ),
    BeuiButtonSize.lg => const _ActionButtonSizeSpec(
      height: 48,
      gap: 10,
      padX: 20,
      textSize: 16,
    ),
    BeuiButtonSize.icon => const _ActionButtonSizeSpec(
      height: 40,
      gap: 0,
      padX: 0,
      textSize: 14,
    ),
  };
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

/// The per-child transition for the single-element paths (blur / roll). Under
/// reduced motion it collapses to a movement-free crossfade (source's `reduce`
/// branch).
///
/// * **blur** — a blurred cross-fade (scale + fade + blur) driven by the
///   *linear* [AnimatedSwitcher] animation, so the blur stays visible across the
///   whole motion. It is eased internally with Framer's built-in easeInOut,
///   symmetric on enter and exit (source `BLUR_TRANSITION`).
/// * **roll** — delegated to [_RollSwapTransition]. Enter rides the
///   [beuiSpringSwap] spring while exit is a 140ms [beuiEaseOut] tween; the two
///   curves differ (spring vs tween), so a single shared builder can't express
///   both. The dedicated widget latches direction off the AnimatedSwitcher
///   controller instead of guessing it per frame.
Widget _swapTransition(
  Widget child,
  Animation<double> animation,
  BeuiActionSwapVariant core,
  bool reduce, {
  bool isIcon = false,
  double textTravel = 18,
}) {
  if (reduce) return FadeTransition(opacity: animation, child: child);

  if (core == BeuiActionSwapVariant.roll) {
    // Icon travel is ±12px (source `ICON_VARIANTS.roll` y: ±12); text rolls by
    // ~115% of the line box (source `TEXT_VARIANTS.roll` y: ±90%, approximated
    // by [textTravel]).
    return _RollSwapTransition(
      animation: animation,
      travel: isIcon ? 12.0 : textTravel,
      child: child,
    );
  }

  // blur
  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final t = animation.value; // linear 0..1
      // Source BLUR_TRANSITION ease: Framer's built-in easeInOut.
      final eased = _framerEaseInOut.transform(t);
      final opacity = eased;
      final blur = (1 - t) * _swapBlurSigma;
      // text scales 0.94→1; icon scales 0.25→1 (source ICON_VARIANTS).
      final from = isIcon ? 0.25 : 0.94;
      final scale = from + (1 - from) * eased;

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
      return Opacity(opacity: opacity.clamp(0.0, 1.0), child: result);
    },
  );
}

/// The roll single-element transition. [AnimatedSwitcher] only ever *builds* a
/// transition for an entering child (its controller starts at 0, forward), so
/// every instance begins life entering: it springs its content up from [travel]
/// to rest on the [beuiSpringSwap] token (source `ROLL_TRANSITION =
/// SPRING_SWAP`), fading and de-blurring as it settles — the same
/// spring-progress pattern the cascade path uses.
///
/// When the child later becomes outgoing the switcher reverses its controller; a
/// status listener latches that and swaps to the exit: a 140ms [beuiEaseOut]
/// tween that rolls the content up and out the top while it fades and blurs
/// (source `ROLL_EXIT_TRANSITION = {duration: 0.14, ease: EASE_OUT}`). Latching
/// once on the reverse status is reliable because a fresh entry is never
/// exiting — no per-frame direction guessing needed.
class _RollSwapTransition extends StatefulWidget {
  const _RollSwapTransition({
    required this.animation,
    required this.travel,
    required this.child,
  });

  final Animation<double> animation;
  final double travel;
  final Widget child;

  @override
  State<_RollSwapTransition> createState() => _RollSwapTransitionState();
}

class _RollSwapTransitionState extends State<_RollSwapTransition> {
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_onStatus);
    // A fresh entry starts forward; guard the rare case it is already reversing.
    _exiting = widget.animation.status == AnimationStatus.reverse;
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse && !_exiting) {
      setState(() => _exiting = true);
    }
  }

  @override
  void didUpdateWidget(_RollSwapTransition old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation) {
      old.animation.removeStatusListener(_onStatus);
      widget.animation.addStatusListener(_onStatus);
      _exiting = widget.animation.status == AnimationStatus.reverse;
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final travel = widget.travel;

    if (!_exiting) {
      // Enter: spring the content up from +travel to rest (beuiSpringSwap).
      // Opacity and blur ride the spring's own progress.
      return SingleMotionBuilder(
        value: 0.0,
        from: travel,
        motion: beuiSpringSwap,
        builder: (context, dy, child) {
          final p = (1 - dy / travel).clamp(0.0, 1.0);
          Widget result = child!;
          final sigma = (1 - p) * _rollBlurSigma;
          if (sigma > 0.05) {
            result = ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.decal,
              ),
              child: result,
            );
          }
          return Opacity(
            opacity: p,
            child: Transform.translate(offset: Offset(0, dy), child: result),
          );
        },
        child: widget.child,
      );
    }

    // Exit: a 140ms EASE_OUT tween driven by the reverse animation (1→0). The
    // content rolls up and out the top (−travel) while it fades and blurs.
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final t = widget.animation.value; // 1 → 0 during reverse
        final q = beuiEaseOut.transform(1 - t); // eased exit progress 0 → 1
        final dy = -travel * q;
        final opacity = 1 - q;
        final sigma = _rollBlurSigma * q;
        Widget result = child!;
        if (sigma > 0.05) {
          result = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: sigma,
              sigmaY: sigma,
              tileMode: TileMode.decal,
            ),
            child: result,
          );
        }
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, dy), child: result),
        );
      },
      child: widget.child,
    );
  }
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
