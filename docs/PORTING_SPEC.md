# beUI Flutter — Porting Spec

The source of truth is **beUI v2** (`starc007/ui-components`, live at [beui.dev](https://beui.dev)): a React motion-component library built on Next.js 15, React 19, Tailwind 4, and `motion` (Framer Motion) v11. This document captures everything needed to port it one-to-one to a Flutter package. It is the spec; `CLAUDE.md` is the working guide.

> Goal: a published **pub.dev package** whose widgets match the source components in behavior, motion feel, and API surface — not a copy-paste registry. Fidelity of *motion* is the point of the library, so the motion-token mapping below is the most important section.

---

## 1. Motion tokens (port first — everything depends on these)

Source: `lib/ease.ts`. Framer Motion springs are parameterized by `stiffness`, `damping`, `mass` — **the exact same physical parameters as Flutter's `SpringDescription(mass, stiffness, damping)`**. This is a near-perfect 1:1 mapping; do not approximate springs with `Curves.elasticOut` etc.

### Springs → `SpringDescription`

| Token | stiffness | damping | mass | Used for |
|---|---|---|---|---|
| `SPRING_PRESS` | 500 | 30 | 0.6 | Press feedback on buttons / tappable surfaces |
| `SPRING_SWAP` | 460 | 30 | 0.55 | Content swaps (label/icon slots trading places) |
| `SPRING_PANEL` | 420 | 40 | 0.5 | Overlay panel entrances (modals, sheets) |
| `SPRING_LAYOUT` | 360 | 32 | 0.6 | Shared-layout glides (pills, indicators morphing) |
| `SPRING_MOUSE` | 200 | 15 | 0.3 | Cursor-follow physics (magnetic, tilt, dock) |

```dart
// lib/src/tokens/springs.dart
const springPress  = SpringDescription(mass: 0.6,  stiffness: 500, damping: 30);
const springSwap   = SpringDescription(mass: 0.55, stiffness: 460, damping: 30);
const springPanel  = SpringDescription(mass: 0.5,  stiffness: 420, damping: 40);
const springLayout = SpringDescription(mass: 0.6,  stiffness: 360, damping: 32);
const springMouse  = SpringDescription(mass: 0.3,  stiffness: 200, damping: 15);
```

Drive these with `AnimationController` + `SpringSimulation` (or `controller.animateWith(SpringSimulation(...))`). Framer's `layoutId` shared-element transitions map to Flutter `Hero` widgets or a hand-rolled `AnimatedPositioned`/`Stack` with a shared layout key driven by `springLayout`.

### Easing curves → `Cubic`

| Token | cubic-bezier | Flutter |
|---|---|---|
| `EASE_OUT` | `0.16, 1, 0.3, 1` | `Cubic(0.16, 1, 0.3, 1)` |
| `EASE_IN_OUT` | `0.77, 0, 0.175, 1` | `Cubic(0.77, 0, 0.175, 1)` |
| `EASE_DRAWER` | `0.32, 0.72, 0, 1` | `Cubic(0.32, 0.72, 0, 1)` |

### Motion rules (from source `AGENTS.md` + motion-patterns doc) — preserve these

- Animate **transform and opacity only**, never layout-affecting properties. In Flutter that means `Transform`/`Opacity`/`FractionalTranslation`, not animating `Padding`/`width`/`height` where avoidable.
- Blur ≤ 10px. **Exits faster than entrances.** UI animations under ~300ms; press feedback ~100–160ms.
- Icon motion should mimic the real action (bell swings from the top, download drops, copy snaps once) — no single generic bounce for every icon.
- **Reduced motion** (`useReducedMotion()` in source): in Flutter, gate transform-based motion on `MediaQuery.disableAnimationsOf(context)`. Reduced motion keeps opacity/color transitions and drops movement; it must not just zero out duration on everything.
- **Hover-capable gating** (`useHoverCapable()` in source): decorative hover effects (magnetic pull, tilt, dock magnify) must not fire on touch. Flutter's `MouseRegion` only reports real pointer devices, so building hover effects on `MouseRegion`/`onEnter`/`onExit` is the natural gate. Do not drive hover effects from `GestureDetector`.

---

## 2. Theme system

Source: `lib/themes.ts` + `app/theme.css`. A complete neutral token set (light + dark), with 11 optional color themes (`violet`, `blue`, `green`, `amber`, `blood-orange`, `rose`, `red`, `teal`, `indigo`, `lime`) that start from the neutral base and override only the **brand** tokens (`--primary`, `--primary-foreground`, `--accent`, `--accent-foreground`). Every theme exports a complete, drop-in palette.

Token set (CSS var → Flutter): `background, foreground, card, card-foreground, popover, popover-foreground, primary, primary-foreground, secondary, secondary-foreground, muted, muted-foreground, accent, accent-foreground, destructive, border, input, ring`.

**Port as a `ThemeExtension<BeuiColors>`** carrying these as `Color` fields, accessed via `Theme.of(context).extension<BeuiColors>()!`. Provide `BeuiColors.light()` / `BeuiColors.dark()` factories and per-color-theme variants.

> Source colors are **oklch** (e.g. `oklch(72% 0.18 195)`). Dart's `Color` has no oklch constructor — convert oklch→sRGB once and store the resulting `Color` literals (keep the original oklch in a comment for traceability). Do not ship a runtime oklch parser unless a component genuinely needs live hue math.

Typography: source uses Inter (sans), a mono font, and a pixel font (`--font-pixel`, Geist pixel-square) used by some components (e.g. terminal not-found). Map to a `BeuiTextTheme` or bundle the fonts in the package and reference via `TextStyle(fontFamily: ...)`.

---

## 3. Component catalog

Two categories in the source registry: **`motion`** (primitives, shown as "Components") and **`blocks`** (composed product widgets). Port the full set. Names below are the source slugs — see §4 for the Dart naming rule (many collide with Flutter built-ins).

### `motion` — primitives

| Source slug | What it does |
|---|---|
| `tilt-card` | 3D perspective tilt on hover with cursor-tracked glare |
| `button` | Spring-pressed `Button` (optional `ripple`), `StatefulButton` (idle→loading→success/error), `MagneticButton` |
| `marquee` | Infinite horizontal/vertical scroll, pause-on-hover |
| `tabs` | Pill / segment / underline tabs with spring `layoutId` indicator |
| `switch` | Toggle with spring-driven thumb + press feedback |
| `checkbox` | Animated check draw |
| `radio` | Animated radio selection |
| `bottom-sheet` | Draggable sheet with snap points, inertia, glass surface |
| `shared-layout-bg` | Pill that glides between hovered items via shared layout |
| `dock` | macOS-style dock, grouped actions, gliding active pill, hover magnify |
| `tooltip` | Hover/focus tooltip, blur enter/exit, spring spawn |
| `morphing-modal` | Panel morphing height across inner views, blur cross-fade |
| `text-animation` | `text-reveal` (word/char spring slide-up + blur), `text-shimmer` (gradient sweep), `text-cascade` (letter slot roll) |
| `number` | `number-ticker` (slot-machine digits) + `animated-number` (spring count-up in view) |
| `animated-badge` | Status badge with animated state icons + pulse |
| `action-swap` | Core swap primitives (Button/Text/Icon) with `blur`, `roll`, `cascade` variants |
| `animated-toast-stack` | Stacked toasts, status morphs, swipe dismissal, layout-aware motion |
| `theme-toggle` | Theme toggle with full-page clip-path reveal (View Transition API) |
| `bouncy-accordion` | Single-open accordion, weighted spring layout, icon rows |
| `drawer` | Edge drawer (uses `EASE_DRAWER`) |
| `scroll-animation` | Group: `smooth-scroll` (Lenis provider + hook), `scroll-progress` (bar/ring), `parallax`, `scroll-to`, `scroll-reveal` |
| `range-slider` | Range slider with tick dots, bouncy vertical-bar thumb snapping between steps, drag + keyboard |
| `magnetic` | Cursor-attracted magnetic pull wrapper |

### `blocks` — composed product widgets

| Source slug | What it does |
|---|---|
| `swap` | Cross-chain swap widget, chain/token selectors, morphing views |
| `dynamic-island` | iOS-style island pill morphing between live-activity views |
| `command-palette` | ⌘K palette, fuzzy filter, spring-animated active row |
| `expandable-action-bar` | Icon actions expanding into labeled controls on hover/focus |
| `overflow-actions` | Connected pill rail springing open to reveal extra controls |
| `expandable-tabs` | Icon tab bar; active tab expands to labeled pill with height-morphing panel |
| `swipeable-list` | Rows swipe left/right to reveal contextual action buttons |
| `file-upload` | Drag-drop upload queue, progress rows, retry/remove |
| `prediction-market` | Trade ticket, buy/sell modes, outcome prices, rolling amount entry |
| `otp-input` | OTP input, gliding focus ring, roll-in digits, error shake, success draw |
| `create-menu` | Button morphing open into grid menu via shared layout + clip-path |
| `not-found` | 404 variants: `glitch`, `magnetic`, `spotlight`, `stacked`, `terminal` |

---

## 4. React → Flutter porting conventions

| Source convention | Flutter equivalent |
|---|---|
| Named exports, one component per file | One widget per file under `lib/src/`, snake_case filenames, exported from a barrel `lib/beui.dart` |
| Every component takes `className` merged via `cn()` | Components take optional `style`/`color`/`padding` overrides; lean on `ThemeExtension` for defaults rather than per-call styling |
| `"use client"` interactive components | All widgets are stateful where they animate; use `StatefulWidget` + `SingleTickerProviderStateMixin` |
| Controlled + uncontrolled (`value`/`defaultValue`/`onChange`) | Mirror with `value` + `onChanged` (controlled) and an internal-state fallback when `value == null` — Flutter's own `Switch`/`Slider` pattern |
| Variants via props (e.g. tabs pill/segment/underline) | `enum` + named constructors or a `variant:` parameter |
| Framer `AnimatePresence` (mount/unmount animation) | `AnimatedSwitcher`, `AnimatedSize`, or explicit controllers with status listeners for exit |
| Framer `layout` / `layoutId` (shared layout) | `Hero`, or `Stack` + animated alignment/position driven by `springLayout` |
| Lenis smooth scroll | A `ScrollController`-based smooth-scroll wrapper or `scrollable_positioned_list`; `scroll-reveal`/`parallax` read scroll offset via `NotificationListener<ScrollNotification>` |

**Naming — important:** many source names collide with Flutter framework widgets (`Switch`, `Drawer`, `Tooltip`, `Checkbox`, `Radio`, `Tabs`, `Tab`). Prefix every public widget with **`Beui`** (`BeuiSwitch`, `BeuiDrawer`, `BeuiTooltip`, `BeuiButton`, …) to avoid import clashes and make the library legible at call sites. Keep the file/slug names matching the source (`switch.dart`, `drawer.dart`) for traceability.

---

## 5. What the source ships that the Flutter port does NOT need

These are React/web-only or registry infrastructure with no Flutter analog — **do not port**:

- The shadcn registry endpoints (`app/r/*`, `lib/registry*.ts`, `llms.txt`, registry JSON) — the chosen distribution is a normal pub.dev package.
- The Next.js docs website chrome (`components/app/*`, `app/*` pages, OG image generation, SEO, sitemap). The Flutter equivalent is a single **`example/` showcase app**.
- Shiki syntax highlighting, `next-themes`, Vercel analytics.

Keep an `example/` Flutter app as the living gallery (one screen/route per component) — it doubles as visual QA and the place golden tests render from.
