import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Builds the overlay content. [animation] runs 0→1 on enter and 1→0 on exit;
/// [link] is the anchor's [LayerLink], for positioning relative to the trigger
/// (e.g. a tooltip via [CompositedTransformFollower]). Modal content can ignore
/// [link] and position itself full-screen (e.g. `Align`/`Positioned`).
typedef BeuiOverlayBuilder =
    Widget Function(
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
    this.barrierEnterDuration,
    this.barrierExitDuration,
    this.barrierCurve = Curves.linear,
    this.barrierSaturation = 1,
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

  /// How long the barrier fades in. Defaults to [enterDuration] (the barrier
  /// rides the panel's clock).
  final Duration? barrierEnterDuration;

  /// How long the barrier fades out. Defaults to [exitDuration].
  final Duration? barrierExitDuration;

  /// Easing applied to the barrier's scrim alpha and blur-sigma ramp.
  /// Defaults to [Curves.linear] (the historical behavior).
  final Curve barrierCurve;

  /// Backdrop saturation at rest (CSS `saturate()`, e.g. `1.4` = 140%),
  /// composed with [barrierBlur] into a single backdrop pass and ramped
  /// 1 → [barrierSaturation] along the barrier fade. `1` (default) disables it.
  final double barrierSaturation;

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
    with TickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();

  /// The node wrapping the overlay content, so we can ask whether focus is
  /// currently *inside* this overlay. See [_handleGlobalEscape].
  final FocusNode _overlayFocus = FocusNode(
    debugLabel: 'BeuiOverlay',
    skipTraversal: true,
  );
  // Raw AnimationControllers, not `motor`: `overlayBuilder` hands callers a
  // plain `Animation<double>` to drive their own entrance, which is the
  // framework type these controllers already produce for free.
  late final AnimationController _controller;
  // The barrier fade runs on its own clock (it may be shorter than the
  // panel's, e.g. the drawer's 250ms backdrop under a 400ms panel envelope).
  late final AnimationController _barrier;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: widget.enterDuration,
          reverseDuration: widget.exitDuration,
        )..addStatusListener((status) {
          if (status == AnimationStatus.dismissed && _portal.isShowing) {
            _scheduleHide();
          }
        });
    _barrier = AnimationController(
      vsync: this,
      duration: widget.barrierEnterDuration ?? widget.enterDuration,
      reverseDuration: widget.barrierExitDuration ?? widget.exitDuration,
    );
    if (widget.open) {
      // OverlayPortalController.show() must not run during build/initState —
      // defer it. forward/reverse are fine in any phase.
      _scheduleShow(jumpToEnd: true);
    }
    _syncEscapeRegistration();
  }

  /// Hides the portal, deferring past the build phase when necessary —
  /// a close during build (didUpdateWidget -> reverse() with the controller
  /// still at 0) emits `dismissed` synchronously, and
  /// [OverlayPortalController.hide] asserts outside of it.
  void _scheduleHide() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.open && _portal.isShowing) _portal.hide();
      });
    } else {
      _portal.hide();
    }
  }

  void _scheduleShow({bool jumpToEnd = false}) {
    if (_portal.isShowing) {
      _controller.forward();
      _barrier.forward();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.open) return;
      _portal.show();
      if (jumpToEnd) {
        _controller.value = 1;
        _barrier.value = 1;
      } else {
        _controller.forward(from: 0);
        _barrier.forward(from: 0);
      }
    });
  }

  @override
  void didUpdateWidget(BeuiOverlay old) {
    super.didUpdateWidget(old);
    _controller.duration = widget.enterDuration;
    _controller.reverseDuration = widget.exitDuration;
    _barrier.duration = widget.barrierEnterDuration ?? widget.enterDuration;
    _barrier.reverseDuration =
        widget.barrierExitDuration ?? widget.exitDuration;
    if (widget.open && !old.open) {
      _scheduleShow();
    } else if (!widget.open && old.open) {
      _controller.reverse();
      _barrier.reverse();
    }
    // Deregisters as soon as `open` flips false, so Esc never re-dismisses an
    // overlay that is already playing its exit.
    _syncEscapeRegistration();
  }

  @override
  void dispose() {
    _escapeStack.remove(this);
    _uninstallEscapeHandlerIfEmpty();
    _overlayFocus.dispose();
    _controller.dispose();
    _barrier.dispose();
    super.dispose();
  }

  void _dismiss() => widget.onDismiss?.call();

  // ---------------------------------------------------------------------
  // Esc without a focus trap
  //
  // The Esc binding below lives in a `CallbackShortcuts`, which — like every
  // shortcut in Flutter — only receives key events travelling *up the focus
  // chain*. With `trapFocus: false` nothing inside the overlay ever takes
  // focus, and the overlay content is mounted in the root `Overlay`, a
  // different branch from wherever the primary focus actually sits. So the
  // event never reaches the binding and **Esc is dead** on exactly the
  // surfaces that need it most: the composer's `+` and model menus, the
  // select popover, the tooltip, the table menu (the audit's I2).
  //
  // The fix is to also listen at the one place that does not require focus —
  // `HardwareKeyboard` — while keeping the focus-tree path intact for
  // focus-trapping overlays (a modal's descendants must still be able to
  // handle Esc first). Two rules keep the two paths from fighting:
  //
  //  1. Only overlays that cannot use the focus path register here
  //     (`trapFocus: false`), and only when there is something to dismiss.
  //  2. If focus *has* landed inside this overlay anyway — the roving-focus
  //     menus do exactly this — the focus path will fire, so the global
  //     handler stands down rather than dismissing twice.
  //
  // The registry is a stack, so with several dismissible surfaces open only
  // the topmost (most recently opened) closes — the behaviour a user expects
  // from Esc, and the one a bare set of handlers would get wrong, since
  // `HardwareKeyboard` invokes handlers in registration order.
  static final List<_BeuiOverlayState> _escapeStack = <_BeuiOverlayState>[];
  static bool _escapeHandlerInstalled = false;

  static bool _handleGlobalEscape(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    if (_escapeStack.isEmpty) return false;
    final topmost = _escapeStack.last;
    // Focus is inside: the CallbackShortcuts path owns this event.
    if (topmost._overlayFocus.hasFocus) return false;
    topmost._dismiss();
    return true;
  }

  /// True when this overlay cannot rely on the focus tree for Esc.
  bool get _needsGlobalEscape => !widget.trapFocus && widget.onDismiss != null;

  void _syncEscapeRegistration() {
    if (widget.open && _needsGlobalEscape) {
      if (_escapeStack.contains(this)) return;
      _escapeStack.add(this);
      if (!_escapeHandlerInstalled) {
        _escapeHandlerInstalled = true;
        HardwareKeyboard.instance.addHandler(_handleGlobalEscape);
      }
    } else {
      if (!_escapeStack.remove(this)) return;
      _uninstallEscapeHandlerIfEmpty();
    }
  }

  /// Removes the global Esc handler once the last overlay that needed it is
  /// gone. Shared by [dispose] and [_syncEscapeRegistration] — both drop this
  /// state from [_escapeStack] and then need the same cleanup.
  static void _uninstallEscapeHandlerIfEmpty() {
    if (_escapeStack.isEmpty && _escapeHandlerInstalled) {
      _escapeHandlerInstalled = false;
      HardwareKeyboard.instance.removeHandler(_handleGlobalEscape);
    }
  }

  Widget _buildOverlay(BuildContext context) {
    final barrierColor =
        widget.barrierColor ?? const Color(0x66000000); // ~40% black scrim

    // The barrier fills explicitly (Positioned.fill); the content sizes itself
    // — anchored content (e.g. a tooltip) must not be stretched to full screen,
    // which `StackFit.expand` would do.
    Widget content = Stack(
      children: [
        if (widget.barrier)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _barrier,
              builder: (context, _) {
                final t = widget.barrierCurve.transform(
                  _barrier.value.clamp(0.0, 1.0),
                );
                // Animate the blur *sigma* (and scrim alpha) so the blur ramps
                // in progressively. Fading a constant-blur BackdropFilter via
                // opacity does NOT work in Flutter: the opacity saveLayer
                // isolates the filter's backdrop, so the blur snaps on only
                // when fully opaque. Sigma churn costs more, but only during
                // the brief open/close (the in-place morph keeps sigma fixed,
                // and the panel's RepaintBoundary keeps it off this layer).
                Widget scrim = ColoredBox(
                  color: barrierColor.withValues(alpha: barrierColor.a * t),
                );
                if (widget.barrierBlur > 0 || widget.barrierSaturation != 1) {
                  ImageFilter filter = ImageFilter.blur(
                    sigmaX: widget.barrierBlur * t,
                    sigmaY: widget.barrierBlur * t,
                  );
                  if (widget.barrierSaturation != 1) {
                    // CSS saturate(): ramps 1 → target with the fade and
                    // composes with the blur into one backdrop pass.
                    final s = 1 + (widget.barrierSaturation - 1) * t;
                    filter = ImageFilter.compose(
                      outer: _saturationFilter(s),
                      inner: filter,
                    );
                  }
                  scrim = BackdropFilter(filter: filter, child: scrim);
                }
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.barrierDismissible ? _dismiss : null,
                  child: scrim,
                );
              },
            ),
          ),
        widget.overlayBuilder(context, _controller, _link),
      ],
    );

    if (widget.trapFocus) {
      content = FocusScope(autofocus: true, child: content);
    }

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _dismiss},
      child: Focus(
        focusNode: _overlayFocus,
        autofocus: widget.trapFocus,
        child: content,
      ),
    );
  }

  /// CSS `saturate(s)` as a color-matrix filter (Rec. 709 luma weights).
  /// [ColorFilter] implements [ImageFilter], so it composes with the blur.
  static ImageFilter _saturationFilter(double s) {
    final inv = 1 - s;
    final r = 0.2126 * inv;
    final g = 0.7152 * inv;
    final b = 0.0722 * inv;
    return ColorFilter.matrix(<double>[
      r + s, g, b, 0, 0, //
      r, g + s, b, 0, 0, //
      r, g, b + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ]);
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
