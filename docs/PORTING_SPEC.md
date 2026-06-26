# beUI Flutter — Porting Spec

The source of truth is **beUI v2** (`starc007/ui-components`, live at [beui.dev](https://beui.dev)): a React motion-component library built on Next.js 15, React 19, Tailwind 4, and `motion` (Framer Motion) v11. This document captures everything needed to port it one-to-one to a Flutter package. It is the spec; `CLAUDE.md` is the working guide.

> Goal: a published **pub.dev package** whose widgets match the source components in behavior, motion feel, and API surface — not a copy-paste registry. Fidelity of *motion* is the point of the library, so the motion-token mapping below is the most important section. The port is faithful but not blind: where Flutter or publishing demands it, this spec documents deliberate deviations (no arbitrary `className`; `magnetic` promoted to a public wrapper; glass-blur exception) at the point they occur.

### Contents

1. Motion tokens
2. Theme system
3. Iconography
4. Component catalog
5. Definition of done & interaction states
6. React → Flutter porting conventions
7. Platform scope
8. Accessibility & input
9. Testing & fidelity verification
10. Package, release & licensing
11. What the source ships that the Flutter port does NOT need

---

## 1. Motion tokens (port first — everything depends on these)

Source: `lib/ease.ts`. Framer Motion springs are parameterized by `stiffness`, `damping`, `mass` — the exact same physical parameters as Flutter's `SpringDescription(mass, stiffness, damping)`. The parameterization maps 1:1; do not approximate springs with `Curves.elasticOut` etc.

> Two different integrators (Framer's `motion ^11` vs Flutter/`motor`) fed identical `{stiffness, damping, mass}` need not produce identical per-frame trajectories — rest thresholds, sub-stepping and solvers differ. The same *physical parameters* carry over; treat trajectory equality as **validated within tolerance**, not guaranteed. See the Testing & fidelity verification section.

### Animation engine: `motor` (standard, not Flutter defaults)

The port uses the **[`motor`](https://pub.dev/packages/motor)** package as its motion engine instead of raw `AnimationController` + `SpringSimulation`. Rationale: `motor.SpringMotion` wraps Flutter's own `SpringDescription`, so beUI's exact physics tokens carry over with **the same physical parameters** — no manual re-tuning — while `MotionBuilder` adds independent-per-dimension spring motion for `Offset`/`Size`/`Rect`/`Alignment`/`Color`, which is exactly what beUI's hardest components need (magnetic pull, dock glide, shared-layout glides, tilt). It also unifies curves and springs under one builder API, matching beUI's mix of `EASE_*` and `SPRING_*` tokens.

**Keep `motor` an implementation detail — but be honest about the coupling.** The five shared tokens below are easy to swap, but `motor`'s builder/controller types are the animation core of nearly every component, and many components carry **bespoke local springs** (see the table below) that are equally `motor`-shaped. The "rewrite N constants" story only holds if `motor` is confined behind a thin facade. Define the shared tokens (and a `motionFor` resolver) in `lib/src/tokens/`, and route builder/controller construction through a small `lib/src/motion/_engine.dart` facade so a `motor` swap is contained rather than spread across 35 widgets. Otherwise, state the coupling plainly: it is real and per-component.

> `motor` is a single-maintainer dependency the entire library rests on. Pin tighter than `^1.1.0` — a caret on a known-good minor (e.g. `motor: '>=1.1.0 <1.2.0'`) — and bump deliberately after re-running fidelity goldens.

### Springs → `motor.SpringMotion(SpringDescription(...))`

| Token | stiffness | damping | mass | Used for |
|---|---|---|---|---|
| `SPRING_PRESS` | 500 | 30 | 0.6 | Press feedback on buttons / tappable surfaces |
| `SPRING_SWAP` | 460 | 30 | 0.55 | Content swaps (label/icon slots trading places) |
| `SPRING_PANEL` | 420 | 40 | 0.5 | Overlay panel entrances (modals, sheets) |
| `SPRING_LAYOUT` | 360 | 32 | 0.6 | Shared-layout glides (pills, indicators morphing) |
| `SPRING_MOUSE` | 200 | 15 | 0.3 | Cursor-follow physics (magnetic, tilt) |

```dart
// lib/src/tokens/motion.dart
import 'package:flutter/physics.dart';
import 'package:motor/motor.dart';

const beuiSpringPress  = SpringMotion(SpringDescription(mass: 0.6,  stiffness: 500, damping: 30));
const beuiSpringSwap   = SpringMotion(SpringDescription(mass: 0.55, stiffness: 460, damping: 30));
const beuiSpringPanel  = SpringMotion(SpringDescription(mass: 0.5,  stiffness: 420, damping: 40));
const beuiSpringLayout = SpringMotion(SpringDescription(mass: 0.6,  stiffness: 360, damping: 32));
const beuiSpringMouse  = SpringMotion(SpringDescription(mass: 0.3,  stiffness: 200, damping: 15));
```

Use `MotionBuilder`/`SingleMotionBuilder` (or a `MotionController`) to animate toward targets — no manual `SpringSimulation` wiring. Multi-dimensional targets (the magnetic `Offset`, a gliding pill's `Rect`) use `MotionBuilder` with the matching converter so each axis springs independently. `SequenceMotionBuilder` with **state sequences** ports state-machine widgets cleanly — `StatefulButton` (idle→loading→success→error), toast status morphs, OTP states. `MotionDraggable` covers drag-with-spring-return (swipeable-list reset, swap). Framer's `layoutId` shared-element transitions map to a `Stack` + `MotionBuilder<Rect>` keyed on the active item, driven by `beuiSpringLayout` (or `Hero` for route-level transitions).

> `MotionDraggable` animates spring-**return** only. Inertial **dismiss** (bottom-sheet fling-to-close, momentum past a snap point) needs a custom drag handler + physics `Simulation`, not `MotionDraggable` alone.

> **`beuiSpringMouse` is structurally different from the other four.** In source `ease.ts` it alone omits `type: "spring"`, and `magnetic.tsx`/`tilt-card.tsx` consume it via `useSpring(motionValue, SPRING_MOUSE)` — a **continuous follow-spring** whose target is re-set on every `mousemove`. Port it as a `MotionController`/`SingleMotionBuilder` whose target is re-pointed on each `MouseRegion` `onHover`, *not* as a discrete state→state transition. The other four (`PRESS`/`SWAP`/`PANEL`/`LAYOUT`) fire on discrete state changes (press, swap, open, layout shift).

### Component-local springs (do NOT replace with table tokens)

Source `AGENTS.md` explicitly sanctions one-off springs where tuning is genuinely component-specific: *"No inline `cubic-bezier` or one-off spring configs; if tuning is genuinely component-specific, keep it a named local const with a comment saying why."* These live **outside** the five-token table and are part of each component's identity — a naive "indicator → `SPRING_LAYOUT`" mapping would render tabs with the wrong physics.

| Component (source file) | stiffness / damping / mass | What it drives |
|---|---|---|
| `switch.tsx` (`THUMB_SPRING`) | 800 / 80 / 4 | Heavy, deliberate thumb travel (high mass, no wobble) |
| `tabs.tsx` (`transition`) | 170 / 24 / 1.2 | Pill/segment/underline indicator glide |
| `text-reveal.tsx` (`DEFAULT_SPRING`) | 140 / 26 / 1.2 | Word/char slide-up + blur reveal (override-able prop) |
| `animated-badge.tsx` | 210 / 24 / 0.85 (y) · 250 / 24 / 0.75 (scale) · 420 / 30 / 0.7 (icon) | Per-axis status-icon entrance + pulse |
| `otp-input.tsx` (success draw) | 500 / 28 / — | Success checkmark scale-in |
| `range-slider.tsx` (`SPRING_GLIDE` / `SPRING_BOUNCY`) | 700 / 50 / 0.5 · 500 / 14 / 0.7 | Critically-damped thumb/fill glide · bouncy grab-scale |
| `bouncy-accordion.tsx` | `{duration, bounce}` form (row 0.55/0.38, open 0.58/0.32, close 0.46/0.26, chevron 0.42/0.28) | Connected-group row/content/chevron springs |
| `overflow-actions.tsx` (`SHELL_TRANSITION`) | 220 / 17 / 0.85 | Softer-than-default shell so group stays attached to toggle |
| `expandable-action-bar.tsx` | 460 / 34 / 0.62 (item) · 380 / 32 / 0.7 (label) | Item expand · label reveal |
| `command-palette.tsx` | 560 / 40 / 0.5 (panel) · 480 / 38 (active row) | Tight panel spawn · row tracker (tighter than `SPRING_LAYOUT`) |
| `swipeable-list.tsx` (`ROW_SETTLE`) | 560 / 48 / 0.82 (+restDelta/restSpeed) | Distance-based row release, native-feeling |
| `tooltip.tsx` | 380 / 30 / 0.7 | Spring spawn (with separate opacity/blur durations) |
| `animated-toast-stack.tsx` (`STACK_SPRING`) | 420 / 34 / 0.75 | Stack reflow on enter/dismiss |
| `create-menu.tsx` (`SPRING_FOLDER` / grid item) | 320 / 24 / 0.9 · 460 / 30 | Button→grid morph · staggered grid items |
| `swap/controls.tsx` (flip) | 380 / 26 / 0.6 | Swap-direction flip rotation |
| `scroll-progress.tsx` / `parallax.tsx` | 120 / 30 / 0.6 | Smoothed scroll-driven follow (`useSpring`) |
| `not-found/terminal.tsx` (`TYPE_SPRING`) | 320 / 30 / 0.6 | Terminal type-in caret/line |

Port each as a **named local const with a `// why` comment**, mirroring source `AGENTS.md` — do not force them onto the five shared tokens. Note `bouncy-accordion` uses Framer's `{duration, bounce}` spring form (not `{stiffness, damping, mass}`); convert to physical params for `motor` and document the conversion in the comment.

### Easing curves → `motor.CurvedMotion(curve: Cubic(...))`

| Token | cubic-bezier | Flutter `Cubic` |
|---|---|---|
| `EASE_OUT` | `0.16, 1, 0.3, 1` | `Cubic(0.16, 1, 0.3, 1)` |
| `EASE_IN_OUT` | `0.77, 0, 0.175, 1` | `Cubic(0.77, 0, 0.175, 1)` |
| `EASE_DRAWER` | `0.32, 0.72, 0, 1` | `Cubic(0.32, 0.72, 0, 1)` |

Source also exports `EASE_OUT_CSS` (the CSS-string form of `EASE_OUT`, used for an inline `width 220ms` transition in `action-swap.tsx`). It is the *same* cubic as `EASE_OUT` — it maps to `beuiEaseOut` and needs no separate Dart constant.

```dart
// lib/src/tokens/motion.dart (continued) — duration is per-use; these define the curve
const beuiEaseOut   = Cubic(0.16, 1, 0.3, 1);
const beuiEaseInOut = Cubic(0.77, 0, 0.175, 1);
const beuiEaseDrawer = Cubic(0.32, 0.72, 0, 1);
// e.g. CurvedMotion(duration: Duration(milliseconds: 220), curve: beuiEaseOut)
```

### Motion rules (from source `AGENTS.md` + motion-patterns doc) — preserve these

- Animate **transform and opacity only**, never layout-affecting properties. In Flutter that means `Transform`/`Opacity`/`FractionalTranslation`, not animating `Padding`/`width`/`height` where avoidable.
- Blur ≤ 10px. **Exits faster than entrances.** UI animations under ~300ms; press feedback ~100–160ms.
- Icon motion should mimic the real action (bell swings from the top, download drops, copy snaps once) — no single generic bounce for every icon.
- **Reduced motion** (`useReducedMotion()` in source): `motor` does **not** handle this automatically — gate it yourself. The source reduce-branches are **heterogeneous**, so the resolver must support **three** outcomes, not one blanket swap:
  - Most components zero out duration → `NoMotion`.
  - `drawer`/`bottom-sheet` keep a short ~0.18–0.2s `EASE_OUT` entrance → a brief `CurvedMotion`, not nothing.
  - `magnetic`/`tilt` disable the effect entirely → the widget renders static.
  Reduced motion **keeps opacity/color transitions and drops *movement*** — it must not just zero out duration on everything. Encode the movement-vs-opacity distinction in the resolver signature (e.g. `motionFor(context, token, {required bool isMovement})`) so "keep opacity, drop movement" is enforced by the type, and centralize the check there rather than per widget.
- **Hover-capable gating** (`useHoverCapable()` in source): decorative hover effects (magnetic pull, tilt) must not fire on touch. Flutter's `MouseRegion` only reports real pointer devices, so building hover effects on `MouseRegion`/`onEnter`/`onExit` is the natural gate. Do not drive hover effects from `GestureDetector`.

---

## 2. Theme system

Source: `lib/themes.ts` + `lib/theme-css.ts` (+ `app/theme.css`). A complete neutral token set (light + dark) forms the base; on top of it sits a neutral base (`default`/Mono) plus **10** color themes (`violet`, `blue`, `green`, `amber`, `blood-orange`, `rose`, `red`, `teal`, `indigo`, `lime`) — 11 `ColorTheme` values total. Each colored theme starts from the neutral base and overrides only the **brand** tokens — `--primary`, `--primary-foreground`, `--accent`, `--accent-foreground`, and `--ring` (a hue-tinted version of the primary at alpha ~0.5 light / ~0.55 dark). Every theme exports a complete, drop-in palette.

> **Two canonical sources, two tiers.** `lib/themes.ts` holds the *inlined per-theme values* — it is the **canonical palette source** (port colors from here). `lib/theme-css.ts` is an aliased `var()` graph (`--destructive` = `--danger`, `--input` = `--border`, `--ring` = `--border-strong`) and is where the **extension/glass/alias tier** lives — consult it for `--border-strong`, the glass family, and to resolve which base token an alias points at.

### Core token set (18) — CSS var → Flutter `Color`

`background, foreground, card, card-foreground, popover, popover-foreground, primary, primary-foreground, secondary, secondary-foreground, muted, muted-foreground, accent, accent-foreground, destructive, border, input, ring`.

### Second tier — components consume these, so `BeuiColors` must carry them

`theme-css.ts` defines tokens beyond the core 18 that real components read:

| Extra token | Source | Consumed by |
|---|---|---|
| `--border-strong` | `oklch(15% 0 0 / 0.12)` light · `rgb(255 255 255 / 0.1)` dark (and what `--ring` aliases) | switch, dock, radio, checkbox, otp-input |
| `--glass-bg` | `oklch(99% 0 0 / 0.55)` · `rgb(28 28 28 / 0.55)` | ~10 overlay/surface components |
| `--glass-border` | `oklch(15% 0 0 / 0.08)` · `rgb(255 255 255 / 0.08)` | glass surfaces |
| `--glass-strong-bg` | `rgb(255 255 255 / 0.7)` · `rgb(28 28 28 / 0.6)` | bottom-sheet, modal, command-palette |
| `--glass-thin-bg` | `rgb(255 255 255 / 0.45)` · `rgb(21 21 21 / 0.45)` | lighter overlays |

**Port as a `ThemeExtension<BeuiColors>`** carrying the core 18 as `Color` fields, accessed via `Theme.of(context).extension<BeuiColors>()!`. Extend it with:

- `borderStrong` (and let `ring` default to it where a theme doesn't override),
- `accentForeground` (if not already present in the core fields),
- a small **glass sub-API** — `bg` / `border` / `strong` / `thin` colors plus the glass blur radii — grouped so overlay components read one cohesive surface descriptor.

Provide `BeuiColors.light()` / `BeuiColors.dark()` factories and per-color-theme variants.

> **Color formats are mixed — do not assume oklch everywhere.** Source tokens mix **oklch**, **raw hex** (`#151515`, `#1c1c1c`), and **rgb()/oklch *with alpha*** (dark `--border`/`--input`/`--ring` = `rgb(255 255 255 / 0.05)`; light base + every brand tint use oklch-with-alpha, e.g. `oklch(15% 0 0 / 0.06)`, tints `… / 0.5`). The build-time precompute (oklch→sRGB done once, results stored as `Color` literals) must:
> 1. **preserve alpha** into the Dart `Color` (don't drop the `/ a` term),
> 2. **pass hex/rgb literals straight through** — do NOT route them through the oklch converter.
> Keep the original literal in a `//` comment for traceability. Do not ship a runtime oklch parser unless a component genuinely needs live hue math.

```dart
// oklch-with-alpha → precompute oklch(15% 0 0) → sRGB, keep the / 0.06 alpha
static const border = Color(0x0F262626); // oklch(15% 0 0 / 0.06)
// raw hex → pass straight through, no oklch conversion
static const backgroundDark = Color(0xFF151515); // #151515
```

> **Blur conflict — glass is a documented exception.** The motion rules cap blur at **≤ 10px**, but `theme-css.ts` glass surfaces use **12–20px** backdrop blur (`glass` 20px, `glass-strong` 16px, `glass-thin` 12px). Treat glass-surface blur as a *deliberate, documented exception* to the cap (or reconcile it explicitly) — flag it here so the rule isn't silently violated when porting overlays.

### Switching axes & picker

Brightness (light/dark) and `colorTheme` are **independent, runtime-combinable** axes — `BeuiColors` variants must be selectable on both (any color theme × either brightness), and each variant must expose `name` + a `swatch` color (distinct from `--primary`; `THEME_LIST` carries both) for a theme picker.

> The CSS-export feature (`themeExportCss` / copyable `:root`/`.dark` blocks) is **out of scope** — no Flutter analog.

### Typography

**Do not bundle fonts in the published package.** Expose family names via `BeuiTextTheme` and let consumers wire fonts themselves (pubspec `fonts:` or `google_fonts`), falling back to the platform monospace when the mono family is absent.

- Sans: **Inter**.
- Mono: **JetBrains Mono** (OFL, loaded via `next/font/google` in source) — *not* Geist Mono.
- The pixel font (`--font-pixel`) is **docs-site chrome only**; **no portable library component uses it**, so it is not part of the port.

The published package ships **no bundled fonts**; only the `example/` gallery may bundle Inter/JetBrains Mono for visual parity.

---

## 3. Iconography

Source uses **`lucide-react`** for all glyphs. ~15 of the ~35 catalog components import it — roughly half the library, so an icon decision blocks the port. Representative dependants: `animated-badge`, `animated-toast-stack`, `command-palette`, `bouncy-accordion`, `overflow-actions`, `action-swap`, `file-upload`, `create-menu`, `prediction-market`, `swap` (+ its `controls`/`field`/`quote-row`/`token-picker` parts), `theme-toggle`, and `StatefulButton`. The icon type even **leaks into the public API**: `animated-badge` and `animated-toast-stack` type their status maps as `Record<Status, LucideIcon>` and `command-palette` types `icon?: LucideIcon` on a public prop — so the choice isn't just internal defaults, it shapes the widget surface.

### Default icon source

Use **[`lucide_icons`](https://pub.dev/packages/lucide_icons)** (Lucide ported as a Flutter `IconData` font) for visual parity with the source. Re-export it through the barrel `lib/beui.dart` so consumers get the defaults without adding a second dependency. **This is a consumer-facing transitive dependency cost** — anyone adding `beui` inherits the Lucide icon font (its bundle weight and version) whether or not they touch a defaulted icon. State this plainly in the package README. (`flutter_lucide` is an acceptable equivalent if `lucide_icons` lags on Lucide releases; pick one and pin it in `lib/src/tokens/` — never import it ad hoc across widgets, same discipline as the `motor` rule in **Motion tokens**.)

### Public API rule for icon props

Mirror the source's two prop shapes:

| Source prop type | Meaning | Flutter prop |
|---|---|---|
| `icon?: LucideIcon` (component ref) | "pick a Lucide glyph" | `IconData? icon` |
| `icon?: ReactNode` (rendered node) | "drop in any element" | `Widget? icon` |

A component that takes an icon accepts **`IconData`** (the common case — consumer substitutes any glyph) and/or **`Widget`** (escape hatch for fully custom content), exactly mirroring the `LucideIcon`-vs-`ReactNode` split already in the source. Components with a fixed status set (`animated-badge`, `animated-toast-stack`) ship default icons pulled from the chosen Lucide package; consumers may override per-status. No public widget should expose a `lucide_icons`-specific type — `IconData` is framework-native, so swapping the icon package later touches the defaults table, not the API. This honors the controlled/uncontrolled spirit in **React → Flutter porting conventions**: a sensible default with a clean override.

### Inline glyphs are not assets

Where the source hand-draws a mark instead of using Lucide (`otp-input`'s success-check `<svg>` draw, `scroll-progress`'s ring), port it as Flutter `Icon`/`Text`/`CustomPaint`, **not** a bundled SVG/image asset — the OTP success stroke is an animated `CustomPaint` path, the progress ring is a `CustomPaint` arc. Text-rendered marks become `Text`. **No icon font or image asset is bundled beyond the chosen Lucide package's** — the package ships zero `assets/` icons of its own.

### Risk / escape hatch

If no Lucide-for-Flutter package proves acceptable (stale, unmaintained, or licensing concern), drop the default icon dependency entirely: icon params become **required** (`required IconData icon` / `required Widget icon`) with no defaults, pushing the icon choice onto the consumer. This keeps the library icon-agnostic at the cost of more verbose call sites and a from-scratch default set in the `example/` gallery. Prefer the re-exported-default approach; treat required-params as the fallback, not the baseline.

---

## 4. Component catalog

Two categories in the source registry: **`motion`** (primitives, shown as "Components") and **`blocks`** (composed product widgets). The registry documents **22 `motion` primitives + 12 `blocks`**; port the full set. Names below are the source slugs — see the React → Flutter porting conventions section for the Dart naming rule (many collide with Flutter built-ins).

> Note: the source stores **both** `motion` and `blocks` files under `components/motion/` (with sub-folders for multi-file widgets like `button/`, `swap/`, `not-found/`). The primitives/blocks split in the port is a deliberate organizational choice driven by each entry's registry `category` field — it is *not* a 1:1 mirror of the source folder layout.

### `motion` — primitives

| Source slug | What it does |
|---|---|
| `tilt-card` | 3D perspective tilt on hover with cursor-tracked glare |
| `button` | Spring-pressed `Button` (optional `ripple`), `StatefulButton` (idle→loading→success/error), `MagneticButton` |
| `marquee` | Infinite horizontal/vertical scroll, pause-on-hover |
| `tabs` | Pill / segment / underline tabs with spring `layoutId` indicator |
| `switch` | Toggle with spring-driven thumb + press feedback |
| `checkbox` | Animated check draw, press feedback, indeterminate (tri-state) state |
| `radio` | Animated selection; gliding `layoutId` indicator dot; public widget is a group (`BeuiRadioGroup` + items) |
| `bottom-sheet` | Draggable sheet with snap points, inertia, glass surface |
| `shared-layout-bg` | Pill that glides between hovered items via shared layout |
| `dock` | macOS-style dock with grouped actions and a gliding active pill (shared layout, `SPRING_LAYOUT`) |
| `tooltip` | Hover/focus tooltip, blur enter/exit, spring spawn |
| `morphing-modal` | Panel morphing height across inner views, blur cross-fade |
| `text-animation` | `text-reveal` (word/char spring slide-up + blur), `text-shimmer` (gradient sweep), `text-cascade` (letter slot roll) |
| `number` | `number-ticker` (slot-machine digits) + `animated-number` (in-view count-up — a *tween*, `animate(from, value)` over a duration with `EASE_OUT`; maps to `CurvedMotion(beuiEaseOut)`, not a `SpringMotion`) |
| `animated-badge` | Status badge with animated state icons + pulse |
| `action-swap` | Core swap primitives (Button/Text/Icon) with `blur`, `roll`, `cascade` variants |
| `animated-toast-stack` | Stacked toasts, status morphs, swipe dismissal, layout-aware motion |
| `theme-toggle` | Theme toggle with full-page clip-path reveal. Source is built on the **View Transition API** + clip-path (no clean Flutter analog) — port as a custom `ClipPath`/circular-reveal overlay, or documented reduced parity. See the Platform scope section. |
| `bouncy-accordion` | Single-open accordion, weighted spring layout, icon rows |
| `drawer` | Edge drawer (uses `EASE_DRAWER`) |
| `scroll-animation` | Group: `smooth-scroll` (Lenis provider + hook), `scroll-progress` (bar/ring), `parallax`, `scroll-to`, `scroll-reveal` |
| `range-slider` | Range slider with tick dots, bouncy vertical-bar thumb snapping between steps, drag + keyboard |
| `magnetic` | Cursor-attracted magnetic pull wrapper. **Derived/foundational** — the source has **no standalone `magnetic` registry slug**; it lives at `components/motion/button/magnetic.tsx` and is exposed only through composition (`MagneticButton` via `button-magnetic`, and the `not-found-magnetic` variant). The port may deliberately surface it as `BeuiMagnetic`, but treat that as a **promotion**, not a 1:1 registry component. |

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
| `file-upload` | Drag-drop upload queue, progress rows, retry/remove. Needs drag-drop + a file picker (desktop-focused; requires a file-picker plugin — no clean mobile analog). See the Platform scope section. |
| `prediction-market` | Trade ticket, buy/sell modes, outcome prices, rolling amount entry |
| `otp-input` | OTP input, gliding focus ring, roll-in digits, error shake, success draw |
| `create-menu` | Button morphing open into grid menu via shared layout + clip-path |
| `not-found` | 404 variants: `glitch`, `magnetic`, `spotlight`, `stacked`, `terminal` |

---

## 5. Definition of done & interaction states

The one-line entries in the component catalog name *what a widget is*, not *what it does on its public surface*. Every interactive source component ships interaction states, a keyboard contract, ARIA roles/state flags, and a controlled/uncontrolled API that the catalog sentence omits. **This section — not the catalog — is the porting contract.** A component is done only when it clears the rubric below; the catalog is just the index of what to build.

### Part A — Definition-of-Done rubric

A component is *done* when **all** of the following hold (this extends, not replaces, `CLAUDE.md`'s structural gate of *widget under `lib/src/` + barrel export + example route + test*):

- [ ] **Controlled + uncontrolled API ported.** A `value` (or `checked`/`open`/`viewId`) + `onChanged` pair, with an internal-state fallback when the value param is null — the Flutter `Switch`/`Slider` convention (see the React→Flutter conventions table). Match the source's exact split (e.g. `RadioGroup` controls `value`/`defaultValue`/`onValueChange` at the group, items are stateless).
- [ ] **All source variants exposed.** Every variant present in source is reachable via a Dart `enum` parameter or named constructor — tabs `pill`/`segment`/`underline`, button `primary`/`secondary`/`ghost`/`outline` × `sm`/`md`/`lg`/`icon`, file-upload `default`/`centered`, drawer `left`/`right`, action-swap `blur`/`roll`/`cascade`. Don't ship a subset.
- [ ] **Every applicable interaction state implemented** — idle / hover / focus(-visible) / pressed / disabled / loading / success / error — wherever the source has it. The non-obvious ones (disabled-press shake, focus-vs-pointer distinction, error-shake, success-draw, indeterminate, `aria-busy` lockout) are itemized per component in Part B; implement what that row lists, not just the happy path.
- [ ] **Keyboard contract matched** to source key-for-key (see Part B and the Accessibility & input section). Where source has none (pure pointer/drag widgets), add Flutter-idiomatic focus + activation rather than inventing bindings absent upstream.
- [ ] **`Semantics` role + state flags set** — the Flutter analog of the source's `role`/`aria-*` (see the Accessibility & input section). E.g. `Semantics(toggled:)` for switch/checkbox, `checked`/`inMutuallyExclusiveGroup` for radio, `selected` for tabs, `value`/`increasedValue`/`decreasedValue` for the slider, `liveRegion` for stateful-button/dynamic-island/file-upload status.
- [ ] **Reduced-motion behavior correct** — resolved through the central token resolver (see the Motion tokens section), never an ad-hoc check. Movement-bearing tokens degrade to `NoMotion` or a short curve while opacity/color transitions are kept; transform-only flourishes (shake, magnetic, tilt, cascade roll) are dropped, not merely zero-durationed.
- [ ] **Fidelity test** asserting (a) the correct token drives the correct property (the spring/curve a property animates under is the one the source maps to), and (b) under reduced motion the widget produces **no transform delta** — opacity/color may still settle (see the Testing & fidelity verification section).
- [ ] **A rest-state golden** (and any load-bearing variant/state goldens) committed.
- [ ] **Dartdoc on the entire public API** — widget, every public param, and each variant enum value (see the Package, release & licensing section).
- [ ] **An `example/` gallery route** exercising the variants and the non-obvious states (disabled, error, success, loading) so the route doubles as visual QA and the golden render target.

Per-component exact props and exact key bindings live in each component's port as it is built; this section sets the bar and captures the non-obvious states the catalog omits.

### Part B — Interaction-state matrix (interactive components)

Pure display primitives — `marquee`, `text-reveal`/`text-shimmer`/`text-cascade`, `number-ticker`/`animated-number`, `scroll-*`, `parallax`, `shared-layout-bg` — are **exempt** from Part B (no interaction states; they still owe the Part A reduced-motion, token-fidelity, golden, and dartdoc bars). The stateful/interactive set, verified against source:

| Component | States beyond the obvious | Keyboard | Semantics role / flags | Reduced-motion |
|---|---|---|---|---|
| **switch** | focus-visible ring; pointer-press thumb squish; disabled-press **shake** (pointer only, delayed); pointer-vs-keyboard gate | native button activation | `role="switch"`, `aria-checked`, `disabled` | thumb spring → 0; no squish, no shake |
| **checkbox** | indeterminate (**mixed**); whileTap scale; focus-visible ring; check-draw vs indeterminate-bar draw | native activation | `role="checkbox"`, `aria-checked` = true/false/**mixed** | mark appears instant (opacity only), no scale/path-draw |
| **radio** | group selection; whileTap scale; focus-visible ring; selected dot **glides** between items (shared layout) | native activation | group `role="radiogroup"`; item `role="radio"`, `aria-checked` | dot crossfades in place, no glide |
| **tabs** | hover text color; active indicator **glides** (pill/segment/underline); panel fade-in | native activation | `role="tablist"`/`tab` (`aria-selected`); panel content | indicator jumps; panel fades, no y-offset |
| **button (base)** | hover scale (hover-capable only); whileTap press scale; optional ripple from press point; disabled lockout | native activation | native button; `disabled` | no hover/press scale; ripple suppressed |
| **button (stateful)** | idle→loading→success→error; per-state icon + text swap (cascade letters); width morph; busy lockout | inherits base; disabled while loading | `aria-busy`; `aria-live="polite"` status text | icon/text crossfade, no cascade/roll/blur |
| **range-slider** | grab/active thumb scaleY; spring-glide fill+thumb; snap-to-step; disabled | Arrow←↑→↓ ±step, Home=min, End=max (**no PageUp/Down in source**) | `role="slider"`, `aria-valuemin/max/now`, `aria-disabled`; `tabIndex` off when disabled | position follows raw value (no spring); no thumb scale |
| **otp-input** | idle/error/success; active-slot caret; digit roll-in; **error-shake**; **success check-draw**; mask; autoFocus; `onComplete` on empty→full | digit insert, Backspace (clear/step-back), Delete, ←→, Home, End; paste + SMS autofill | hidden input `aria-label`, `aria-invalid`; `aria-live` message | digits fade in place; no shake, no draw, caret static |
| **command-palette** | open/closed; query filter; active row **glides**; hover sets active; scroll-into-view | **⌘/Ctrl+K** toggle, **Esc** close, ↑↓ nav, Enter select; autofocus input | `role="dialog"`+`aria-modal`; input `combobox`+`aria-activedescendant`; `listbox`/`option` `aria-selected` | panel/overlay fade (no y/scale); active-row jump |
| **bottom-sheet** | drag with snap points; velocity fling (next snap / dismiss); body scroll-lock; backdrop dismiss | (none in source — pointer drag) | `role="dialog"`, `aria-modal`, `aria-label` | enters via opacity not y-translate |
| **drawer** | left/right; backdrop fade; `dismissable` gates backdrop; body scroll-lock | **Esc** close | `role="dialog"`, `aria-modal`, `aria-label`; backdrop is labeled Close button | enters via opacity not x-slide |
| **morphing-modal** | open(null=closed); height morph across views; per-view blur crossfade; backdrop dismiss; scroll-lock | (none in source) | `role` via container `aria-hidden` toggle | view crossfade opacity-only, no y/blur/scale |
| **tooltip** | hover **and** focus open; open delay + warm-window (instant after recent close); blur enter/exit; hover-capable gate | opens on focus, closes on blur | `role="tooltip"`; trigger `aria-describedby` | opacity-only fade, no scale/blur/offset |
| **bouncy-accordion** | single-open; collapsible; height + corner-radius morph; chevron rotate; focus-visible bg; disabled row | native trigger activation | trigger `aria-expanded`+`aria-controls`; panel `role="region"`+`aria-labelledby`+`aria-hidden` | instant open/close; no bounce, chevron snaps |
| **expandable-tabs** | bar-only(null) vs expanded; shell width/height morph; active tab expands to labeled pill; label blur-in; outside-click/Esc close | **Esc** close; focus-visible ring | `role="tablist"`+`aria-orientation`; tab `aria-selected`+`aria-label` | shell resizes instant; label width only, no blur |
| **swipeable-list** | drag-reveal left/right rails; distance+velocity snap open/close; only one row open; per-action tone; disabled row | rail buttons focusable **only when that side is open** (`tabIndex`) | action buttons `aria-label`; rail `aria-hidden` when closed | reveal snaps to target (no settle spring) |
| **file-upload** | dropzone idle/hover/**dragging**/focus/disabled/max-reached; per-row queued/uploading/success/error; retry on error; remove | dropzone is a button (Enter/Space → file picker); hidden input `tabIndex=-1` | `role="progressbar"` (`aria-valuenow`); status `sr-only`; per-action `aria-label` | rows fade (no y); progress sets `scaleX` directly; spinner `animate-none` |
| **create-menu** | trigger↔panel **morph** (shared layout); whileTap trigger scale; grid clip-path reveal + staggered items; outside-click/Esc close | **Esc** close | trigger `aria-haspopup="menu"`+`aria-expanded` | morph timing collapses; items fade, no scale/blur/stagger; clip-path skipped |
| **dynamic-island** | compact pill ↔ expanded view (`view=null` = pill); shell width/height **morph** to measured content; slot unfurl/suck-back | (none — driven by `view` prop) | `role="status"`, `aria-live="polite"` | shell resize instant; slots opacity-only, no scale/y/blur |

---

## 6. React → Flutter porting conventions

| Source convention | Flutter equivalent |
|---|---|
| Named exports, one component per file | One widget per file under `lib/src/`, snake_case filenames, exported from a barrel `lib/beui.dart` |
| Every component takes `className` merged via `cn()` | Each component exposes an immutable `Beui<Component>Style` data class (fields resolved from `BeuiColors`, with `copyWith`) **or** a documented, fixed set of named override params (`color`/`padding`/`borderRadius`/…). Defaults come from the `ThemeExtension`. Arbitrary `className`-style overriding is **intentionally not ported** — a deliberate fidelity/API trade-off (an open style hole would let callers break the motion-critical layout the components depend on) |
| `"use client"` interactive components | Stateful widgets driving `motor` builders/controllers; use `StatefulWidget` (+ `SequenceMotionController` etc. where a sequence is held) |
| Controlled + uncontrolled (`value`/`defaultValue`/`onChange`) | Mirror with `value` + `onChanged` (controlled) and an internal-state fallback when `value == null`, seeded from a `defaultValue`/`initialValue` constructor arg — Flutter's own `Switch`/`Slider` pattern. Follow the source's split rule (from `AGENTS.md`): larger components (tabs, range-slider, otp-input, **radio**) support both; simple toggles (switch, checkbox) are controlled-only. Radio is *not* controlled-only — it carries `value`/`defaultValue` + internal state |
| Variants via props (e.g. tabs pill/segment/underline) | `enum` + named constructors or a `variant:` parameter |
| Framer `AnimatePresence` (mount/unmount animation) | `AnimatedSwitcher`/`AnimatedSize` for simple in-place swaps (use `AnimatedSwitcher.reverseDuration` to honor "exits faster than entrances"); `SequenceMotionBuilder` state sequences for status-driven widgets (stateful button, toasts, OTP). Note: `AnimatedSwitcher` does **not** animate exit-before-unmount during list reflow — for list-removal-with-reflow (toast stack's `mode="popLayout"`, file-upload rows, swipeable-list) use `AnimatedList`/`SliverAnimatedList` so neighbors glide into the vacated slot |
| Framer `layout` / `layoutId` (shared layout) | `Stack` + `MotionBuilder<Rect>` keyed on the active item driven by `beuiSpringLayout`; `Hero` for route-level transitions |
| `ResizeObserver` / `getBoundingClientRect` / `offsetWidth` (runtime element measurement) | `GlobalKey` + `RenderBox` (`localToGlobal` / `.size`) read in a post-frame callback (`addPostFrameCallback`), wrapped in **one** reusable `MeasureSize` helper; feed the resulting `Rect`/`Size` into `MotionBuilder<Rect>`/`<Size>` with `beuiSpringLayout`. The source hand-rolls this in expandable-tabs, overflow-actions, dynamic-island, range-slider, bouncy-accordion, tilt-card and action-swap — dynamic-island even comments that the observer fires async after mount. Mirror that **one-frame-late caveat** (the first measured value lands a frame after layout; spring toward it, don't snap), and route **every** shared-layout / measure-driven component through the same helper so the timing is identical |
| `createPortal` → `document.body` / fixed-overlay | `Overlay` / `OverlayEntry` (or `OverlayPortal`); animate entry with `beuiSpringPanel`. Source uses `createPortal` in command-palette, bottom-sheet and animated-toast-stack, with in-tree `fixed inset-0` for morphing-modal and drawer. Note: decide **once**, library-wide, between an imperative `show()`/controller surface and a declarative `open` + `onOpenChange` surface, and keep it consistent. Flutter `Transform`/`ClipRect` ancestors create the same containing-block hazards the source's bottom-sheet comment warns about (a transformed ancestor re-parents fixed/positioned descendants); `Overlay` escapes the ancestor chain and avoids them |
| Global `keydown` (Escape, ⌘K) | `Shortcuts`/`Actions` or `Focus(onKeyEvent:)` at the overlay root. Source: global ⌘/Ctrl+K + Escape in command-palette; Escape-to-close in drawer, create-menu, expandable-tabs and swap's token-picker. Map ⌘/Ctrl to `LogicalKeyboardKey.meta` / `.control` (meta on macOS/iOS, control on others). Use the modern key API (`HardwareKeyboard` / `Focus`'s `onKeyEvent`), **not** the deprecated `RawKeyboardListener`. See the *Accessibility & input* section |
| Element-level `onKeyDown` (Arrow / Enter / Home / End nav) | `Focus(onKeyEvent:)` on the focused element. Source: Arrow/Enter row-nav in command-palette, and Arrow/Home/End value-nav in range-slider and otp-input. Same modern key API as above; cross-ref the *Accessibility & input* section |
| Imperative focus + `:focus-visible` rings + focus trap | `inputRef.focus()` → `FocusNode.requestFocus()` (in a post-frame callback, matching command-palette's `requestAnimationFrame(() => inputRef.focus())` on open); `:focus-visible` rings (present across ~11 components) → `FocusableActionDetector` (keyboard-vs-pointer aware); overlay focus trap → `FocusScope`. The OTP input's animated focus ring is a measured `Rect` glided with `beuiSpringLayout`, not a static outline |
| Framer variants spring per dimension (`x`/`y`/scale) | `MotionBuilder` with the matching converter (`Offset`/`Size`/`Rect`/`Alignment`/`Color`) — each axis springs independently |
| Lenis smooth scroll | Port as a **provider** (Lenis's `root` page-level vs `root={false}` contained scope) exposing offset / progress / velocity and an imperative `scrollTo`, consumed by a hook-equivalent (`InheritedWidget` + `of(context)`); `scroll-progress` (bar/ring), `parallax`, `scroll-to` and `scroll-reveal` read from it. Honor reduced motion the way the source does — the `lenis = null` path is a **native `ScrollPhysics` bypass** (hand control back to the platform scroller), not merely zeroed durations |

**Naming — important:** many source names collide with Flutter framework widgets (`Switch`, `Drawer`, `Tooltip`, `Checkbox`, `Radio`, `Tabs`, `Tab`). Prefix every public widget with **`Beui`** (`BeuiSwitch`, `BeuiDrawer`, `BeuiTooltip`, `BeuiButton`, …) to avoid import clashes and make the library legible at call sites. Keep the file/slug names matching the source (`switch.dart`, `drawer.dart`) for traceability.

---

## 7. Platform scope

The source never declares a target platform. Its `useHoverCapable()` gating implies desktop/web, but a pub.dev package's dominant consumers are mobile (iOS/Android). Resolve it explicitly: **support all six Flutter targets — mobile + web + desktop — with per-feature degradation. Hover-only flourishes degrade gracefully on touch; nothing is hover-or-nothing.**

### Hover-gated components on touch

`useHoverCapable()` is used by exactly these components (repo-wide grep, excluding the docs-only `press-link`). On touch, the hook returns false; each must stay **functional**, dropping only the decorative flourish:

| Component | Hover flourish | Touch fallback |
|---|---|---|
| `magnetic` | Cursor-attracted pull | **Omitted flourish, functional** — renders its child statically (no pull); taps pass through. |
| `tilt-card` | 3D perspective tilt + glare | **Omitted flourish, functional** — flat card, content intact; optional tap-press scale only. |
| `tooltip` | Hover/focus spawn | **Tap-driven** — long-press / tap to reveal (and focus still works); no hover trigger. |
| `overflow-actions` | Hover springs the pill rail open | **Tap-driven** — tap the rail to expand/collapse instead of hover. |
| `button` (base) | Hover-scale lift | **Omitted flourish, functional** — no lift; press-feedback (tap-scale) remains. |
| `not-found` `magnetic` variant (`not-found/shared` + `magnetic.tsx`) | Magnetic CTA pull | **Omitted flourish, functional** — static CTAs, still navigable. |
| `not-found` `stacked` variant | Hover-driven card spread | **Static** — renders the resting stacked state; CTAs work. |
| `not-found` `spotlight` variant | Cursor-tracked spotlight | **Static** — fixed/centered spotlight (or none); CTAs work. |

Policy in one line: hover effects build on `MouseRegion` (which never fires on touch), so the touch path is the **default** render — no separate touch branch needed for the pure flourishes; only `tooltip` and `overflow-actions` need an explicit tap affordance because their *reveal* is the hover, not just decoration.

### Platform-API-bound components (plugins / reduced parity)

- **`file-upload`** — uses a `type="file"` picker plus OS drag-drop (`onDrop` / `dataTransfer.files`). Drag-drop is **desktop/web only**; needs a file-picker plugin (e.g. `file_picker`) for the picker on all platforms, and a desktop drop target (`super_drag_and_drop` / `desktop_drop`) for the drag path. **On mobile: tap-to-pick only, no OS drag-drop.** The upload queue / progress / retry UI is platform-agnostic and ships everywhere.
- **`theme-toggle`** — uses the View Transition API (`startViewTransition`) with clip-path circle/inset reveals. No Flutter equivalent of View Transitions; implement the reveal as a **custom `ClipPath` animation on every platform** (so the reveal is uniform, not web-only). The toggle itself works everywhere; the clip-path flourish is the port target, not the browser API.

### Wiring

- The pubspec **`platforms:`** declaration must be driven by this section — list every target that has at least the functional (degraded) path, i.e. all six. Do not silently drop mobile because hover flourishes don't apply.
- The **`example/` gallery must be runnable on at least mobile + web** so both the touch path (degraded flourishes, tap-driven reveals, tap-to-pick upload) and the hover path (magnetic / tilt / tooltip / hover-scale) are verifiable. Golden tests should cover both states where a component diverges by pointer type.

---

## 8. Accessibility & input

The source authors a11y by hand — explicit `role`/`aria-*` on every control, manual keyboard handlers, `tabIndex` toggling for disabled state — and backs it with a **jest-axe suite** (`tests/a11y.test.tsx`) that CI runs on every PR and push (`bun test` in `.github/workflows/ci.yml`). None of that has carried into this spec. It must. The axe suite is a ready-made porting checklist; treat its component-state list as the minimum.

### Semantics on every stateful control (required)

Wrap each interactive widget in `Semantics` and map the source's `role`/`aria-*` to Flutter Semantics properties. Defaults from `Theme`/material widgets are not enough — the source sets these explicitly, so the port must too.

| Source control | Source aria/role | Flutter `Semantics` |
|---|---|---|
| `BeuiSwitch` | `role="switch"` + `aria-checked` | `toggled: value` |
| `BeuiCheckbox` | `role="checkbox"` + `aria-checked` (incl. `"mixed"`) | `checked: value` / `mixed: tristate` |
| `BeuiRadio` | `role="radio"` + `aria-checked` | `checked: selected`, `inMutuallyExclusiveGroup: true` |
| `BeuiRangeSlider` | `role="slider"` + `aria-valuenow/min/max` | `value`, `increasedValue`, `decreasedValue`, `onIncrease`/`onDecrease` |
| `BeuiTabs` (trigger) | `role="tab"` + `aria-selected` | `selected: isActive`, `button: true` |
| `BeuiMorphingModal` / `BeuiDrawer` / `BeuiBottomSheet` / `BeuiCommandPalette` | `role="dialog"` + `aria-modal` + label | `scopesRoute: true`, `namesRoute: true`, `label:`; trap focus with `FocusScope` |
| `BeuiAnimatedToastStack` / `BeuiAnimatedBadge` status | live status text | `liveRegion: true` |
| `BeuiButton` / `BeuiStatefulButton` | `<button>` + `aria-busy` in loading | `button: true`, `enabled:`, announce loading via `liveRegion` |

Decorative-only wrappers (`Magnetic`, `TiltCard`, `Parallax`, `Marquee`, `ScrollReveal`) add no role but **must not swallow** their child's semantics — never wrap them in `ExcludeSemantics`; merge with `Semantics(container: false)` or pass through.

### Keyboard parity (required)

Every behavior the source exposes to keyboard must work in Flutter — see **React → Flutter porting conventions** for the controlled/uncontrolled mapping and **Definition of done** for the gate. Concretely: toggles fire on Space/Enter; slider responds to arrow keys (`onIncrease`/`onDecrease` + a `Shortcuts`/`Actions` block for page steps); tabs move with arrow keys and wrap; modals/palette/drawer close on Escape and trap focus; OTP advances/backspaces across fields; command palette navigates rows with Up/Down and commits with Enter. Drive these through `Shortcuts` + `Actions` or `FocusableActionDetector`, not ad-hoc `RawKeyboardListener`.

### RTL via `Directionality` (required)

Direction-sensitive components must read `Directionality.of(context)` rather than hardcoding left/right:

- **`BeuiDrawer`** — edge side (a `left` drawer is on the `right` in RTL unless explicitly pinned).
- **`BeuiTabs` / `BeuiMarquee`** — indicator glide and scroll direction.
- **`BeuiSwipeableList`** — reveal side of action buttons mirrors.
- **`BeuiRangeSlider`** — value-to-position axis flips.

Build offsets from `AlignmentDirectional`/`EdgeInsetsDirectional` and resolve against text direction; do not feed raw `dx` into the magnetic/layout springs without mirroring first.

### Focus visibility & traversal

- **focus-visible:** distinguish keyboard focus from pointer focus with `FocusableActionDetector` (`onShowFocusHighlight`) — render the focus ring only for keyboard focus, matching the source's `:focus-visible` styling. The OTP gliding focus ring and tabs ring are keyboard-driven.
- **disabled = unfocusable:** the source toggles `tabIndex` to pull disabled controls out of tab order. Mirror with `Focus(canRequestFocus: false, skipTraversal: true)` (or `enabled: false` on the action detector) so disabled `BeuiButton`/`BeuiSwitch`/etc. are skipped by traversal and excluded from semantics actions.

### a11y as a CI gate

Port the source suite to `flutter_test` semantics matchers and run it in CI alongside `flutter analyze && flutter test`:

```dart
// Per-control: structural a11y assertions
expect(tester.getSemantics(find.byType(BeuiSwitch)), matchesSemantics(
  isToggled: false, hasToggledState: true, isEnabled: true, isFocusable: true,
));

// Per-screen: WCAG guideline checks
final handle = tester.ensureSemantics();
await expectLater(tester, meetsGuideline(textContrastGuideline));
await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
handle.dispose();
```

**The source axe suite enumerates ~18 component states** (`Button`/`Button disabled`/`Button ripple`, `CreateMenu`, `Switch`, `AnimatedBadge`, `SmoothScroll`, `ScrollProgress` bar/circle, `Parallax`, `ScrollTo`, `RangeSlider`, `Checkbox`, `RadioGroup`, `ScrollReveal`, `TextReveal`, `Tooltip`, `Tabs`). That set is the **minimum** a11y-test coverage to port — add a row whenever a new interactive widget ships, exactly as the source instructs in its test header.

---

## 9. Testing & fidelity verification

The library's headline claim is *motion fidelity*, yet nothing here makes it falsifiable. Goldens freeze a single frame; they cannot prove a spring's trajectory. This section defines what "fidelity" actually means in tests and pins it down with deterministic, value-level assertions rather than pixel-by-pixel comparison against Framer.

### Soften the claim, then verify it

We do **not** claim pixel-identical-to-Framer trajectories — two integrators will never produce byte-identical intermediate frames. What we claim and verify is: **same physical spring parameters, behavior within tolerance.** Fidelity is proven by asserting the *parameters* (the `motor` tokens) and the *which-token-drives-what* wiring, not by diffing animation frames.

### Testing layers

**(a) Token & resolver tests** — pin the constants. There may already be a token test under `test/`; build on it. Assert each `beuiSpring*` carries the exact `mass`/`stiffness`/`damping` from the **Motion tokens** table and each `beuiEase*` the exact `Cubic` control points. Then test the reduced-motion resolver: `motionFor(context, beuiSpringMouse)` returns `NoMotion` when `MediaQuery.disableAnimationsOf` is true, and the real token otherwise.

```dart
test('beuiSpringPress matches source SPRING_PRESS token', () {
  expect(beuiSpringPress.spring.mass, 0.6);
  expect(beuiSpringPress.spring.stiffness, 500);
  expect(beuiSpringPress.spring.damping, 30);
});
```

**(b) Goldens — settled state only.** Capture **rest/settled frames** and key variant/state permutations (tabs pill/segment/underline, button idle/loading/success/error, switch on/off, each color theme). **Never golden a mid-animation frame** — it is nondeterministic across integrators and platforms and will flake. Pump animations to completion (`tester.pumpAndSettle()`) before matching.

**(c) Deterministic frame-pumped widget tests** — this is where motion is actually verified. Drive time by hand with `tester.pump(Duration(...))` and assert *which token moves which property*:
- Press feedback animates **scale** under `beuiSpringPress` — pump partway, assert the `Transform` scale is between 1.0 and the press target and converging.
- **Per-dimension independence:** for a magnetic/dock target, assert the `Offset`'s `dx` and `dy` springs settle independently (drive one axis, the other stays put).
- **Reduced motion = no transform delta:** with `disableAnimationsOf` true, pump and assert there is **zero** translation/scale change, while opacity/color transitions *may* still occur. This is the single most important fidelity regression guard.

```dart
testWidgets('press animates scale under beuiSpringPress; none under reduced motion', (t) async {
  await t.pumpWidget(wrap(const BeuiButton(child: Text('Go'))));
  await t.press(find.byType(BeuiButton));
  await t.pump(const Duration(milliseconds: 60));
  expect(scaleOf(t, find.byType(BeuiButton)), lessThan(1.0)); // pressing in
  await t.pumpAndSettle();
  expect(scaleOf(t, find.byType(BeuiButton)), 1.0);            // settled back
});
```

**(d) Optional — settle-time reference table.** For each token, record the approximate settle time to within a tolerance band and assert against it. This catches *integrator drift* (a `motor` upgrade that quietly changes the solver) that parameter-only tests would miss.

| Token | Approx. settle (±tolerance) |
|---|---|
| `beuiSpringPress` | record on first green run, then pin |
| `beuiSpringMouse` | record on first green run, then pin |

### Gate & golden regen

`flutter analyze && flutter test` is the gate — both green before work is considered done. Regenerate goldens with `flutter test --update-goldens` **only** for intentional visual changes, and review the image diff in the PR. A new component is not done until it ships a motion-assertion test from layer (c) — see **Definition of done**.

---

## 10. Package, release & licensing

The port targets pub.dev but has no package metadata, no versioning policy, and no release process. Worse, the scaffolded `LICENSE` drops the upstream MIT attribution — a license violation that must be fixed before the first publish.

### Pubspec essentials

```yaml
name: beui
description: >-
  A Flutter port of beUI — a motion-first component library with spring-physics
  widgets (switches, tabs, docks, modals, magnetic & tilt effects). Ported from
  starc007/ui-components.
version: 0.1.0
repository: https://github.com/codenameakshay/beui
topics: [ui, widgets, animation, motion, components]

environment:
  sdk: ">=3.4.0 <4.0.0"
  flutter: ">=3.22.0"

dependencies:
  flutter:
    sdk: flutter
  motor: ">=1.1.0 <1.2.0"   # pin tighter than ^1.1.0 — see Motion tokens

platforms:                  # driven by the Platform scope section
  android:
  ios:
  macos:
  web:
  windows:
  linux:
```

- **`description`** 60–180 chars (pub.dev scores length) and names the upstream.
- **`motor` bound:** pin tighter than a loose `^1.1.0`. `motor`'s solver output *is* the fidelity contract (see **Testing & fidelity verification** layer (d)); a minor bump that changes integration must be an opt-in, reviewed upgrade, not an automatic `pub get`. Use a constrained range and bump deliberately.
- **`platforms:`** list exactly what **Platform scope** declares supported — every entry must have a working `example/` route and pass tests on that target. Pointer-only effects (magnetic, tilt) degrade gracefully on touch platforms but the package still *supports* them.
- **`topics`** drives discoverability; keep ≤5, all lowercase.

### Versioning (semver)

- **Pre-1.0 (`0.x`)** for the whole catalog-fill phase. Per semver, `0.y.z` allows breaking changes in `y` bumps — appropriate while the API is still moving. Stay on `0.x` until the catalog in **Component catalog** is substantially complete and the API has settled.
- A **breaking change** for a widget library means: removing or renaming a public `Beui*` widget or a public parameter; changing a parameter's type or required-ness; **or changing a component's default motion feel** (swapping the token a property animates under, or altering a default spring). Default-feel changes are breaking precisely because motion fidelity is the product — bump accordingly and call it out in the changelog.
- Additive (new widget, new optional param, new variant enum value) is a minor bump; bug/fidelity fixes that preserve behavior are patches.

### Release process

1. `flutter analyze && flutter test` green (includes the a11y gate and motion-assertion tests).
2. `dart pub publish --dry-run` clean — no warnings.
3. Update **`CHANGELOG.md`** with one section per release (`## 0.x.y`), grouping breaking / added / fixed.
4. **Dartdoc** on the entire public API surface — every exported `Beui*` widget and the token/theme API documented; pub.dev scores dartdoc coverage %.
5. Confirm `example/` builds (counts toward the pub.dev *example* metric).
6. Publish.

**pub.dev score factors to keep green:** dartdoc coverage %, a working `example/`, declared `platforms:` that actually pass, up-to-date dependencies (the tight `motor` pin must still resolve to a current version), and `flutter analyze` with zero issues.

### Licensing (must fix before first publish)

The upstream is **MIT, "Copyright (c) 2026 Saurabh Chauhan"** (confirmed in the source `LICENSE`). MIT requires *"the above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software."* A one-to-one port is a derivative work, so this is binding. The scaffolded `LICENSE` that **drops Saurabh Chauhan's line and claims sole "Copyright (c) 2026 codenameakshay" is non-compliant** and cannot ship.

Required:

1. **Carry both notices in `LICENSE`** — preserve the upstream copyright line *and* add the port's own, e.g.:
   ```
   MIT License

   Copyright (c) 2026 Saurabh Chauhan (original beUI, starc007/ui-components)
   Copyright (c) 2026 codenameakshay (Flutter port)

   Permission is hereby granted, free of charge, ...
   ```
   (keep the full MIT permission/warranty body intact.)
2. **Add a NOTICE/attribution line in `README.md`** crediting the upstream: this package is a Flutter port of **beUI** by **Saurabh Chauhan** (`starc007/ui-components`, [beui.dev](https://beui.dev)), and links back. This is both the courteous and the compliant thing — it satisfies the notice requirement in the user-facing surface and sets the `LICENSE` field on pub.dev correctly to `MIT`.

---

## 11. What the source ships that the Flutter port does NOT need

These are React/web-only or registry infrastructure with no Flutter analog — **do not port**:

- The shadcn registry endpoints (`app/r/*`, `lib/registry*.ts`, `llms.txt`, registry JSON) — the chosen distribution is a normal pub.dev package.
- The Next.js docs website chrome (`components/app/*`, `app/*` pages, OG image generation, SEO, sitemap). The Flutter equivalent is a single **`example/` showcase app**.
- Shiki syntax highlighting, `next-themes`, Vercel analytics (`@vercel/analytics`, `@vercel/speed-insights`).
- `clsx` + `tailwind-merge` — the `cn()` helper (`lib/utils.ts`) is a runtime Tailwind-class merge. Flutter has no class strings: replace it with the typed `Beui<Component>Style` / `color` / `padding` overrides plus `ThemeExtension` defaults (see *React → Flutter porting conventions*), not a runtime merge.
- `react-use-measure` — **declared in `package.json` but unused by any component** (a repo-wide grep finds it only in a `tests/setup.ts` comment). There is no measurement primitive to port from it; do not invent one. Element measurement, where a component needs it, is done via the `GlobalKey` + `RenderBox` approach in *React → Flutter porting conventions*.

### Assets: the published package ships zero runtime image/sound assets

- The logo / wordmark / hero gif under `public/assets` are **docs-site only** — they live in the showcase, not the library.
- Decorative glyphs in components are inline SVG → port as `CustomPaint` (or plain text initials), not bundled image files.
- The only genuine bundled-asset question is **fonts**, and the answer is *don't bundle* — see *Theme system* (map to `TextStyle(fontFamily: ...)` / `BeuiTextTheme`, leave the font to the consumer).

### Per-file `lib/` keep/drop boundary

The source's `lib/` mixes genuine library primitives with site/registry machinery. Mine the values, drop the generators.

| Source file | Action |
|---|---|
| `lib/ease.ts` | **Keep the concepts** → motion tokens (see *Motion tokens*). |
| `lib/themes.ts` | **Keep the concepts** → `BeuiColors` theme variants (see *Theme system*). |
| `lib/hooks/use-hover-capable.ts` | **Keep** — the one real library primitive in `lib/hooks/`. Extract it as a hover-capability check; in Flutter this collapses largely into the `MouseRegion` gate (see the hover-capable rule in *Motion tokens*). |
| `lib/theme-css.ts` | **Mine the VALUES, drop the machinery.** It holds the real extension/glass token values (`--border-strong`, `--glass-bg`, `--glass-border`, `--glass-strong-bg`, etc.) — pull those into *Theme system*. Drop the CSS-string generator / shadcn-init export itself. |
| `lib/github.ts`, `lib/source-files.ts`, `lib/og.tsx`, `lib/seo.ts`, `lib/registry.ts`, `lib/registry-server.ts` | **Drop** — GitHub/source fetching, OG images, SEO, registry generation; all docs/registry infrastructure. |

### Keep the `example/` app — and port the preview states into it

Keep an `example/` Flutter app as the living gallery (one screen/route per component) — it doubles as visual QA and the place golden tests render from.

Note: `components/previews/{motion,blocks}/*.preview.tsx` (52 files — 36 motion + 16 blocks) are **canonical per-component demo states**, and are **not** part of the drop list. `example/` route authors should **port those preview states** rather than re-deriving demo data — they encode the intended default props, variants, and showcase scenarios for each component.
