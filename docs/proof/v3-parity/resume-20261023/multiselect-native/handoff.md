# Next bounded obligation after the calendars

Read-only reconciliation, 2026-10-23. Repository root: `/Users/codenameakshay/.t3/worktrees/beui/t3-df4b55e2`. Source root used for inspection: `/tmp/beui-charts-reference-20261023`, identified by the existing archives as pin `a76e57c9bbc2837e96420b2610e9c82a3271bb05`. I read files only; I did not independently revalidate that checkout's Git identity, run tests/builds/browser/captures, change the repository or Git, or start children. This report is the only write.

## Recommendation: Sortable List controlled rejection and Undo eligibility

There is a concrete implementation mismatch worth fixing before another broad state sweep. This is established by code inspection, not a newly executed failing test or native reproduction.

- Candidate `lib/src/motion/sortable_list.dart:80` creates a new `_ids` list on every access. At line 172, `canUndo` uses `_previousIds != _ids`, a list identity comparison, after checking membership. It therefore enables Undo whenever previous IDs have the same members, even when their order equals the current order.
- `_move` at lines 113-130 stores the previous order and rebuilds after publishing a proposal. If a controlled owner rejects that proposal, the visible order remains unchanged, but Undo becomes enabled. `_undo` at lines 133-149 checks membership only; activation can publish an unchanged order and announce `Previous order restored.`
- Pinned source `components/motion/sortable-list.tsx:166-178` requires `previous.some((id, index) => id !== ids[index])` and checks `canUndo` inside `undo`. In the same rejected-control case, source Undo stays disabled.
- Existing `test/motion/sortable_list_test.dart:137-153` checks the proposed callback order and original input immutability. It does not check Undo eligibility, rendered order, or a redundant Undo callback after rejection. The normal Undo test at lines 90-104 cannot cover this defect.

Bound the assignment to `lib/src/motion/sortable_list.dart`, `test/motion/sortable_list_test.dart`, and new dedicated proof/fixture files. Use `example/lib/demos/sortable_stack_demo.dart` and source `components/previews/motion/sortable-stack.preview.tsx` as composition references. The existing preview accepts proposals, so label the rejection fixture as a supplemental public-API composition, not the unchanged source preview. Do not edit shared focus, Tooltip, theme or recorder code speculatively.

Observable acceptance:

1. Start with explicit A/B/C identities and a controlled owner that records but rejects updates. Native Tab to A's handle followed by ArrowDown proposes B/A/C once, leaves visible A/B/C, and leaves Undo disabled on source and candidate. Attempted Undo activation produces no second callback and no restoration announcement. Preserve the source's existing move announcement behavior; do not invent a separate accessibility policy.
2. With an accepting owner, the same move renders B/A/C, enables Undo, and Undo restores A/B/C once, disables itself, and retains the source-observed handle focus. Verify Home/End and boundary no-ops without expanding into a full drag project.
3. After an accepted move, an external owner reset to the saved A/B/C order disables Undo. Replacing membership invalidates the saved order; later reintroducing old members must not revive it. Preserve uncontrolled Undo and disabled-root behavior.
4. First add behavioral regressions that fail on the current implementation. Then compare the bounded native source/candidate sequence under both motion preferences with exact input/build identity and trusted input. Assert order, callback counts, disabled state and focus explicitly. Keep DOM/live-region observations separate from actual screen-reader announcement certification.

The historical ledger's keyboard pickup/cancel/drop wording is not the pinned source contract. Source `sortable-list.tsx:350-379` implements direct ArrowUp/ArrowDown/Home/End movement, with no Space pickup or Escape-cancel branch. Do not implement an invented keyboard drag mode to satisfy that TODO. Pointer drag lifecycle and whole-gesture Undo are a later adjacent obligation, not acceptance for this small fix.

## Next two priorities

2. MultiSelect native token removal and controlled rejection. This remains an unverified state slice, not a demonstrated defect. Candidate files: `lib/src/motion/multi_select.dart:166-269`, `test/motion/multi_select_test.dart:124-164`, `example/lib/demos/multi_select_demo.dart`. Source files: `components/motion/multi-select/context.tsx`, especially value/remove ownership around lines 235-270; `trigger.tsx:138-254` for token removal and input keys; `list.tsx` for disabled rows; and `components/previews/motion/multi-select.preview.tsx`. Use fixed selected IDs and query. Observe native empty-query Backspace removing exactly the final token, nonempty-query Backspace editing text, pointer chip removal, accepted versus rejected owner updates, and disabled-item exclusion. Assert visible chips, callback payload/count, actual query, focus and popup state on both sides. Existing widget coverage already implements/removes tokens; do not assign token removal as missing code. Default-only round-two footage does not establish these native outcomes.

