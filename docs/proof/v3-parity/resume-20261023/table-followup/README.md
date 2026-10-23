# Table outcomes follow-up

The data-table resize measurement previously conflated pointer-down layout changes with the subsequent drag. The pinned Editable preview also clips its last row. These are separate findings, not evidence of incorrect drag sensitivity or failed row deletion.

## Resize measurement correction

The original native source observations are retained in beui-table-research.json and PNGs. resize-phases.json separates the three phases:

| Phase | Handle x | Checkbox width | Name width |
| --- | ---: | ---: | ---: |
| Before pointer-down | 491.453125 | 24 | 112.453125 |
| After pointer-down freezes columns | 515.453125 | 48 | 112.453125 |
| After 50 px pointer move | 565 | 48 | 162 |

The handle's total displacement is 73.546875 px. Its post-freeze displacement is 49.546875 px, and the resulting Name width is the rounded starting width plus 50. The old archived assertion requiring exactly 50 px total handle movement is invalid. Its original script and failed output remain sealed and unchanged; this report supersedes that assertion, not the captured pixels.

Source use-column-resize.ts freezes rounded measured widths; index.tsx switches to w-max. Invalid CSS 1.4fr/1.8fr column widths are discarded by the browser, whereas the Flutter preview supplies actual flex weights. Exact intrinsic layout correspondence remains open. No 24 px offset or drag-sensitivity workaround was applied.

## Editable recovery composition

Production/demo commit 5749bdc20 adds the explicitly labeled example=editable-recovery. It allocates room for a header and rows with a 240 px viewport floor. The original example=editable and default gallery composition retain their source-matching shrinking heights and their existing test. No shared Table code changes.

The pinned source preview succeeds down to one row, then its 48 px viewport clips the body input. Scrolling places the input beneath the sticky header. Positive DOM rectangles alone did not prove a reachable control. With an explicitly supplemental 240 px source viewport floor, all four rows can be deleted and Insert first row restores one. This CSS modification is labeled supplemental in every new result, never passed off as the pinned preview.

Two new widget tests first fail without the recovery composition, then pass under normal/reduced motion. All six selected gallery tests pass, including the unchanged original-height test. Scoped analyzer and fresh release build pass.

The final native r4 run verifies source-supplemental and candidate-recovery deletion/restoration under both motion preferences, with 24 observed states, original PNGs, trusted input logs, served-script hashes and effective candidate motion probes. Candidate targets must be hit-testable and clicking the first body input must expose the expected row value in the active native field. This avoids relying on Flutter's initially empty semantic input values. The earlier r1/r2 locator failures and r3 successful run remain unchanged.

This is behavior proof for supplemental compositions. It does not certify original-preview recovery, exact geometry, pixels, timing, or dark-mode coverage. Intrinsic data-table layout remains assigned for follow-up.
