# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A **one-to-one Flutter port of beUI v2** — a React motion-component library (source: `starc007/ui-components`, live at [beui.dev](https://beui.dev)). Distributed as a published **pub.dev package**: components are exported widgets consumers add with `flutter pub add`, not copy-paste source.

The port's defining goal is **motion fidelity** — matching the source's spring physics and timing, not just its visual layout. Read [docs/PORTING_SPEC.md](docs/PORTING_SPEC.md) before porting any component; it holds the full component catalog, the spring/easing token mapping, the theme system, and the React→Flutter convention table. This file is the working guide; the spec is the source of truth for *what* to build.

> Status: greenfield. The project skeleton is not scaffolded yet. The commands and structure below are the intended conventions — establish them with the first code.

## Commands

```bash
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
- `lib/src/tokens/` — **port this first; everything depends on it.** `springs.dart` (the five `SpringDescription` constants), `curves.dart` (the three `Cubic` easings). These mirror the source's `lib/ease.ts` exactly — see the spec's token tables.
- `lib/src/theme/` — `BeuiColors` as a `ThemeExtension` (the source's design-token palette, light/dark + 11 color themes), plus text/typography. Components read colors from `Theme.of(context).extension<BeuiColors>()`, never hardcoded.
- `lib/src/motion/` — the components. One widget per file, snake_case filenames matching the source slugs (`switch.dart`, `dock.dart`); multi-file widgets get a folder (`button/`). The source splits primitives (`motion`) from composed widgets (`blocks`) — keep that split as subfolders or a clear grouping.
- `example/` — Flutter showcase app, one route per component. This is the Flutter analog of the source's docs site and the render target for golden tests. It is the living gallery, not part of the published library surface.
- `test/` — widget tests + golden tests per component.

### Non-negotiable motion rules (enforced, mirror the source)

- **Springs use `SpringDescription` driven by `AnimationController` + `SpringSimulation`.** Do not approximate the source's springs with `Curves.elasticOut`/`bounceOut`. The token values in the spec are the physics; use them verbatim.
- **Gate transform motion on reduced motion:** `MediaQuery.disableAnimationsOf(context)`. Reduced motion keeps opacity/color transitions and drops *movement* — it is not a blanket duration-zeroing.
- **Build decorative hover effects (magnetic, tilt, dock magnify) on `MouseRegion`**, never `GestureDetector` — this naturally excludes touch devices, matching the source's `useHoverCapable()` gate.
- Animate transform/opacity only; blur ≤ 10px; exits faster than entrances; UI motion < ~300ms, press feedback ~100–160ms.

### Naming

Prefix every public widget with **`Beui`** (`BeuiSwitch`, `BeuiDrawer`, `BeuiTooltip`, `BeuiButton`). Many source names collide with Flutter framework widgets (`Switch`, `Drawer`, `Tooltip`, `Checkbox`, `Radio`, `Tabs`) — the prefix avoids import clashes. Keep filenames matching the source slug for traceability.

### Component API conventions

- Mirror the source's controlled + uncontrolled pattern: a `value` + `onChanged` pair, with internal state when `value` is null (Flutter's own `Switch`/`Slider` convention).
- Expose source variants (e.g. tabs pill/segment/underline, action-swap blur/roll/cascade) as a Dart `enum` parameter or named constructors.
- A new component is not done until it has: the widget under `lib/src/`, a barrel export in `lib/beui.dart`, a route in the `example/` gallery, and a test. Check it against the catalog in the spec first — port what exists there; don't invent components.

## What NOT to port

The source ships a shadcn registry (`app/r/*`, `lib/registry*.ts`, `llms.txt`), a Next.js docs website, OG/SEO tooling, and Shiki highlighting. None of that has a Flutter analog — the `example/` app replaces the docs site, and pub.dev replaces the registry. See the spec's §5.

## Commits

Conventional lowercase prefixes (`feat:`, `fix:`, `refactor:`, `docs:`), imperative subject — matching the source repo's convention. No AI attribution / Co-Authored-By lines.
