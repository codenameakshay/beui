# Final component evidence audit

This is a partial implementation handoff. No route has exact visual or motion
parity. The implementation head is `8ccb169aa6d6786c451456f756af2087d2672c89`.
The pristine baseline is `5ec78ac30e1274727ddd185a883346e4d908e6c8`.
The pinned checkout is `a76e57c9bbc2837e96420b2610e9c82a3271bb05`.
The live deployment revision is unknown.

## Integrity results

The final audit ran on 2026-10-23 in the components worktree.

| Check | Result |
|---|---|
| Original before videos and capture metadata | All 300 byte sizes and SHA-256 hashes match `before-sha256.json` |
| Final repaired and reference default-route videos | All 74 byte sizes and SHA-256 hashes match `release-video-sha256.json` |
| Labeled before/after videos | All 18 decode to the sum of their actual original input frame counts |
| Presentation intermediate frame counts | Each saved part count equals its original input count |
| Video-index links | All 96 targets exist locally |
| Pinned source files | All 48 inventory SHA-256 hashes match the source checkout |
| Audit scope | All 28 routes contain every audit scenario and the four mandatory common states |
| Local inventory | 223 state/example obligations, including 17 new-badged routes |
| Final static analysis | `flutter analyze` reports no issues |

The frame audit uses FFprobe `-count_frames`, not nominal FPS metadata.
It decodes the original before and repaired inputs again and compares their
counts with each presentation's saved `frameProof` and decoded final video.
The hash audit reads file bytes again. It does not regenerate expected hashes.
These checks do not judge the depicted interaction or certify its timing.

The first scope-check attempt compared each full local state array with the
audit's route-specific array. It failed because the local array also includes
the four common states and named install examples. The corrected check verifies
that every mandatory common state and every audit scenario is present.
No inventory or audit baseline changed to satisfy that check.

## Decoded footage inspection

The final inspection decoded the labeled Tooltip after frame at 7.6 seconds.
Its AFTER caption is readable, and the Right trigger displays "More context".
The original 1280px imagery remains centered inside the padded 1440px frame.
The caption states the repaired revision, wrapper width, and unproven parity.

The Image Viewer light frame at 1.5 seconds shows the real architecture photo
inside the open modal, its 1/3 counter, and the close action. The Timeline dark
frame at 1.2 seconds shows the selected "Shared spaces" card and source-style
grid tile. These observations reject blank capture for those frames only.

The decoded PNGs remain beside their respective videos. Earlier Tooltip
keyboard inspection found failed focus navigation. That failure remains in
`MOTION_REVIEW.md` and the video index.

Captions describe the implementation change across the pair. They do not claim
that the BEFORE clip already contains the described repaired behavior.
Card, breadcrumb, and image-viewer BEFORE clips are labeled static inventory.
Baseline and repaired viewport widths differ and are labeled on the videos.
The presentation copies are not matching-width comparison inputs.

## Retained evidence and open gates

The 18 final presentation videos and their captions are committed. The 36
intermediate presentation parts remain local and ignored to avoid storing
duplicate video. Their frame counts and dimensions remain in `index.json`.
No original recording was replaced, resized, interpolated, or deleted.

The 20 failed golden images are retained under `golden-failures/`. The final
behavior run passed 2143 tests only with the existing golden-skip flag.
The five unsuppressed golden failures remain open.
The unfiltered staged whitespace check reports eight trailing-space lines in
raw Flutter failure logs. Those logs remain byte-for-byte unchanged.
The staged whitespace check excluding raw test logs passes.

The final per-route records distinguish known mismatches and failed visual
gates from inconclusive routes. No generated verdict says pass.
All examples, all widget parts, matching-width baseline recaptures, reduced
motion footage, touch, and complete drag/focus/interruption flows remain
unfinished. Default-route footage does not discharge those requirements.
The delivered cadence does not establish native 60 FPS.

`INTEGRATION.md` records shared-file reconciliation and implementation gaps.
`VIDEO_INDEX.md` links all 28 route records and every labeled change video.
