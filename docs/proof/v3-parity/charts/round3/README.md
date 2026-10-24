# Chart round three evidence

The seven audited charts now use the source inspection models instead of the previous generic chart keyboard model. This round also repairs the donut's directional readout and native legend. This is an implementation handoff, not exact visual or motion certification.

## Final integration repairs

The parent integration exposed a real regression in the v8 donut center. Its 56% wrapper constrained the shared DigitSwap row after the blocks owner switched slots to actual zero-glyph metrics in `82f12dbe`. Both unchanged parent tests reproduced the 47px and 56px RenderFlex overflows. `201c4bde` adds a failing-first intrinsic-value regression. `13f480bb` keeps the 56% caption cap while allowing the source's non-wrapping, centered, 24px digits to retain their intrinsic width. It does not shrink or clip the value and does not change generic DigitSwap.

The independent review tests from `4df5cc9b` are integrated unchanged as testing dependency `541726b4`. They reproduced eight passes and three failures. `86db12e9` prevents an old controlled donut blur callback from clearing the newly focused destination. It checks actual row focus because the controlled parent has not necessarily rebuilt yet. `058967a0` discards removed uncontrolled status ownership in `status_bar.dart`, without changing the shared active-state helper.

`c14b7c41` repairs fan target touch-down toggling, but was not sufficient on Flutter web. Actual v9 trusted-touch footage showed the second tap reopening High. Temporary diagnostics found a touch-kind `PointerHoverEvent` after touch-up. The hover handler called `_moveTo` and restored the target. `a2f31b75` reproduces that exact ordering and fails before `dc7d3332`. That repair ignores touch hover and exit, following `price-target-fan/context.ts` and `plot.tsx`. No generic Tooltip fallback is added. The final v10 second-tap frame returns to Mean with no tooltip, matching the source. V9 failed footage and its `observed-touch.json` remain intact.

The status identity browser fixture imports the untouched pinned source StatusBar and Tooltip. Native Tab opens Tuesday. Native R removes it and I reinserts it without a focus transfer. Its readout stays closed until ArrowRight explicitly inspects again. Source and candidate pass all five visibility checks in both motion preferences, and the exact same focused DOM element remains mounted at every step. `status-ownership-browser-states-2.json` records the 20 states. `captures-status-identity/` supplies actual source and candidate videos. The first verification attempt used an incorrect exact-text selector for Flutter's combined semantics label. Its failure is retained; the corrected observer recognizes the actual combined label and still requires a positive initial readout. These are behavior-only fixtures, not source pixel baselines.

Final-frame review rejected the v10 candidate fan keyboard claim. Its canvas mouse click did not acquire target focus. Tab reached the shell and Enter navigated to Components. The source endpoint click retained target focus. `b436f8d8` reproduces the native mouse-click, pointer-exit, Tab failure. `4118dffa` gives targets stable chart-owned FocusNodes and requests focus on non-touch pointer-down only. It also preserves the destination when Flutter delivers the previous target or history blur after the new focus callback. No generic Tooltip or button code changes. The new test covers native mouse release, pointer exit, Tab, Escape, Enter, Space, reverse traversal into history, and Tab back to High.

The replacement `captures-final-v11/` visibly shows Mean after the first Tab, Low after the second, closed after Escape, Low after Enter, closed after Space, and Low after Enter again. Both motion preferences pass this visible sequence. Four new trusted-touch recordings repeat the same sequence twice per preference. Every second tap closes High and returns to the default Mean header. Every third tap restores High. They retain actual trusted touch pointer-down/up/click observations. The earlier v9 touch failure and v10 keyboard failure remain before evidence, not accepted keyboard or touch results.

## Scope and preserved inputs

Pinned source is `a76e57c9bbc2837e96420b2610e9c82a3271bb05` in `/tmp/beui-charts-reference-20261023`. Its worktree remains clean. Live recordings use `https://beui.dev/charts/<slug>`. Their deployment revision is unknown, not the pinned SHA.

