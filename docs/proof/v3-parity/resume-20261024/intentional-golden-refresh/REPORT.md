# Intentional golden refresh

Updated exactly 35 allowlisted PNGs and five chart fixture files on isolated Flutter 3.47.1. All 35 pass without update mode. Across the 56 classified identities, 35 pass and the expected 21 environment/toolchain cases fail. All 21 references remain byte-identical. All 41 non-allowlisted golden files are unchanged. No additional unlisted golden was updated or selected by the focused update/verify runs; the BeuiButton sibling was excluded.

The classification run executes 57 comparisons covering 56 unique identities: the plain-name selector for `chat app shell` also selects the already-listed `chat app shell below the sidebar breakpoint`; that second identity runs again in its dedicated command. This is one duplicate listed failure, not an additional unlisted failure. Each of the 35 update and 35 verify invocations selected exactly one test.

## Capture repair and red proof

The new content assertions failed in all five original chart captures because entrance opacity was zero. `red-content.jsonl` retains the failures; `reproduce-red.patch` removes only the frame progression from the final tests. Final fixtures use ten sequential 100 ms frames for reduced-motion BumpChart and OrderBook, and twenty for CandlestickChart, DonutChart and VolumeProfile. These cover fades, stagger timers and spring progression without relying on a single large pump. Motion preferences were preserved.

Assertions require two ranking path painters and visible entrance opacity; nine painted candle shapes with full opacity; three painted donut arcs with full ancestor opacity; five nonzero colored depth fills of the expected height; and four nonzero volume fills of meaningful dimensions and final opacity. No missing first frame was adopted. All five resulting PNGs are pixel-identical to the prior forty-frame control (`chart-rest-state-control.json`).

All 35 new original-resolution PNGs and all seven before/after contact sheets were inspected. No new clipping or incomplete chart content was found. SignupForm needs no fixture edit: the same 480x1000 capture contains its taller intended card, all four fields, terms and submit.

## Environment and provenance

Execution used `/tmp/beui-intentional-refresh` and `/tmp/beui-final-golden-triage/sdk-3.47.1`, leaving shared SDKs and dependency files untouched. Source snapshot HEAD is `ad9adb944f8253584317458947d957d472dfff04`; `environment.json` records every source/test input hash, all 76 original golden hashes, full Flutter/engine/Dart version output, OS/kernel and SDK font hashes. The 40 changed-file SHA-256 hashes are in `changed-paths-sha256.json`. Per-image dimensions, old/new SHA-256, author commit, full causal commit hashes, individual reasons and visual review are in `manifest.json`.

Flutter 3.47.1 / Dart 3.13.1 runs on macOS 27.0.1 build 26A434 arm64. The selected root golden fixtures do not load production fonts; Ahem and missing icon glyph boxes remain the existing test rendering contract. No font substitution was introduced. Retained dependency tree, pubspec/lock and package config record the offline resolution. The earlier triage proved the 32 October author controls on this SDK; the three older intentional cases retain disclosed environment residuals. Exact historical author OS/dependencies remain unknown.

## Gates

- Focused update: 35/35 passed, one allowlisted test per command.
- Focused no-update verification: 35/35 passed.
- Classification: 35 intentional passes; 21 expected drift failures, unchanged references.
- Changed-test analyzer: passed with no issues.
- Changed-test formatter: passed, zero changes.
- Root suite with `BEUI_SKIP_GOLDENS=1`: {'success': 2731}, exit 0.
- Example suite: {'success': 66}, exit 0.

The existing skip comparator was used only for the requested root suite. It was unset for update, focused verification and classification. No comparator or tolerance was edited. Full suite results prove this isolated source snapshot, not hosted CI, native engine behavior or release readiness.

The first root attempt omitted three proof JSON fixtures from the isolated copy and ended with 2728 passes plus three PathNotFound errors. Raw output is retained as `root-suite-missing-fixtures.*`. After copying those unchanged required inputs, the corrected complete root suite was run once. The example suite ran once. No product or test code changed to resolve that setup error.

## Individual update reasons

### 01. beui_bump_chart.png

Path: `test/charts/goldens/beui_bump_chart.png`. Causal commits: `5189cd7ef`, `eaeb9fc98`, `059b4dbdb`.

Grid, labels, rank border and reduced-motion entrance changed; initial capture omits fading paths. Forty timed frames restore paths. Fix the rest-state fixture timing before an intentional reference update.

