/// Internal shared helper for scroll-driven widgets (parallax, scroll-reveal):
/// tracks the enclosing scrollable and exposes the element's position relative
/// to the viewport, computed synchronously from [ScrollPosition.pixels] so a
/// scroll tick can update the very next frame.
library;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Mixin for a [State] that needs to know where its element sits within the
/// nearest enclosing scrollable's viewport.
///
/// The element's offset inside the scroll *content* is measured once per
/// layout (post-frame) and cached as an anchor; each scroll tick then derives
/// the viewport-relative position arithmetically — no per-scroll geometry
/// walks, and no one-frame lag.
mixin ScrollGeometryMixin<T extends StatefulWidget> on State<T> {
  ScrollPosition? _position;
  double? _anchor; // element top in scroll-content coordinates

  /// Called on every scroll tick after geometry is refreshed.
  void onScrollGeometryChanged();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_onScroll);
      _position = position;
      _position?.addListener(_onScroll);
    }
    _scheduleAnchorMeasure();
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (mounted) onScrollGeometryChanged();
  }

  void _scheduleAnchorMeasure() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final position = _position;
      final scrollableContext = position != null && position.hasPixels
          ? Scrollable.maybeOf(context)?.context
          : null;
      final viewportBox = scrollableContext?.findRenderObject() as RenderBox?;
      if (box == null || viewportBox == null || !box.attached || !box.hasSize) {
        return;
      }
      final topInViewport = box
          .localToGlobal(Offset.zero, ancestor: viewportBox)
          .dy;
      _anchor = topInViewport + position!.pixels;
      onScrollGeometryChanged();
    });
  }

  /// Height of the tracked viewport, or null before attachment.
  double? get viewportHeight => (_position?.hasViewportDimension ?? false)
      ? _position!.viewportDimension
      : null;

  /// The element's top edge in viewport coordinates, or null before the first
  /// layout has been measured.
  double? get topInViewport => _anchor == null || _position == null
      ? null
      : _anchor! - _position!.pixels;

  /// The element's own height, or null before layout.
  double? get elementHeight {
    final box = context.findRenderObject() as RenderBox?;
    return (box != null && box.hasSize) ? box.size.height : null;
  }

  /// Progress 0→1 as the element crosses the viewport (0: top edge at the
  /// viewport bottom, 1: bottom edge at the viewport top) — the source's
  /// `offset: ["start end", "end start"]`.
  double? get crossingProgress {
    final top = topInViewport;
    final vp = viewportHeight;
    final h = elementHeight;
    if (top == null || vp == null || h == null || vp + h <= 0) return null;
    return ((vp - top) / (vp + h)).clamp(0.0, 1.0);
  }

  /// Fraction of the element currently visible in the viewport (0..1).
  double? get visibleFraction {
    final top = topInViewport;
    final vp = viewportHeight;
    final h = elementHeight;
    if (top == null || vp == null || h == null || h <= 0) return null;
    final visible = (top + h).clamp(0.0, vp) - top.clamp(0.0, vp);
    return (visible / h).clamp(0.0, 1.0);
  }
}
