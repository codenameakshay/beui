# Chart parity implementation handoff

Exact parity is not certified for any chart. This slice contains repairs, preserved baseline recordings, and an explicit remaining-work inventory.

## Revisions and ownership

- Baseline is `5ec78ac30e1274727ddd185a883346e4d908e6c8`.
- Source checkout is `a76e57c9bbc2837e96420b2610e9c82a3271bb05` at `/tmp/beui-charts-reference-20261023`.
- Live references came from `https://beui.dev/charts/<slug>`. The deployed SHA is unknown. The checkout SHA does not identify the live deployment.
- Implementation commit is `bc0966d668c99401f131ce7c8e389917477e8cad`.
- Gallery uses port `8101`. The final release build includes the implementation commit's code. Only evidence files were added afterward.
- Changes stay within charts, chart demos, and chart tests. No shared shell, catalog, barrel, theme, or engine changes are included.
- The parent audit at `fe9213f` supplies the complete route and state obligations. The 13 chart routes are all in scope, including every changed or new-badged route.
- Sankey is a fourteenth live chart with source files, but has no route in this baseline. Adding its route and exports needs parent coordination.

## Immutable before evidence

`before/<slug>/interaction.webm` records the untouched baseline gallery. Each directory also contains `idle.png`, `hover.png`, and `page.json`. `BEFORE.sha256` seals all 52 original files. A final `shasum -a 256 -c ../BEFORE.sha256` from `before/` passed for every file.

Do not rerun `capture.cjs before`. It would overwrite the originals. The existing script is retained unchanged as the capture protocol record.

`reference/<slug>/interaction.webm` records the live site. `after/<slug>/interaction.webm` records the earlier repair build. `after-final/<slug>/interaction.webm` records the final release build, including the volume-area and candle-fill repairs. These are actual browser screencasts, not still-image slideshows.

## Recording limitations and recovery handoff

The T3 preview workflow used `preview_status`, then `preview_open` with an owned tab. Reference navigation succeeded. Two consecutive snapshots returned the same raw error:

```text
Preview automation snapshot timed out after 15000ms.
```

Owned tab was `tab_3_de45f4e8-31fc-4722-b9f5-f0b871f95dbb`. The documented two-failure fallback used isolated headless Chrome through Puppeteer. No user-owned tab was driven.

The script requested 30 FPS. FFprobe reports 25 FPS. The bump reference has 161 decoded frames and its earlier after recording has 147. Native 60 FPS proof is absent. The recordings begin after a 1.8-second settle, so they miss initial reveal motion. Fixed-coordinate sweeps miss some chart-specific controls and do not establish datum A-to-B identity. Event timestamps were not saved.

Final-build recordings have 146 to 336 decoded frames despite the same requested event sequence. FFprobe returns no container duration. The manifest preserves every raw probe. The reported 25 FPS does not establish reliable wall-clock sampling or complete event coverage. The final hash audit caught one provisional probe taken before liquidity recording stopped. The committed manifest uses the completed file's 169-frame probe and final hash.

All sets use a 1440 by 1000 viewport, DPR 1, and dark appearance. Reference and candidate component widths differ. Candle and order-book live updates are not time-synchronized. Locale, timezone, font readiness, zoom, and reduced-motion values were not independently recorded. Candidate `page.json` has no accessible canvas-rendered content. It is not a successful DOM inventory.

The parent has a dedicated capture-recovery worker. This slice adds no replacement recorder. Recovery still owes matched component rectangles, exact data and tick state, entry-before-event capture, timestamped A-to-B-to-A-to-exit interactions, every named source example, light appearance, and effective reduced motion. It also owes side-by-side before/after videos with visible change text. Raw per-route videos and the change manifest are ready for that work.

## Route, part, and state inventory

Every row owes rest, hover exit, keyboard, reduced motion, and every named source example. The state text below comes from the parent audit. A composition capture must identify each exercised part. A screenshot of the root does not certify every part.

