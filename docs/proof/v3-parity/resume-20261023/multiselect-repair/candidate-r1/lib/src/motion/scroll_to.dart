import 'package:flutter/widgets.dart';

import 'smooth_scroll.dart';

/// A tappable wrapper that glides the page to a target — the Flutter port of
/// beUI's `ScrollTo` button.
///
/// Scrolls through the enclosing [BeuiSmoothScroll] provider (Lenis-eased,
/// reduced-motion-aware); targets are a pixel offset ([to]) or a widget
/// ([targetKey]) — the Flutter analog of the source's px / selector / element
/// union. [offset] adds extra px (e.g. negative to clear a sticky header).
class BeuiScrollTo extends StatelessWidget {
  /// Creates a scroll-to trigger. Provide [to] or [targetKey].
  const BeuiScrollTo({
    required this.child,
    this.to,
    this.targetKey,
    this.offset = 0,
    this.duration,
    super.key,
  }) : assert(
         to != null || targetKey != null,
         'Provide a pixel offset (to) or a target widget (targetKey).',
       );

  /// The trigger content (the source renders a `<button>`).
  final Widget child;

  /// Absolute pixel offset to scroll to.
  final double? to;

  /// A key on the widget to scroll into view.
  final GlobalKey? targetKey;

  /// Extra px offset from the target (source `offset`).
  final double offset;

  /// Overrides the glide duration (source `duration`).
  final Duration? duration;

  void _activate(BuildContext context) {
    final api = BeuiSmoothScroll.maybeOf(context);
    if (api == null) return;
    final targetContext = targetKey?.currentContext;
    if (targetContext != null) {
      api.scrollToContext(targetContext, offset: offset, duration: duration);
    } else if (to != null) {
      api.scrollTo(to!, offset: offset, duration: duration);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _activate(context),
          child: child,
        ),
      ),
    );
  }
}