Both ranking series have visible nodes and end labels; the dimmed Studio path is present. Canvas has a null middle rank, so no invented connecting path. Dotted grid and rank rings match the intended change.

Dimensions: [2400, 1800] to [2400, 1800]. Full hashes are in manifest.json.

### 02. beui_candlestick-chart.png

Path: `test/charts/goldens/beui_candlestick-chart.png`. Causal commits: `0444124ce`, `2420167cc`.

Added staggered candle entrance, axes and inspection layout. First-frame capture has no candles; forty timed frames restores all three. Fix rest-state timing before an intentional reference update.

Three candle bodies, three wicks and three volume bars are visible. New right-hand labels and green/pink palette fit the 640x420 capture.

Dimensions: [640, 420] to [640, 420]. Full hashes are in manifest.json.

### 03. beui_composition_chart.png

Path: `test/charts/goldens/beui_composition_chart.png`. Causal commits: `ce3a48f47`, `09cff48a8`.

Source bar geometry, chart height, legend and percentage layout changed; image dimensions change.

Two stacked bars, endpoint labels and two legend entries fit the intentionally taller 640x520 capture. The empty third period remains empty.

Dimensions: [640, 420] to [640, 520]. Full hashes are in manifest.json.

### 04. beui_donut-chart.png

Path: `test/charts/goldens/beui_donut-chart.png`. Causal commits: `0444124ce`, `97329fccc`, `784a2f58d`.

Ring entrance, gaps, legend tracks and center digits changed. First-frame capture contains only the track; forty timed frames restores colored arcs. Fix rest-state timing first.

All three colored arcs, ring gaps, total readout and three legend tracks are visible within the intentionally taller 640x256 boundary.

Dimensions: [640, 200] to [640, 256]. Full hashes are in manifest.json.

### 05. beui_funnel_chart.png

Path: `test/charts/goldens/beui_funnel_chart.png`. Causal commits: `ca0562e0a`, `0219e2845`.

Stage paths, labels, hover tint and legend geometry changed.

Three shaped stages, inset readout pills, horizontal legend and bottom summary remain visible. Stage and legend geometry matches the causal change.

Dimensions: [640, 420] to [640, 420]. Full hashes are in manifest.json.

### 06. beui_heat_calendar.png

Path: `test/charts/goldens/beui_heat_calendar.png`. Causal commits: `ec0513ce8`, `4d30d67cf`, `bf12ab39c`.

Added/reflowed legend, heading and inspection layout; cells remain present.

All calendar cells remain visible; heading and expanded legend fit without clipping.

Dimensions: [640, 480] to [640, 480]. Full hashes are in manifest.json.

### 07. beui_liquidity_heatmap.png

Path: `test/charts/goldens/beui_liquidity_heatmap.png`. Causal commits: `8eedf6248`, `ffb962872`.

Moved price labels to source side and corrected trace/grid geometry.

Four data cells, descending trace, right-hand price labels and color scale remain visible.

Dimensions: [2400, 1800] to [2400, 1800]. Full hashes are in manifest.json.

### 08. beui_order_book.png

Path: `test/charts/goldens/beui_order_book.png`. Causal commits: `ec0513ce8`, `7d5cfaeef`.

Depth bars, native price buttons and opacity entrance changed. Reduced motion retains nonmovement fades; forty timed frames restores depth fills. Fix rest-state timing first.

Both ask fills and all three bid fills are visible, with full row height, balance bar and depth summary.

Dimensions: [2400, 1800] to [2400, 1800]. Full hashes are in manifest.json.

### 09. beui_price_target_fan.png

Path: `test/charts/goldens/beui_price_target_fan.png`. Causal commits: `e8335ba42`, `f55abfc33`, `84e984a3c`.

Projection, now marker, axes, target labels and controls were deliberately rebuilt.

Historical trace joins the now marker and three dashed target projections. Axis and target labels fit.

Dimensions: [800, 640] to [800, 640]. Full hashes are in manifest.json.

### 10. beui_returns_calendar.png

Path: `test/charts/goldens/beui_returns_calendar.png`. Causal commits: `ec0513ce8`, `bf12ab39c`, `28943b965`.

Cell tint/rounding, header and readout ink/spacing changed.

Both year rows and all month cells fit, with revised tint and readout ink.

Dimensions: [640, 480] to [640, 480]. Full hashes are in manifest.json.

