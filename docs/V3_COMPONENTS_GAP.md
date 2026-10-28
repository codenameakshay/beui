# v3 Components family — catalog gap

Source of truth: [beui.dev/components/motion](https://beui.dev/components/motion) via [llms.txt](https://beui.dev/llms.txt) and per-page `.md`. Fetched 2026-10-22 against package `2.0.0` @ `a4d493a`.

Gallery rule: **New first, then All**, matching `IndexPage` (`isNew` cards, then the full `kComponents` list). All-order below is the live sidebar.

## Live All order vs this port

| # | Source page | Slug | Install targets | Port status |
|---|---|---|---|---|
| 1 | Timeline | `timeline` | `timeline` | ported |
| 2 | Animated Alert | `alert` | `alert` | ported |
| 3 | Animated Collapsible | `collapsible` | `collapsible` | ported |
| 4 | Aspect Ratio | `aspect-ratio` | `aspect-ratio` | ported |
| 5 | Arc Picker | `arc-picker` | `arc-picker` | ported |
| 6 | Sortable List | `sortable-stack` | `sortable-stack` (+ `sortable-list` parts) | ported |
| 7 | Image Viewer | `image-viewer` | `morphing-lightbox` | ported |
| 8 | Date Range Picker | `date-range-picker` | `date-range-picker` | ported |
| 9 | Card | `card` | `card` | ported |
| 10 | Color Picker | `color-picker` | `color-picker` | ported |
| 11 | Animated Color Selector | `color-selector` | `color-selector` | ported |
| 12 | Animated Breadcrumb | `breadcrumb` | `breadcrumb` | ported |
| 13 | Tilt Card | `tilt-card` | `tilt-card` | shipped |
| 14 | Button | `button` | `button-metallic`, `button-base`, `button-stateful`, `button-magnetic` | ported (metallic added) |
| 15 | Animated CTA Buttons | `expanding-arrow-button` | expanding / hold / slide | shipped |
| 16 | Expandable Control | `expandable-control` | `expandable-control` | ported |
| 17 | Adaptive Stepper | `adaptive-stepper` | `adaptive-stepper` | ported |
| 18 | Marquee | `marquee` | `marquee` | shipped |
| 19 | Tabs | `tabs` | `tabs` | shipped; icons + overflow |
| 20 | Switch | `switch` | `switch` | shipped |
| 21 | Input | `input` | `input` | shipped; `reserveErrorLine` |
| 22 | Select | `select` | `select`, `select-morph` | shipped (pinch-off + morph present) |
| 23 | Combobox | `combobox` | `combobox` | ported |
| 24 | Multi Select | `multi-select` | `multi-select` | ported |
| 25 | Checkbox | `checkbox` | `checkbox` | shipped |
| 26 | Radio Group | `radio` | `radio` | shipped |
| 27 | Bottom Sheet | `bottom-sheet` | `bottom-sheet` | shipped |
| 28 | Pull to Refresh | `pull-to-refresh` | `pull-to-refresh` | shipped |
| 29 | Shared Layout Background | `shared-layout-bg` | `shared-layout-bg` | shipped |
| 30 | Bounce Sidebar | `bounce-sidebar` | `bounce-sidebar` | shipped |
| 31 | Animated Sidebar | `animated-sidebar` | `animated-sidebar` | shipped |
| 32 | File Tree | `file-tree` | `file-tree` | ported |
| 33 | Preview Rail | `preview-rail` | `preview-rail` | shipped |
| 34 | Dock | `dock` | `dock` | shipped |
| 35 | Tooltip | `tooltip` | `tooltip` | shipped; arrow / align / disabled / Provider / followCursor / collision. **gap** Trigger/Content are identity wrappers |
| 36 | Animated Context Menu | `context-menu` | `context-menu` | shipped |
| 37 | Popover | `popover` | `popover`, `popover-morph` | shipped |
| 38 | Morphing Modal | `morphing-modal` | `morphing-modal` | shipped |
| 39 | Center Morph Modal | `center-morph-modal` | `center-morph-modal` | shipped |
| 40 | Text Animation | `text-animation` | `text-scramble`, `chromatic-text-reveal`, `text-reveal`, `text-shimmer`, `text-cascade` | ported (scramble added) |
| 41 | Number Animation | `number` | `digit-swap`, `number-ticker`, `animated-number` | ported (digit-swap added) |
| 42 | Animated Badge | `animated-badge` | `animated-badge` | shipped |
| 43 | Action Swap | `action-swap` | blur / roll / cascade | shipped (three variants) |
| 44 | Animated Toast Stack | `animated-toast-stack` | `animated-toast-stack` | shipped |
| 45 | Theme Toggle | `theme-toggle` | `theme-toggle` | shipped |
| 46 | Bouncy Accordion | `bouncy-accordion` | `bouncy-accordion` | shipped |
| 47 | Drawer | `drawer` | `drawer` | shipped |
| 48 | Scroll Animation | `scroll-animation` | smooth-scroll, scroll-progress, parallax, scroll-to, scroll-reveal | shipped (five parts) |
| 49 | Range Slider | `range-slider` | `range-slider-inline` + five existing | ported (inline added) |
| 50 | Wheel Picker | `wheel-picker` | `wheel-picker` | shipped |
| 51 | Table | `table` | `table`, `table-editable`, `table-async` | shipped; gallery has editable/async bands |
| 52 | Shader Background | `shader-background` | 21 variants | shipped (21) |
| 53 | Cylinder Carousel | `cylinder-carousel` | `cylinder-carousel` | shipped |
| 54 | Loader | `loader` | 17 variants | shipped (17) |

Charts (`treemap` … `price-target-fan`) are **out of family**. Agents and blocks are **out of family**.

## New widgets this PR ports

Public `Beui*` names (Install target → widget):

- `timeline` → `BeuiTimeline`
- `alert` → `BeuiAlert` (+ Icon/Content/Title/Description/Action/Close)
- `collapsible` → `BeuiCollapsible` (+ Trigger/Content/Indicator)
- `aspect-ratio` → `BeuiAspectRatio`, `BeuiAspectRatioImage`
- `arc-picker` → `BeuiArcPicker`
- `sortable-stack` → `BeuiSortableList` (+ Group/Item/Handle/Content/Undo)
- `morphing-lightbox` → `BeuiImageViewer` (+ Gallery/Thumbnail/Content/Counter/Caption/Close/Previous/Next)
- `date-range-picker` → `BeuiDateRangePicker` (+ Calendar/Header/Grid/Trigger/Content/…)
- `card` → `BeuiCard` (+ Header/Title/Description/Action/Content/Footer)
- `color-picker` → `BeuiColorPicker` (+ Area/Hue/Alpha/Hex/Channels/EyeDropper/Presets/Trigger/Content)
- `color-selector` → `BeuiColorSelector` (+ Label/List/Item)
- `breadcrumb` → `BeuiBreadcrumb` (+ List/Item/Link/Page/Separator/Ellipsis)
- `button-metallic` → `BeuiMetallicButton`
- `expandable-control` → `BeuiExpandableButton`, `BeuiExpandableChip`
- `adaptive-stepper` → `BeuiAdaptiveStepper` (+ Decrement/Value/Increment)
- `combobox` → `BeuiCombobox` (+ Trigger/Input/Content/List/Item/…)
- `multi-select` → `BeuiMultiSelect` (+ Trigger/Value/Input/Content/List/Item/…)
- `file-tree` → `BeuiFileTree` (+ Folder/File)
- `text-scramble` → `BeuiTextScramble`
- `digit-swap` → `BeuiDigitSwap`
- `range-slider-inline` → `BeuiInlineSlider`

`table-editable` / `table-async` are usage targets of the same `BeuiTable` (`onCellEdit`, `onEndReached`, `loading`). They get gallery bands, not new widgets.

## Shared-file protocol

- `lib/beui.dart`: append-only `// v3-components exports` block at EOF.
- `example/lib/explorer/catalog.dart`: `kComponents` only (New badges + All order).
- `CHANGELOG.md`: bullets under `### Components` in Unreleased.
- `README.md`: Components table only.
- Do not touch `example/lib/explorer/shell.dart`.

## Remaining gaps (named, not blocking this PR)

- Tooltip: `BeuiTooltipTrigger` / `BeuiTooltipContent` are identity wrappers; the shorthand `BeuiTooltip` owns hover, arrow, `followCursor` and collision-aware flip. Source hover inside the beui.dev preview iframe often misses the widget (capture_frames lands on chrome).
- Alert: enter/exit uses motor via `_engine.dart` (`SingleMotionBuilder`); variant icon morph is a fade/slide, not a shared-layout glyph swap.
- Timeline demo tiles are `CustomPaint` placeholders; source uses chart/photo imagery.
- Arc Picker: expanding bracket morph is simplified.
- Image Viewer: the local thumbnail-to-viewer transition morphs an actual source `Rect` with `MotionBuilder<Rect>`; no cross-route FLIP/shared-layout equivalent is ported.
- Color Picker: loupe is ported; trigger-to-area morph is not.
- Adaptive Stepper: rest +/- are circular outlined actions with a `foreground` border at alpha `0.18` and a `muted` hover fill. No SVG `Liquid` gooey filter or connected liquid blob is ported.
- Color Selector: selection ring hops with `beuiSpringLayout` (linear spring) rather than the source `arc()` path.
- Tabs overflow host always uses `ClipRect` + horizontal `SingleChildScrollView`. Chevrons come from `ScrollController` metrics after the first frame. A first-frame yellow overflow stripe can appear in debug paint; it is a Flutter debug artifact and does not show in profile/release.
- Harness `defaultMono` paints selected/primary as white; beui.dev uses a blue primary. Color-score drops against the site are theme, not widget bugs.

## Review status

[Review record](https://github.com/codenameakshay/beui/blob/c0878f554a9b44799ad4b727f626980df941cd05/docs/proof/v3-components/REVIEW.md) records the repaired lifecycle, reduced-motion, accessibility, and demo-caller findings with RED evidence and exact central commands. The parent verified 212 local tests passing across 20 affected files and clean analysis of 48 touched Dart files. Goldens were skipped; no app, simulator, or device proof was produced. Existing screenshots and scores predate the repairs and do not certify their visuals. Named parity gaps above remain.
