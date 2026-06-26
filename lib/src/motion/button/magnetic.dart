import 'package:flutter/widgets.dart';

import '../magnetic.dart';
import 'base.dart';

/// A [BeuiButton] wrapped in [BeuiMagnetic] — the Flutter port of beUI's
/// `MagneticButton`. The button is pulled toward the cursor on hover-capable
/// pointers; on touch / reduced motion it is a plain button.
class BeuiMagneticButton extends StatelessWidget {
  /// Creates a magnetic button. All [BeuiButton] parameters are forwarded.
  const BeuiMagneticButton({
    required this.child,
    this.onPressed,
    this.variant = BeuiButtonVariant.primary,
    this.size = BeuiButtonSize.md,
    this.pressScale = 0.93,
    this.ripple = false,
    this.strength = 0.25,
    super.key,
  });

  /// Button content.
  final Widget child;

  /// Tap callback. Null disables the button.
  final VoidCallback? onPressed;

  /// Visual style.
  final BeuiButtonVariant variant;

  /// Size.
  final BeuiButtonSize size;

  /// Press scale.
  final double pressScale;

  /// Material-style ripple.
  final bool ripple;

  /// Magnetic pull strength. Default 0.25.
  final double strength;

  @override
  Widget build(BuildContext context) {
    return BeuiMagnetic(
      strength: strength,
      child: BeuiButton(
        onPressed: onPressed,
        variant: variant,
        size: size,
        pressScale: pressScale,
        ripple: ripple,
        child: child,
      ),
    );
  }
}