### 11. beui_treemap.png

Path: `test/charts/goldens/beui_treemap.png`. Causal commits: `a2c8b3e3d`, `28943b965`.

Cell readouts and legend ink changed; added second text line.

Three rectangles now show two readout lines; legend ink is muted. All rectangles and legend fit.

Dimensions: [640, 420] to [640, 420]. Full hashes are in manifest.json.

### 12. beui_volume-profile.png

Path: `test/charts/goldens/beui_volume-profile.png`. Causal commits: `0444124ce`, `31eac9a54`, `d24249b6c`.

Added entrance, axes, colored volume geometry and summary. Forty timed frames restores bars. Fix rest-state timing first.

All four colored volume bars, left price labels, POC badge and three summary columns are present in the 640x420 capture.

Dimensions: [640, 420] to [640, 420]. Full hashes are in manifest.json.

### 13. beui_adaptive_stepper.png

Path: `test/motion/goldens/beui_adaptive_stepper.png`. Causal commits: `421e9271e`.

Rounded pill replaced by the source liquid silhouette and separated side controls.

Liquid center silhouette and separated diamond-like side controls are intentional; all three controls fit.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 15. beui_alert.png

Path: `test/motion/goldens/beui_alert.png`. Causal commits: `7e764e018`, `6c86802ae`.

Tone colors, retained exit layout and close-control margins changed.

Info tint and close-control position change; title and body remain fully inside the alert.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 16. beui_approval_card.png

Path: `test/motion/goldens/beui_approval_card.png`. Causal commits: `a3c2491fa`, `c729381b2`.

Badge/counter styling and source example field layout changed.

Pending/expandable/rejected cards remain present. Badge outlines and expanded field layout match the intended changes; historical environment residual is included in this intentional refresh.

Dimensions: [500, 520] to [500, 520]. Full hashes are in manifest.json.

### 18. beui_breadcrumb.png

Path: `test/motion/goldens/beui_breadcrumb.png`. Causal commits: `b0a025f76`, `fee57512d`, `8597186fa`.

Inline/wrapped route layout and typography changed; current final route sits inline.

Final route now sits inline with the breadcrumb controls; nothing is clipped.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 19. beui_metallic_button.png

Path: `test/motion/goldens/beui_metallic_button.png`. Causal commits: `ecea1d400`.

Chrome layers and preview states changed; old broad metallic bands removed.

Resting metallic button has the revised thin chrome outline and shadow; broad old bands are gone. Only BeuiMetallicButton was selected.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 20. beui_card_folder.png

Path: `test/motion/goldens/beui_card_folder.png`. Causal commits: `f0cb706cd`, `9d08a1c6f`.

Card press/privacy rendering and text geometry changed.

Folder mask and card geometry remain complete; privacy text and lower card position reflect the intended update.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 21. beui_card.png

Path: `test/motion/goldens/beui_card.png`. Causal commits: `b0a025f76`.

Description line metrics and muted-card border changed; inspected at full image size.

Full-height card and compact muted card remain complete. Description metrics and compact-card border match the declared change.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 24. beui_code_block.png

Path: `test/motion/goldens/beui_code_block.png`. Causal commits: `4fdec936f`.

Shared tokenizer now colors assignment punctuation as keyword. The current/author difference is 182 pixels on 3.44.4, plus 6 pre-existing environment pixels; inspected enlarged token crop.

Assignment punctuation uses keyword ink; line numbers, highlight and all fixture rows remain. Horizontal code viewport clipping already existed in the old reference. Historical environment residual is included.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 25. beui_color_picker.png

Path: `test/motion/goldens/beui_color_picker.png`. Causal commits: `7492c0b3f`, `cfe381654`.

Spectrum/trigger morph, field and hue-track geometry changed.

Spectrum shading, rounded field and hue/alpha tracks change; all handles remain within the control.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 26. beui_color_selector.png

Path: `test/motion/goldens/beui_color_selector.png`. Causal commits: `b0a025f76`, `93ebe4787`.

Selected swatch ring changed from the old oversized oval to the source circular ring.

Selected blue swatch has a centered circular ring; red swatch and label remain intact.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 27. beui_combobox.png

Path: `test/motion/goldens/beui_combobox.png`. Causal commits: `81120f68b`, `5b749f5a6`.

Source workspace trigger and editable-input geometry changed; later reopen fix does not account for the historical mismatch.

