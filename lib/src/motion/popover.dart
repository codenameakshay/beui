import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart' show SingleMotionBuilder, SpringMotion;

/// Which side of the trigger the panel oozes out of.
enum BeuiPopoverSide {
  /// Below the trigger (default).
  bottom,

  /// Above the trigger.
  top,
}

/// Alignment of the panel along the trigger's edge.
enum BeuiPopoverAlign {
  /// Left-aligned (start edge).
  start,

  /// Centered (default).
  center,

  /// Right-aligned (end edge).
  end,
}

/// How the popover is summoned.
enum BeuiPopoverTrigger {
  /// Toggle on tap (default).
  click,

  /// Open on hover / focus, close after a short delay.
  hover,
}

// The source runs two different goo springs — a slower one opening, a snappier
// one closing (`open ? GOO_OPEN_SPRING : GOO_CLOSE_SPRING`), keeping the exit
// faster than the entrance. Framer's `{visualDuration, bounce}` converts to a
// [SpringDescription] at mass 1 by `ω = 2π/visualDuration`, `ζ = 1 - bounce`,
// `stiffness = ω²`, `damping = 2ζω`.

/// `GOO_OPEN_SPRING` — Framer `{visualDuration: 0.3, bounce: 0.15}`:
/// `ω = 2π/0.3 ≈ 20.94`, `ζ = 0.85`.
const _gooOpenSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 438.6, damping: 35.6),
);

/// `GOO_CLOSE_SPRING` — Framer `{visualDuration: 0.21, bounce: 0.15}`:
/// `ω = 2π/0.21 ≈ 29.92`, `ζ = 0.85`.
const _gooCloseSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 895.2, damping: 50.9),
);

const int _hoverCloseDelayMs = 120;

/// A popover whose panel **oozes** out of the trigger like liquid — the Flutter
/// port of beUI's `popover` (gooey variant).
///
/// The trigger pill and a growing blob are painted into one layer and run
/// through a **goo filter** (Gaussian blur → alpha threshold), so the panel
/// appears to stretch out of the trigger through a molten neck as it opens on
/// the [_gooOpenSpring]. The same rounded-rect morph clips the content, so text
/// reveals with the blob. Geometry (trigger and panel rects in a shared box) is
/// measured at runtime and springs one frame late, matching the source.
///
/// **Collapsed from the source's compound `Popover`/`PopoverTrigger`/
/// `PopoverContent`** into a single widget with a [child] trigger and [content]
/// panel — the same shape as [BeuiTooltip], and the Flutter-idiomatic form of
/// the source's context-wired parts.
///
/// Controlled ([open] + [onOpenChange]) or uncontrolled ([defaultOpen]). Closes
/// on Escape, tap-outside (click mode), or blur (hover mode). Reduced motion
/// drops the goo filter and the melt — the panel simply appears (the morph runs
/// briefly, no liquid neck).
class BeuiPopover extends StatefulWidget {
  /// Creates a popover around [child].
  const BeuiPopover({
    required this.child,
    required this.content,
    this.open,
    this.defaultOpen = false,
    this.onOpenChange,
    this.trigger = BeuiPopoverTrigger.click,
    this.side = BeuiPopoverSide.bottom,
    this.align = BeuiPopoverAlign.center,
    this.sideOffset = 14,
    this.panelRadius = 16,
    this.gooStrength = 8,
    super.key,
  });

  /// The trigger.
  final Widget child;

  /// The panel body.
  final Widget content;

  /// Controlled open state. When null the popover manages its own.
  final bool? open;

  /// Uncontrolled initial open state.
  final bool defaultOpen;

  /// Notified when the open state should change (barrier/Esc/toggle).
  final ValueChanged<bool>? onOpenChange;

  /// How the popover opens. Defaults to [BeuiPopoverTrigger.click].
  final BeuiPopoverTrigger trigger;

  /// Which side the panel oozes out of. Defaults to [BeuiPopoverSide.bottom].
  final BeuiPopoverSide side;

