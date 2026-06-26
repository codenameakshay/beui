import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// Heavy, deliberate thumb travel — a one-to-one port of the source
/// `switch.tsx` `THUMB_SPRING`. High mass keeps the glide weighty without
/// wobble. This is a **component-local** spring (sanctioned by the source's
/// `AGENTS.md` for genuinely component-specific tuning) and is intentionally
/// NOT one of the five shared `beuiSpring*` tokens — a switch thumb must feel
/// heavier than a generic layout glide.
const _thumbSpring = SpringMotion(
  SpringDescription(mass: 4, stiffness: 800, damping: 80),
);

/// Test handle on the thumb circle, so motion tests can read its position.
@visibleForTesting
const beuiSwitchThumbKey = ValueKey<String>('beui_switch_thumb');

/// Optional style overrides for [BeuiSwitch]. Any field left null resolves from
/// the ambient [BeuiColors] theme extension (or sensible defaults), so the
/// common case needs no style at all. Mirrors the source's
/// `className`-via-tokens approach within the port's "no arbitrary overrides"
/// rule (see `docs/PORTING_SPEC.md` §6).
@immutable
class BeuiSwitchStyle {
  /// Creates a set of [BeuiSwitch] overrides.
  const BeuiSwitchStyle({
    this.trackOnColor,
    this.trackOffColor,
    this.thumbColor,
    this.width,
    this.height,
    this.thumbSize,
  });

  /// Track fill when on. Defaults to `BeuiColors.primary`.
  final Color? trackOnColor;

  /// Track fill when off. Defaults to `BeuiColors.mutedForeground` at 60% alpha.
  final Color? trackOffColor;

  /// Thumb fill. Defaults to `BeuiColors.background`.
  final Color? thumbColor;

  /// Track width. Defaults to 48.
  final double? width;

  /// Track height. Defaults to 28.
  final double? height;

  /// Thumb diameter. Defaults to 20.
  final double? thumbSize;

  /// Returns a copy with the given fields replaced.
  BeuiSwitchStyle copyWith({
    Color? trackOnColor,
    Color? trackOffColor,
    Color? thumbColor,
    double? width,
    double? height,
    double? thumbSize,
  }) {
    return BeuiSwitchStyle(
      trackOnColor: trackOnColor ?? this.trackOnColor,
      trackOffColor: trackOffColor ?? this.trackOffColor,
      thumbColor: thumbColor ?? this.thumbColor,
      width: width ?? this.width,
      height: height ?? this.height,
      thumbSize: thumbSize ?? this.thumbSize,
    );
  }
}

/// A spring-driven toggle — the Flutter port of beUI's `switch`.
///
/// The thumb glides under a heavy spring ([_thumbSpring]); the track cross-fades
/// its colour over 200ms. On pointer press the thumb squishes; pressing a
/// disabled switch plays a short shake. Keyboard focus shows a focus-visible
/// ring.
///
/// **Controlled only** (matching the source and the `AGENTS.md` rule that simple
/// toggles are controlled-only): pass [value] and handle [onChanged]; there is
/// no internal state.
///
/// Reduced motion (via the central [motionFor] resolver) snaps the thumb with no
/// glide, drops the press squish, and skips the disabled shake — while the track
/// colour transition, an opacity change, is kept.
class BeuiSwitch extends StatefulWidget {
  /// Creates a switch. [value] and [onChanged] are required (controlled-only).
  const BeuiSwitch({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.label,
    this.style,
    super.key,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the toggled value when the user activates the switch.
  final ValueChanged<bool> onChanged;

  /// Whether the switch responds to input. A disabled switch is dimmed, unfocusable,
  /// and plays a shake on press instead of toggling.
  final bool enabled;

  /// Optional label rendered after the switch; tapping it toggles the switch.
  final String? label;

  /// Optional visual overrides.
  final BeuiSwitchStyle? style;

  @override
  State<BeuiSwitch> createState() => _BeuiSwitchState();
}

class _BeuiSwitchState extends State<BeuiSwitch>
    with SingleTickerProviderStateMixin {
  late final FocusNode _focusNode = FocusNode();
  bool _pressed = false;
  bool _focusVisible = false;

  // Disabled-press shake: a fixed keyframe sequence (x: 0 → -2 → 2 → -1 → 0),
  // not a target spring — so it is driven by a TweenSequence controller rather
  // than `motor`, mirroring the source's `animate(thumb, {x: [...]})`. A leading
  // flat segment reproduces the source's 0.2s delay before the 0.6s shake.
  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  late final Animation<double> _shake = TweenSequence<double>(<TweenSequenceItem<double>>[
    TweenSequenceItem(tween: ConstantTween<double>(0), weight: 200),
    TweenSequenceItem(tween: Tween<double>(begin: 0, end: -2).chain(CurveTween(curve: Curves.easeInOut)), weight: 150),
    TweenSequenceItem(tween: Tween<double>(begin: -2, end: 2).chain(CurveTween(curve: Curves.easeInOut)), weight: 150),
    TweenSequenceItem(tween: Tween<double>(begin: 2, end: -1).chain(CurveTween(curve: Curves.easeInOut)), weight: 150),
    TweenSequenceItem(tween: Tween<double>(begin: -1, end: 0).chain(CurveTween(curve: Curves.easeInOut)), weight: 150),
  ]).animate(_shakeController);

  @override
  void dispose() {
    _shakeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!widget.enabled) return;
    widget.onChanged(!widget.value);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled) {
      // Disabled: shake instead of toggle (skipped under reduced motion).
      if (!MediaQuery.disableAnimationsOf(context)) {
        _shakeController.forward(from: 0);
      }
      return;
    }
    setState(() => _pressed = true);
  }

