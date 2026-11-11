# Chart expression-color audit

## Scope and verdict

Read-only audit of the pinned beUI v2 `PriceTargetFan` and `ReturnsCalendar`
color expressions against the current Flutter counterparts. Source revision:
`1ab921e62283e788a686bc4bafa1de5ff56104ea` at
`/Users/codenameakshay/.t3/artifacts/beui-v3.1.0/source-1ab921e6`.

**Verdict: expression-color parity is not established.** There is explicit
source/local drift in both widgets: light-mode relative-OKLCH text capping is
missing; calendar mix percentages round in source but stay continuous locally;
and fan text consumers currently receive the same raw target color as the
geometry. This audit intentionally changes no widget, shared parser, test, or
golden.

The chart source relies on CSS Color 4 relative colors and `color-mix()`. The
chart CSS parser in `lib/src/charts/_shared.dart` explicitly does not evaluate
those expressions (or arbitrary CSS); parsing ordinary literal colors or
simple `var(--token)` aliases is not an equivalent implementation. Do not infer
“any CSS color parity” from this audit. A future chart-owned, literal
expression implementation would need its own behavior tests; it must not
silently expand the shared parser's contract.

## Source expressions and consumers

`price-target-fan/utils.ts` defines `UP = var(--success)`,
`MID = var(--accent)`, `LOW = var(--warning)`, and
`ink(c) = oklch(from c min(l, var(--ink-l, 1)) c h)`. Its chart wrapper sets
`--ink-l: 0.5` in light mode and `dark:--ink-l: 1` in dark mode.

- `price-target-fan/context.ts`: target colors default by target index to UP,
  MID, LOW; explicit `target.color` overrides them.
- `price-target-fan/series.tsx`: projection lines and endpoint strokes consume
  the raw target color; target price SVG text consumes `ink(p.color)`.
- `price-target-fan/header.tsx`: the signed percentage consumes `ink(head.color
  ?? (headPct >= 0 ? UP : LOW))`.
- `price-target-fan/tooltip.tsx`: the accent metric value consumes
  `ink(overlay.accent.color)`.
- Header/tooltip body text and SVG axes use ordinary `--foreground` /
  `--muted-foreground` tokens, not `ink()`.

`returns-calendar/utils.ts` defines UP=`var(--success)`,
DOWN=`var(--destructive)`, `range = 8`, the same relative-OKLCH `ink()` cap,
and `tint(v, range, on)` as a `color-mix(in srgb, hue pct, transparent)` where
`pct = Math.round(min(abs(v)/range,1)*55 + (on ? 24 : 8))`.

- `returns-calendar/grid.tsx`: monthly cell background uses `tint(v,8,on)`;
  monthly numeral color is `color-mix(in srgb, var(--foreground) pct%,
  transparent)` with `pct = Math.round(85 + min(abs(v)/8,1)*15)`; annual numeral
  color is `ink(totals[y] >= 0 ? UP : DOWN)`.
- Annual neutral fill is transparent foreground at 6% (or background while
  hot); focus/selection ring uses foreground. These do not use the hue cap.
- `returns-calendar/tooltip.tsx:48` also applies `ink()` to its signed metric.
  The local grid composes a muted label and shared `BeuiChartTicker` in a
  `Wrap`, then passes that widget to the shared chart tooltip. Its signed metric
  uses raw success/destructive colors without the source cap. Annual cell text
  is not the only calendar `ink()` consumer.

## Literal expected source expressions

The table gives the CSS expression that source constructs for the requested
values. “Hot” means `on=true` for the tint. Negative returns use DOWN while
positive and zero returns use UP. The foreground numeral mix is sign-neutral.
The source `range` is 8. Percentages below use JavaScript `Math.round`.

| `v` | monthly tint, normal | monthly tint, hot | month numeral mix |
|---:|---|---|---|
| 0 | `color-mix(in srgb, var(--success) 8%, transparent)` | `color-mix(in srgb, var(--success) 24%, transparent)` | `color-mix(in srgb, var(--foreground) 85%, transparent)` |
| 1 | `color-mix(in srgb, var(--success) 15%, transparent)` | `color-mix(in srgb, var(--success) 31%, transparent)` | `color-mix(in srgb, var(--foreground) 87%, transparent)` |
| 2 | `color-mix(in srgb, var(--success) 22%, transparent)` | `color-mix(in srgb, var(--success) 38%, transparent)` | `color-mix(in srgb, var(--foreground) 89%, transparent)` |
| 4 | `color-mix(in srgb, var(--success) 36%, transparent)` | `color-mix(in srgb, var(--success) 52%, transparent)` | `color-mix(in srgb, var(--foreground) 93%, transparent)` |
| 8 | `color-mix(in srgb, var(--success) 63%, transparent)` | `color-mix(in srgb, var(--success) 79%, transparent)` | `color-mix(in srgb, var(--foreground) 100%, transparent)` |
| -2 | `color-mix(in srgb, var(--destructive) 22%, transparent)` | `color-mix(in srgb, var(--destructive) 38%, transparent)` | `color-mix(in srgb, var(--foreground) 89%, transparent)` |

Annual positive/zero ink expression:

```css
/* light root */
oklch(from var(--success) min(l, var(--ink-l, 1)) c h)
/* dark root */
oklch(from var(--success) min(l, var(--ink-l, 1)) c h)
```

Annual negative expression is the same template with `var(--destructive)`.
The expression text is identical in both modes; computed lightness differs
because the root custom property is 0.5 in light and 1 in dark. Fan text uses
the identical template for whichever raw target color it consumes (including
`var(--warning)` and `var(--accent)`). The fallback `1` applies only if the
wrapper's `--ink-l` is absent.

