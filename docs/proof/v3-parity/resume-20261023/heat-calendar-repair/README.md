# Heat Calendar interaction and lifecycle repair

This archive retains the original repairs, rejected/intermediate attempts, independent review findings, and replacement native evidence. The before-repair archive remains separately unchanged at ../heat-calendar-native.

The repair adds legend pointer/focus activation, chronological native semantics traversal, and cleanup of invalid hover and selection state. A chart FocusScope retains focus after a focused day is removed. The next Tab traverses from the final surviving cell; Shift+Tab visits that cell. Moving focus outside cancels continuation. Custom compositions use their existing traversal order rather than a hard-coded legend target. Controlled invalid selection is hidden without mutating the owner's value or emitting a callback.

Worker round one fixed filtering, final-day traversal and stale readouts but retained the wrong post-removal Tab destination. Independent review also reproduced an invalid locked range surviving replacement. Both intermediate failures are preserved. Worker round two and its native default/custom sessions are under lifecycle-worker. Parent's first intermediate capture is under parent. Final parent capture belongs under lifecycle-parent.

Run python3 verify.py with ffprobe installed. It verifies sealed hashes, original screenshot/frame hashes and decoded frame counts, recomputes final default native focus assertions, and checks final built chart identity. Native Flutter ARIA omits the selected state/readout, so the range result additionally requires inspecting new-anchor-locked.png: October5-6, two days and2 commits. Passing archive verification is not pixel or timing certification.

The original worker scripts retain historical /tmp paths. Final source and candidate served trees and regular-file build inputs are archived for reproduction. No original frame is rescaled or relabeled. Native defaults cover both motion preferences; supplemental custom compositions use reduced motion. Arbitrary nested scopes, multiple grids, other browser engines, screen-reader behavior, visual parity and native60 remain unverified.

Production commit d74fae552 passed independent review round two. Parent reran the complete chart suite:287 pass with BEUI_SKIP_GOLDENS=1, scoped analysis clean, isolated final-source release build passed. Parent final native capture independently passes all four default sessions, including forward/reverse continuation, external cancellation and fresh range selection. Source and candidate originals remain separate. Prior golden failures are not cleared by this run.