  /// Alignment along the trigger edge. Defaults to [BeuiPopoverAlign.center].
  final BeuiPopoverAlign align;

  /// Gap between trigger and panel, in px — the length of the gooey neck.
  final double sideOffset;

  /// Corner radius of the open panel, in px.
  final double panelRadius;

  /// Blur radius feeding the goo filter — higher melts more.
  final double gooStrength;

  @override
  State<BeuiPopover> createState() => _BeuiPopoverState();
}

class _BeuiPopoverState extends State<BeuiPopover> {
  final GlobalKey _triggerKey = GlobalKey();
  final GlobalKey _measureKey = GlobalKey();

  bool _internalOpen = false;
  Size _triggerSize = Size.zero;
  Size _panelSize = Size.zero;

  /// Owned by the state so the `Focus` that hosts the Esc binding can stay
  /// mounted across the whole open/close cycle — see the note in [build].
  final FocusNode _focusNode = FocusNode(debugLabel: 'BeuiPopover');

  bool get _open => widget.open ?? _internalOpen;

  @override
  void initState() {
    super.initState();
    _internalOpen = widget.defaultOpen;
  }

  /// Cancellable, so re-hovering inside the delay (or disposing mid-delay)
  /// doesn't leave a stale close still pending. See the note in
  /// `message_bubble.dart`'s `_ContentRevealState._delay`.
  Timer? _closeTimer;

  @override
  void dispose() {
    _closeTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  /// Moves focus into the panel when it opens (so the Esc binding is live) and
  /// releases it when it closes. Previously this fell out of the `Focus` widget
  /// being mounted/unmounted with `autofocus: true`; the wrapper is now
  /// permanent, so the focus move is explicit.
  ///
  /// Deliberately edge-triggered on [_open]. Re-asserting focus on every frame
  /// would yank it back from anything the user tabbed to while the panel was
  /// open — `autofocus` only ever fired once, and so does this.
  bool? _focusSyncedOpen;

  void _syncFocus() {
    if (widget.trigger != BeuiPopoverTrigger.click) return;
    if (_focusSyncedOpen == _open) return;
    _focusSyncedOpen = _open;
    if (_open) {
      _focusNode.requestFocus();
    } else if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
  }

  void _setOpen(bool next) {
    // Re-hovering (or refocusing) inside the close delay cancels it — a
    // pointer that dips out and back in should never see the panel close.
    if (next) {
      _closeTimer?.cancel();
      _closeTimer = null;
    }
    final was = _open;
    if (widget.open == null) {
      setState(() => _internalOpen = next);
    }
    if (was != next) widget.onOpenChange?.call(next);
  }

  void _measure() {
    final t = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final p = _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (t != null && t.hasSize && t.size != _triggerSize) {
      setState(() => _triggerSize = t.size);
    }
    if (p != null && p.hasSize && p.size != _panelSize) {
      setState(() => _panelSize = p.size);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measure();
      _syncFocus();
    });
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);

    final geo = _buildGeo(
      _triggerSize,
      _panelSize,
      widget.side,
      widget.align,
      widget.sideOffset,
      widget.panelRadius,
    );

    final trigger = KeyedSubtree(key: _triggerKey, child: widget.child);

