import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../tokens/motion.dart';
import '_engine.dart';
import '_scroll_geometry.dart';

/// Reveals its child when scrolled into view: fade + rise + blur settling on
/// `EASE_OUT` — the Flutter port of beUI's `ScrollReveal`.
///
/// Visibility is measured against the nearest enclosing scrollable's viewport;
/// the reveal fires once [amount] of the element is visible. [once] keeps it
/// revealed after it leaves view (default), otherwise it hides again and
/// re-reveals on every entry.
///
/// Reduced motion keeps the opacity fade and drops the rise and blur (the
/// source's `useReducedMotion()` branch).
class BeuiScrollReveal extends StatefulWidget {
  /// Creates a scroll reveal wrapper.
  const BeuiScrollReveal({
    required this.child,
    this.y = 16,
    this.blur = 8,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
    this.once = true,
    this.amount = 0.3,
    super.key,
  });

  /// The revealed content.
  final Widget child;

  /// Slide distance in px before reveal (source `y = 16`).
  final double y;

  /// Enter blur in px, kept ≤ 10 per the motion conventions (source
  /// `blur = 8`).
  final double blur;

  /// Reveal duration (source `duration = 0.6`).
  final Duration duration;

  /// Delay before the reveal starts (source `delay`).
  final Duration delay;

  /// Reveal only once (default) or every time it enters view.
  final bool once;

  /// Fraction of the element that must be visible to trigger (source
  /// `amount = 0.3`).
  final double amount;

  @override
  State<BeuiScrollReveal> createState() => _BeuiScrollRevealState();
}

class _BeuiScrollRevealState extends State<BeuiScrollReveal>
    with ScrollGeometryMixin {
  bool _shown = false;
  bool _revealedOnce = false;
  Timer? _delayTimer;

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }

  @override
  void onScrollGeometryChanged() {
    final fraction = visibleFraction;
    if (fraction == null) return;
    final inView = fraction >= widget.amount;
    if (inView && !_shown) {
      if (widget.delay == Duration.zero) {
        setState(() => _shown = _revealedOnce = true);
      } else {
        _delayTimer ??= Timer(widget.delay, () {
          _delayTimer = null;
          if (mounted) setState(() => _shown = _revealedOnce = true);
        });
      }
    } else if (!inView && _shown && !(widget.once && _revealedOnce)) {
      _delayTimer?.cancel();
      _delayTimer = null;
      setState(() => _shown = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return SingleMotionBuilder(
      value: _shown ? 1.0 : 0.0,
      from: 0.0,
      motion: CurvedMotion(widget.duration, beuiEaseOut),
      builder: (context, t, child) {
        Widget body = child!;
        if (!reduce) {
          final sigma = (1 - t) * widget.blur / 2; // blur(Npx) ≈ σ N/2
          if (sigma > 0.05) {
            body = ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: TileMode.decal,
              ),
              child: body,
            );
          }
          body = Transform.translate(
            offset: Offset(0, (1 - t) * widget.y),
            child: body,
          );
        }
        return Opacity(opacity: t.clamp(0.0, 1.0), child: body);
      },
      child: widget.child,
    );
  }
}
