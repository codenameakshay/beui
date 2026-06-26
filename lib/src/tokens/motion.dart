/// Motion tokens — the foundation every animated beUI component depends on.
///
/// A one-to-one port of the source's `lib/ease.ts`. Framer Motion springs are
/// parameterized by `stiffness`, `damping`, and `mass` — the exact same physical
/// parameters as Flutter's [SpringDescription] — so the tokens carry over with
/// zero fidelity loss. Do **not** approximate these springs with
/// `Curves.elasticOut`/`bounceOut`; use the values verbatim.
///
/// This is the ONLY place `motor` types appear directly. Components consume the
/// `beui*` constants and the [motionFor] resolver defined here — never scatter
/// `SpringMotion(...)`/`CurvedMotion(...)` literals across widgets. If `motor`
/// is ever dropped, you rewrite these ~8 constants, not every component.
///
/// See `docs/PORTING_SPEC.md` §1.
library;

import 'package:flutter/widgets.dart'; // re-exports SpringDescription (physics) + Cubic
import 'package:motor/motor.dart';

// ---------------------------------------------------------------------------
// Springs → motor.SpringMotion(SpringDescription(...))
//
// Mirrors the source `SPRING_*` tokens (stiffness / damping / mass). Drive
// targets with MotionBuilder / SingleMotionBuilder / a MotionController — no
// manual SpringSimulation wiring.
// ---------------------------------------------------------------------------

/// Press feedback on buttons and tappable surfaces (source `SPRING_PRESS`).
///
/// stiffness 500 · damping 30 · mass 0.6 — a crisp, quick settle for the
/// ~100–160ms press-feedback window.
const beuiSpringPress = SpringMotion(
  SpringDescription(mass: 0.6, stiffness: 500, damping: 30),
);

/// Content swaps — label/icon slots trading places (source `SPRING_SWAP`).
///
/// stiffness 460 · damping 30 · mass 0.55.
const beuiSpringSwap = SpringMotion(
  SpringDescription(mass: 0.55, stiffness: 460, damping: 30),
);

/// Overlay panel entrances — modals, sheets (source `SPRING_PANEL`).
///
/// stiffness 420 · damping 40 · mass 0.5 — heavier damping for a composed,
/// overshoot-free panel arrival.
const beuiSpringPanel = SpringMotion(
  SpringDescription(mass: 0.5, stiffness: 420, damping: 40),
);

/// Shared-layout glides — pills and indicators morphing between positions
/// (source `SPRING_LAYOUT`).
///
/// stiffness 360 · damping 32 · mass 0.6. Pair with a `MotionBuilder<Rect>`
/// keyed on the active item for `layoutId`-style transitions.
const beuiSpringLayout = SpringMotion(
  SpringDescription(mass: 0.6, stiffness: 360, damping: 32),
);

/// Cursor-follow physics — magnetic pull, tilt, dock magnify (source
/// `SPRING_MOUSE`).
///
/// stiffness 200 · damping 15 · mass 0.3 — light and loose so the element
/// trails the pointer. Build these effects on `MouseRegion` so they never fire
/// on touch.
const beuiSpringMouse = SpringMotion(
  SpringDescription(mass: 0.3, stiffness: 200, damping: 15),
);

// ---------------------------------------------------------------------------
// Easing curves → Cubic, for use inside motor.CurvedMotion(duration, curve).
//
// These define the curve only; duration is chosen per use, e.g.
//   CurvedMotion(const Duration(milliseconds: 220), beuiEaseOut)
// (motor's CurvedMotion takes (duration, [curve]) positionally.)
// ---------------------------------------------------------------------------

/// Default ease-out, `cubic-bezier(0.16, 1, 0.3, 1)` (source `EASE_OUT`).
///
/// Fast start, gentle settle — the workhorse for entrances and UI motion.
const beuiEaseOut = Cubic(0.16, 1, 0.3, 1);

/// Symmetric ease-in-out, `cubic-bezier(0.77, 0, 0.175, 1)` (source
/// `EASE_IN_OUT`).
///
/// For motion that accelerates and decelerates, e.g. cross-fades and morphs.
const beuiEaseInOut = Cubic(0.77, 0, 0.175, 1);

/// Drawer easing, `cubic-bezier(0.32, 0.72, 0, 1)` (source `EASE_DRAWER`).
///
/// The source's dedicated curve for edge-drawer slides.
const beuiEaseDrawer = Cubic(0.32, 0.72, 0, 1);

// ---------------------------------------------------------------------------
// Reduced-motion resolver
// ---------------------------------------------------------------------------

/// Resolves [motion] against the platform's reduced-motion setting.
///
/// `motor` does **not** honor reduced motion on its own, so route
/// transform-driven tokens through this resolver. When
/// [MediaQuery.disableAnimationsOf] is true it returns a movement-free
/// [NoMotion]; otherwise it returns [motion] unchanged.
///
/// Reduced motion drops **movement**, not all animation: keep opacity and
/// color transitions running normally and only pass the tokens that produce
/// *translation/scale/rotation* through here. This is the port of the source's
/// `useReducedMotion()` gate — centralized so individual widgets don't each
/// re-check the media query.
///
/// ```dart
/// final motion = motionFor(context, beuiSpringMouse); // NoMotion if disabled
/// ```
Motion motionFor(BuildContext context, Motion motion) {
  return MediaQuery.disableAnimationsOf(context) ? const NoMotion() : motion;
}
