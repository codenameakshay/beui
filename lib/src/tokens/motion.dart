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

/// Cursor-follow physics — magnetic pull, tilt (source `SPRING_MOUSE`).
///
/// stiffness 200 · damping 15 · mass 0.3 — light and loose so the element
/// trails the pointer. Build these effects on `MouseRegion` so they never fire
/// on touch.
///
/// **Structurally different from the other four tokens.** In source `ease.ts`
/// this is the only token that omits `type: "spring"`, and `magnetic.tsx` /
/// `tilt-card.tsx` consume it via `useSpring(value, SPRING_MOUSE)` — a
/// **continuous follow-spring** whose target is re-set on every `mousemove`,
/// *not* a discrete state→state transition. Port it as a `MotionController` /
/// `SingleMotionBuilder` whose target is re-pointed on each `MouseRegion`
/// `onHover`. The other four ([beuiSpringPress], [beuiSpringSwap],
/// [beuiSpringPanel], [beuiSpringLayout]) fire on discrete state changes
/// (press, swap, open, layout shift); this one tracks the pointer every frame.
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
///
/// The source also exports `EASE_OUT_CSS` (the CSS-string form used for an
/// inline `width 220ms` transition in `action-swap.tsx`). It is the *same*
/// cubic as `EASE_OUT`, so it maps here too — there is deliberately no separate
/// `beuiEaseOutCss` constant.
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
/// `motor` does **not** honor reduced motion on its own, so every animated
/// component routes its tokens through this one resolver instead of re-checking
/// the media query. It is the port of the source's `useReducedMotion()` gate.
///
/// **The keep-opacity / drop-movement rule is enforced by the signature.** Pass
/// [isMovement] `true` for tokens that produce *translation, scale, or rotation*
/// and `false` for tokens that only drive *opacity or color*. The source's
/// reduce-branches are **heterogeneous**, so this resolver supports three
/// outcomes rather than one blanket swap:
///
/// 1. **Most components** — movement-bearing motion collapses to a movement-free
///    [NoMotion]. Call `motionFor(context, token, isMovement: true)`.
/// 2. **drawer / bottom-sheet** — keep a short (~0.18–0.2s) `EASE_OUT` entrance
///    rather than nothing. Pass it as [reducedFallback], e.g.
///    `motionFor(context, beuiSpringPanel, isMovement: true, reducedFallback:
///    const CurvedMotion(Duration(milliseconds: 190), beuiEaseOut))`.
/// 3. **magnetic / tilt** — the effect is disabled *by the component* (it renders
///    static); that is a component-level decision, not this resolver's job. The
///    resolver simply never forces movement onto those widgets.
///
/// Opacity/color transitions ([isMovement] `false`) are **never** dropped — they
/// return [motion] unchanged even under reduced motion. Reduced motion drops
/// *movement*, it is not a blanket duration-zeroing.
///
/// When reduced motion is off, [motion] is always returned unchanged.
///
/// ```dart
/// // movement → NoMotion under reduced motion
/// final pull = motionFor(context, beuiSpringMouse, isMovement: true);
/// // movement, but keep a brief curve (drawer/bottom-sheet)
/// final enter = motionFor(context, beuiSpringPanel, isMovement: true,
///     reducedFallback: const CurvedMotion(Duration(milliseconds: 190), beuiEaseOut));
/// // opacity/color → always preserved
/// final fade = motionFor(context, beuiSpringSwap, isMovement: false);
/// ```
Motion motionFor(
  BuildContext context,
  Motion motion, {
  required bool isMovement,
  Motion? reducedFallback,
}) {
  if (!MediaQuery.disableAnimationsOf(context)) return motion;
  if (!isMovement) return motion;
  return reducedFallback ?? const NoMotion();
}