The original baseline is still `5ec78ac30e1274727ddd185a883346e4d908e6c8`. `original52-final-v7.log` verifies all 52 sealed original artifacts against `../BEFORE.sha256`. The original `../before/`, prior round evidence, and golden images are not edited. New `before/` recordings in this directory show round-two head `cb473df0b4f51800db0a67b4ba0b9b9498ce8d50`, not the original baseline.

Owned changes cover chart implementations and tests. No font, theme, generic Tooltip, recorder, shell, or engine implementation is owned here. Only port 8109 is used. Other workers' servers and worktrees are untouched. Parent PR26 remains the only PR. This worker does not push or merge.

The round-two blanket statement that the parent owns every new recording is superseded. This worker supplies actual route-specific before, source, and after videos, original frames, hashes, effective input timelines, and SRT captions. Parent still owns the final montage and independent review.

## Source correspondence

Source paths below are relative to the pinned checkout. Candidate paths are under `lib/src/charts/`.

| Chart | Implemented correspondence | Source |
| --- | --- | --- |
| Shared chart tooltip | Controlled `open` and `onOpenChange`. The same mounted target owns the `externalAnchor` key and `anchorLink`. Charts own dismissal and keyboard reopening. Composition and bump also supply controlled visibility. No arbitrary key reopens a dismissed chart tooltip. | `components/motion/tooltip.tsx`, `tooltip-surface.tsx`; candidate `_shared.dart`, `composition_chart.dart`, `bump_chart.dart`. |
| Liquidity | 24px cells, actual roving focus, two-dimensional arrows, row-local Home/End, straight trace segments, 280ms interrupted geometry tween, reduced-motion snap, source underlay/stroke order, 350ms size ticker. | `components/charts/liquidity-heatmap.tsx`, especially keyboard handling, SVG cells, trace, and tooltip. |
| Returns | Jan/Feb month labels, month-first titles, source 480px width, native cell Tab/Enter/Escape, no invented arrow traversal, compounded selected spans, diagonal entrance and 1.15 hover, year replay wave, signed-color 350ms return ticker. | `returns-calendar/grid.tsx`, `context.ts`, `tooltip.tsx`, `utils.ts`. |
| Heat | UTC weekday/month/day without an invented year, chronological native Tab across the weekly display, Escape without invented arrows, sorted reversed range labels, source inline count layout, 350ms count and total tickers. | `heat-calendar/grid.tsx`, `tooltip.tsx`, `utils.ts`. |
| Status | One range inspector per row, 44px hit region, distributed 180ms delay, 240ms fade and PRESS entrance, simultaneous 150ms reduced fade, stable keyed status crossfades, source outward active ring and capsule legend. Native Up increases and Down decreases. Initial Tab opens the current period. Escape retains its value. Focused inspection survives pointer exit. A dismissed same-period pointer does not reopen until its identity changes. | `status-bar/plot.tsx`, `legend.tsx`, `tooltip.tsx`. |
| Treemap | Spatial focus moves real FocusNodes. Blur only clears its own inspection. Ancestor path and leaf title are separate. The value and share use 200ms tickers with source foreground/muted ink and spacing. | `treemap/plot.tsx`, `tooltip.tsx`. |
| Order book | Native price-only button focus, no invented root arrow/Home navigation. PANEL depth springs retarget in flight. Entrance is 180ms with 25ms row stagger. Quantity tint rises in 80ms and falls in 200ms. Source cumulative summary remains static inline text, not a Tooltip or numeric ticker. | `order-book/depth-row.tsx`, `order-book.tsx:288-328`. |
| Fan | One history slider, UTC timestamp positions, source whole-plot nearest-curve inspection and neutral now gap, 900ms history reveal, 800ms fan reveal after 850ms, PANEL endpoints, GLIDE cursor, source nice-number dashed grid and UTC axis labels. Static metrics use a 148px surface. Target labels start at endX+10 and dim with their projections. The now dot lands after 850ms. Its 2.2s tail ring has a 1.6s repeat gap and is absent under reduced motion. | `price-target-fan/series.tsx`, `plot.tsx`, `context.ts`, `tooltip.tsx`, `utils.ts`. |
| Donut | Directional DigitSwap instead of numeric interpolation, source 220ms caption slide/fade and 120ms reduced fade, 56% center cap, 8px caption dot and 6px gap. Native legend buttons have cyclic Up/Down focus and one Tab stop per row. Left/Right/Home/End are not invented chart commands. Source 14px/48px rows, 10px dots, inset 4px share tracks, and delayed LAYOUT entrance are restored. | `donut-chart/center.tsx`, `legend.tsx`; shared `motion/digit-swap.tsx` is called, not reimplemented. |