Closed workspace trigger is complete with source input geometry; no reopen-state claim is made.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 33. beui_date_range_picker.png

Path: `test/motion/goldens/beui_date_range_picker.png`. Causal commits: `3122ad6b0`, `87d8456f3`, `baf7b62b0`.

Completed trigger omits repeated year and uses source tabular widths/typography.

Selected date range and controls fit the existing full-height card. Trigger text spacing reflects omitted repeated year.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 34. beui_digit_swap.png

Path: `test/motion/goldens/beui_digit_swap.png`. Causal commits: `f0cb706cd`, `9d08a1c6f`.

Source digit spacing/width changed; four separated digit cells replace contiguous cells.

Four separated digit groups fit without cropping.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 35. beui_expandable_control.png

Path: `test/motion/goldens/beui_expandable_control.png`. Causal commits: `6f97bc3da`.

Resting foreground intentionally changed to mutedForeground, with foreground reserved for hover.

Both expanded and collapsed resting labels use muted foreground; outlines remain complete.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 37. beui_file_diff.png

Path: `test/motion/goldens/beui_file_diff.png`. Causal commits: `eca6b142a`, `4fdec936f`, `4e441e295`.

Diff token colors, replay/hunk layout and row geometry changed.

Diff rows, token ink and replay/footer control match the intentional layout. Horizontal code viewport remains intentional. Historical environment residual is included.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 38. beui_file_tree.png

Path: `test/motion/goldens/beui_file_tree.png`. Causal commits: `6f97bc3da`.

Selected/emphasized file icon now uses foreground instead of mutedForeground. All 140 changed pixels are localized to that icon; inspected enlarged crop.

Selected file icon uses foreground ink; tree indentation and rows remain unchanged in structure.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 39. beui_image_viewer.png

Path: `test/motion/goldens/beui_image_viewer.png`. Causal commits: `b0a025f76`, `1479c7d57`.

Thumbnail geometry and morph behavior changed; both thumbnails are shorter/narrower.

Both thumbnails retain complete rounded edges, with intentionally smaller geometry.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 42. beui_morphing_search_chips.png

Path: `test/motion/goldens/beui_morphing_search_chips.png`. Causal commits: `aace02b0a`.

Closed trigger now reserves/displays the searchable chip input layout; width and visible text changed.

Closed trigger now includes the input alongside the existing chip; complete pill boundary is visible.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 43. beui_morphing_tabs.png

Path: `test/motion/goldens/beui_morphing_tabs.png`. Causal commits: `f0cb706cd`.

Source card/tab colors and geometry changed, including outer dark surface.

Dark outer tab surface and light content geometry match intended colors; tab labels and content remain inside.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 45. beui_prediction_market_card.png

Path: `test/motion/goldens/beui_prediction_market_card.png`. Causal commits: `f0cb706cd`.

Outcome button colors/layout, sparkline and card geometry changed.

Green/red outcome buttons and green sparkline appear in the complete card. Source card layout is retained.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 48. beui_signup_form.png

Path: `test/motion/goldens/beui_signup_form.png`. Causal commits: `af4522f83`, `250a649c0`.

Typography, fields and confirmation gap changed; fixture output bounds also change. Review intended capture bounds before updating.

Both old and new images are 480x1000. The new card spans approximately y=161..839, compared with y=217..783 before. Title, four fields, terms and submit fit. No capture-bound correction or test edit is necessary; the triage phrase about changed output bounds referred to content geometry, not PNG dimensions.

Dimensions: [480, 1000] to [480, 1000]. Full hashes are in manifest.json.

### 49. beui_sortable_list.png

Path: `test/motion/goldens/beui_sortable_list.png`. Causal commits: `6f97bc3da`, `91819aa8e`.

Handle/undo styles and focus treatment changed; retained rows and undo control shift visually.

Three rows and undo control remain intact with revised handles, ink and spacing.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

### 51. beui_tabs.png

Path: `test/motion/goldens/beui_tabs.png`. Causal commits: `dfe5bd4e5`, `aa0a372f6`.

Underline moved inside the trigger and focus fill was removed; 136 pixels differ on 3.44.4.

All three tab variants fit; the bottom underline is now inside the trigger, with revised focus fill.

Dimensions: [800, 600] to [800, 600]. Full hashes are in manifest.json.

Original triage, archived failures, production code, all other tests and parent engine/CI work were left untouched. No child agents, commits, pushes or merges were made.
