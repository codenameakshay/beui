# Table vertical diagnosis after 3e1c3f4bb

Read-only repository investigation. All new files are in this directory. No repository edits, git mutations, builds, servers, tests or children. Original captures and archive untouched. This is a diagnosis, not a new parity claim. Horizontal sizing was not changed or challenged.

## Reproduction and identity

Run `node /tmp/beui-table-vertical-research/measure.mjs`, then `node /tmp/beui-table-vertical-research/border-model.mjs` and `python3 /tmp/beui-table-vertical-research/pixels.py` while the parent endpoints remain available. Scripts currently overwrite only their own research outputs.

Playwright core imported from `/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs`; headless installed Google Chrome; fresh owned browser contexts; viewport 1280x1000, DPR 1, both no-preference and reduce. URLs `http://127.0.0.1:18137/source/?example=data&theme=light` and `/after/?example=data&theme=light`. Measurements are at rest. Parent's existing horizontal rest/freeze/drag comparisons remain independent.

Source JS SHA256 `c31b6542667d935f84871670d76b84013a0214c409e7ce8eed44e67afebbe7d4`; candidate `c5b13dd0985cf017542a352778d5cce72c2472ca6daede83fcaecaa342dff62a`, matching the archived final candidate. Source inspected at supplied pinned checkout `/tmp/beui-v3-parity-components-source`, pin a76e57c9.

`measurements.json` contains full rectangles, computed source styles, text ranges, source baseline probes, candidate semantics, effective motion probe and script hashes. Both motion preferences produced the same vertical geometry.

## Measured geometry

Coordinates are CSS/logical pixels. Source DOM table width is 651.234375; visible inner viewport x361..919 has width558 and y41..461 has height420. Candidate semantics exposes that same viewport and clips row rectangles to its width; these are not contradictory table-width measurements.

- Source header row rectangle: x361, y41, width651.234375, height52.5, bottom93.5. Header flex content is y41, height52. Source Name cell x385, width112.453125. Candidate header allocation is y41, height52, bottom93, confirmed by body start and code; its resize handle is y41, height51 because Container border padding consumes one pixel.
- Source body rows start at y93.5,145.5,197.5,249.5,301.5,353.5,405.5. Each has height52. Candidate rows start at y93,145,197,249,301,353,405, each height52. No accumulating drift.
- Source header Name line box y57..77; text range y58..76; measured alphabetic baseline72. Candidate header Name button/line extent y56.5..76.5. Exact candidate alphabetic baseline is unavailable through the current semantics/probe.
- Source first-row Name/Email/Role text ranges y110.5..128.5, alphabetic baseline124.5. Subsequent baselines176.5,228.5,280.5,332.5,384.5,436.5. Source normal 14px/20px line box is y109.5..129.5, centered at119.5.
- Candidate first-row content center is118.5, confirmed by checkbox rect y108.5..128.5 and the 51px content height from its one-sided Container border. A 20px body line box therefore occupies y108.5..128.5 by layout construction. Body text nodes are merged into row semantics; this is a layout inference, not a direct RenderParagraph measurement. Do not label a guessed candidate baseline as measured.
- Source first-row checkbox wrapper y109.5..129.5; candidate checkbox y108.5..128.5. This establishes a 1px content-placement difference independent of text rasterization.
- Source status badge is an inline span, rect y110.5..130.5, with text baseline124.5 shared with ordinary cell text. Candidate badge is a standalone centered 20px box, inferred y108.5..128.5 from its 16px text height + 4px padding and row alignment. The 2px box-placement difference consists of the 1px row-content difference plus the source inline badge's own baseline geometry.

## Why source header is 52.5px

`components/motion/table/index.tsx:266` applies `border-collapse` to the HTML table. Header `tr` has height52, while each data `th` contains a flex div with an explicit height52 (`table-header.tsx`). Header cells have a 1px bottom border and no top border. In collapsed table layout the grid border contributes half its width to the cell edge, so this full-height child requires a 52.5px header row. Row height is a minimum in CSS table layout, not a clipping constraint.

