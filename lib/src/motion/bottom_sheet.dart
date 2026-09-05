import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';

/// A draggable bottom sheet with snap points — the Flutter port of beUI's
/// `bottom-sheet`, built on [BeuiOverlay].
///
/// A modal panel (capped at 672px wide — source `max-w-2xl` — and centered)
/// that slides up over a fading,
/// blurred backdrop and settles at one of [snapPoints] — fractions of the
/// viewport height, `[0.5, 0.92]` by default, with [defaultSnap] the opening
/// index. Drag the handle to move it: an upward fling snaps to the next point,
/// a downward fling/drag snaps to the previous point or dismisses (past
/// [dismissThreshold]). Backdrop tap and Esc also dismiss; focus is trapped.
///
/// **Controlled** ([open] + [onOpenChange]), the source's API. Enter/exit use
/// the drawer curve (`EASE_DRAWER`, 500ms / 180ms under reduced motion, which
/// fades opacity instead of sliding). The height snaps instantly, matching the
/// source (it sets `style.height` per snap, only the drag transform animates).
class BeuiBottomSheet extends StatelessWidget {
  /// Creates a bottom sheet whose [child] is the scrollable content.
  const BeuiBottomSheet({
    required this.open,
    required this.onOpenChange,
    this.snapPoints = const [0.5, 0.92],
    this.defaultSnap = 0,
    this.title,
    this.description,
    this.dismissThreshold = 120,
    this.child,
    super.key,
  }) : assert(snapPoints.length > 0, 'Provide at least one snap point.');

  /// Whether the sheet is open (controlled).
  final bool open;

  /// Called when the sheet requests to close (fling/drag dismiss, backdrop, Esc).
  final ValueChanged<bool> onOpenChange;

  /// Rest heights as fractions of the viewport height (0–1). The first entry (or
  /// [defaultSnap]) is where the sheet opens.
  final List<double> snapPoints;

  /// Index into [snapPoints] the sheet opens at.
  final int defaultSnap;

  /// Optional heading shown in the drag area (also the dialog's a11y label).
  final String? title;

  /// Optional supporting line under [title].
  final String? description;

  /// Raw downward drag distance (px) past which a release dismisses the sheet.
  final double dismissThreshold;

  /// The sheet's scrollable content.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);

    return BeuiOverlay(
      open: open,
      barrier: true,
      barrierColor: colors.background.withValues(
        alpha: 0.4,
      ), // bg-background/40
      barrierBlur: 2, // backdrop-blur-sm (4px) → σ2
      // The barrier fade rides the panel's 500ms clock (the overlay default)
      // with the drawer curve, matching the source's backdrop transition.
      barrierCurve: beuiEaseDrawer,
      onDismiss: () => onOpenChange(false),
      // Source `DRAWER` (0.5s) in BOTH directions — deliberately symmetric,
      // overriding the house exits-faster-than-entrances rule. The
      // reduced-motion branch is 0.18s.
      enterDuration: Duration(milliseconds: reduce ? 180 : 500),
      exitDuration: Duration(milliseconds: reduce ? 180 : 500),
      overlayBuilder: (context, animation, link) => _BottomSheetPanel(
        animation: animation,
        open: open,
        onOpenChange: onOpenChange,
        snapPoints: snapPoints,
        defaultSnap: defaultSnap,
        title: title,
        description: description,
        dismissThreshold: dismissThreshold,
        colors: colors,
        child: child,
      ),
      child: const SizedBox.shrink(),
    );
  }
}

class _BottomSheetPanel extends StatefulWidget {
  const _BottomSheetPanel({
    required this.animation,
    required this.open,
    required this.onOpenChange,
    required this.snapPoints,
    required this.defaultSnap,
    required this.title,
    required this.description,
    required this.dismissThreshold,
    required this.colors,
    required this.child,
  });

  final Animation<double> animation;
  final bool open;
  final ValueChanged<bool> onOpenChange;
  final List<double> snapPoints;
  final int defaultSnap;
  final String? title;
  final String? description;
  final double dismissThreshold;
  final BeuiColors colors;
  final Widget? child;

  @override
  State<_BottomSheetPanel> createState() => _BottomSheetPanelState();
}

