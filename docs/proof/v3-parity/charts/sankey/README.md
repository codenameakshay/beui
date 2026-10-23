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
