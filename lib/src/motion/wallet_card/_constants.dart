import 'package:flutter/widgets.dart';

import '../_engine.dart' show SpringMotion;

/// Shared motion + layout tokens for the wallet-card block — the Flutter port of
/// the source's `constants.ts`.

/// The trigger box grows into the full-width panel and back as one shared
/// surface. Source: `MORPH = { type: "spring", duration: 0.5, bounce: 0.22 }`.
///
/// Framer's `duration`/`bounce` spring → [SpringDescription] (mass 1):
/// `ω = 2π/0.5 ≈ 12.57`, damping ratio `ζ = 1 − bounce = 0.78`, so
/// `stiffness = ω² ≈ 158`, `damping = 2ζω ≈ 19.6`. Bouncy on purpose — the
/// panel overshoots slightly as it snaps open.
const kWalletMorph = SpringMotion(
  SpringDescription(mass: 1, stiffness: 158, damping: 19.6),
);

/// The leading icon + input in the search bar travel across the row, so they
/// glide on a **critically-damped** spring (no overshoot) rather than inheriting
/// the box's bounce — otherwise the icon reads as jittering right-then-left.
/// Source: `glide = { type: "spring", duration: 0.5, bounce: 0 }` → `ζ = 1`,
/// `stiffness = ω² ≈ 158`, `damping = 2ω ≈ 25.1`.
const kWalletGlide = SpringMotion(
  SpringDescription(mass: 1, stiffness: 158, damping: 25.1),
);

/// List reveal stagger — source `LIST` variants: `staggerChildren: 0.035`,
/// `delayChildren: 0.12`.
const int kListDelayChildrenMs = 120;
const int kListStaggerMs = 35;

/// Per-item entrance — source `ITEM` variants: from `{opacity:0, y:-6,
/// blur(3px)}` to `{opacity:1, y:0, blur(0)}`.
const double kItemOffsetY = -6;
const double kItemBlurPx = 3; // → σ1.5 via beuiBlurSigma

/// Shared padding for the account trigger + panel header (source `HEAD`:
/// `flex items-center gap-2 px-2 py-1.5`) so the avatar/name stay put as the box
/// morphs — the panel reads as the trigger itself growing open.
const EdgeInsets kHeadPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 6);
const double kHeadGap = 8;

/// Corner radius of the morphing trigger/panel surface (source `borderRadius:
/// 16`).
const double kPanelRadius = 16;
