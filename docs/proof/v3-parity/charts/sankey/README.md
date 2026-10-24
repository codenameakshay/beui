# Sankey parity supplement

This adds the omitted `charts/sankey-chart` route. Historical 76-route and 601-state counts remain unchanged. This supplement is additive, not a rewrite of the earlier census.

## Source and baseline

The immutable source is `starc007/ui-components` at `a76e57c9bbc2837e96420b2610e9c82a3271bb05`. `source/pin.json` records the original file hashes and archived bytes. The registry entry has `badge: new` and `launchedAt: 2026-10-22`. The live beui.dev deployment revision is unknown and is not inferred from this checkout.

The Flutter starting commit is `8a1970d3`, including `a2942181`. `before-mounted/` captures the actual absent route. `?slug=sankey-chart&section=charts` falls back to the Charts index. There is no pristine Sankey widget baseline. The earlier `before/` capture is rejected because the deployment base href loaded the wrong script location and produced a blank page. Both attempts are retained. The accepted deployment changes only the copied index's base href to `/before/`; `main.dart.js` is unchanged and hashed.

## Route, state, and part inventory

One new route exposes three widgets: `BeuiSankeyChart`, `BeuiSankeyChartPlot`, and `BeuiSankeyChartTooltip`. The public data consists of nodes, links, cleaned graph diagnostics, placed nodes, placed links, a measured layout, and a node-or-link active selection. Native Flutter `Color` replaces arbitrary CSS strings. Plot height replaces the source CSS height class. `controlled: true` represents controlled null without conflating it with an omitted Dart argument.

The source preview has ten nodes and nine flows. Q3 starts with subscriptions 70, services 17, marketplace 14, cost 36, R&D 22, sales 17, and admin 7. Gross profit is 65 and operating profit is 19. Q2 uses 62, 18, 10, 34, 20, 16, and 7, with gross profit 56 and operating profit 13. Both periods use the source colors and labels.

The state inventory includes the following source contracts.

- Initial in-view draw, column delay, node fade, and label fade.
- Data-change spring geometry, resize snap, and reduced-motion snap.
- Idle, node inspection with immediate neighbours, and flow inspection with its two endpoints.
- Static final-geometry hit targets, 24px minimum node height, 8px minimum flow width, and thin-flow precedence.
- Pointer enter and move, pointer exit clearing, touch press and drag, touch release retention, and outside-press clearing.
- One roving node tab stop, native focus opening, Up and Down within a column, Left and Right to the nearest node in the next populated column, Home and End, Escape closing without clearing highlight, and external blur clearing.
- Focus recovery after a node is removed, stale active ids clearing, controlled selection requests, and node identity precedence over a colliding flow id.
- Default and composed parts, custom tooltip content and side, node descriptions, largest four flows per direction, overflow count, flow shares, exact-data semantics, and the two empty states.
- 512px minimum plot width, horizontal narrow-screen scroll, short-node label suppression, fitted ellipsis, conditional values, and background-colored label halos.
- Duplicate node handling, merged unnamed links, first explicit link identity, invalid edge omission, iterative cycle breaking, longest-path depth, right-aligned sinks, six relaxation passes, stable column order, source-value scaling, sorted band stacking, gradient bands, and exact midpoint-control cubic paths.

## Execution choices

Model the Domain keeps cleaning and layout independent of widget state. Prove It Works requires source-derived numeric fixtures and actual browser input, not just compilation. Test Behavior, Not Implementation requires observable selection, geometry, focus, and rendered readouts. These Poteto principles guide this port. The requested no-children and no-PR boundaries override Poteto delegation and PR steps. The installed catalog has no `deslop` or `control-ui` skill; the existing repository capture workflow supplies browser control. Shared Tooltip, theme, fonts, motion engine, and recorder remain outside ownership.

The throughput checkpoint is one graph algorithm and one plot implementation, followed by independent geometry comparison, focused widget behavior tests, and browser recordings. No shared-framework refactor is needed. Source fixture builds import untouched source files and retain their complete input hashes and dependency lock.

Verification results are appended below as they are measured.

## Implementation and final verification

The implementation is `4cc61982`. `9191acf8` repairs native activation of a non-current node after external focus. `6dd459414aee242e772aa4162f652ddfb9f56134` preserves native implicit touch capture. The final release fixtures and gallery build use `6dd45941`. `builds-release/provenance.json` records both commands and exact served JavaScript hashes. Both JavaScript files are archived.

The native activation repair is observable in the real gallery. After inspecting Revenue, changing quarters and clicking Subscriptions must focus Subscriptions. ArrowRight must then focus Revenue. The earlier implementation opened the readout but left native focus on a quarter tab. The semantic action regression test and final gallery checks cover this sequence.

The pinned source's native implicit pointer capture keeps the initially pressed node or flow selected throughout a touch drag. Release retains inspection. This differs from selecting whichever band is under the moving finger. `activation-native-oracle-corrected/` retains the failing pre-repair Flutter result. `activation-release-flows/` verifies the source and final implementation for node and flow press, drag, and release. Enter and Space do not reopen inspection after Escape; directional keys do.

The hidden exact-data fallback is a semantic table with a caption label, rows, column headers, and cells. First-column cells carry Flutter's header flag. Flutter does not expose a separate row-header role. It is not a flattened text summary. The public active selection is a sealed node-or-link type, and node identity wins a collision with a flow identity.

The final measured checks are as follows.