| Route | Owned parts | Required source states | Retained change | Verdict and remaining gap |
| --- | --- | --- | --- | --- |
| treemap | Chart, Plot, Tooltip, Legend | Q1 Q2 Q3 reversal and zero leaf; A-to-B value and label; exit restoration; tile focus and legend pin | None | Inconclusive. Matched layout, tooltip transitions, zero-leaf replacement, and keyboard recordings remain absent. |
| candlestick-chart | Chart, Legend, Plot | Initial reveal and deterministic live updates; A-to-B crosshair and OHLC; leave baseline restore; Pause Step and keyboard | Source axis, gutters, volume geometry, Y crosshair, pointer tag, blur, focus, and live controls | Fail. Wick, body, and volume geometry still lack independent source springs and the 12ms entrance stagger. Legend palette, focus ring, formatting, and matched tick recordings remain unresolved. |
| donut-chart | Chart, Plot, Center, Legend | Sweep reveal; each segment A-to-B label/value/share; leave and pin; reorder, zero, keyboard | Cap-aware gaps and controlled demo selection | Fail. Source ring entrance and segment motion remain unmatched. Narrow viewport column layout is not ported. Center and tooltip text trajectories lack matched proof. |
| volume-profile | Chart, Plot, Summary, Tooltip | Every session tab; highest/middle/lowest bin; leave and placement; uneven prices, empty, replacement, keyboard | Source session observations and value-area expansion rules | Fail. Public bins still expose one representative price rather than stable IDs and priceLow/priceHigh ranges. Source range geometry and validation are missing. |
| status-bar | Chart, Plot, Legend, Tooltip | Both source series; Replay; exact period A-to-B status and timestamp; exit with retained selection; keyboard after exit | API and Website rows, Replay, Simulate/Resolve incident | Inconclusive. Both-row layout, exact tooltip text transition, entry stagger, selection retention, and keyboard-after-exit need matched recordings. |
| composition-chart | Chart, Plot, Legend | Both views and all periods; A-to-B values/shares; leave then keyboard; series pin, missing periods, updates | None | Fail. Candidate plot defaults to 240px. Source desktop plot is 320px and paints a cursor absent from the candidate painter. |
| funnel-chart | Chart, Plot, Summary | Canonical stages/counts; A-to-B conversion/dropoff; leave restore; keyboard, disabled, empty, zero, replacement | None | Fail. Demo still uses ChoiceChips and does not reproduce source controls, heading, and subtitle. Shape and motion comparison remains open. |
| liquidity-heatmap | Chart, Plot, Legend | Canonical bands and trace; Resimulate; cell A-to-B exact units/price; exit and clipping; irregular buckets, empty, keyboard | Source phase-zero price/data formula and stable-ID resimulation | Inconclusive. Cell geometry, tooltip A-to-B continuation, trace motion, axes, and irregular buckets lack matched evidence. |
| bump-chart | Chart, Plot, Legend | All rank paths/dots/labels/gaps; exact rank A-to-B; hover versus pin and exit; focus, Enter, blur, removal | Source viewBox geometry, aligned dots, outlined markers, rank change text, Shuffle permutations | Fail. Path and point springs, entry and hover motion are not ported. Tool diagnostic is static and inconclusive. |
| order-book | Root, Header, Side, Spread, DepthSummary, Balance | Canonical asks/bids; Pause Step; row A-to-B cumulative size/average/spread; exit; live reorder, empty, one-sided, keyboard | Source-sized rows, live snapshots, Pause/Resume, Step, selected-price text | Inconclusive. Reference tick state is unsynchronized. Row-depth springs, cumulative tooltip changes, and one-sided behavior need exact recordings. |
| heat-calendar | Root, Grid, Legend, Tooltip | Canonical dates/totals/ranges; weekday/date/value A-to-B; exit/filter reset; keyboard blanks and refresh | Removed invented cyan override | Inconclusive. Exact dates, tint scale, entry stagger, blank-day traversal, filtering, and tooltip text transitions remain unproved. |
| returns-calendar | Root, Grid, Tooltip | Year/month cells and rounding; Jan June July full-name percent A-to-B; exit/year selection; unavailable and short years | None | Inconclusive. Cell geometry, month naming, year controls, entrance and ticker motion lack matched-state proof. |
| price-target-fan | Root, Header, Plot, Svg, Axes, History, Targets, Now, Cursor, HistoryPoints, Tooltip | Dated history and targets; exact history/target A-to-B readout; leave/blur Mean restore; drag from point, resize, theme, update | None | Inconclusive. Complete part composition, actual-point drag, tooltip exit, axis sizing, and source trajectory proof remain absent. |

Shared chart parts also remain in scope. These are `BeuiChartSwatch`, `BeuiChartLegend`, `BeuiChartLegendItem`, `BeuiChartSpring`, `BeuiChartSpringRect`, `BeuiChartFade`, `BeuiChartTicker`, `BeuiChartTooltip`, `BeuiChartTooltipCard`, and `BeuiChartFrame`. The shared chart code was not changed. Tests assert that hover tooltip bodies contain `BeuiChartTicker` and `BeuiNumberTicker`, but that does not prove a visible A-to-B character transition or interruption behavior.

## Checks and exact limits

- `chart-behavior-final-v2.log` records 139 passing behavioral chart tests.
- `analyze-final.log` records a clean full `flutter analyze`.
- `build-final.log` records a successful release web build. The build warns about a missing Cupertino icon font. No claim about that unrelated font is made.
- `chart-tests-final.log` records 141 passes and 11 golden failures. The untouched baseline log records 130 passes and nine golden failures. Candlestick and volume profile add mismatches after intentional rendering repairs. Donut and bump also change their existing mismatch deltas. The existing goldens were not changed.
- `full-tests-final.log` records 2092 passes and 47 failures in the full repository run. It is not green. Only the chart baseline was independently rerun, so no claim is made that every non-chart failure predates this slice.
- `volume-area-red.log` and `volume-area-green.log` preserve early failed attempts with incomplete numeric formatting literals. They are not valid red-to-green proof. The final tests use explicit two-decimal price and one-decimal percentage strings and pass in the behavior log.
- `design-compare-bump-diagnostic.json` preserves the actual Design Compare response. It compared the first 100 native frames of the full viewport recordings. `motion_status` is `static`, `motion_score` is null, and temporal correlation is approximately -0.094. Different rectangles and insufficient motion make this inconclusive. No source-to-before or useful tight-region motion comparison passed.
- No settled matched-region image diff has passed. No light or reduced-motion reference/candidate video pair passed. No route is ready for exact-parity sign-off.

## Principle decisions

Model the Domain kept candle identity separate from pointer Y, so keyboard inspection clears pointer-only geometry. Test Behavior, Not Implementation added visible midpoint labels, pointer state transitions, exact bump marker coordinates, rendered donut gap pixels, demo actions, and value-area summaries. Prove It Works kept analysis, behavioral tests, unchanged-golden failures, browser recordings, and source parity as separate results.

Poteto's requested `deslop` plugin is not installed. The writing and staged diff received a manual unslop pass. Its delegated review steps were not run because this sub-agent was explicitly forbidden to spawn further agents. No PR was created, pushed, or merged.
