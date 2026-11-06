# Components verification checkpoint

This branch targets `release/beui-v3.1.0`. It is not a release-readiness claim.
Canonical source is `starc007/ui-components` at
`1ab921e62283e788a686bc4bafa1de5ff56104ea`.
All current commands use Flutter 3.44.4 with `--no-pub`.

## Changes in this branch

| Unit | Consumer-facing change | Regression coverage |
| --- | --- | --- |
| Select | Source ownership, placement, keyboard activation, rich labels, and reveal behavior | Initial-open placement, controlled refusal, traversal, semantics, and shadow raster |
| AnimatedSidebar | Shared provider state and focus-managed mobile composition | Nearest-provider ownership, shortcuts, traversal, and restoration |
| TextShimmer | Additive widget-child composition | Layout, text inheritance, reduced motion, and retained state |
| NumberTicker | Decimal formatting without a consumer fork | Literal formatted values and source digit composition |
| AdaptiveStepperValue | Optional pure value builder with retained opacity and blur presence | Literal entry and exit values, interruption, identity, reduced motion, and accessible actions |
| Tooltip | Transformed anchor bounds in root-overlay coordinates | Unscaled gap and panel, resize, scrolling, retained transforms, and pointer pass-through |
| AvatarGroup | Source member, overflow, and expansion composition | 29 cases, including genuine first Tab from an outside control |
| Pagination | Source range, controlled and uncontrolled state, presence, and router metadata | 14 cases, including temporary total shrink and labelled focus semantics |

The barrel exports Avatar and Pagination. The gallery uses the canonical
preview data through the `avatar-group` and `pagination` routes.
The branch also contains the reviewed glide token and internal size observer.

## Current checks

The combined Avatar and Pagination run passed 43 cases with exit 0 and
`done.success=true`. Its 219-file import closure and six configs stayed exact.
Log SHA256 is
`8d8f454ba364b9da36c275500177e235ce22e94ac73e7c8e941bcfee47f11c8d`.
The original red logs remain intact.

Root analysis passed with no issues after five mechanical lint corrections.
All 587 local Dart files and six configs stayed exact.
Log SHA256 is
`b69eb5df37b1a3f5c14d9429e56430b566505d9d959157a05d1c06496ab93263`.

The full root run completed with 2,886 passes and 31 golden failures, exit 1.
Every failure was a pixel comparison. All 31 candidate PNGs match the preserved
unchanged-baseline candidates byte-for-byte. The 546-file import closure and
six configs stayed exact. Log SHA256 is
`5d90298f7c8c86596d0bd5f84b4208d44eecad660aece5607f5fd41b84f9ed88`.
This does not make the full golden gate green or give all failures one cause.
No golden was regenerated or skipped.

That full run preceded a newly reproduced Stepper focus-semantics correction.
Real Tab focus reached Decrease value while its labelled node lacked focus
flags and a focus action. Four production lines now bind the labelled node to
the existing input focus, separately from focus-ring visibility. The strengthened
Stepper suites pass all 32 cases with exit 0 and done true. Their 219-file import
closure and six configs stayed exact. Log SHA256 is
`749da2da28fc3da81ca430260e40f2ad5692968086b41dfa94d8da529da4f000`.
The original regression and the two fixture-correction logs remain preserved.

Example analysis passed with no issues. Log SHA256 is
`38da3d1037025997c8777cdb5df669fbf0c4917ae735ed50a4437ddf36983950`.
Final root analysis after the Stepper correction also passed with no issues.
Its 587-file scope and six configs stayed exact. Log SHA256 is
`d1ba9c32b0a66a0647767e76843adabe3bb13e69f6db7e17c0205e5a966e1f7b`.

All 66 example tests passed with exit 0 and done true. Their 373-file import
closure and six configs stayed exact. Log SHA256 is
`09d4a7248338b9a3043357e1f2349dcffc11f31be86a95cae2f6ff23f72d9640`.

The current release-web build passed. Its 350-file import closure and six
configs stayed exact. Log SHA256 is
`797fb4cf38f57dd7c15c4d9310a2205bdb5ffa2cf4ea5e5b5c41204c7c278ee6`.
The build reports a missing Cupertino icon-font warning. Glyph painting is
a separate open check.

Native arm64 simulator compilation passed with a command-line iOS 15 target.
The project compatibility floor did not change. Its 350-file import closure
and six configs stayed exact. Log SHA256 is
`f95219f87d39e9c180be7f32fb297176a41ec444fb336c42cdc6e15cc2013533`.
The generic simulator build failed in Flutter's combined-architecture check.
The verbose diagnostic and successful single-architecture build remain separate
records. This is not physical-device, Intel simulator, or iOS 13 proof.

The built app installed and launched on the assigned iPhone Duo simulator.
Changed-widget interaction remains unverified. The search attempt lost its
input focus, and the recovery press did not establish a visible input.
No changed-widget screenshot or native motion acceptance follows from launch.

Hosted Linux CI skips goldens through the existing `BEUI_SKIP_GOLDENS` policy.
Its result cannot close the unskipped local golden gate.

Bulk logs, original frames, and manifests remain outside git under the durable
beui-v3.1.0 task artifact directory. They are not public PR attachments.
The committed unit receipts record earlier focused checks and their limits.
They remain historical records, not claims that all current acceptance gates pass.

## Final review pass

A cross-model review of `792ad82d..f005d0c4c` found two defects. Both are fixed with tests that fail without them.
`ffd6b3b8a` mirrors the Pagination indicator and page movement in right-to-left layouts.
`d0b9ce8a3` keeps AdaptiveStepper steps finite when finite bounds overflow their difference. This defect predates the branch.
Select keeps exact-prefix typeahead, because the source-parity tests require it.

| Run, head `d0b9ce8a3` | Result | Log SHA-256 |
|---|---|---|
| Root analysis, review1 | Exit 0, no issues | `f6f2359e08e47e6e61c8a742d0325fdf57bc0d32c8b5211cd08169c95da5178a` |
| Example analysis, review1 | Exit 0, no issues | `44cf9ab6c9826ddcf67859f115e29eecf618528e1c02d21df15f28d6bf646a5a` |
| Full package suite, all 199 test files, review1 | 2889 passed, 31 golden errors, exit 1 | `4cf82716549a48ca8114efe5014ff62e83c05e49aad29de2718b164e5788e021` |

All 31 errors are golden pixel mismatches. The failing tests write 32 candidate images, all byte-identical to the unchanged-baseline candidates from `835f4396d`.
No golden was changed or skipped.

## Open acceptance gates

The PR was marked ready for merge at the user's request on 2026-11-06. These gates remain open:

- The cause of the 31 baseline golden mismatches on this machine.
- Matched source, unchanged-before, and current-after visual and motion review.
- Accessible PR screenshots and recordings. Local-only paths do not satisfy this gate.
- Native interaction checks and calibrated performance evidence.
- Complete family inventory and variant acceptance.
- Approved six-target audio backend and integration, tracked separately.
- Exact pushed-head review and hosted CI, followed by root integration review.

No family or release PR can merge on focused-test evidence alone.
