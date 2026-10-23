# Sortable Undo eligibility repair

The order-based eligibility and action guard are fixed. The full native acceptance is **not complete**: native focus differs from the pinned source. No focus implementation or shared primitive was changed in this bounded patch.

## Exact changes and red/green evidence

Base HEAD is `1254bfa63a70298061c557616abeb9c6a67db372`. Source pin is `a76e57c9bbc2837e96420b2610e9c82a3271bb05`.

- `lib/src/motion/sortable_list.dart` adds `_canUndo`, comparing each saved ID with the ID at the current position after membership validation. Both the button state and `_undo` action use it. The existing permanent membership invalidation remains intact.
- `test/motion/sortable_list_test.dart` adds eight regressions covering rejected and accepted controlled owners under both motion settings, external reset plus retained-action invocation, permanent membership invalidation, uncontrolled Home/End/boundaries, and disabling a root with a retained Undo action.
- New evidence lives only in this directory. Scratch work lives under `/tmp/beui-sortable-undo` and `/tmp/beui-sortable-red`. Concurrent `RUN_STATE.md` and MultiSelect changes were left alone. `.impeccable` was not modified. No commit, push, merge, children or broad suites were run.

Baseline `red-controlled.log` records both rejected-owner failures: Undo incorrectly has an action. `red-reset.log` records the saved-order-reset failure. `red-action-guard-2.log` executes the retained action before checking the UI and records expected callback count 1 versus actual 2 on the baseline production file. Its exact baseline and final test inputs are archived. `red-action-guard.log` is the earlier version that first checked the disabled UI; it is retained too.

`green-final-guard.log` passes all 15 non-golden Sortable tests. `analysis-final.log` reports no issues for the two changed Dart files. No golden was updated. Existing rest-state golden coverage was excluded by name, not reported as passing.

## Native results

These are isolated supplemental public-API compositions with fixed A/B/C IDs, not unchanged upstream previews. Source uses the verbatim pinned Sortable component. Fixture CSS and candidate Material layout differ; this is behavioral evidence, not a pixel comparison. Source npm resolution is separately locked and is not claimed to reproduce the upstream Bun deployment.

The corrected full sequence is `attempt-4`: 38 checkpoints and 158 assertions per target/motion pair. Source passes all 316 assertions. Candidate passes 296 of 316, with exactly 20 focus failures. Every order, callback count/payload, Undo eligibility, membership-reset and disabled-root assertion passes. Normal accepted Undo restores A/B/C once, disables itself, and focuses A in both targets. Home/End order changes and boundary no-ops also pass.

`attempt-5-direct` additionally exercises only native Tab to A followed directly by ArrowDown, then a native pointer attempt on disabled Undo. Source and candidate both propose B/A/C exactly once, render A/B/C, leave Undo disabled and never expose the restoration announcement. This passes under both motion preferences. Its source/no-preference timestamp video loses one frame; the original PNGs and a complete RGB index replay are retained below.

The unresolved native focus defect is reproducible in both motion settings and both accepted controlled and uncontrolled composition:

1. After accepted ArrowDown, End or Home, candidate DOM focus is BODY; source keeps the moved handle focused. Reset and membership scenarios likewise expose BODY immediately after their accepted move.
2. After moving A to the end, Home moves it to the front. Undo correctly restores B/C/A, but candidate focus remains Reorder A; source focuses Reorder B, the first differing ID in the saved order.

These are ten failed focus assertions per motion preference, listed in each `attempt-4/*/results.json`. The driver uses explicit native Tab recovery before later checks when needed. Recovery is not presented as preserved focus. `_focusedId` and the existing handle's autofocus behavior merit a separate focus-lifecycle investigation; no speculative focus patch was made here. This archive does not establish the cause in shared semantics or certify a repair.

DOM/ARIA observations include the source's move announcement even when the owner rejects the proposal. They are not actual screen-reader announcement certification. No Space pickup or Escape cancellation contract was invented. Pointer drag lifecycle and whole-gesture Undo are outside this sequence.

## Capture failures and original media

Attempt 1 stopped on a redirect response whose body could not be read. Its 158 original frames and 158-frame index replay remain. It has no completed assertion report or original timestamp manifest, so that replay is untimed evidence only.

Attempts 2 and 3 retain all failures. Flutter initially reported a DOM element labeled Reorder A before a native Tab had initialized keyboard traversal. The helper mistakenly treated that as already having tabbed to A, so initial movement did not reach the component. Increasing waits in attempt 3 did not fix it. Attempt 4 explicitly sends the initial native Tab before searching for the handle. This correction is in task-local capture files only. No existing recorder was edited.

