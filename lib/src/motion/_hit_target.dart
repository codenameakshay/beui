/// Minimum-hit-target helper — expands what a finger can hit without moving
/// what the eye can see.
///
/// Package-internal. Not exported from `lib/beui.dart`.
///
/// The audit found interactive targets from 14px (message-rail ticks) to 36px
/// (sidebar rows) against a 44px floor — inline citation markers at 16px, the
/// approval actions at 27px, copy buttons at 28px, the feedback close at 20px
/// (under even WCAG 2.5.8's relaxed 24px). The fix is uniform and must not
/// touch the visual: this port's whole premise is source fidelity, so the
/// painted geometry stays exactly where it is and only the hit slop grows.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The touch-target floor, in logical pixels.
///
/// 44 is the Apple HIG / WCAG 2.2 SC 2.5.8 (AAA) value and Flutter's own
/// `kMinInteractiveDimension`. Material's `MaterialTapTargetSize.padded`
/// applies the same number the same way — by padding the *hit test*, not the
/// paint.
const double beuiMinHitTarget = 44;

/// Grows [child]'s hit area to at least [minSize] square, leaving its painted
/// size and its parent's layout untouched.
///
/// The child lays out and paints exactly as it would without this widget. The
/// extra slop is a transparent region that participates in hit testing and
/// overhangs into the parent's space, so a 20px close button gains 12px of
/// invisible margin on each side and still occupies 20px of layout.
///
/// Because the slop overhangs, it can overlap a *sibling's* slop. Where two
/// small controls sit within [minSize] of each other (the response action row
/// is 28px controls at 2px spacing; rail ticks abut at 0px), widen the visual
/// spacing or accept that the nearer target wins — Flutter hit-tests the
/// topmost child first, so paint order decides. Expanding slop is not a
/// substitute for spacing controls apart.
///
/// ```dart
/// BeuiMinHitTarget(
///   child: GestureDetector(onTap: onCopy, child: const Icon(size: 16)),
/// )
/// ```
///
/// Put this *outside* the gesture detector, not inside — it enlarges the box
/// the detector receives pointers through.
class BeuiMinHitTarget extends StatelessWidget {
  /// Wraps [child] with at least [minSize] of hit area in both axes.
  const BeuiMinHitTarget({
    required this.child,
    this.minSize = beuiMinHitTarget,
    this.enabled = true,
    super.key,
  });

  /// The control, painted and laid out unchanged.
  final Widget child;

  /// The hit-area floor in both axes. Defaults to [beuiMinHitTarget].
  final double minSize;

  /// When false this is a pass-through, for callers that gate the slop on
  /// pointer kind (a mouse does not need 44px).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return _MinHitTarget(minSize: minSize, child: child);
  }
}

class _MinHitTarget extends SingleChildRenderObjectWidget {
  const _MinHitTarget({required this.minSize, required Widget super.child});

  final double minSize;

  @override
  _RenderMinHitTarget createRenderObject(BuildContext context) =>
      _RenderMinHitTarget(minSize: minSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMinHitTarget renderObject,
  ) {
    renderObject.minSize = minSize;
  }
}

/// Sizes and paints as its child, but accepts pointers inside a [minSize]
/// square centred on the child.
///
/// This is the mechanism `RenderConstrainedBox` + Material's tap-target
/// padding use, reduced to the one behaviour needed here: [hitTest] is
/// overridden to widen the accepted region while [performLayout] and [paint]
/// stay pass-through, so nothing in the layout or the pixels changes.
class _RenderMinHitTarget extends RenderProxyBox {
  _RenderMinHitTarget({required double minSize}) : this._(minSize);

  _RenderMinHitTarget._(this._minSize);

  /// The hit-area floor in both axes.
  double get minSize => _minSize;
  double _minSize;

  set minSize(double value) {
    if (_minSize == value) return;
    _minSize = value;
    // Hit-test-only: no layout or paint depends on this, so nothing to mark.
  }

  /// The slop rectangle in local coordinates — the child's box grown to
  /// [minSize] about its centre.
  Rect get _hitRect {
    final dx = ((_minSize - size.width) / 2).clamp(0.0, double.infinity);
    final dy = ((_minSize - size.height) / 2).clamp(0.0, double.infinity);
    return Rect.fromLTRB(-dx, -dy, size.width + dx, size.height + dy);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // A hit on the painted child is an ordinary hit — nothing to redirect.
    if (super.hitTest(result, position: position)) return true;
    // Outside the paint but inside the slop: re-run the child's hit test as if
    // the pointer had landed dead centre. This is the mechanism Material's
    // `_RenderInputPadding` uses for `MaterialTapTargetSize.padded`, and it
    // matters that it is a *transform* rather than a synthesised entry — the
    // child's own detectors enter the gesture arena normally, so drag, long
    // press, and tap-cancel all behave as if the touch were on the control.
    final child = this.child;
    if (child == null || !_hitRect.contains(position)) return false;
    final centre = child.size.center(Offset.zero);
    return result.addWithRawTransform(
      transform: MatrixUtils.forceToPoint(centre),
      position: centre,
      hitTest: (result, position) {
        assert(position == centre);
        return child.hitTest(result, position: centre);
      },
    );
  }
}
