<div align="center">

# beUI

**Motion components for Flutter** — a one-to-one port of [beUI v2](https://beui.dev) (`starc007/ui-components`).

Spring-physics UI primitives and composed blocks, built on the [`motor`](https://pub.dev/packages/motor) motion engine so the original's *exact* spring feel carries over — not just its look.

[![Live gallery](https://img.shields.io/badge/demo-live%20gallery-14b8a6?style=flat-square)](https://codenameakshay.github.io/beui/)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.44-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square)](LICENSE)

<br/>

<img src="https://raw.githubusercontent.com/codenameakshay/beui/main/.github/screenshots/01-components-dark.png" alt="beUI component explorer" width="880" />

</div>

---

## What this is

beUI is a Flutter widget library that ports the [beUI](https://beui.dev) React motion library. It ships **49 components** across two groups — expressive **Components** (motion primitives with composable APIs) and product-ready **Blocks** (composed patterns like a command palette, wallet card, or availability scheduler).

The port's defining goal is **motion fidelity**. Framer Motion springs are parameterized by `stiffness`, `damping`, and `mass` — the exact same physical parameters as Flutter's `SpringDescription` — so the source's spring tokens carry over with no fidelity loss. Components don't approximate the feel with `Curves.elasticOut`; they use the real physics through [`motor`](https://pub.dev/packages/motor).

- 🎬 **Spring-accurate motion** — five spring tokens + three easings ported verbatim from the source's `ease.ts`.
- 🎨 **Themeable** — `BeuiColors` `ThemeExtension` with light/dark and 11 color themes.
- ♿ **Reduced-motion aware** — one resolver drops *movement* while keeping opacity/color feedback (not a blanket duration-zeroing).
- 🧩 **Native APIs** — controlled/uncontrolled `value` + `onChanged` pairs, framework-native `IconData`/`Widget` icon props, variants as Dart enums.
- 🪟 **One overlay foundation** — every floating surface (tooltip, drawer, sheet, modal, command palette) builds on a shared `BeuiOverlay`.

> **Status:** actively developed. 49 of 51 catalog entries are ported (Pull to Refresh and Animated CTA Buttons are pending). Not yet published to pub.dev — install from Git (see below).

## Live gallery

The [`example/`](example) app is a beui.dev-style component explorer — sidebar, card grid, per-component detail pages with live Preview / Usage / Code tabs, and a Motion Guides page. It's deployed to GitHub Pages on every push to `main`:

### 👉 **[codenameakshay.github.io/beui](https://codenameakshay.github.io/beui/)**

<table>
  <tr>
    <td width="50%"><img src="https://raw.githubusercontent.com/codenameakshay/beui/main/.github/screenshots/05-blocks-dark.png" alt="Blocks index" /><br/><sub><b>Blocks</b> — composed, product-ready motion patterns</sub></td>
    <td width="50%"><img src="https://raw.githubusercontent.com/codenameakshay/beui/main/.github/screenshots/02-detail-dark.png" alt="Component detail page" /><br/><sub><b>Detail page</b> — live Preview / Usage / Code tabs</sub></td>
  </tr>
  <tr>
    <td width="50%"><img src="https://raw.githubusercontent.com/codenameakshay/beui/main/.github/screenshots/03-motion-guides.png" alt="Motion guides" /><br/><sub><b>Motion Guides</b> — when to move, which token, how to fall back</sub></td>
    <td width="50%"><img src="https://raw.githubusercontent.com/codenameakshay/beui/main/.github/screenshots/04-components-light.png" alt="Light theme" /><br/><sub><b>Light & dark</b> — every screen renders in both</sub></td>
  </tr>
</table>

## Install

Not yet on pub.dev — add it from Git:

```yaml
dependencies:
  beui:
    git:
      url: https://github.com/codenameakshay/beui.git
```

Once published, it will be a normal hosted dependency:

```yaml
dependencies:
  beui: ^0.0.1
```

Then import the single public entrypoint:

```dart
import 'package:beui/beui.dart';
```

## Quick start

### 1. Register the theme

Components read their colors from a `BeuiColors` `ThemeExtension`, so install it on your `ThemeData`. Color theme and brightness are independent axes — any of the 11 themes works in light or dark.

```dart
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

ThemeData beuiTheme(Brightness brightness) {
  final colors = BeuiColors.of(BeuiColorTheme.violet, brightness);
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: colors.background,
    extensions: [colors], // ← the only required line
  );
}

MaterialApp(
  theme: beuiTheme(Brightness.light),
  darkTheme: beuiTheme(Brightness.dark),
  home: const MyHomePage(),
);
```

### 2. Drop in a component

Every stateful component mirrors Flutter's controlled + uncontrolled convention — pass `value` + `onChanged` to control it, or omit `value` to let it hold its own state.

```dart
// A spring-thumbed switch
bool wifi = true;
BeuiSwitch(
  value: wifi,
  label: const Text('Wi-Fi'),
  onChanged: (v) => setState(() => wifi = v),
);

// Tabs with a gliding indicator — pill / segment / underline
BeuiTabs<String>(
  variant: BeuiTabsVariant.underline,
  tabs: const [
    BeuiTab(value: 'overview', label: Text('Overview')),
    BeuiTab(value: 'activity', label: Text('Activity')),
  ],
  defaultValue: 'overview',
  onChanged: (v) => print(v),
);

// A spring-pressed button
BeuiButton(
  variant: BeuiButtonVariant.primary,
  onPressed: () {},
  child: const Text('Continue'),
);

// A hover/focus tooltip with a blur enter/exit
BeuiTooltip(
  content: const Text('Copy to clipboard'),
  side: BeuiTooltipSide.top,
  child: const Icon(LucideIcons.copy),
);

// A GPU shader background (mesh, grain, warp, waves, voronoi…)
BeuiShaderBackground(
  variant: BeuiShaderVariant.meshGradient,
  speed: 0.6,
);
```

## Component catalog

Mirrors the [beui.dev](https://beui.dev) sidebar order. ✨ marks entries added in beUI v2.

### Components — motion primitives

| Component | Widget(s) | What it does |
| --- | --- | --- |
| Marquee | `BeuiMarquee` | Infinite horizontal/vertical scroll with pause-on-hover |
| Tabs | `BeuiTabs` | Pill, segment or underline tabs with a spring layout indicator |
| Switch | `BeuiSwitch` | Toggle with a spring-driven thumb and press feedback |
| Input | `BeuiInput` | Text field with icons, error shake and a success check draw |
| Select ✨ | `BeuiSelect`, `BeuiMorphSelect` | Panel that bouncily unfolds from the trigger, plus a Morph variant |
| Checkbox ✨ | `BeuiCheckbox` | Draw-on checkmark with spring press feedback and indeterminate |
| Radio Group ✨ | `BeuiRadioGroup` | Single-select with a gliding indicator dot and spring feedback |
| Bottom Sheet | `BeuiBottomSheet` | Draggable sheet with snap points, inertia and a glass surface |
| Pull to Refresh ✨ | _pending_ | Pull-to-refresh with drag resistance and async handling |
| Shared Layout Background | `BeuiSharedLayoutBg` | A pill that glides between hovered items with a blur enter/exit |
| Preview Rail ✨ | `BeuiPreviewRail` | Navigation rail of ticks that reveal a floating destination preview |
| Dock | `BeuiDock` | macOS-style dock with grouped actions and a gliding active pill |
| Tooltip | `BeuiTooltip` | Hover or focus tooltip with a blur enter/exit and spring spawn |
| Popover ✨ | `BeuiPopover`, `BeuiMorphPopover` | Gooey popover that oozes from the trigger, plus a Morph variant |
| Morphing Modal | `BeuiMorphingModal` | A panel that morphs its height between inner views, blur cross-fade |
| Text Animation | `BeuiTextReveal`, `BeuiTextShimmer`, `BeuiTextCascade` | Reveal sequences, shimmer loading states and letter-cascade swaps |
| Number Animation | `BeuiAnimatedNumber`, `BeuiNumberTicker` | Count-up values and rolling digit tickers |
| Animated Badge | `BeuiAnimatedBadge` | Status badge with animated state icons and pulse feedback |
| Action Swap | `BeuiActionSwapButton` | Swap a button's text and icons with blur, roll or cascade motion |
| Animated Toast Stack | `BeuiAnimatedToastStack` | Stacked toasts with status morphs, swipe dismissal and actions |
| Theme Toggle | `BeuiThemeToggle`, `BeuiThemeSwitcher` | Theme toggle with a full-page clip-path reveal |
| Bouncy Accordion | `BeuiBouncyAccordion` | Single-open accordion with a weighted spring layout |
| Drawer | `BeuiDrawer` | Side panel that springs in with a backdrop blur and esc-to-close |
| Scroll Animation | `BeuiSmoothScroll`, `BeuiScrollProgress`, `BeuiScrollReveal`, `BeuiScrollTo` | Smooth-scroll provider and a reading-progress indicator |
| Range Slider ✨ | `BeuiRangeSlider`, `BeuiRangeSliderDual` | Tick dots and a bouncy vertical-bar thumb that snaps between steps |
| Wheel Picker ✨ | `BeuiWheelPicker` | iOS-style 3D picker drum with momentum snap |
| Table ✨ | `BeuiTable` | Virtualized table smooth at 10k+ rows: sort, select, resize, reorder |
| Shader Background ✨ | `BeuiShaderBackground` | 21 GPU shader backgrounds (mesh, grain, warp, waves, voronoi…) |
| Cylinder Carousel ✨ | `BeuiCylinderCarousel` | Items line the inside of a cylinder; drag or scroll with springy snap |
| Loader ✨ | `BeuiLoader` | Loading indicator with seventeen variants from one size prop |
| Tilt Card | `BeuiTiltCard` | 3D perspective tilt on hover with a cursor-tracked glare |
| Button | `BeuiButton`, `BeuiStatefulButton`, `BeuiMagneticButton` | Spring-pressed Button, StatefulButton and MagneticButton |
| Animated CTA Buttons ✨ | _pending_ | CTA buttons with expanding, hold and slide interactions |

### Blocks — composed patterns

| Block | Widget | What it does |
| --- | --- | --- |
| Availability Scheduler ✨ | `BeuiAvailabilityScheduler` | Weekly availability grid with per-day time ranges |
| Multi-chain Swap | `BeuiMultiChainSwap` | Token swap card with chain switching and an animated quote |
| Dynamic Island | `BeuiDynamicIsland` | iOS-style island that morphs between compact and expanded views |
| Command Palette | `BeuiCommandPalette` | ⌘K palette with fuzzy search and spring-animated results |
| Expandable Action Bar | `BeuiExpandableActionBar` | Icon rail whose segments expand to reveal a label on hover |
| Overflow Actions | `BeuiOverflowActions` | Primary actions with an overflow that fans out from a ⋯ toggle |
| Expandable Tabs | `BeuiExpandableTabs` | Icon tabs where the active tab expands to show its label |
| Swipeable List | `BeuiSwipeableList` | List rows with spring-backed swipe-to-reveal actions |
| File Upload | `BeuiFileUpload` | Drop zone with per-file progress and status transitions |
| Prediction Market | `BeuiPredictionMarket` | Market card with a gliding outcome pill and animated odds |
| Wallet Card ✨ | `BeuiWalletCard` | Wallet card with an account switcher and morphing search |
| OTP Input | `BeuiOtpInput` | One-time-code field with per-cell focus and a success check |
| Bloom Menu ✨ | `BeuiBloomMenu` | Radial action menu that blooms open from a floating trigger |
| Feedback Widget ✨ | `BeuiFeedbackWidget` | Feedback popover that morphs to a success state on submit |
| 404 / Not Found | `BeuiNotFoundGlitch`, `…Magnetic`, `…Spotlight`, `…Stacked`, `…Terminal` | Five expressive 404 treatments |
| Infinite Masonry ✨ | `BeuiInfiniteMasonry` | Masonry grid that lazily appends tiles as you scroll |
| Notification Stack ✨ | `BeuiNotificationStack` | Collapsed notification stack that expands with layout-aware motion |
| Knockout Bracket ✨ | `BeuiKnockoutBracket` | Tournament bracket with connectors that animate as rounds fill |

Also exported as standalone primitives: `BeuiMagnetic` (cursor-follow pull), `BeuiParallax` (scroll parallax), and the `BeuiOverlay` foundation.

## Theming

`BeuiColors` is a `ThemeExtension` ported from the source's design tokens. Read colors in your own widgets the same way components do:

```dart
final colors = Theme.of(context).extension<BeuiColors>()!;
Container(color: colors.card /* colors.foreground, .primary, .border, .muted, … */);
```

**11 color themes**, each valid in light and dark — resolve with `BeuiColors.of(theme, brightness)`:

`Mono` (neutral base) · `Violet` · `Blue` · `Green` · `Amber` · `Blood Orange` · `Rose` · `Red` · `Teal` · `Indigo` · `Lime`

Each `BeuiColorTheme` value carries picker metadata (`name`, `slug`, `swatch`) for building a theme switcher. Overlay surfaces use a dedicated frosted-glass tier (`BeuiGlass`) with the source's 12–20px backdrop blur.

## Motion system

The whole library speaks one motion language, defined once in `lib/src/tokens/motion.dart` and exported through the barrel:

| Token | Physics | Used for |
| --- | --- | --- |
| `beuiSpringPress` | stiffness 500 · damping 30 · mass 0.6 | Button / tap press feedback |
| `beuiSpringSwap` | stiffness 460 · damping 30 · mass 0.55 | Content swaps (label/icon slots) |
| `beuiSpringPanel` | stiffness 420 · damping 40 · mass 0.5 | Overlay panel entrances (modals, sheets) |
| `beuiSpringLayout` | stiffness 360 · damping 32 · mass 0.6 | Shared-layout glides (pills, indicators) |
| `beuiSpringMouse` | stiffness 200 · damping 15 · mass 0.3 | Cursor-follow physics (magnetic, tilt) |

Plus three easings — `beuiEaseOut`, `beuiEaseInOut`, `beuiEaseDrawer` — and helpers `beuiBlurSigma(px)` (CSS-blur → Flutter sigma) and `motionFor(context, token, isMovement:)` (the reduced-motion resolver).

**Reduced motion** is respected everywhere: with the OS setting on, movement-bearing tokens collapse to movement-free motion while opacity/color transitions are preserved — motion that *explains* rather than *distracts*. See the Motion Guides page in the [live gallery](https://codenameakshay.github.io/beui/).

## Icons

beUI re-exports the [`flutter_lucide`](https://pub.dev/packages/flutter_lucide) icon set (the Flutter equivalent of the source's `lucide-react` glyphs), so defaults in badges, toasts, and the command palette work out of the box — `LucideIcons.*` is available from the barrel.

> **Transitive dependency:** adding `beui` pulls in the Lucide icon font whether or not you use a defaulted icon. Icon props accept the framework-native `IconData` (any glyph) or `Widget` (custom content), so you can override every default without depending on Lucide directly.

## Develop

Uses [FVM](https://fvm.app) (pinned to Flutter stable in `.fvmrc`).

```bash
fvm flutter pub get
fvm flutter analyze          # static analysis + lints
fvm flutter test             # widget + golden tests
fvm flutter test --update-goldens   # regenerate goldens after intentional visual changes
cd example && fvm flutter run       # the component explorer
```

Run `fvm flutter analyze && fvm flutter test` before considering work done. See [`CLAUDE.md`](CLAUDE.md) for architecture and conventions, and [`docs/PORTING_SPEC.md`](docs/PORTING_SPEC.md) for the full catalog and the motion-token mapping.

## Credits

A Flutter port of **beUI** by **Saurabh Chauhan** — [beui.dev](https://beui.dev) (`starc007/ui-components`). All component designs and the original motion work are his; this package brings them to Flutter.

## License

MIT — see [`LICENSE`](LICENSE). Both the upstream copyright (Saurabh Chauhan) and the port's copyright are preserved, as the MIT license requires for derivative works.