Body `tr` has height52 and a 1px collapsed bottom rule (`index.tsx:345-396`). Its content is smaller than the row minimum; shared rules leave symmetric edge contributions and preserve a 52px row advance. Content centers at row top+26.

Controlled clones on an owned browser page preserve the live fixture and isolate this mechanism (`border-model.json`). With header/body bottom borders set to0,1,2px, header heights are52,52.5,53px; body heights remain52 in all cases. Removing the header child's explicit52px height also restores a52px header despite the1px border. Clone horizontal widths differ because they are offscreen/in a different containing block; no horizontal conclusion uses these experiments.

Candidate `table_header.dart:218-231` instead gives the entire bordered Container height52. Its bottom border reduces content to51. Candidate `_DataRowState.build` in `table.dart:1087-1101` also uses a52px Container with a one-sided inset border, centering content in51px. These are two distinct structural differences: header contributes0.5px too little to body start; body border padding moves content up another0.5px.

## Visible rules and rasterization

At blank x700, source header rule is pixel row93, RGB238; candidate row92, same RGB238. First body rule is source row145, candidate144, both RGB243. Other pixels immediately above/below confirm these are single-pixel rules in this capture. Source paints collapsed rules centered on the row boundary; candidate paints its rule inside the row. Their color already matches at this sample.

`pixels.json` records thresholded ink bounds, not baselines: Name header occupies y62..71 on both; first body Name and Role occupy y115..124 source versus114..123 candidate; Email y115..126 versus114..125. Threshold is neutral RGB with minimum channel<180. Thus a 0.5px header line-box shift can quantize to the same visible ink rows, while the measured1px body placement shift is visible. Weight/antialiasing differences remain and cannot be quantified as a baseline shift from screenshots. No fitted offset or shared typography change is justified by this result.

## Repair recommendation

Implement the collapsed vertical grid model in Table, scoped initially to the source-compatible intrinsic path unless broader behavior is intentionally revised:

1. Allocate header advance `rowHeight + ruleWidth/2` for this full-height header-child configuration. Keep its content box exactly `rowHeight`, starting at the header top. Center the header rule on the grid boundary. Do not simply enlarge the existing fully inset-bordered Container, which would still make its content too short.
2. Keep body advance `rowHeight`. Center body content in the full row or apply symmetric half-border insets. Paint the bottom rule centered on the grid boundary without imposing one-sided layout padding. Account for paint overlap/clipping so adjacent rows do not erase half the rule. Derive dimensions from the rule width, not screenshot constants.
3. Compute the body viewport from actual header advance, preserving the total420px viewport. Retain the already-repaired sampling semantics and horizontal allocation. Check first/last visible rows and scrolling when implementing this; no scroll verification was run here.
4. Address the demo status badge separately if needed: model an inline padded12px/16px span participating in the parent14px/20px line's alphabetic baseline. Its current independently centered padded box cannot express that relationship. Use measured font/line metrics and baseline layout, not an added translate. Leave arbitrary custom cells' alignment contracts intact.

Before judging font weight, add a focused Flutter RenderParagraph line-box/alphabetic-baseline probe during the parent's implementation phase. The existing release fixture exposes semantics but no Flutter text baselines. Compare the resulting baseline to source124.5 for the first row after repairing the grid. This research did not build or instrument candidate production code.

## Limits

Only the supplied data/light fixture at rest was remeasured; reduced motion was included. No new parity assertion for resize states, other row heights, editable/loading paths, scrolling, other DPRs/platforms, fonts or full pixels. Source baseline measurement uses a zero-size inline baseline marker inserted and immediately removed in the owned page; cell rectangles stayed identical. Source text range rectangles were captured before insertion. Source clones were detached after each experiment. No persistent fixture changes were made.