Generic Tooltip animates the surface, not chart glyphs. Status dates/status/descriptions and fan tooltip metrics remain static. Fan header numbers animate. Liquidity, returns, heat, and treemap supply their own source tickers. Donut supplies DigitSwap. Raw DOM ticker rails are not a transcript of visible text.

## Corrected derived expectations

These corrections change derived tests and audit interpretation only. No source baseline is changed.

- Returns abbreviated months and month-first titles follow `returns-calendar/utils.ts` and live Jan/Feb captures. Full-name and year-first expectations were incorrect.
- Liquidity row-local Home/End, 2D arrows, and straight trace follow `liquidity-heatmap.tsx`. The previous flat/cubic expectations were incorrect.
- Heat dates are UTC and omit the year. Its source uses native cell traversal, not chart arrows.
- Source status is a native range. Up increments, Down decrements, and Escape closes the readout without clearing the range value. Generic inspector expectations were incorrect.
- Source treemap legend is display-only. This round does not invent legend pinning to satisfy the conflicting audit wording.
- Source order book has no floating Tooltip. Its cumulative hover/focus summary is inline and static. An interpolated numeric tooltip would diverge.
- Source fan tooltip metrics are static. Its header is animated. History is one slider, not a list of focusable points.
- Source donut legend wraps actual native focus with Up/Down only. The previous root autofocus and Left/Right navigation test was incorrect. Status legend counts include parentheses.

## Owned commits and shared dependencies

Owned implementation commits, in dependency order, are listed below. Parent may already have integrated their equivalents.

```text
f5d1e6bb control anchored tooltip visibility
9df67a3b liquidity grid and trace
dd6d0f8a native calendar inspection
18d35c03 status and treemap inspection
a18a625a order depth springs and price focus
41c8cdd1 fan slider and reveal
4d209b9a source interaction regressions
56fd807d returns width and sorted heat spans
cac1e5a0 one status range inspector
b4230fa0 full fan projection inspection
a87eb753 exclude decorative status gesture semantics
51c5b433 directional donut readout
f3b7c3a4 returns and treemap readout ink/spacing
322c3789 fan axes and static readout
5201f70c native status ownership, ring, and legend
6585cf33 fan now marker and target labels
a6691d7c native donut legend and caption layout
201c4bde failing-first intrinsic center regression
13f480bb intrinsic center digits with capped caption
86db12e9 controlled donut destination focus ownership
058967a0 removed status identity cleanup
c14b7c41 target touch-down toggle and mouse retention
a2f31b75 failing-first web touch-up hover regression
dc7d3332 source touch hover/exit guard
1a9fa600 source/candidate status ownership fixtures
b436f8d8 failing-first native mouse focus regression
4118dffa native fan target focus and blur ordering
```

The following local commits are testing dependency copies, not owned handoff commits. Do not cherry-pick them into the parent again.

