# Returns Calendar native replacement evidence

This archive compares bounded deterministic fixtures using pinned React source a76e57c9bbc2837e96420b2610e9c82a3271bb05 and a regular-file copy of the current Flutter library. It is not full Returns Calendar parity certification. Production files and historical evidence were not changed.

## Inputs and execution

Both wrappers read snapshots.json. Initial years are 2024 and 2025, with twelve explicit returns per row. Missing truncates 2025 to January and February. Replace substitutes 2030 with twelve returns of seven. Remove drops 2025. Empty removes both years. Native i/m/r/d/e keys change public inputs without clicking away from the focused cell. These controls belong to the fixture, not the production demo. The current demo was read and retained: its five years (2021–2025) and fixed source-sample arrays are outside this bounded fixture.

The historical coverage ledger's missing/short-year and keyboard obligations guided the sequence; its classifications are not evidence of absent implementation. No ledger count was changed.

base-head.txt records the checkout base at copying. candidate-inputs.json hashes final isolated inputs including library, demo, fixture, fonts, shaders and dependency locks. candidate-input-originals.tar.gz preserves those regular files. The source manifest, transitive originals, npm lock and pinned-input-check.json bind the bundle to the reference commit. served-js retains actual response bodies. served-builds.tar.gz preserves both complete final served trees. Inputs remain fixed even if the parent concurrently changes the shared checkout.

Each completed session retains native screenshots, original Chrome compositor frames, their timestamps and hashes, a lossless video, raw trusted pointer/key/focus event logs, focused-element labels, and the tracked element's connected/same-focused identity. Assignment of a reference to document.activeElement only observes identity; it does not set focus. Flutter accessibility bootstrap uses one synthetic zero-coordinate placeholder click. Subsequent pointer and keyboard events are trusted browser input. Browser reduced-motion and effective Flutter MediaQuery.disableAnimations are probed separately.

## Reproduction and limits

Run `python3 /absolute/path/to/returns-calendar-native/verify.py` from any directory. Python and ffprobe are required. The verifier reads only this exported folder, validates hashes, source pinning, media frame counts, native input trust, equal fixture arrays and specific recorded behavior. Passing archive integrity does not imply source parity.

For native replay, run `python3 replay.py`, then `node capture.mjs NEW-UNUSED-ATTEMPT`. Replay extracts archived regular files and serves only port 18155. Capture uses /tmp/beui-parity-capture-runtime and the documented Google Chrome executable. Stop replay with Ctrl+C. Offline verification requires neither that runtime nor the original temporary build checkout.

Attempt 1 retains two complete source sessions and a candidate startup timeout. The initial Flutter build used base href /, causing a root flutter_bootstrap.js 404. attempt-1-builds.tar.gz retains the failing build; startup-diagnosis.txt records the correction. Build 2 only changes the isolated build's base path. Attempt 2 is the final paired run. No failing originals were replaced.

Sessions use light theme, desktop pointer, 1000x800 CSS viewport and DPR 1. Screenshots and compositor frames remain at their delivered dimensions without rescaling. Videos preserve emitted frame timestamps without interpolation. Settled observations use 450 ms waits, not guarantees of exact spring/ticker completion. No native60, exact-pixel, interrupted-animation, full-gallery, dark-theme, mobile, minimum-SDK, screen-reader, controlled-selection, general span arithmetic, CI, deployment or merge claim is made. Typography, geometry and visual/timing equivalence remain open. These public-input replacements do not establish full-demo equivalence.

## Observed results and defect hypotheses

All four final sessions completed 23 checkpoints without page errors. Both motion preferences produce the following behavior.

Missing months keep March 2025's focused element connected and focused, changing its accessible value from +4.0% to +0.0%. Native Tab reaches April and opens the +0.0% readout. Reinserting values keeps April focused and changes its readout to −4.0%. Shift+Tab returns to March with +4.0%. Both implementations agree on these bounded states. The capture clears selection with Escape before replacement, so this does not certify selected-span identity or arithmetic under replacement.

Replacing 2025 with 2030 disconnects the source March element. The next Tab reaches January 2030. The candidate preserves the same focused element, relabels it March 2030, then Tabs to April. Restoring 2025 removes the source replacement row again, with next Tab reaching January 2025. Candidate remains on April 2025 and next Tab reaches May. This is a reproduced native identity/traversal mismatch. The likely cause is identity based on row position: source grid.tsx keys its row by year and cells by year/month; candidate builds positional Rows and uses row/month keys on InkWell, retaining _ReturnsCellState and its FocusNode when the year label changes. This is a root-cause hypothesis based on current code and native observations, not a verified repair.

Removing the focused 2025 annual cell disconnects it in both implementations; next Tab reaches the fixture initial button. Reinsert does not reconnect the removed element; next Tab reaches missing in both. Clearing all years after focusing March 2024 disconnects the tracked element in both, but candidate immediately focuses the previously visited missing control and next Tab reaches replace. Source returns to body and next Tab reaches initial. Investigate Flutter focus-scope restoration/history and browser traversal integration. No universal fallback policy or internal causal proof is claimed.

Source also retains a Jan 2025 readout after the replacement row is restored while browser focus is on body. This source behavior is preserved, not silently treated as the desired generic cleanup policy. Candidate readouts are merged into button semantics, so verification checks actual readout strings rather than requiring an ARIA tooltip role. Reviewed missing-next screenshots confirm the visible zero readout. Styling and tooltip positioning visibly differ and remain outside exact visual certification.

No production fix, broad tests, golden update, git commit, push or merge was performed. The final verifier explicitly asserts the observed year identity divergence. Capture summary pass flags only mean capture completion, motion agreement, input trust and video encoding.