After substituting the pinned chart wrapper's `--ink-l`, the expected source
expressions are explicitly:

```css
/* light */
oklch(from var(--success) min(l, 0.5) c h)
oklch(from var(--warning) min(l, 0.5) c h)
oklch(from var(--accent) min(l, 0.5) c h)
oklch(from var(--destructive) min(l, 0.5) c h)
/* dark */
oklch(from var(--success) min(l, 1) c h)
oklch(from var(--warning) min(l, 1) c h)
oklch(from var(--accent) min(l, 1) c h)
oklch(from var(--destructive) min(l, 1) c h)
```

## Theme inputs (source values, not rendered-color claims)

Pinned `lib/theme-css.ts` and `app/globals.css` establish these generic CSS
inputs. `--destructive` aliases `--danger`. `--ink-l` is a chart wrapper value,
not a palette token.

| CSS input | light source literal | dark source literal | current local neutral `BeuiColors` |
|---|---|---|---|
| `--ink-l` | chart wrapper `0.5` | chart wrapper `1` | no corresponding chart-level cap |
| `--foreground` | `oklch(15% 0 0)` | `oklch(96% 0 0)` | `0xFF0B0B0B` / `0xFFF2F2F2` |
| `--success` | `oklch(70% 0.18 155)` | same base literal | `0xFF00BE6A` both brightnesses |
| `--warning` | `oklch(78% 0.18 75)` | same base literal | `0xFFF9A300` both brightnesses |
| `--accent` | `oklch(72% 0.18 195)` | `oklch(80% 0.18 195)` | Mono: `0xFF00C5C7` / `0xFF00DFE1`; colored Flutter themes override this field |
| `--destructive` | `var(--danger)` → `oklch(62% 0.22 25)` | same base literal | `0xFFEE343B` both brightnesses |

The local sRGB hex values are the committed outputs in
`lib/src/theme/beui_colors.g.dart`; they are conversion-reference diagnostics,
not browser-effective or wide-gamut color evidence. Do not assume the default
source accent remains in force for every consumer/theme: CSS custom properties
can be overridden by an embedding app, and local `BeuiColorTheme` intentionally
changes accent for non-Mono variants. The pinned source snapshot's generic
theme CSS has the light/dark inputs above; it does not establish all possible
consumer overrides. Actual effective colors require a live source/browser
check per relevant theme.

## Local mapping and observed drift

| Source consumer | Flutter counterpart | Current behavior / drift |
|---|---|---|
| Fan raw target defaults/overrides → projection geometry | `_targetColor` at `lib/src/charts/price_target_fan.dart:1195`, painter at `:1355`; colors through `beuiChartColor` in `_shared.dart:45` | Ordinary theme-token/raw target resolution is present. No relative-color operation is present. This is appropriate for raw geometry, not a substitute for text `ink()`. |
| Fan `ink()` for target price labels, header percentage, tooltip accent metric | target label `:757`; header percentage `:453`; tooltip metric `:1143` all use raw theme/target colors | Missing OKLCH lightness cap (light `min(l,0.5)`); these text consumers currently share raw colors with geometry. Source header also prefers the active head target color before sign-based UP/LOW, whereas local header colors solely by sign. |
| Calendar `tint()` month fill | `lib/src/charts/returns_calendar.dart:773-780` | Uses continuous `(hot ? .24 : .08) + intensity * .55`, then alpha-blends over background. Source rounds the resulting alpha percentage to an integer before CSS color-mix. |
| Calendar selected month outline | `:782-785` | Uses fixed alpha `.65`; source's visual cell selection ring is foreground `RING`, while the separate transient hover border is raw UP/DOWN. Compare source state/role, not only hue strength. |
| Calendar month numeral foreground mix | `:797-799` | Uses continuous `.85 + intensity * .15`; source rounds the corresponding percentage (e.g. 1→87%, 2→89%, 4→93%). |
| Calendar annual numeral `ink(UP/DOWN)` | `:795-797` | Uses raw success/destructive; missing source light cap (`--ink-l=0.5`). |
| Calendar tooltip signed metric `ink(UP/DOWN)` | Grid `Wrap` at `:546` contains a muted label and shared `BeuiChartTicker`; its metric style at `:561` uses raw success/destructive, then `_ReturnsCell` passes the widget to `BeuiChartTooltip` at `:720` | The signed metric already has separate styling, but lacks the relative-OKLCH cap. Keep the shared ticker and tooltip when repairing the chart color. |
| Calendar annual neutral fill | `:767-772` | `.06` foreground alpha matches source's 6% expression in strength; exact effective color depends on source background/theme compositing. |
| Theme resolution | `lib/src/theme/beui_colors.g.dart`; `BeuiColors` is passed into charts | Generic light/dark neutral tokens match the pinned CSS conversion inputs. Local brand variants alter `accent`; source browser output under a matching consumer override has not been captured here. |

## Evidence boundary / remaining gates

- Source hashes and local snapshot hashes are in `expression-colors.json`.
- No browser was run and no source/comparison screenshot was captured. CSS
  expression strings and percentage arithmetic above are source-derived
  expectations, not actual computed browser colors.
- Before claiming color parity, verify effective CSS custom properties and
  computed colors in the actual source browser for light/dark plus any relevant
  brand/consumer theme, and compare matching Flutter output.
- Add literal outcome regression tests for fan text-vs-geometry routing,
  calendar integer rounding, sign/hot-state tint, and light/dark ink caps before
  resolving the drift. These are future tests, not present proof.
- No shared-parser arbitrary-CSS support, any-CSS-parity claim, production fix,
  widget test, fixture, build, device run, or visual/performance claim is part
  of this audit.
