# Chart round two evidence

The six assigned implementation gaps are repaired. No chart has exact visual or motion certification.

## Revisions and scope

The original baseline remains `5ec78ac30e1274727ddd185a883346e4d908e6c8`. All 52 files in its `before/` recording set retain their hashes. This round starts at `b3308ad`, which contains round one. The new `before-round2/` captures show that commit, not the original baseline.

Implementation commit is `e86beb842859e7cd72b3daf70215c10786181aec`. `inputs.json` records the exact candidate file hashes and canonical source-preview hashes.

Pinned source remains `a76e57c9bbc2837e96420b2610e9c82a3271bb05` at `/tmp/beui-charts-reference-20261023`. Its worktree is clean. Live references use `https://beui.dev/charts/<slug>`, with deployment revision unknown.

Port 8101 belongs to Python PID 15201 in another worktree. This worker leaves it untouched and serves its release build on 8106. Changes cover charts, their demos, their tests, and append-only chart evidence. No shell, theme, barrel, catalog, engine, or Sankey change is included. PR26 remains the single parent PR. This worker does not push, create a PR, or merge.

The full audit inventory contains 13 chart rows. Each points to `components/previews/charts/<slug>.preview.tsx`. Their `sourceExamples` arrays are empty. This does not waive `audit/states.json` or certify every composed part.

## Changed states and source correspondence

Source paths are relative to the pinned checkout. Candidate paths are relative to this repository.

| Chart and parts | Before round two | Repaired states | Source correspondence |
| --- | --- | --- | --- |
| Candlestick Chart and Plot | Only the last close springs. Other geometry jumps. No stagger. | Stable candle IDs own independent wick, body, and volume rectangle springs. Updates and reversal retarget in flight. Entrance fades for 300ms with 12ms per-candle delay, capped at 600ms. Last-price line and tag spring in pixel coordinates through scale changes. Reduced motion snaps geometry. | `components/charts/candlestick-chart/plot.tsx:138-220,250-258`; `lib/src/charts/candlestick_chart.dart`, plot and `_AnimatedCandle`. |
| Bump Chart and Plot | Paths, dots, and endpoint labels jump. Missing path hover and point motion. | Shared X/Y springs per series ID and period align paths, dots, and labels. Path reveal runs for 280ms with 25ms series stagger. Path hover uses a scaled 16px transparent-hit-stroke equivalent. Point entrance starts at .85 scale. Hover reaches 1.12 without pinning. Exit restores the pinned series. Focus, Enter, Space, and Escape remain supported. Removed identities dispose controllers. | `components/charts/bump-chart/use-geometry.ts:7-52`, `series.tsx:45-90`, `point.tsx:41-108`; `lib/src/charts/bump_chart.dart`, `_BumpGeometry`, `_BumpPathLayer`, `_BumpDot`. |
| Donut Chart, Plot, demo | Total drives entrance. Narrow layout remains a desktop row. | Entrance waits for 40% visibility, then runs once. Ring starts at -90 degrees, .88 scale, and zero opacity for 900ms. Segments fade for 400ms after 150ms plus 60ms per index. Emphasis springs to 1.05 around the ring center. Static hit geometry stays fixed. Root and demo stack below 640px. Root and narrow demo use 256px plots; desktop demo stays 240px. Track opacity becomes .6. | `components/charts/donut-chart.tsx:26-35`, `donut-chart/plot.tsx:31-122`; `lib/src/charts/donut_chart.dart`, `_BeuiDonutPlotState`; `example/lib/demos/donut_chart_demo.dart`. |
| Volume Profile, Plot, Tooltip state | Positional IDs and midpoint prices cannot express stable replacement or unequal ranges. | `.range(id:, priceLow:, priceHigh:, volume:)` adds stable bounded bins. Legacy `price:` is a documented unit-width adapter. Validation rejects duplicate IDs, overlapping or reversed ranges, nonfinite or negative values, invalid targets, and aggregate overflow. Real ranges drive bar heights and gap hit testing. Same-ID replacement retains inspection; removal and empty data clear it. Up/Right increase price, Down/Left decrease it. Escape and exit close the tooltip without clearing selection. Five measured-width price ticks, bottom volume ticks, source colors, grid, and POC marker replace the old rails. | `components/charts/volume-profile/model.ts:10-121`, `plot.tsx:42-225`, `context.ts`; `lib/src/charts/volume_profile.dart`; explicit demo ranges in `example/lib/demos/volume_profile_demo.dart`. |
| Composition Plot and demo | Default plot is 240px. Cursor is absent. | Desktop default becomes 320px. A 70%-foreground dashed cursor springs to the inspected column center. Home/End change its rendered pixels. Demo spacing and grouped visit counts follow source. | `components/charts/composition-chart/plot.tsx:48,123-138`; `lib/src/charts/composition_chart.dart:286,386-403,575-585`; `example/lib/demos/composition_chart_demo.dart`. |
| Funnel demo | ChoiceChips, different controls, heading, and subtitle. | Source-style Vertical/Horizontal buttons, heading, `Product conversion · Sample cohorts`, refresh icon, Next cohort, and 24px spacing. Cohort replacement uses canonical counts. | `components/previews/charts/funnel-chart.preview.tsx:16-62`; `example/lib/demos/funnel_chart_demo.dart`. |

