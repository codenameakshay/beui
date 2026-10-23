import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../tokens/motion.dart';
import '_engine.dart';

/// Wraps [child] so it is magnetically pulled toward the cursor — the Flutter
/// port of beUI's `Magnetic`.
///
/// A **continuous follow-spring**: on every pointer move the target offset is
/// re-pointed to `(cursor - center) * strength` and chased with [beuiSpringMouse]
/// (the source's `useSpring(value, SPRING_MOUSE)`). On exit it springs back to
/// rest.
///
/// Decorative and hover-only: built on [MouseRegion], so it never fires on touch
/// (no phantom hover), and it is disabled entirely under reduced motion — both
/// matching the source's `useHoverCapable() && !reduce` gate.
class BeuiMagnetic extends StatefulWidget {
  /// Wraps [child] with a magnetic pull.
  const BeuiMagnetic({required this.child, this.strength = 0.35, super.key});

  /// The widget to pull.
  final Widget child;

  /// Pull strength (fraction of the cursor's offset from center). Default 0.35.
  final double strength;

  @override
  State<BeuiMagnetic> createState() => _BeuiMagneticState();
}

class _BeuiMagneticState extends State<BeuiMagnetic> {
  final GlobalKey _key = GlobalKey();
  Offset _target = Offset.zero;

  void _onHover(PointerHoverEvent event) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final center = box.size.center(Offset.zero);
    setState(() => _target = (event.localPosition - center) * widget.strength);
  }

  void _reset() {
    if (_target != Offset.zero) setState(() => _target = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion disables the effect entirely (renders static).
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return MouseRegion(
      key: _key,
      onHover: _onHover,
      onExit: (_) => _reset(),
      child: MotionBuilder<Offset>(
        value: _target,
        motion: beuiSpringMouse,
        converter: const OffsetMotionConverter(),
        builder: (context, offset, child) =>
            Transform.translate(offset: offset, child: child),
        child: widget.child,
      ),
    );
  }
}