| Upstream dependency | Local copy |
| --- | --- |
| Components `11ee280`, `8ccb169` | `2625a31`, `c580bf2` |
| External-anchor API `1dde262aa3ab172e4255233a524d712a48952f0a` | `1fb1113` |
| Recorder recovery `62d8ab9`, equivalent to `d9ff199` | `1efa708` |
| Config/action validation `a88d982` | `61f44d2` |
| Wrapper/probe `d831524` | `193a69c` |
| Held pointer support `d53695ffca9e4c9d1403e75712a9ff8e2ceed8ed` | `141bbda` |
| Generic fallback removal `7dfd8bd85822de6e7e56660d0d3a8256ceabb75b` | `7f1247d519a94a3309a2967cdb92bbc4611c62aa` |
| Shared DigitSwap file and tests through `82f12dbe002f3f588c97d7730592d49ae4dc3319` | `5170c05d`. Exact owner content, not the unrelated blocks files. |
| Shared Tooltip file and parity tests through `12155d8e1fa7776086e6f1b9334fecbf1ccd414e` | `bb961d33`. Exact owner content, including earlier provider repairs. |
| Independent chart review tests `4df5cc9b82d31e8ac68a53cc025540b91a48f32f` | `541726b4`. Tests unchanged. |

The after footage uses the fallback-removed Tooltip. Final configs contain the original dependency IDs and local-copy mappings. The exact build HEAD supplies the complete transitive input revision, including the unchanged font assets available in this checkout. Later shared-font worker changes are not silently attributed to these builds.

## Effective builds

All candidate script hashes below are SHA-256 of `main.dart.js`. Shared-recorder captures hash the actual script response before their first frame and reject mismatches.

| Build | Exact HEAD | Served JS SHA-256 |
| --- | --- | --- |
| Legacy before | `cb473df0b4f51800db0a67b4ba0b9b9498ce8d50` | `6a12b7832c0532c7a4c6021bd9df232d61f6b5f76a5b9540de1fb315449a0af2` |
| v4 | `a87eb75339ac88467ebb6a026c1a4f22e6f32cfb` | `b3d20ce0ba067a7346435853266c1483da60a99607bf0c607e5fa629eb54c546` |
| v6 | `322c378917698731662db2f8bc1ca002bd94aace` | `9f9ac605fb3347f0e95ad5e93e3e59fa46c48800beae6243c6c5c0ac083937bf` |
| v7 | `6585cf33e87f7e50c0140247c2f4451355fa9279` | `fb0c9a79bec89a2b82d6a0143515272d791e4140700bfd26a6a5eeb576ac717c` |
| v8 | `a6691d7c81d844b7422a7f13032859eb33287f35` | `62b4b3869cc56f500caf627e1c773f4f6494a2cce952d5175bb3741e226e7f6d` |
| v9, touch rejected | `c14b7c41f06c6fd783530bd5c81ebbafeccff800` | `7cda4e0e32d0d423dd7fb1dc26fb4c550bf937fa40b6a7749125e2f258d27675` |
| v10, final gallery | `dc7d333255e309c5439bda109f676ec011f597a5` | `36fce96aa60bdeac7f9f97e93dfe46f853eeb8a14a8c72640281d117b95c489a` |
| v11, native fan replacement | `4118dffac7ecd680e8dae48cd0463c59b82144db` | `f82bac3e3928834cad8d16109c5c318626fac945f4043841298b6acb5c71978e` |
| Status candidate fixture | `1a9fa600`, gallery behavior through `dc7d3332` | `328f4127a0ae022aafc9a928824d3c74ae746d9e86c7d398afea71026395dd49` |
| Status pinned-source fixture | Pinned source plus `1a9fa600` consumer wrapper | `e0d41182af78f5afc8d1702daccf34c3e3fda67bf122c7be9f1a88954b88e97c` |

Release builds are retained under `/tmp/beui-charts-round3-after-20261023-v{4,6,7,8}`. The legacy before build is `/tmp/beui-charts-round3-before-build-20261023`. The failed v5 build is not footage provenance.

V9 and v10 release directories use the same naming scheme. V10 compilation began with the final hover guard in the working tree and that exact file was committed as `dc7d3332` during compilation. There were no intervening chart edits. The status fixture is `/tmp/beui-charts-round3-status-fixture-v2-20261023`; the first build has the same script bytes. Its source `inputs.json` and runtime lock are retained as `status-source-inputs.json` and `status-source-package-lock.json`. The source bundle hashes every actual transitive input. Neither source checkout nor source baselines are amended.