`BeuiChartTween` is a chart-local helper in `_shared.dart`, not a new barrel export or engine. It uses the existing facade, source ease-out curve, cancellable mount delay, and explicit reduced-motion policy.

## Reproduction and tests

`repro-round1.log` runs applicable new regressions against untouched round-one code in `/tmp/beui-charts-round2-before-20261023`. Eight tests fail and one passes. Reduced-motion candle targets already snap in round one. The stable-range API test is excluded because that API does not exist there. The original baseline worktree is not changed.

Eleven new tests in `test/charts/chart_round2_test.dart` cover these observations:

- Rendered non-last candle wick, body, and volume bounds at intermediate frames, interruption, and reversal.
- Reduced-motion candle targets without intermediate movement.
- The second candle's 12ms entrance delay.
- Bump dot and endpoint-label geometry during interrupted rank motion.
- Bump point hover at 1.12, no pin callback, and pinned restoration.
- Bump path hover, no pin callback, and exit restoration.
- Donut root and demo narrow layout at 256px width.
- Donut 40% visibility gating and no entrance replay.
- Volume stable replacement, unequal heights, gap hit testing, keyboard direction, retained selection on Escape, removal, and invalid input.
- Composition 320px height and cursor movement through rendered pixel-column assertions.
- Funnel direction controls and literal canonical cohort counts.

Existing donut pixel expectations change from track opacity .65 to source .6. Existing volume unit-bin bounds become `price ± .5`. Its keyboard test changes Down to Up after a live-source experiment. Bump hover semantics now distinguish hover from pinning. Legend tests still assert accessible labels, allowing the existing duplicated semantics text.

Final local results:

| Gate | Result |
| --- | --- |
| Chart behavioral suite | 150 pass, including all prior 139. |
| Full `flutter analyze` | No issues. |
| Release web build | Success. Existing missing Cupertino icon-font warning remains. |
| Full chart suite | 152 pass, 11 golden failures. Round one had 141 pass and the same 11 failures. Original baseline had nine golden failures. No golden image changes. |
| Original artifact hashes | All 52 pass. |

Logs are preserved in this directory. The full repository suite is not rerun. No hosted CI, physical-device, or release result is claimed.

## Actual render setup

`render-probe.cjs` refuses to overwrite an output directory. All 13 routes have source, round-one, and repaired `rest.png` and `render.json` files. Final volume is in `after-round2-final-v3/volume-profile/`. Final bump is in `after-round2-final-bump/bump-chart/`. Earlier round-two renders remain intact. The final volume rail uses intrinsic text layout, so font readiness cannot leave a stale pre-font width measurement.

Conditions are 1280 by 1000 CSS pixels, DPR 1, dark appearance, browser zoom 1, `en-US`, and `Asia/Kolkata`. Manifests record actual browser, font readiness, rectangles, scroll, reduced-motion preference, page errors, and timer overrides. Flutter accessibility is enabled to expose canvas readouts. Candidate captures use a release web build.

The capture setup suppresses only 900ms and 950ms timers before page code runs. Source and Flutter candle manifests both record a suppressed 900ms interval, freezing canonical tick zero. Animation frames remain active. DOM ticker text contains hidden digit rails and is not a transcript of visible characters.

