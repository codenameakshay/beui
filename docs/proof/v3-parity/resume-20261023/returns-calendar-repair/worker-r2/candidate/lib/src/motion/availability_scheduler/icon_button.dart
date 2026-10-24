import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/beui_colors.dart';
import '../../tokens/motion.dart';
import '../_engine.dart';

/// A small square icon button — the Flutter port of the availability-scheduler's
/// `icon-button.tsx`.
///
/// 32×32, rounded-lg, muted-foreground that brightens to foreground on hover
/// with a muted background fill. On pointer press the whole button squishes to
/// `scale 0.86` on `SPRING_PRESS` (source `whileTap={{ scale: 0.86 }}` with
/// `transition={SPRING_PRESS}`). Reduced motion (and the disabled state) drop
/// the press squish; the colour transition is kept.
///
/// Internal to the scheduler — not part of the public surface.
class SchedulerIconButton extends StatefulWidget {
  /// Creates an icon button.
  const SchedulerIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.expanded = false,
    this.enabled = true,
    super.key,
  });

  /// The glyph content (typically an [Icon]).
  final Widget icon;

  /// Accessible label (source `aria-label`).
  final String label;

  /// Tap handler.
  final VoidCallback onPressed;

  /// Whether the button controls an expanded surface (source `aria-expanded`).
  final bool expanded;

  /// Whether the button responds to input.
  final bool enabled;

  @override
  State<SchedulerIconButton> createState() => _SchedulerIconButtonState();
}

class _SchedulerIconButtonState extends State<SchedulerIconButton> {
  late final FocusNode _focusNode = FocusNode();
  bool _pressed = false;
  bool _hovered = false;
  bool _focusVisible = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.enabled;

    final active = _hovered && enabled;
    // Press squish gated the same way as BeuiCheckbox: routing through
    // motionFor → NoMotion would freeze the button mid-squish, so we hold the
    // press target at 1 under reduced motion instead.
    final pressTarget = (_pressed && enabled && !reduce) ? 0.86 : 1.0;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.ease, // CSS transition-colors, kept under reduced motion
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? colors.muted : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconTheme.merge(
        data: IconThemeData(
          size: 16,
          color: active ? colors.foreground : colors.mutedForeground,
        ),
        child: widget.icon,
      ),
    );

    final ringed = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8 + 2),
        boxShadow: _focusVisible
            ? [
                BoxShadow(color: colors.ring, spreadRadius: 2),
                BoxShadow(color: colors.background, spreadRadius: 0),
              ]
            : null,
      ),
      child: content,
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      expanded: widget.expanded,
      child: Listener(
        onPointerDown: (_) {
          if (enabled) setState(() => _pressed = true);
        },
        onPointerUp: (_) {
          if (_pressed) setState(() => _pressed = false);
        },
        onPointerCancel: (_) {
          if (_pressed) setState(() => _pressed = false);
        },
        child: FocusableActionDetector(
          enabled: enabled,
          focusNode: _focusNode,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                if (enabled) widget.onPressed();
                return null;
              },
            ),
          },
          onShowFocusHighlight: (v) => setState(() => _focusVisible = v),
          onShowHoverHighlight: (v) => setState(() => _hovered = v),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? widget.onPressed : null,
            child: SingleMotionBuilder(
              value: pressTarget,
              motion: beuiSpringPress,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Opacity(opacity: enabled ? 1.0 : 0.4, child: ringed),
            ),
          ),
        ),
      ),
    );
  }
}
