# Blocks parity evidence

This slice repairs Card Folder, Morphing Tabs, Prediction Market Card, Digit Swap, and Text Scramble. Exact parity is not established. The artifacts include preserved baseline videos, labeled before and after viewing edits, and screenshot recordings for all 19 required routes. Secondary examples and many interaction states remain unverified.

See the [change manifest](CHANGES.md), [per-route video index and gaps](VIDEO-INDEX.md), [invalid capture list](INVALID-CAPTURES.md), and machine-readable [scope inventory](scope.json).

## Round2 follow-up

The [round2 report](round2/README.md) records source-backed card, glyph, SVG, feedback and Search Chips repairs.
It includes native decoding and sizing regressions, source-layer held-press repair, effective Flutter reduced-motion flows, labeled viewing videos and new failed image diagnostics.
Original round1 PNGs, frozen-before hashes and invalid foreign-build records remain unchanged.
No exact-parity or native 60fps verdict changed.

## Integration and policy follow-up

The [round3 report](round3/README.md) records the actual duplicate Card semantics tree, contained SVG network and decode failures, and source Feedback draft policy.
It adds independent Card control states, eye scale and blur transitions, font-body readiness diagnostics, and decoded 750ms privacy-release footage with shared Tooltip dependency `12155d8e`.
Original records and failed parity verdicts remain unchanged.

## Integration commits

The owned implementation commits are:

- `5b292f5345349e812c4632aad7fbb8bb92b9b025` aligns cards, tabs, and shared text behavior.
- `6e7df10989243b3e82136d0b2321d6edc74c0c79` removes duplicate CTA focus stops.
- `34e2fc756e6bf5da84b521c48eabe37148d36c99` retains the clicked outcome for keyboard activation.
- `2f7ef985656cedef16ea60ff8ea8734f818d7bd6` restores the offset CTA keyboard focus ring.

The local shared-width commit `945eb13` is a cherry-pick of `c119a9f3801f06d0bef7a0a344ed57a6c6fa4cc5`. It is not owned slice work. The parent already has the equivalent shared change. Do not integrate it twice. This slice creates no PR, pushes no branch, and performs no merge.

## Provenance

| Input | Identity |
| --- | --- |
| Pristine baseline | `5ec78ac30e1274727ddd185a883346e4d908e6c8` |
| Pinned source checkout | `a76e57c9bbc2837e96420b2610e9c82a3271bb05` in `/tmp/beui-charts-reference-20261023` |
| Live visual authority | `https://beui.dev`, deployment revision unknown |
| Independent inventory | Parent audit `fe9213f`, registry SHA-256 in `scope.json` |
| First frozen release | Code head `34e2fc7`, JS SHA-256 `aea97a92218d9462a95d601dde72b6bc9e4fee1c060ea4730967aa05fdaf1bbb` |
| Final market release | Code head `2f7ef985656cedef16ea60ff8ea8734f818d7bd6`, JS SHA-256 `79a13520a36daf1181c63e6bd729a4c7e504fe5ac07924d96f31d923132758d6` |
| Candidate | Python static server on port 8103, release web build, CanvasKit screenshot backend |
| Baseline gallery | Parent port 8105, baseline library and demo files, debug build for expanded baseline captures |
| Toolchain | Flutter 3.47.1, Dart 3.13.1, Chrome 155.0.8059.86, macOS 27.0.1 build 26A434 |

All recovered candidate batches fetch `http://127.0.0.1:8103/main.dart.js` and reject a hash mismatch before recording. `served-build.json` records URL, UTC check time, expected hash, actual hash, and code head. The parent removed the colliding Dart server. Old foreign-build captures remain explicitly invalid.

## Capture conditions

Recovered recordings request a 1280 by 900 CSS viewport at DPR 1 with dark theme and no browser reduced-motion preference. Chrome actually returns 1280 by 813 pixels. That discrepancy remains in the originals, metadata, and derived videos. There is no stretch or frame interpolation.

The candidate uses `previewWidth=592`. The shared stage tests establish a 592px inner constraint and a 658px outer frame at this viewport. The source preview occupies the 592px docs column in the measured first-example captures. Fixed-size source controls were also measured separately. For example, source and candidate tabs both have 154px slots with a 170px start interval. Card Folder is 384 by 220.90625 logical pixels in both implementations. This does not establish every route's effective child width or complete responsive parity.

The pristine baseline has no width-query support. No capture-only wrapper patch was applied here. Its original videos retain the default frame. The labeled change videos disclose that condition. They are before-then-after viewing edits, not synchronized, same-condition comparisons.

The first seven source and candidate baseline sets were captured before implementation. `before-sha256.txt` remains unchanged. Expanded baseline captures use the separate baseline server. Every original remains at its original path. The final verification checks the frozen before hashes and every recovered PNG hash.

