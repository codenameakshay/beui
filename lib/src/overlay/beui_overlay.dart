import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Builds the overlay content. [animation] runs 0→1 on enter and 1→0 on exit;
/// [link] is the anchor's [LayerLink], for positioning relative to the trigger
/// (e.g. a tooltip via [CompositedTransformFollower]). Modal content can ignore
/// [link] and position itself full-screen (e.g. `Align`/`Positioned`).
typedef BeuiOverlayBuilder = Widget Function(
  BuildContext context,
  Animation<double> animation,
  LayerLink link,
);

/// The shared overlay foundation for beUI — the single seam every floating
/// surface (tooltip, drawer, bottom-sheet, modal, command-palette, create-menu)
/// is built on. The Flutter port of the source's `createPortal` / fixed-overlay
/// pattern.
///
/// **Declarative, library-wide** (the decision the spec's §6 asks to make once):
/// the consumer owns an [open] bool and reacts to [onDismiss]; this widget does
/// not hold open/closed state. When [open] flips false it animates the content
/// out, *then* unmounts.
///
/// Renders into the root [Overlay] (via [OverlayChildLocation.rootOverlay]), so
/// the content escapes any ancestor `Transform`/`ClipRect` — the containing-block
/// hazard the spec warns about. Provides a fading (optionally blurred) barrier,
/// tap-to-dismiss, Esc-to-dismiss, and a focus trap. The *panel's own* entrance
/// (scale / slide / blur) is owned by [overlayBuilder] via [animation]; reduced
/// motion is each panel's responsibility (drop transform, keep opacity).
class BeuiOverlay extends StatefulWidget {
  /// Creates an overlay host around [child] (the trigger / where it lives).
  const BeuiOverlay({
    required this.open,
    required this.overlayBuilder,
    required this.child,
    this.onDismiss,
    this.barrier = true,
    this.barrierColor,
    this.barrierBlur = 0,
    this.barrierDismissible = true,
    this.trapFocus = true,
    this.enterDuration = const Duration(milliseconds: 240),
    this.exitDuration = const Duration(milliseconds: 160),
    super.key,
  });

  /// Whether the overlay is open (controlled by the consumer).
  final bool open;

  /// Builds the floating content.
  final BeuiOverlayBuilder overlayBuilder;

  /// The trigger / anchor subtree, always in the tree.
  final Widget child;

  /// Called on barrier tap or Esc. The consumer should set [open] to false.
  final VoidCallback? onDismiss;

  /// Render a dismiss barrier behind the content.
  final bool barrier;

  /// Barrier scrim colour. Defaults to a translucent black.
  final Color? barrierColor;

  /// Backdrop blur (sigma) applied behind the barrier — the glass effect.
  final double barrierBlur;

  /// Whether tapping the barrier dismisses.
  final bool barrierDismissible;

  /// Trap focus within the overlay while open.
  final bool trapFocus;

  /// Enter animation duration.
  final Duration enterDuration;

  /// Exit animation duration (typically faster than [enterDuration]).
  final Duration exitDuration;

  @override
  State<BeuiOverlay> createState() => _BeuiOverlayState();
}

class _BeuiOverlayState extends State<BeuiOverlay>
    with SingleTickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.enterDuration,
      reverseDuration: widget.exitDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.dismissed && _portal.isShowing) {
          _portal.hide();
        }
      });
    if (widget.open) {
      // OverlayPortalController.show() must not run during build/initState —
      // defer it. forward/reverse are fine in any phase.
      _scheduleShow(jumpToEnd: true);
    }
  }

  void _scheduleShow({bool jumpToEnd = false}) {
    if (_portal.isShowing) {
      _controller.forward();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.open) return;
      _portal.show();
      if (jumpToEnd) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    });
  }

  @override
  void didUpdateWidget(BeuiOverlay old) {
    super.didUpdateWidget(old);
    if (widget.open && !old.open) {
      _scheduleShow();
    } else if (!widget.open && old.open) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() => widget.onDismiss?.call();

  Widget _buildOverlay(BuildContext context) {
    final barrierColor =
        widget.barrierColor ?? const Color(0x66000000); // ~40% black scrim

    Widget content = Stack(
      fit: StackFit.expand,
      children: [
        if (widget.barrier)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              Widget scrim = ColoredBox(
                color: barrierColor.withValues(
                    alpha: barrierColor.a * t.clamp(0.0, 1.0)),
              );
              if (widget.barrierBlur > 0) {
                scrim = BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: widget.barrierBlur * t,
                    sigmaY: widget.barrierBlur * t,
                  ),
                  child: scrim,
                );
              }
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.barrierDismissible ? _dismiss : null,
                child: scrim,
              );
            },
          ),
        widget.overlayBuilder(context, _controller, _link),
      ],
    );

    if (widget.trapFocus) {
      content = FocusScope(autofocus: true, child: content);
    }

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _dismiss},
      child: Focus(autofocus: widget.trapFocus, child: content),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayLocation: OverlayChildLocation.rootOverlay,
        overlayChildBuilder: _buildOverlay,
        child: widget.child,
      ),
    );
  }
}