3. FileTree nested collapse and focus continuation. This also remains unverified, not an established implementation defect. Candidate files: `lib/src/motion/file_tree.dart:233-342`, `test/motion/file_tree_test.dart`, `example/lib/demos/file_tree_demo.dart`. Source files: `components/motion/file-tree.tsx:199-358` and `components/previews/motion/file-tree.preview.tsx`. Use an explicit parent/nested-folder/leaf tree. Observe native ArrowRight expansion and entry, ArrowLeft parent/collapse behavior, Home/End, disabled-row exclusion, and controlled collapse while a descendant has focus. Derive the expected post-collapse Tab and selection outcome from the unchanged source before judging candidate cleanup. Check visible rows, expanded IDs, callback counts and actual native focus. Existing keyboard/focus implementation means the historical absent-footage label is not evidence of missing navigation. Do not add typeahead solely because the old ledger requests it; establish the pinned source contract first.

## Reconciliation and exclusions

The latest `resume-20261023/RUN_STATE.md` changed during this read. Its new leading section and `returns-calendar-repair/README.md` agree on production `d8688c53f`, accepted review r3, 122 final native checkpoints, root 2,553 passes with the exact same 56 golden failure identities, and gallery 66 passes. The new state records successful clean-export verification and archive commit/push still queued. Parent owns that delivery; this report makes no push claim.

`heat-calendar-repair/README.md` and current RUN_STATE supersede the historical Heat Calendar TODOs: `d74fae552` and archive `aef70e819` cover accepted legend filtering, chronological traversal, stale-readout cleanup, post-removal continuation and invalid-range cleanup within their recorded scopes. Returns Calendar R020-R025 are accepted within the reviewed scopes. Do not reopen them as untouched defects.

`order-book-deterministic/README.md` accepts deterministic readouts, selection, traversal, reorder, Step, empty and one-sided replacement. Full-demo timer equivalence remains separate. `minimum-sdk-3442/REPORT.md` records resolution, compilation, contract and 294 native states; zero actual ancestor reorders leaves a causal measurement limitation, not a reproduced regression. RUN_STATE records the corrected Flutter >=3.44.2 declaration. These supersede the first and third recommendations in `/tmp/beui-pr26-next-obligations-20261023.md`.

The same old report's mono diagnosis recommendation is completed. RUN_STATE's chart-mono section records that current narrowing did not reproduce in the fresh fixture or actual gallery, advances match aliases, DOM differences are below 0.019px and baseline difference is 0.26px. Nonzero original raster comparisons remain. These are renderer/raster residuals with unresolved historical cause, not evidence supporting another font or component-offset change.

The historical `coverage-ledger.md` is explicitly an a2942181 snapshot. Its sortable/multiselect/file-tree entries at lines 177-191, 385-399 and 433-447 are corroborated by `components/round2/README.md`, which labels these routes default-only. The later `components/round3-examples/README.md` handles button/slider/table examples, not these interaction slices. Current RUN_STATE also supersedes the ledger's missing Sankey and missing 264 originals assignments. Later Table, Tooltip, Bump, candle/volume, composition/funnel, signup and agent repairs must not be reassigned from the old ledger.

## Remaining proof boundaries

- Real implementation defect identified here: Sortable List Undo uses reference inequality where the source requires order inequality. Runtime/native reproduction is the first next step, not a result of this task.
- Unverified states: MultiSelect and FileTree sequences above, Order Book live timer correspondence, and broader per-route/public-part obligations. Absence of evidence does not establish a defect.
- Renderer residuals: nonzero typography/raster comparisons and the existing 56 golden failures remain unwaived. This inspection supplies no exact-pixel acceptance or new causal attribution.
- Measurement limits: no native60 claim. Returns parent reduced-motion timestamp video has 559 decoded frames for 560 original PNGs; the 560-frame index replay preserves RGB but its 25fps playback is not timing proof. The retained rejected worker mismatch is separate. Screen-reader behavior and minimum-SDK causal ancestor-reorder coverage remain unverified.

No new completeness count, exact-head hosted CI, deployment, merge, original-pixel acceptance or motion certification is inferred from this report or the historical 76-route/601-obligation floor.