Recorder implementation is upstream `d53695ffca9e4c9d1403e75712a9ff8e2ceed8ed`. Its file SHA-256 is `2aa405da2051b7a59a3010f7b0e3291108e3c51c65f6e1e76bf73bca120709ca`. The wrapper/probe is upstream `d831524e86ecb1703362b1dccd149325f05c50cc`. These are reported dependencies, not duplicate owned commits.

## Recording index

Each capture directory retains `capture.mp4`, original PNG frames, frame hashes, `config.json`, `environment.json`, `scripts.json`, effective `timeline.json`, `ffprobe.json`, and `captions.srt`. Legacy before directories use the older equivalent manifest names. Source readout identities and target rectangles are in each config's `observedProbeTargets`. Actual dispatch intervals and pointer coordinates are in the timeline, not inferred from successful API calls.

| Changed behavior | Before | Source | Latest after |
| --- | --- | --- | --- |
| Liquidity | `before/liquidity-heatmap/` | `captures-final-v4/reference-liquidity-heatmap-*` | `captures-final-v4/after-liquidity-heatmap-*` |
| Returns | `before/returns-calendar/`, then v4 readout | `captures-final-v4/reference-returns-calendar-*` | `captures-final-v6/after-returns-calendar-*` |
| Heat | `before/heat-calendar/` | `captures-final-v4/reference-heat-calendar-*` | `captures-final-v4/after-heat-calendar-*` |
| Treemap | `before/treemap/`, then v4 readout | `captures-final-v4/reference-treemap-*` | `captures-final-v6/after-treemap-*` |
| Order book | `before/order-book/` | `captures-final-v4/reference-order-book-*`, including tall summary | `captures-final-v4/after-order-book-*`, including tall summary |
| Status range ownership | `captures-status-ownership/before-status-bar-*`, v6 | `captures-status-ownership/reference-status-bar-*` | `captures-status-ownership/after-status-bar-*`, v7 |
| Status replay and incident reversal | `before/status-bar/` | `captures-final-v4/reference-status-bar-replay-*` | `captures-final-v4/after-status-bar-replay-*` |
| Fan projection and text | `before/price-target-fan/`, then v6 axes/readout | `captures-final-v4/reference-price-target-fan-*` | `captures-final-v7/after-price-target-fan-*` |
| Donut DigitSwap | `captures-donut/before-donut-chart-*`, v4 | `captures-donut/reference-donut-chart-*` | `captures-final-v6/after-donut-chart-*` |
| Donut native legend and caption layout | `captures-donut-legend/before-donut-chart-*`, v7 | `captures-donut-legend/reference-donut-chart-*` | `captures-donut-legend/after-donut-chart-*`, v8 |

The latest accepted integration recordings supersede the older after paths above without replacing them.

| Integration behavior | Before or source | Final after |
| --- | --- | --- |
| Donut cap, readout, native wrap and Tab | v8 after is superseded; source legend recordings remain valid | `captures-final-v10/after-donut-chart-*` |
| Fan touch second-tap toggle | `captures-touch-final-v9/after-*` fails; `captures-touch-final-v9/reference-*` shows source off/on | `captures-touch-final-v11/after-*`, two runs per preference |
| Fan mouse release and native keyboard toggles | Candidate v10 fails native focus. `captures-fan-source-keyboard-final-v10/reference-*` clicks actual endpoint circles before native Tab | `captures-final-v11/after-price-target-fan-*` |
| Status inspection and exit/reopen | Source status ownership recordings remain valid | `captures-final-v10/after-status-bar-*` |
| Status removed focused identity | `captures-status-identity/source-*`, actual pinned-source fixture | `captures-status-identity/after-*` |

`review-final-v10/` verifies 10 recordings and 1,726 original frames. `review-touch-final-v10/` verifies two recordings and 190 frames. `review-status-identity/` verifies four recordings and 537 frames. `review-fan-source-keyboard-final-v10/` verifies two recordings and 245 frames. The earlier v10 source fan records used group bounding-box midpoints. They remain useful hover footage but do not prove native focus acquisition. The final source keyboard batch uses endpoint circle coordinates and supersedes that focus claim.

