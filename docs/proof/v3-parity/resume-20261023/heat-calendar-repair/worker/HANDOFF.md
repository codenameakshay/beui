# Heat Calendar repair handoff

Only lib/src/charts/heat_calendar.dart and the new test/charts/heat_calendar_native_regression_test.dart were edited in the shared checkout. No commits, pushes, children, shared tooltip edits, golden changes or proof edits. Parent archive work was left alone.

## Changes and mechanism

- Legend uses pointer entry and scale exit, focus/blur, and Enter/Space activation. Existing tap toggling remains. This follows pinned source heat-calendar/legend.tsx handlers. Pointer exit clears even after a click. Existing narrow/wide touch filter tests pass.
- Each rendered cell has an OrdinalSortKey using its existing chronological index. The row-based visual layout and NumericFocusOrder are unchanged. Original semantics traversal was row-major, unlike source's column/day DOM order. Native browser capture after the change reaches legend 0 then legend 1 from October 23 in both motion preferences. This establishes that chronological semantics plus focusable legend repairs the demonstrated native-order failure; it does not claim every platform follows the same native focus path.
- Invalid hover/dismissal coordinates are cleared on input replacement. A focused cell that becomes invalid is explicitly unfocused before detachment. Flutter FocusAttachment.detach (focus_manager.dart:223-233) otherwise calls unfocus with previouslyFocusedChild. A focused October 4 followed by October 23 then removal reproduces a stale readout in an ordinary widget regression. Default unfocus clears that history instead of restoring the earlier day. No extra semantic focus handler or shared Tooltip change was needed.

## Behavioral test evidence

- red.log: initial original-file run, five behavioral failures, two passes.
- red-final3.log: final ten tests against an isolated copy with original.dart restored; eight failures and two passes. Includes pointer click/exit and the prior-focus restoration regression. red-tests contains exact copied inputs.
- green-final2.log: final ten regressions pass in shared checkout.
- existing-tests2.log: eight affected existing tests pass (range anchor/lock, controlled selection, touch legend filter, hover, layout, semantics, keyboard). Golden test deliberately excluded by test-name selection.
- analyze-final2.log: two owned files, no issues.
- Earlier failed compile, test cleanup, missing isolated asset, wrong name-filter, and build attempts remain in /tmp. They are not passing evidence.

## Native evidence

native-attempt2/{source,candidate}-{no-preference,reduce}/results.json contains trusted input traces, active DOM identities, ARIA snapshots, served JS hashes and original compositor frames. Each directory contains unscaled PNGs and capture.mp4. native-checks.json records focused October 23, Tab to legend 0 then 1, removal with no cell focus/readout, and input trust assertions for both candidate preferences. The capture script's own pass flag is sequence integrity, not parity.

Visual inspection of filter-hover.png shows only level 2 undimmed and its legend outline; filter-hover-exit.png and filter-click-exit.png clear the filter. Both motion preferences reproduce the repair. future-removal-focused.png has no stale October 4 readout. Original failing comparison remains in the parent's archived attempt 3.

Regular files were extracted from candidate-input-originals.tar.gz and served-builds.tar.gz. Only the chart implementation was replaced in the isolated candidate. Build command: flutter build web --release --no-wasm-dry-run --base-href /candidate/example/build/web/. Build log is build3.log. Served on owned port 18150. Capture copied the archived capture.mjs with port changed and candidate cell lookup changed from row-major nth position to exact date-label matching. This avoids silently targeting a different cell after semantics reordering. No programmatic focus was introduced. Original semantics bootstrap click remains the only allowed synthetic input.

input-hashes.json identifies original, built chart, final chart and regression test. Built chart differs from final chart only in import ordering and two explanatory comments added after compilation. Parent must build/capture the final shared input independently as requested. Full isolated input and served files remain under build/ and served/.

native-attempt1 preserves two source sessions and the candidate startup failure: my first isolated build omitted base-href, causing /flutter_bootstrap.js 404. The failure is in native-attempt1.log and server.log. Corrected build3 and native-attempt2 are separate.

## Remaining limits

After a focused cell is removed by endDate or weeks, next Tab reaches candidate fixture control initial; source reaches legend 0. The patch clears stale focus/readout but does not implement a speculative browser-like continuation policy. Candidate legend selected state is visible in Flutter semantics/widget assertions and pixels, but its native ARIA snapshot does not expose aria-selected on these buttons. No full-gallery, assistive-technology, mobile, pixel-parity, broad suite, CI or release claim. Parent owns independent review and final replacement capture.
