# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A **one-to-one Flutter port of beUI v2** — a React motion-component library (source: `starc007/ui-components`, live at [beui.dev](https://beui.dev)). Distributed as a published **pub.dev package**: components are exported widgets consumers add with `flutter pub add`, not copy-paste source.

The port's defining goal is **motion fidelity** — matching the source's spring physics and timing, not just its visual layout. Read [docs/PORTING_SPEC.md](docs/PORTING_SPEC.md) before porting any component; it holds the full component catalog, the spring/easing token mapping, the theme system, and the React→Flutter convention table. This file is the working guide; the spec is the source of truth for *what* to build.

> Status: greenfield. The project skeleton is not scaffolded yet. The commands and structure below are the intended conventions — establish them with the first code.

## Commands

```bash
flutter pub add motor                # the motion engine (add when scaffolding; see Architecture)
flutter pub get                      # install deps
flutter analyze                      # static analysis + lints (the typecheck+lint gate)
dart format .                        # format (run before committing)
flutter test                         # all widget/unit tests
flutter test test/switch_test.dart   # a single test file
flutter test --name "thumb glides"   # a single test by name
flutter test --update-goldens        # regenerate golden images after intentional visual changes
cd example && flutter run            # run the showcase/gallery app
dart pub publish --dry-run           # validate the package before publishing
```

Run `flutter analyze && flutter test` before considering work done. Do not run `flutter run` or launch the example app unless explicitly asked.

## Architecture

Intended layout for the package:

- `lib/beui.dart` — barrel file; the single public entrypoint that re-exports every component and the theme/token API. Consumers `import 'package:beui/beui.dart'`.
- `lib/src/tokens/` — **port this first; everything depends on it.** `motion.dart` holds the five spring tokens as `motor.SpringMotion(SpringDescription(...))` constants and the three easings as `Cubic` constants, mirroring the source's `lib/ease.ts` exactly (see the spec's token tables). This file is the only place `motor` types appear directly — see the motion-engine rule below. `icons.dart` is the only place the icon package (`flutter_lucide`) is referenced — see Icons below.
- `lib/src/theme/` — `BeuiColors` as a `ThemeExtension` (the source's design-token palette, light/dark + a neutral base + 10 color themes (11 ColorTheme values)), plus text/typography. Components read colors from `Theme.of(context).extension<BeuiColors>()`, never hardcoded.
- `lib/src/motion/` — the components. One widget per file, snake_case filenames matching the source slugs (`switch.dart`, `dock.dart`); multi-file widgets get a folder (`button/`). The source splits primitives (`motion`) from composed widgets (`blocks`) — keep that split as subfolders or a clear grouping.
- `lib/src/overlay/` — the shared overlay foundation (`BeuiOverlay`). Every floating surface (tooltip, drawer, bottom-sheet, modal, command-palette, create-menu) builds on it; do **not** hand-roll `OverlayPortal`/`Overlay` per component. The library-wide decision (the spec's §6 "decide once") is **declarative**: the consumer owns an `open` bool and handles `onDismiss`; `BeuiOverlay` animates content in/out and unmounts after exit. It renders into the root overlay (escaping ancestor `Transform`/`ClipRect`) and provides the barrier, Esc/tap dismiss, and focus trap. The panel's own entrance (scale/slide/blur) lives in the component's `overlayBuilder`, which gets the `animation` and the anchor `LayerLink` (use it with `CompositedTransformFollower` for anchored surfaces like tooltips).
- `example/` — Flutter showcase app, one route per component. This is the Flutter analog of the source's docs site and the render target for golden tests. It is the living gallery, not part of the published library surface.
- `test/` — widget tests + golden tests per component.

### Non-negotiable motion rules (enforced, mirror the source)

- **Motion engine is [`motor`](https://pub.dev/packages/motor), not raw `AnimationController`.** `motor.SpringMotion` wraps Flutter's `SpringDescription`, so the source's exact spring tokens carry over with the same physical parameters (trajectories validated within tolerance, not pixel-identical to Framer — see the spec's Testing & fidelity verification section), and `MotionBuilder` gives independent-per-dimension springs (`Offset`/`Rect`/`Size`/`Alignment`/`Color`) for magnetic/tilt/dock/shared-layout. Do not approximate springs with `Curves.elasticOut`/`bounceOut`; use the token values verbatim.
- **`motor` stays an implementation detail.** The shared token constants live in `lib/src/tokens/motion.dart`, but `motor`'s builder/controller types are the animation core of nearly every component (plus the component-local bespoke springs in the spec's Motion tokens table). To keep "swap motor → rewrite a few files" true, route builder/controller construction through a thin `lib/src/motion/_engine.dart` facade — otherwise the coupling is real and per-component. Pin `motor` tighter than `^1.1.0`.
- **Gate transform motion on reduced motion:** `MediaQuery.disableAnimationsOf(context)` → swap to `motor.NoMotion` (movement-free). `motor` does not do this for you. Reduced motion keeps opacity/color transitions and drops *movement* — it is not a blanket duration-zeroing. Centralize the check in one resolver rather than per widget.
- **Build decorative hover effects (magnetic, tilt) on `MouseRegion`**, never `GestureDetector` — this naturally excludes touch devices, matching the source's `useHoverCapable()` gate.
- Animate transform/opacity only; blur ≤ 10px; exits faster than entrances; UI motion < ~300ms, press feedback ~100–160ms.

### Naming

Prefix every public widget with **`Beui`** (`BeuiSwitch`, `BeuiDrawer`, `BeuiTooltip`, `BeuiButton`). Many source names collide with Flutter framework widgets (`Switch`, `Drawer`, `Tooltip`, `Checkbox`, `Radio`, `Tabs`) — the prefix avoids import clashes. Keep filenames matching the source slug for traceability.

### Icons

Default icon set is `flutter_lucide`, re-exported through the barrel (and referenced only in `lib/src/tokens/icons.dart` — same discipline as the `motor` rule; never import it ad hoc in a widget). Icon props on public widgets are framework-native: `IconData? icon` (pick a glyph) or `Widget? icon` (custom content) — never a `flutter_lucide`-specific type, so the icon package can be swapped without touching any widget API. Components with a fixed status set (animated-badge, animated-toast-stack) ship `LucideIcons.*` defaults that consumers can override per status. Hand-drawn marks in the source (otp-input success check, scroll-progress ring) port to `CustomPaint`, **not** bundled assets — the package ships no `assets/` icons of its own. See the spec's §3.

### Component API conventions

- Mirror the source's controlled + uncontrolled pattern: a `value` + `onChanged` pair, with internal state when `value` is null (Flutter's own `Switch`/`Slider` convention).
- Expose source variants (e.g. tabs pill/segment/underline, action-swap blur/roll/cascade) as a Dart `enum` parameter or named constructors.
- A new component is not done until it has: the widget under `lib/src/`, a barrel export in `lib/beui.dart`, a route in the `example/` gallery, and a test. Check it against the catalog in the spec first — port what exists there; don't invent components.

## What NOT to port

The source ships a shadcn registry (`app/r/*`, `lib/registry*.ts`, `llms.txt`), a Next.js docs website, OG/SEO tooling, and Shiki highlighting. None of that has a Flutter analog — the `example/` app replaces the docs site, and pub.dev replaces the registry. See the spec's §11 ("What the source ships that the Flutter port does NOT need").

## Commits

Conventional lowercase prefixes (`feat:`, `fix:`, `refactor:`, `docs:`), imperative subject — matching the source repo's convention. No AI attribution / Co-Authored-By lines.
