# Combined gallery native verification

Fresh release build of the unchanged current production/gallery snapshot succeeded. The three requested component hashes match exactly, as do all six inputs recorded by components-integration-20261024. No production, shared evidence, goldens, commits or pushes were changed by this task. Existing root 2609 pass / 56 unchanged golden failures and gallery 66 pass were read, not rerun.

The served main.dart.js SHA-256 is `11c8793e3b26481a2dc98940ba5d8ed3449b88d8ca41d959cab446ce7fa11f00`. Every recorded context fetched those bytes. `production-manifest.json` identifies the complete copied production inputs; `build-manifest.json` identifies the complete fresh release output. Build used Flutter 3.47.1 / Dart 3.13.1, matching the preceding MultiSelect native archive SDK. Exact SDK and build warnings are retained. The existing missing Cupertino font-family warning is not treated as a failed build.

Actual routes were `?slug=multi-select`, `?slug=file-tree`, and `?slug=sortable-stack`, with `theme=light&captureProbe=1`. No fixture was substituted. Chrome and Playwright use the documented runtime; package locks and browser versions are preserved. Viewport 1440x1100, device scale 1. Both no-preference and reduce were checked against matchMedia, gallery MediaQuery.disableAnimations and platform accessibility flags; motionOverride remained null.

## Outcomes

- MultiSelect: pointer removal of Design is accepted and focuses the native input. Typing, Escape with empty query, then typing again work under both preferences. A matching query gives a focusable Research option; first Tab moves inside the control and preserves the query. Next Tab exits the browser document, with document.hasFocus false and BODY active. Retaining the popup across that browser boundary is observed, not certified as external-field behavior. The fresh no-match path uses zz, Escape, xy, Tab: Tab reaches the actual related Sortable List button and closes the visible Options panel in both preferences. The inactive native input still reports xy; this is not proof of the effective Dart query. Shift+Tab reaches Arc Picker, not the fixture's external-field return path. No generic Tab/Shift+Tab parity claim follows.
- FileTree: actual initial rows, Down, Enter selection, Home, collapse/expand, Right child, End, Up and recorded Tab continuation work in both preferences. Selection is exposed as aria-current. No disabled rows exist in this composition. Disabled-state behavior and exact tree/treeitem / aria-selected parity remain outside this gallery proof.
- Sortable: first ArrowDown changes the accepted order and enables Undo. Browser focus falls to BODY in both preferences, retaining the known engine focus failure. A second ArrowDown is issued without recovery and focus stays BODY. A trusted pointer click on actual Undo restores the original order and disables Undo. No browser focus calls were made. Controlled rejection is absent from this gallery and is not proven.

No new production regression is established by these bounded checks. The gallery traversal and document-exit differences above remain explicit limitations, not fixture-equivalent passes. No source comparison, screen-reader, pixel, motion timing, frame-rate, minimum SDK, hosted CI or release-readiness certification is made.

## Preserved attempts and interpretation

All 16 context recordings, original screencast PNGs, screenshots, MP4s, frame-index lossless videos, input events and failed assertions remain intact.

`run-1` initially assumed single Product/Research labels and aria-label on focused FileTree buttons. Actual Flutter names repeat option text and use button textContent. It also incorrectly assumed first Tab leaves MultiSelect. `run-2` corrects names and distinguishes first Tab inside, but its extra outside-Tab and immediate-return assertions remain failed: the destination is the browser boundary, then Research. These are retained as failed assumptions, not silently erased.

`tab-followup` records document.hasFocus and extra native Tabs. Its later pointer/type probe is exploratory: normal motion did not retain zz, while reduce did. It is not a deterministic no-match proof. `no-match` starts fresh and establishes that path under both preferences. Its no-match wording assertion incorrectly expected "No results" instead of the actual "No options found." Its Shift+Tab return assumption also fails because the gallery traversal reaches Arc Picker. The verifier independently checks the actual no-match text and popup disappearance without rewriting those original outcomes.

Screens visually inspected: run-1 MultiSelect retyping, reduced FileTree collapse, Sortable accepted move; run-2 reduced MultiSelect document exit, normal FileTree selection, reduced Sortable Undo; tab-followup reduced no-match Tab. Text and icons are legible in those captures, and selected/order/collapse states agree with recorded semantics. This is sampled inspection, not all-frame pixel certification.

## Replay and integrity

Run `python3 verify.py` from any regular-file export with Python Pillow, ffmpeg and ffprobe installed. It verifies source/build/input locks, served script bytes, effective motion, trusted input records, every original frame/screenshot hash, decoded video counts, exact RGB reconstruction from lossless frame-index videos, and the precise retained failure set. MP4 counts are reported independently; lossless index videos are authoritative for original-frame identity. Archive integrity success deliberately does not mean every behavioral assertion passed.

The capture scripts use the documented local runtime at /tmp/beui-parity-capture-runtime and installed Chrome. They are preserved capture provenance, not a promise of browser-free recapture portability. No dependency network lookup is needed by the archive verifier. Only checked-free port 18181 was used; 18182 remained unused. Only this task's server is stopped.