`review-final-v11/` verifies two replacement native mouse/keyboard recordings and 396 original frames. Their cadence is 32.75 to 39.00fps. `review-touch-final-v11/` verifies four trusted-touch recordings and 391 original frames, at 21.12 to 47.77fps. The replacement served response is checked before each recording's first frame. No direct focus injection or programmatic semantics activation establishes the native mouse/keyboard sequence.

Touch recordings use the unchanged shared recorder through `touch_capture_round3.mjs`, a chart-owned Playwright transport that translates its click actions into real `touchscreen.tap` calls. Every config records the wrapper SHA. `observed-touch.json` proves trusted touch pointer-down/up/click, `maxTouchPoints=1`, and no hover capability. No synthetic DOM input or direct focus injection is used. Source and candidate native videos retain their own original dimensions and times.

The `*` suffix means both `dark-no-preference` and `light-reduce`. Fan entrance videos include an actual browser reload before the history/fan/now-marker sequence. Status ownership videos include a held range press, move, release, exit, Home, and Escape. The source API periods are 2026-08-21 and 2026-08-22. Their source-visible labels omit the year. Donut's exact values are Team 42,900 and Business 31,250. Source order-book pause is an actual click, but equal dynamic tick data across runs is not verified.

Integrity inventories and caption provenance are under `review-before/`, `review-final-v4/`, `review-donut-before/`, `review-final-v6/`, `review-status-ownership/`, `review-final-v7/`, and `review-donut-legend/`. They verify every original PNG hash and decoded frame count. An earlier liquidity diagnostic remains in `after-shared-v3-liquidity-dark/`; it is not the latest batch. Failed and superseded config/log directories are retained, not relabeled as successful evidence.

### Capture conditions and limits

Shared captures use the screenshot backend for actual CanvasKit output, CSS viewport 1280x1000, DPR 1, browser zoom 1, `en-US`, and the Asia/Kolkata timezone alias reported as Asia/Calcutta. CanvasKit script responses are retained in `scripts.json`. Native encoded output is 1280x913, not 1280x1000. Tall order-book recordings use CSS 1280x1500 and native 1280x1413. Originals are not resized, interpolated, or replaced.

Candidate URLs include `previewWidth=592&captureProbe=1`. The actual Flutter probe records root rectangles, constraints, background ARGB, and both effective and platform reduced-motion values. Both browser and actual Flutter `MediaQuery.disableAnimations` must match the requested preference. No preference override is used. The source-matched wrapper background is recorded by the actual probe, not inferred from the transparent browser body. Root widths remain chart-specific within that host, such as the 520px fan and order book, 480px returns, and 576px donut.

The shared batches use no timer overrides. Legacy before footage suppresses 900ms/950ms timers and has no effective Flutter motion probe. Its wrapper differs. It must not be presented as a same-wrapper motion timing control. Its order-book probe found only one target, so it makes no before A/B claim.

Measured cadence is below reliable native 60fps. Timing verdicts for short springs, glyph trajectories, and interruption remain inconclusive. The actual footage is still supplied. A dispatched event, DOM hidden rail, widget test, or nonzero screenshot similarity is not visual parity certification. Review actual neighboring original frames and per-event exposure intervals. The parent montage can burn the supplied captions without replacing these originals.

## Verification

Final implementation gates run against v10 chart code with shared DigitSwap metrics, Tooltip through `12155d8e`, and generic fallback removal present. V8 tests were stale relative to the parent's shared DigitSwap and do not waive the reproduced overflows.

