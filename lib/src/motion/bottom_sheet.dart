import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// The sheet's enter/exit glide and inter-snap height morph — the source's
/// `DRAWER = { duration: 0.5, ease: EASE_DRAWER }`.
const _drawerMotion = CurvedMotion(Duration(milliseconds: 500), beuiEaseDrawer);

/// A draggable bottom sheet with snap points — the Flutter port of beUI's
/// `bottom-sheet`, built on [BeuiOverlay].
///
/// A modal panel (capped at 512px wide, centered) that slides up over a fading,
/// blurred backdrop and settles at one of [snapPoints] — fractions of the
/// viewport height, `[0.5, 0.92]` by default, with [defaultSnap] the opening
/// index. Drag the handle to move it: an upward fling snaps to the next point,
/// a downward fling/drag snaps to the previous point or dismisses (past
/// [dismissThreshold]). Backdrop tap and Esc also dismiss; focus is trapped.
///
/// **Controlled** ([open] + [onOpenChange]), the source's API. Enter/exit and
/// inter-snap morphs use the drawer curve (`EASE_DRAWER`, 500ms); reduced motion
/// fades opacity instead of sliding and settles instantly.
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
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);

    return BeuiOverlay(
      open: open,
      barrier: true,
      barrierColor: colors.background.withValues(
        alpha: 0.4,
      ), // bg-background/40
      barrierBlur: 4, // backdrop-blur-sm
      onDismiss: () => onOpenChange(false),
      // Enter and exit both use the 0.5s drawer glide (source `DRAWER`).
      enterDuration: const Duration(milliseconds: 500),
      exitDuration: const Duration(milliseconds: 500),
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
  double _dragOffset = 0; // elastic, visual (px)
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
    super.dispose();
  }

  double _targetHeight(double viewportH) =>
      widget.snapPoints[_snap] * viewportH;

  /// Framer's `dragElastic`: freely draggable down (bottom 0.4), all but pinned
  /// going up (top 0.02) — the constraints are `{top: 0, bottom: 0}`.
  double _elastic(double raw) => raw >= 0 ? raw * 0.4 : raw * 0.02;

  double _offsetNow() {
    if (_dragging) return _dragOffset;
    return _returnFrom * (1 - beuiEaseDrawer.transform(_return.value));
  }

  void _onDragStart(DragStartDetails _) {
    _return.stop();
    setState(() {
      _dragging = true;
      _rawDy = 0;
      _dragOffset = 0;
    });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _rawDy += d.delta.dy;
      _dragOffset = _elastic(_rawDy);
    });
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
      _returnFrom = _dragOffset;
      _dragOffset = 0;
      _snap = target;
    });
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
    final target = _targetHeight(viewportH);

    final Widget sheet;
    if (_reduce) {
      sheet = _buildSheet(target);
    } else {
      sheet = SingleMotionBuilder(
        value: target,
        motion: _drawerMotion,
        builder: (context, h, _) => _buildSheet(h),
      );
    }

    return Positioned.fill(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 512), // max-w-2xl
          child: sheet,
        ),
      ),
    );
  }

  Widget _buildSheet(double height) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.animation, _return]),
      builder: (context, _) {
        final t = widget.animation.value.clamp(0.0, 1.0);
        final double translate;
        final double opacity;
        if (_reduce) {
          translate = _offsetNow();
          opacity = Curves.easeOut.transform(t);
        } else {
          final e = beuiEaseDrawer.transform(t);
          translate = (1 - e) * height + _offsetNow(); // slide up + drag
          opacity = 1;
        }
        return Transform.translate(
          offset: Offset(0, translate),
          child: Opacity(
            opacity: opacity,
            child: SizedBox(height: height, child: _surface()),
          ),
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
            color: colors.card,
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _dragArea(colors),
              Flexible(
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