Several live-source pages emit React hydration error 418 during this setup. Their manifests preserve the exact error. The charts render afterward, but the source run is not an error-free health result. Candidate render manifests contain no page errors. The cause of the source hydration error is not diagnosed here.

Widths are measured, not assumed. `source-widths-1440.jsonl` records 752px candle, funnel, and bump widths at 1440px. The candidate shell clips 752px to 694px there. At 1280px, source candle, treemap, status, composition, funnel, and bump are 592px. Volume and donut roots are 576px. Order book, fan, and liquidity SVG are 520px. The query selects those widths without a shell edit. Geometry differences inside those roots remain defects.

The round-one diagnostic build already contains the parent's opt-in capture-width wrapper. It is not the immutable original baseline. No wrapper patch is applied to `5ec78ac`.

## Explain the candle and volume golden mismatches

These two failures were added in round one. They remain failures. Matched source evidence explains the intentional changes without replacing goldens.

| Chart | Matched region and data | Explanation and residual difference |
| --- | --- | --- |
| Candle | `reference/candlestick-chart/plot.png`, `before-round2/candlestick-chart/plot.png`, `after-round2/candlestick-chart/plot.png`. Each is 592 by 320 with the canonical 48 candles at tick zero and last close 2,368.44. | Source axes, 64px gutter, volume allocation, and filled candles intentionally differ from the old golden. Both current images show the same five ticks and canonical price/volume path. SSIM is 0.946841, not 1. Background, half-pixel candidate X origin, tick typography, price-tag size, and dashed-line rendering still differ. No static pass. |
| Volume | `reference/volume-profile/plot.png`, `before-round2/volume-profile/plot.png`, `after-round2-final-v3/volume-profile/plot.png`. Each is 576 by 344, Today session, 24 bins, bounds 64,000 and 66,400, maximum 278. | Source uses explicit 100-dollar ranges, five price ticks, bottom volume ticks, and a POC marker. The old inferred range stops at midpoint prices. Repaired and source bar regions both measure 513.59375px. Final SSIM is 0.932090, not 1. Background, tick typography, POC treatment, edge antialiasing, hover overlay, summary, and tooltip still differ. No static pass. |

`candlestick-ssim.log`, `volume-final-ssim.log`, and `*-difference.png` preserve the raw diagnostics. The earlier volume diagnostic is retained separately as `volume-ssim.log`. FFmpeg crops do not resize, recolor, blur, or mask either image. Fractional crop origins round to screenshot pixels. These are explanations, not pixel-exact certification.

## Remaining seven-chart behavioral audit

The audit covers source and Dart hover, text, and keyboard state handling. `interaction-probe.cjs` also records A, B, A, exit, direct focus, and ArrowRight/Home/End/Escape for all seven routes. Raw records and reversal stills sit beside the rest captures.