| Gate | Result |
| --- | --- |
| Chart suite with golden comparison disabled | 199 pass. `all-chart-final-v10.log`. All behavioral assertions in golden-named tests still run. |
| Chart suite after native fan focus repair | 200 pass. `all-chart-final-v11.log`. `fan-native-focus-before.log` fails before repair; `fan-native-focus-after-4.log` passes all 37 focused tests. |
| Full chart suite | 188 pass, 11 golden failures. `full-chart-final-v10.log`. No golden updates. |
| Full chart suite after native fan focus repair | 189 pass, 11 golden failures. `full-chart-final-v11.log`. No golden updates. |
| Tooltip, external anchors, DigitSwap, chart adapter, composition, bump | 68 pass with golden comparison disabled. `shared-dependencies-final-v9-2.log`. The only subsequent production edit is the fan touch hover guard. |
| Focused fan | 34 pass, including nice-grid coordinates, static metric layout, target focus/geometry, now-dot delay, pulse, and reduced suppression. `fan-now-labels-final.log`. |
| Focused status and round-three regressions | 26 pass. `status-native-ownership-final-2.log`. |
| Focused donut | 9 pass, including actual cyclic native focus and literal row/track geometry. `donut-legend-layout-final.log`. |
| Analyzer | No issues. `analyze-final-v10.log`. |
| Analyzer after native fan focus repair | No issues. `analyze-final-v11.log`. |
| Release web build | v10 and status fixture succeed. Existing missing Cupertino icon-font warning remains. `build-after-v10.log`, `build-status-fixture-v2.log`. |
| Original baseline artifacts | All 52 pass. `original52-final-v9.log`. |
| Shared recorder validation | All six config tests pass. `recorder-config-final-v7.log`. |

Reproduce the behavioral suite with `BEUI_SKIP_GOLDENS=1 flutter test test/charts --reporter expanded`. Full suite is `flutter test test/charts --reporter expanded`. The broader repository suite and hosted CI are not claimed. Focused review failures and before/after logs remain separate from these aggregate gates.

The full chart suite still fails candle, volume, order book, bump, composition, donut, treemap, liquidity, returns, heat, and fan golden comparisons. These are failures, not expected passes. Round two already had these 11 failing chart names. New targeted geometry and interaction tests do not waive them.

## Unresolved implementation work

The remaining-six audit is not waived by this handoff. Donut readout and legend repairs are implemented, but the following chart work remains distinct from measurement limits.

- Candle source legend palette, focus-visible ring, exact tag formatting, and repeated opacity-delay behavior.
- Bump source rank/change legend grid and complete source keyboard semantics.
- Volume floating tooltip placement, total/POC/value-area summary grid, hover tint instead of border, opacity entrance, and replacement behavior.
- Composition bar/area geometry animation and source narrow 256px breakpoint.
- Funnel shape/stage motion, tooltip placement, and pathological-data behavior.
- Remaining exact pixel geometry, typography, tooltip collision bounds, and default/composed/narrow/empty/update examples across the chart catalog still need source-state comparison. No full audit-state completion is claimed.

Separate measurement gaps remain native 60fps trajectories, matched live order-book tick sizes, and exhaustive source-state recordings. Those gaps do not excuse the implementation work above.

## Self-contained archive

All round-three original PNG sequences, including failed and superseded runs, are committed beside their MP4s, timelines, configs, and captions. Local-only hashes are not the archive. `ARCHIVE-v11.json` seals every file's path, byte count, and SHA-256. Its counts exclude only the seal itself. `node test/charts/verify_round3_archive.mjs` verifies those bytes, every timeline's original frame hash, decoded MP4 frame counts, served script hashes, and effective browser and Flutter reduced-motion values where required. `CHART_ARCHIVE_ROOT` selects an exported archive without a worker worktree. The archive verifier does not rewrite captures or captions. Old diagnostic captures remain diagnostic even when their byte integrity passes.

Poteto decisions are specific. Model the Domain keeps chart-specific focus ownership and native range state out of generic Tooltip. Sequence Work into Verifiable Units keeps each repair in a focused commit with a local gate. Prove It Works checks the served response, actual Flutter motion setting, original recordings, and unchanged baseline hashes. Delegation is skipped because the user prohibits subagents. The unavailable `deslop` plugin is not claimed; diffs and prose receive a manual pass.