`verification.json` records 25 recovered recordings, 2,710 verified original PNGs, and 185 successful frozen-before manifest checks. The six labeled viewing videos retain exactly the summed input frame counts. Their separate manifests preserve the derivation.

## Recording results

The five paired screenshot runs have the following measured cadence. None meets the requested native 60 FPS gate.

| First example | Reference FPS | Candidate FPS at 34e2fc7 | Largest candidate gap |
| --- | --- | --- | --- |
| Card Folder | 12.49 | 17.18 | 880.27ms |
| Morphing Tabs | 12.86 | 24.37 | 351.66ms |
| Market Card | 15.99 | 26.47 | 779.57ms |
| Digit Swap | 15.01 | 30.40 | 45.88ms |
| Text Scramble | 15.03 | 20.72 | 75.23ms |

The final market recording at `2f7ef98` measures 24.47 FPS with a 165.84ms maximum gap. Its decoded frame 89 shows the Lakers No action and the offset keyboard outline. Card privacy digits and market Yes and No labels were inspected in original PNGs. Labeled viewing videos were decoded and inspected too. The remaining route protocols and uncertainties are explicit in the video index.

The shared recorder preserves input dispatch times, screenshot request and response times, original PNGs, hashes, and FFprobe counts. A screenshot's exposure time is unknown inside its request-response interval. Even a successful event dispatch does not prove that its requested UI state appeared. The preserved 25 FPS Playwright videos are also not native 60 FPS proof.

## Comparisons

`compare/card-rest` contains equal-sized source, before, and after crops. The diagnostic SSIM is 0.643388 and the difference is nonzero. It is a failed parity comparison.

The earlier `compare/card-motion/after-result.json` returns `capture_unreliable` and a null score. It is not motion success. The recovered `compare/card-recovered` run selects 22 existing paired samples at a nominal 100ms grid. Missing intervals are recorded in `selection.json`. Its Design Compare result is `compared`, score 23.3, energy ratio 0.233, temporal correlation 0.334925. This sparse diagnostic is not a timing verdict or a parity pass.

Card crops retain the complete 416 by 340 interaction region without resizing. Source origin is 392,350. Candidate origin is 564,260. No masks or baseline changes reduce the reported difference. Other routes do not yet have complete paired crop comparisons.

## Tests and analysis

At final implementation head `2f7ef98`:

- `behavior-focus-ring-final.log` reports 229 passing non-golden tests across 20 explicitly named block, text, and Dock test files. The CLI excludes names containing `golden`.
- `focus-ring-final.log` reports 30 passing non-golden market and tab tests.
- `analysis-focus-ring-reviewed.log` reports no issues from `flutter analyze` after the final test edit.
- `build-focus-ring.log` reports a successful release web build. The existing missing Cupertino font warning remains in the raw log.
- `full-tests-focus-ring-final.log` reports 2,095 passes and 45 golden-comparison failures. No golden was updated.

Earlier focused counts of 225 and 232, and the earlier full result of 2,094 passes with 45 failures, are separate runs. They are not the latest focused result. `full-tests-after.log` is an intermediate run that overlapped edits and is not a final gate.

The direct regressions cover opposite outgoing digit motion, stagger cancellation, same-value style refresh, scramble completion, card keyboard activation, equal tab slots, panel sizing, actual narrow root constraints, both callback sides, tab traversal, pointer-to-keyboard selection, and painted focus geometry. Passing these tests does not prove visual or motion fidelity.

Raw command logs retain their original trailing spaces. A whole-evidence `git diff --check` reports those spaces. They were not trimmed or hidden. The code and authored documentation pass the whitespace check when raw `.log` files are excluded.

## Reproduce the evidence checks

Run `node docs/proof/v3-parity/blocks/verify-evidence.mjs` to verify original PNG hashes, decoded frame counts, and the immutable before manifest. Run `node docs/proof/v3-parity/blocks/artifact-index.mjs docs/proof/v3-parity/blocks/video-manifest.json` to regenerate the media index.

`recovered-batch.mjs` calls the parent's shared `tool/parity_capture.mjs` from the capture-recovery worker. It adds route protocols and build identity checks, not another recorder. Every output batch must have a fresh name. The full command and inputs remain in each config. The shared recorder must be present at the recorded absolute path or updated to its integrated parent location before rerunning elsewhere.

## Open gates

No required route receives an exact-parity pass. The complete source-example and widget-part obligations are still open. Light and dark pairing, effective Flutter reduced motion, keyboard entry from neighboring controls, complete click flows, enter and exit trajectories, animated tooltip text, native assets, and stable native 60 FPS recordings require more work.

The live font family differs from the spec, and baseline and after stage wrappers are not identical. These are reported, not normalized away. No shared theme, engine, catalog, barrel, app, or shell change is part of the owned implementation commits.