| Chart | Source behavior and browser observation | Candidate difference or unresolved gate |
| --- | --- | --- |
| Treemap | `treemap/plot.tsx:49-99` uses spatial focus. Browser Right moves AAPL to LLY, Home to AAPL, End to SHEL, Escape closes. `tooltip.tsx:38-65` separates ancestor path and uses 200ms value/share tickers. | Candidate combines path/title and uses separate value/share rows. Focus ownership differs. Source legend is display-only, conflicting with audit legend pinning. AAPL 210K and MSFT 190K agree. Zero-leaf replacement and text trajectories remain uncaptured. |
| Status | `status-bar/tooltip.tsx:33-55` renders static date/status/description, not numeric tickers. Browser Home shows Aug 21, End Oct 7, Escape closes. Entrance distributes 180ms delay with 240ms fade and press translation/scale. | Candidate entrance duration/stagger and reduced-motion handling differ. Existing tests cover exit retention and keyboard reopen. Direct DOM focus landed on shell focus in this probe, so keyboard parity remains unproved. Both-row replay and incident motion need capture. |
| Liquidity | `liquidity-heatmap.tsx:152,170-185,202,293-301` uses 24px cells, row-local Home/End, 2D arrows, straight trace segments with 280ms geometry tween, and 350ms size ticker. Browser Right changes 14:00/265 SOL to 14:02/414 SOL. End reaches 14:46/93 SOL in that row. | Candidate uses 18px cells, flat traversal, and cubic trace. Existing tests assert cubic behavior, not source equivalence. Irregular buckets and text continuation remain uncaptured. |
| Order book | `order-book/depth-row.tsx:38-57,75-124` uses PANEL depth springs, .85 entrance, 25ms stagger capped at eight, 80ms rise and 200ms tint fade, and price-button focus/blur. Native price buttons do not implement chart arrows. | Candidate depth/tint motion and generic inspection differ. Both renders freeze the 950ms timer. The probe found only one price target, so it does not prove A-to-B cumulative tooltip motion. Empty and one-sided states remain unrecorded. |
| Heat calendar | `heat-calendar/utils.ts:35-41` formats UTC weekday/month/day without a year. `grid.tsx:94-106` uses per-cell focus and Escape, not arrow traversal. Browser Jul 6/Jul 7 show 0/3 commits. Tooltip uses 350ms ticker and selected-span text. | Candidate adds the year and changes readout layout and arrow behavior. Its DOM ordering is weekly, unlike source day order. Blank traversal, filtering, range totals, and count need matched proof. |
| Returns calendar | `returns-calendar/utils.ts:7`, `grid.tsx:95-101,177-183`, `context.ts:145-149` use Jan/Jun/Jul, month-first titles, per-cell Tab/Enter/Escape, diagonal entrance, hover 1.15, and year-row wave. Browser Jan/Feb 2021 show +1.1%/+4.0%. Arrows do not move native focus. | Candidate uses full names, year-first titles, generic arrows, and different motion. Audit full-name labels conflict with pinned and live source. This round makes no naming-policy change. |
| Price target fan | `price-target-fan/series.tsx:16-54,74-96,134-166` exposes one history slider and separate targets. History focus selects latest; arrows/Home/End scrub; blur clears. History reveals for 900ms, fan for 800ms after 850ms, targets use PANEL. Tooltip metrics are static; header animates. High/Mean browser values are $232/$205 with 9/34 analysts. | Candidate exposes individual history points and generic inspection. Existing tests cover actual-point drag and Mean restoration. Browser exit also restores $205 Mean. History-slider parity, target/header trajectories, axes, resize, theme, and updates remain open. |

Direct focus is not Tab traversal. Flutter sometimes redirects it to a parent or shell control. Those records are inconclusive, never a keyboard pass. Raw tooltip strings contain hidden ticker rails. They do not certify visible animated characters.

## Remaining work and recorder handoff

The six repaired charts still have these gaps:

- Candle legend palette, focus-visible ring, exact tag formatting, repeated opacity-delay behavior, and matched tick recordings.
- Bump source rank/change legend grid and exact keyboard semantics. Point, path, and hover-text trajectories still need matched recording.
- Donut source DigitSwap center text and caption opacity/slide. Segment trajectories remain unproved.
- Volume floating tooltip placement, source total/POC/value-area summary grid, hover tint instead of border, opacity entrance, and replacement trajectories.
- Composition bar/area geometry animation and source narrow 256px height breakpoint.
- Funnel shape, stage motion, tooltip placement, and pathological-data recordings.

This implementation worker produces no new video. The parent's dedicated recorder owns cadence, procedure, side-by-side assembly, and visible captions. The 52 old baseline artifacts remain unchanged. Their 25fps fixed sweeps cannot certify short springs or ticker motion.

The parent still owes native 60fps reference/before/after sequences, exact datum identities and timestamps, entry-before-event capture, light mode, effective Flutter reduced motion, Tab traversal, interruption, exit, and all audit states. The round-two captions are in `../changes.md`. New stills are diagnostics, not video replacements.

The motion review remains blocked for parity sign-off. Source-specific durations take precedence over generic polish preferences. Candidate interruption tests do not prove source trajectories. No nonzero image diff is a pass.

Poteto choices are concrete. Model the Domain keeps stable range and point identities. Fix Root Causes replaces total-driven donut entrance and last-close-only candle motion. Prove It Works separates local gates, unchanged golden failures, actual renders, and missing motion proof. The user forbids agents, so delegated review steps are skipped. The unavailable `deslop` plugin is replaced by a manual diff and unslop pass, not claimed as a plugin run.