    Widget triggerWrapped = widget.trigger == BeuiPopoverTrigger.click
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _setOpen(!_open),
            child: trigger,
          )
        : FocusableActionDetector(
            onShowHoverHighlight: (h) => h ? _setOpen(true) : _scheduleClose(),
            onFocusChange: (f) => f ? _setOpen(true) : _scheduleClose(),
            child: trigger,
          );

    final stack = Stack(
      clipBehavior: Clip.none,
      children: [
        // Off-stage measurement of the panel content at its natural size.
        Positioned(
          left: 0,
          top: 0,
          child: Offstage(
            child: ConstrainedBox(
              key: _measureKey,
              // Source: `max-w-[min(92vw,20rem)]` — the 20rem arm was missing.
              constraints: BoxConstraints(
                maxWidth: math.min(
                  MediaQuery.sizeOf(context).width * 0.92,
                  320,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: widget.content,
              ),
            ),
          ),
        ),
        SingleMotionBuilder(
          value: _open ? 1.0 : 0.0,
          motion: reduce
              ? beuiSpringSnap
              : (_open ? _gooOpenSpring : _gooCloseSpring),
          builder: (context, p, _) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Goo body (behind the trigger): blurred + thresholded blend of
                // the static trigger pill and the morphing blob.
                if (geo != null && (p > 0.001 || _open))
                  Positioned(
                    left: geo.left,
                    top: geo.top,
                    width: geo.layerW,
                    height: geo.layerH,
                    child: IgnorePointer(
                      child: _GooBody(
                        geo: geo,
                        progress: p,
                        color: colors.popover,
                        gooStrength: widget.gooStrength,
                        reduce: reduce,
                      ),
                    ),
                  ),
                // Trigger.
                triggerWrapped,
                // Content, clipped by the same morph.
                if (geo != null && p > 0.001)
                  Positioned(
                    left: geo.left,
                    top: geo.top,
                    width: geo.layerW,
                    height: geo.layerH,
                    child: _GooContent(
                      geo: geo,
                      progress: p,
                      interactive: _open,
                      color: colors.popoverForeground,
                      content: widget.content,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );

    // The dismiss wrapper is mounted **unconditionally** and only its behaviour
    // is gated on [_open]. Mounting it just while open changes the depth of the
    // tree above the goo's `SingleMotionBuilder`, so Flutter cannot match the
    // old element on a toggle: it discards the state and builds a fresh
    // `MotionController` seeded at `initialValue: value` — i.e. already *at* the
    // target. The result was that neither goo spring ever ran; the panel snapped
    // open and snapped shut in a single frame. Keep this structure stable.
    //
    // `stack` is the inline-flex isolate: it sizes to the trigger.
    final isClick = widget.trigger == BeuiPopoverTrigger.click;
    return CallbackShortcuts(
      bindings: _open
          ? {
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  _setOpen(false),
            }
          : const <ShortcutActivator, VoidCallback>{},
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: _open && isClick,
        child: TapRegion(
          onTapOutside: _open && isClick ? (_) => _setOpen(false) : null,
          child: stack,
        ),
      ),
    );
  }

  void _scheduleClose() {
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: _hoverCloseDelayMs), () {
      if (mounted && widget.trigger == BeuiPopoverTrigger.hover) {
        _setOpen(false);
      }
    });
  }
}

/// Trigger and panel rects in one shared local coordinate box (origin at the
/// box top-left). A direct port of the source `buildGeo`.
class _Geo {
  const _Geo({
    required this.layerW,
    required this.layerH,
    required this.left,
    required this.top,
    required this.trigger,
    required this.panel,
  });
  final double layerW;
  final double layerH;
  final double left; // offset of the box from the trigger top-left
  final double top;
  final _RRect trigger;
  final _RRect panel;
}

class _RRect {
  const _RRect(this.x, this.y, this.w, this.h, this.r);
  final double x;
  final double y;
  final double w;
  final double h;
  final double r;
}

_Geo? _buildGeo(
  Size t,
  Size c,
  BeuiPopoverSide side,
  BeuiPopoverAlign align,
  double gap,
  double panelRadius,
) {
  if (t == Size.zero || c == Size.zero) return null;
  final tW = t.width, tH = t.height, cW = c.width, cH = c.height;
  final py = side == BeuiPopoverSide.bottom ? tH + gap : -(gap + cH);
  final px = switch (align) {
    BeuiPopoverAlign.start => 0.0,
    BeuiPopoverAlign.end => tW - cW,
    BeuiPopoverAlign.center => (tW - cW) / 2,
  };

  final left = px < 0 ? px : 0.0;
  final top = py < 0 ? py : 0.0;
  final layerW = (tW > px + cW ? tW : px + cW) - left;
  final layerH = (tH > py + cH ? tH : py + cH) - top;
  final triggerRadius = tH / 2 < panelRadius ? tH / 2 : panelRadius;

  return _Geo(
    layerW: layerW,
    layerH: layerH,
    left: left,
    top: top,
    trigger: _RRect(-left, -top, tW, tH, triggerRadius),
    panel: _RRect(px - left, py - top, cW, cH, panelRadius),
  );
}