All recorded keyboard/pointer events in completed attempts have `isTrusted: true`. Flutter consumes some keydown events before the document listener; trusted keyup records and the driver sequence establish those inputs. The initial verifier incorrectly required document keydown records and failed; `verify-initial.log` preserves that verifier error. The corrected verifier uses keyup. No driver `.focus()`, DOM click, key dispatch or synthetic semantics activation is used. Candidate calls `ensureSemantics` in the fixture before runApp. Each completed report includes Chrome version, viewport, motion probe, source/candidate callback probe, ARIA snapshot, DOM focus, original PNG hashes, CDP frame metadata and hashes of served JavaScript. Source esbuild inputs and candidate build inputs/locks/output are archived and bound in `bindings.json`.

| Capture | Checkpoints | Original frames | Decoded timestamp-video frames | Recorded failures |
| --- | ---: | ---: | ---: | ---: |
| attempt-2/candidate-no-preference | 38 | 152 | 152 | 48 |
| attempt-2/candidate-reduce | 38 | 95 | 95 | 48 |
| attempt-2/source-no-preference | 38 | 424 | 424 | 0 |
| attempt-2/source-reduce | 38 | 86 | 86 | 0 |
| attempt-3/candidate-no-preference | 38 | 153 | 153 | 47 |
| attempt-3/candidate-reduce | 38 | 94 | 94 | 47 |
| attempt-3/source-no-preference | 38 | 486 | 486 | 0 |
| attempt-3/source-reduce | 38 | 87 | 87 | 0 |
| attempt-4/candidate-no-preference | 38 | 234 | 234 | 10 |
| attempt-4/candidate-reduce | 38 | 126 | 126 | 10 |
| attempt-4/source-no-preference | 38 | 478 | 478 | 0 |
| attempt-4/source-reduce | 38 | 84 | 84 | 0 |
| attempt-5-direct/candidate-no-preference | 4 | 9 | 9 | 0 |
| attempt-5-direct/candidate-reduce | 4 | 9 | 9 | 0 |
| attempt-5-direct/source-no-preference | 4 | 12 | 11 | 1 |
| attempt-5-direct/source-reduce | 4 | 11 | 11 | 0 |

The direct source/no-preference video has 11 decoded frames for 12 originals. `MEDIA_LIMIT.json` records this explicitly. `rgb-index-replay.mp4` decodes all 12 frames, each RGB-identical to its corresponding original PNG. Its 25 fps index playback is not timing evidence. All original videos, original frames and checkpoint PNGs, including failed attempts, remain unmodified. No native60, motion certification or exact-pixel claim is made.

## Verification and handoff

Run `python3 verify.py` from any exported copy of this directory. Python 3, ffprobe, ffmpeg and Pillow are required. Both in-place and copied-export integrity verification passed; strict mode returned exit 1 as expected. It verifies every archived hash, input/build binding, served bundle identity, trusted input records, original frame hashes, decoded frame counts and the documented RGB replay. It independently rechecks final central eligibility outcomes from recorded probes. Integrity verification permits documented behavioral failures; `--require-parity` intentionally exits nonzero while those failures exist.

`commands.md` records build/test/capture commands. Original build and capture scripts preserve the historical `/tmp` paths; the offline verifier uses archive-relative paths. Logs and build output may match repository ignore rules and need explicit inclusion by the parent when archiving. No files were staged.

SHA-256:

- Production Sortable: `2cd852ea3cbf4e377708c1043e6eadca06e12f20735ffdb06ef194c9850736af`
- Regression tests: `74b29b9acf59b7befa4684866dc2a12abe3717617abf13a1421b61f6f27c1b38`
- Baseline Sortable: `ef96ca95ae498d68a78bfb2d8156e72e81ed16e7ac8249e9671c2d7f5ed40943`
- Pinned source Sortable: `740c2ae4c5d23455eb7ba61a60ab0ef2ee46d3bf986b0ff0e5ef6be329806027`
- Served candidate main.dart.js: `769ceffdda3b77e65d5cfdab47c50d3e40efe7ff29952cc61bc12822f9c9d57b`
- Served source.js: `a461b82bed094f3566725f56ddb50014f7525e6d25b4dad8cc7e49add0a35928`

`archive-sha256.json` enumerates exact hashes for every other artifact, including preserved verification logs. The manifest does not hash itself. This is ready for parent review of the narrow Undo fix, with the native focus acceptance explicitly unresolved. No hosted CI, release, merge or deployment result is inferred.