  void _endPress([PointerEvent? _]) {
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);
    final style = widget.style;

    final reduce = MediaQuery.disableAnimationsOf(context);
    final value = widget.value;
    final enabled = widget.enabled;

    final width = style?.width ?? 48.0;
    final height = style?.height ?? 28.0;
    final thumbSize = style?.thumbSize ?? 20.0;
    final pad = (height - thumbSize) / 2;

    final onColor = style?.trackOnColor ?? colors.primary;
    final offColor =
        style?.trackOffColor ?? colors.mutedForeground.withValues(alpha: 0.6);
    final thumbColor = style?.thumbColor ?? colors.background;

    // Squish only from a real pointer press (keyboard activation never sets
    // `_pressed`), matching the source's pointer-vs-keyboard gate.
    final squish = _pressed && enabled && !reduce;

    // Ask the central resolver whether the thumb may move. NOTE: `motor`'s
    // NoMotion *freezes at the source value* — it does not snap to the target —
    // so a discrete position transition cannot pipe NoMotion into a builder.
    // When the resolver drops movement we therefore render the thumb directly
    // at its target (instant, no glide), the correct "reduced motion" result.
    final thumbMotion = motionFor(context, _thumbSpring, isMovement: true);
    final snapThumb = thumbMotion is NoMotion;
    final targetT = value ? 1.0 : 0.0;

    final thumb = AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(reduce ? 0 : _shake.value, 0),
        child: child,
      ),
      child: Container(
        key: beuiSwitchThumbKey,
        width: thumbSize,
        height: thumbSize,
        decoration: BoxDecoration(
          color: thumbColor,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2)),
            BoxShadow(color: Color(0x0F000000), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
      ),
    );

    final track = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.ease, // CSS `transition-colors` default; a colour change, kept under reduced motion
      width: width,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: pad),
      decoration: BoxDecoration(
        color: value ? onColor : offColor,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: snapThumb
          // Reduced motion: thumb appears at its target, no glide, no squish.
          ? Align(alignment: Alignment(targetT * 2 - 1, 0), child: thumb)
          : SingleMotionBuilder(
              value: targetT,
              motion: thumbMotion,
              builder: (context, t, _) => Align(
                alignment: Alignment(t * 2 - 1, 0), // -1 (left) → 1 (right)
                child: SingleMotionBuilder(
                  value: squish ? 0.9 : 1.0,
                  motion: thumbMotion,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: thumb,
                ),
              ),
            ),
    );

    final ringed = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2 + 4),
        boxShadow: _focusVisible
            ? [
                // ring-2 ring-offset-2: 2px gap in the background colour, then a 2px ring.
                BoxShadow(color: colors.ring, spreadRadius: 4),
                BoxShadow(color: colors.background, spreadRadius: 2),
              ]
            : null,
      ),
      child: track,
    );

    final control = Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _endPress,
      onPointerCancel: _endPress,
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: _focusNode,
        mouseCursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _toggle();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _toggle : null,
          child: Opacity(opacity: enabled ? 1.0 : 0.6, child: ringed),
        ),
      ),
    );

    final Widget result = widget.label == null
        ? control
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              control,
              const SizedBox(width: 12),
              GestureDetector(
                onTap: enabled ? _toggle : null,
                // Name comes from the Semantics label below — exclude the visual
                // text so it isn't announced twice.
                child: ExcludeSemantics(
                  child: Text(
                    widget.label!,
                    style: TextStyle(fontSize: 14, color: colors.foreground),
                  ),
                ),
              ),
            ],
          );

    // One merged node carrying toggle state, enablement, label, and the tap
    // action — the Flutter analog of the source's role="switch" + aria-checked.
    return MergeSemantics(
      child: Semantics(
        toggled: value,
        enabled: enabled,
        label: widget.label,
        child: result,
      ),
    );
  }
}