/// Interpolates the morphing rect (trigger → panel) at [p].
_RRect _rectForProgress(_Geo geo, double p) {
  final a = geo.trigger, b = geo.panel;
  return _RRect(
    lerpDouble(a.x, b.x, p)!,
    lerpDouble(a.y, b.y, p)!,
    lerpDouble(a.w, b.w, p)!,
    lerpDouble(a.h, b.h, p)!,
    lerpDouble(a.r, b.r, p)!,
  );
}

/// The goo layer: a static trigger pill plus the morphing blob, painted in the
/// popover color and (unless [reduce]) run through the blur→threshold goo
/// filter so the two merge with a liquid neck.
class _GooBody extends StatelessWidget {
  const _GooBody({
    required this.geo,
    required this.progress,
    required this.color,
    required this.gooStrength,
    required this.reduce,
  });

  final _Geo geo;
  final double progress;
  final Color color;
  final double gooStrength;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final blob = _rectForProgress(geo, progress);
    final shapes = Stack(
      children: [
        // Static trigger pill.
        Positioned(
          left: geo.trigger.x,
          top: geo.trigger.y,
          width: geo.trigger.w,
          height: geo.trigger.h,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(geo.trigger.r),
            ),
          ),
        ),
        // Morphing blob.
        Positioned(
          left: blob.x,
          top: blob.y,
          width: blob.w,
          height: blob.h,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(blob.r),
            ),
          ),
        ),
      ],
    );

    if (reduce) return shapes;

    // Goo filter: blur, then an alpha-threshold color matrix that re-sharpens
    // the blurred alpha back into a solid shape with a liquid neck — the port
    // of the source SVG `feGaussianBlur` + `feColorMatrix (…22 -10)`. Flutter's
    // matrix works in 0..255, so the SVG's `alpha*22 - 10` (0..1) becomes
    // `alpha*22 - 10*255`.
    final goo = ImageFilter.compose(
      outer: const ColorFilter.matrix(<double>[
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0, //
        0, 0, 1, 0, 0, //
        0, 0, 0, 22, -2550, //
      ]),
      inner: ImageFilter.blur(sigmaX: gooStrength, sigmaY: gooStrength),
    );
    return ImageFiltered(imageFilter: goo, child: shapes);
  }
}

/// The panel content, clipped by the morphing rect so it reveals with the blob.
class _GooContent extends StatelessWidget {
  const _GooContent({
    required this.geo,
    required this.progress,
    required this.interactive,
    required this.color,
    required this.content,
  });

  final _Geo geo;
  final double progress;
  final bool interactive;
  final Color color;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    final clip = _rectForProgress(geo, progress);
    return IgnorePointer(
      ignoring: !interactive,
      child: ClipRRect(
        clipper: _RRectClipper(clip),
        child: Stack(
          children: [
            Positioned(
              left: geo.panel.x,
              top: geo.panel.y,
              width: geo.panel.w,
              height: geo.panel.h,
              child: DefaultTextStyle.merge(
                style: TextStyle(color: color),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: content,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RRectClipper extends CustomClipper<RRect> {
  _RRectClipper(this.rect);
  final _RRect rect;

  @override
  RRect getClip(Size size) => RRect.fromRectAndRadius(
    Rect.fromLTWH(rect.x, rect.y, rect.w, rect.h),
    Radius.circular(rect.r),
  );

  @override
  bool shouldReclip(_RRectClipper old) =>
      old.rect.x != rect.x ||
      old.rect.y != rect.y ||
      old.rect.w != rect.w ||
      old.rect.h != rect.h ||
      old.rect.r != rect.r;
}