class _BottomSheetPanelState extends State<_BottomSheetPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _return; // drives the drag offset back to rest
  late int _snap = widget.defaultSnap.clamp(0, widget.snapPoints.length - 1);

  bool _dragging = false;
  // Elastic, visual drag offset (px). A ValueNotifier — NOT setState — so a
  // pointer-move only re-runs the transform builder, never the sheet surface.
  final ValueNotifier<double> _drag = ValueNotifier<double>(0);
  double _rawDy = 0; // raw finger travel (px) — the fling logic reads this
  double _returnFrom = 0; // drag offset captured at release
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _return = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void didUpdateWidget(_BottomSheetPanel old) {
    super.didUpdateWidget(old);
    // Re-open resets to the default snap (source's `useEffect([open])`).
    if (widget.open && !old.open) {
      _snap = widget.defaultSnap.clamp(0, widget.snapPoints.length - 1);
    }
  }

  @override
  void dispose() {
    _return.dispose();
    _drag.dispose();
    super.dispose();
  }

  double _targetHeight(double viewportH) =>
      widget.snapPoints[_snap] * viewportH;

  /// Framer's `dragElastic`: freely draggable down (bottom 0.4), all but pinned
  /// going up (top 0.02) — the constraints are `{top: 0, bottom: 0}`.
  double _elastic(double raw) => raw >= 0 ? raw * 0.4 : raw * 0.02;

  double _offsetNow() {
    if (_dragging) return _drag.value;
    return _returnFrom * (1 - beuiEaseDrawer.transform(_return.value));
  }

  void _onDragStart(DragStartDetails _) {
    _return.stop();
    _rawDy = 0;
    _drag.value = 0;
    setState(() => _dragging = true); // cursor change only
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _rawDy += d.delta.dy;
    _drag.value = _elastic(_rawDy); // no setState — transform-only update
  }

  void _onDragEnd(double velocity) {
    final offset = _rawDy;
    final last = widget.snapPoints.length - 1;
    var target = _snap;
    var dismiss = false;

    // Strong downward fling or large drag → snap to a smaller point, else close.
    if (velocity > 600 || offset > widget.dismissThreshold) {
      if (_snap > 0 &&
          velocity < 800 &&
          offset < widget.dismissThreshold * 1.6) {
        target = _snap - 1;
      } else {
        dismiss = true;
      }
    } else if (velocity < -500) {
      target = math.min(last, _snap + 1); // strong upward fling → next point
    } else if (offset > 80 && _snap > 0) {
      target = _snap - 1;
    } else if (offset < -80 && _snap < last) {
      target = _snap + 1;
    }

    setState(() {
      _dragging = false;
      _returnFrom = _drag.value;
      _snap = target;
    });
    _drag.value = 0;
    if (_reduce) {
      _returnFrom = 0; // no settle animation under reduced motion
    } else {
      _return.forward(from: 0);
    }
    if (dismiss) widget.onOpenChange(false);
  }

  @override
  Widget build(BuildContext context) {
    _reduce = MediaQuery.disableAnimationsOf(context);
    final viewportH = MediaQuery.of(context).size.height;
    // Height is set directly per snap (source's `style.height`) — no tween; only
    // the drag `y` transform animates.
    final target = _targetHeight(viewportH);

    return Positioned.fill(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672), // max-w-2xl (42rem)
          child: _buildSheet(target),
        ),
      ),
    );
  }

  Widget _buildSheet(double height) {
    // PERF: the full surface (Material / decoration / scrollable content) is
    // built once per state build and threaded through the `child` slot, so
    // each slide frame and drag pointer-move only re-runs the
    // Transform/Opacity wrappers below.
    final surface = SizedBox(height: height, child: _surface());
    return AnimatedBuilder(
      animation: Listenable.merge([widget.animation, _return, _drag]),
      child: surface,
      builder: (context, child) {
        final t = widget.animation.value.clamp(0.0, 1.0);
        final double translate;
        final double opacity;
        if (_reduce) {
          translate = _offsetNow();
          opacity = beuiEaseDrawer.transform(t); // source reduce ease
        } else {
          final e = beuiEaseDrawer.transform(t);
          translate = (1 - e) * height + _offsetNow(); // slide up + drag
          opacity = 1;
        }
        return Transform.translate(
          offset: Offset(0, translate),
          child: Opacity(opacity: opacity, child: child),
        );
      },
    );
  }

  Widget _surface() {
    final colors = widget.colors;
    return Material(
      key: const ValueKey<String>('beui_bottom_sheet_panel'),
      type: MaterialType.transparency,
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        label: widget.title,
        explicitChildNodes: true,
        child: Container(
          clipBehavior: Clip.antiAlias, // overflow-hidden
          decoration: BoxDecoration(
            color: colors.background, // source: bg-background
            border: Border.all(color: colors.border),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 25,
                spreadRadius: -5,
                offset: Offset(0, -8),
              ),
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 10,
                spreadRadius: -6,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dragArea(colors),
              // `flex-1`: the scroll body fills the rest of the fixed-height
              // sheet (and scrolls when the content overflows it).
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: widget.child ?? const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dragArea(BeuiColors colors) {
    final title = widget.title;
    final description = widget.description;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: (d) => _onDragEnd(d.velocity.pixelsPerSecond.dy),
      onVerticalDragCancel: () => _onDragEnd(0),
      child: MouseRegion(
        cursor: _dragging
            ? SystemMouseCursors.grabbing
            : SystemMouseCursors.grab,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), // px-4 pt-3 pb-2
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.mutedForeground.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              if (title != null || description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12), // mt-3
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.foreground,
                          ),
                        ),
                      if (description != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            description,
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.mutedForeground,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
