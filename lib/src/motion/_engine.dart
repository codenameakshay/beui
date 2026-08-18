/// Internal motion-engine facade — the single seam between beUI components and
/// the [`motor`](https://pub.dev/packages/motor) package.
///
/// Components import the builder / controller / [Motion] types from HERE, never
/// from `package:motor/motor.dart` directly, so a future `motor` swap is
/// contained to this file plus the token definitions in
/// `lib/src/tokens/motion.dart`. Same discipline as the `motor` rule documented
/// in `docs/PORTING_SPEC.md` §1.
///
/// This is a thin re-export, not a wrapping abstraction: component-local bespoke
/// springs (e.g. a switch's heavy thumb spring) still construct [SpringMotion]
/// by name, so the coupling is real but localized — exactly the trade-off the
/// spec calls out.
library;

export 'package:motor/motor.dart'
    show
        CurvedMotion,
        Motion,
        MotionBuilder,
        MotionController,
        MotionConverter,
        NoMotion,
        OffsetMotionConverter,
        RectMotionConverter,
        SingleMotionBuilder,
        SingleMotionController,
        SingleVelocityMotionBuilder,
        SizeMotionConverter,
        SpringMotion;