| Check | Result | Evidence |
| --- | --- | --- |
| Focused Sankey tests | 11 pass | `logs/sankey-tests-final.log` |
| Root and example analysis | No issues | `logs/analyze-root-final.log`, `logs/analyze-example-final.log` |
| Source model layout | Every node and link endpoint matches within `1e-9` at three sizes | `source/geometry.json`, `sankey_chart_test.dart` |
| Actual demo cubic controls | Every Q2/Q3 control matches within `1e-9` | `source/curves.json`, `sankey_chart_test.dart` |
| Interior curve samples | Blink and Skia arc-length samples agree within 0.5 logical pixels; length within 0.1 | `source/curves.json`, `sankey_chart_test.dart` |
| Native browser state matrix | 102 states pass | `browser-release/result.json`, `states.json`, original PNGs |
| Touch capture and closed activation | Node and flow press/drag/release, Enter and Space pass for source and Flutter | `activation-release-flows/result.json` |
| Source demo hit-target geometry | Q2/Q3 in both themes; maximum DOM difference 0.014954 logical pixels | `demo-geometry-release/geometry.json` |
| Real gallery route | Q2/Q3 and native focus pass in light and dark; no page errors; served JavaScript hash matches the archive | `gallery-release-light-hashed/`, `gallery-release-dark-hashed/` |
| Full chart suite | 200 pass, 11 golden failures | `logs/chart-suite-6dd.log` |

The full chart suite is not green. The failing golden names are candle, volume, order book, bump, composition, donut, treemap, liquidity, returns, heat, and fan. The same eleven names are documented in the parent round-three proof. This work does not regenerate their goldens or waive their failures. No full-package, hosted-CI, merge, deployment, or device result is claimed.

## Image and motion evidence

`diff-release-dark/` and `diff-release-light/` compare the unmasked 768 by 320 plot at x256, y266. Their original inputs are the idle PNGs in `browser-release/`.

| Plot comparison | Pixels with any channel delta | Pixels over 8 levels | Pixels over 24 levels | Mean absolute channel delta |
| --- | ---: | ---: | ---: | ---: |
| Dark | 81,515 of 245,760 | 7,197 | 2,301 | 0.814480 |
| Light | 99,907 of 245,760 | 8,935 | 4,704 | 1.349738 |

These are nonzero differences, not pixel-zero parity. The diff images show label and edge differences plus low-level band-color differences. Numeric layout and cubic control checks are independent of these raster comparisons. Shared theme, font, Tooltip, engine, and recorder files remain unchanged.

`captures/` retains all sixteen recording attempts and their 1,213 original PNG frames. The accepted final candidate recordings begin `after-release-`. Their matching pinned source recordings begin `source-`. The `after-dark-`, `after-light-`, and `after-native-` recordings retain the earlier implementation revisions recorded in their configs. Nothing replaces their original inputs.

Every recording includes the config, environment, served-script hashes, original PNGs, event timeline, ffconcat input, lossless video, and decoded-frame probe. The recorder is the unchanged `tool/parity_capture.mjs`. No timers or animation clocks are overridden. Browser preferences are emulated and the effective Flutter MediaQuery value is recorded, without an app-level motion override. Entrance recordings use a real browser reload. Input recordings use actual mouse and keyboard events for inspection, Q2 changes, directional focus, and Escape.

The layout viewport is 1280 by 800 at DPR 1. Chrome's screenshot backend delivers 1280 by 713 images; the entire chart fits within them. Final candidate recordings measure 9.48 to 17.36 captured frames per second, with maximum frame gaps of 174.73 to 340.57ms. These recordings show event ordering and broad transitions. They do not certify fast-motion trajectories or 60fps performance. Frame-pumped widget tests independently verify draw progress, column delay, intermediate spring geometry, convergence, resize snap, and reduced-motion targets.

## Retained attempts and observation corrections

All earlier PNGs and state files remain original. `probe-source*` and `probe-after*` are fixture-development attempts, not additional baselines. The early source fixture lacked some theme mappings and then the medium font face. `source-fixture-v6/` archives the accepted untouched source component bundle, wrapper inputs, dependency lock, CSS, and font bytes. These fixture corrections do not change the pinned component files.

`browser-v3`, `browser-v4`, and `browser-v4-observer-corrected` retain early observer and native-tab-stop failures. `browser-v6`, `browser-v7`, and `browser-candidate` retain later intermediate checks. `browser-v8-table` rejects a blank candidate caused by a copied index with the wrong base href. It is not accepted implementation evidence.

`browser-final` and `browser-final-complete` check `4cc61982`; the former completed its assertions but its browser-close operation hung and its owned process was terminated. The latter has an explicit passing result. `gallery-input-final-v2` retains the real quarter-change focus failure. Its preceding observer incorrectly expected Flutter to place the accessible name only in `aria-label`, rather than also in text content.

`browser-native-final` and `gallery-native-final` check `9191acf8`. `activation-native-final` records the incorrect expectation that the source would switch nodes during a captured touch drag. The corrected source oracle exposed the actual Flutter mismatch in `activation-native-oracle-corrected`. The final accepted checks are `browser-release`, `activation-release-flows`, `demo-geometry-release`, and both `gallery-release-*` directories.

The collaborative preview snapshot failed twice with `Preview automation snapshot timed out after 15000ms.` Browser proof then used the repository's Playwright workflow. Only the task-owned server on port 18119 was used. No other server was changed.

## Evidence integrity

`EVIDENCE.json` seals every evidence file except this README and the manifest itself. `test/charts/verify_sankey_evidence.mjs` verifies the census, bytes, hashes, immutable source pin, recording frame hashes, decoded-frame counts, event dispatches, and served JavaScript hashes. It also compares the final fixture bundle against the final recording configs. All original image and video inputs are committed. No golden regeneration occurred.

The final proof commit changes only Sankey proof tools and this dedicated evidence directory. The production changes are the new Sankey files, one barrel export, and one new catalog entry. Historical 76-route and 601-state counts remain untouched.
