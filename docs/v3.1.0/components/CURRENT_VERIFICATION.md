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

The full root test run, including unchanged goldens, is in progress at this
checkpoint. Example analysis, current release-web compilation, and current
native compilation are separate pending checks. No golden was regenerated.

Bulk logs, original frames, and manifests remain outside git under the durable
beui-v3.1.0 task artifact directory. They are not public PR attachments.
The committed unit receipts record earlier focused checks and their limits.
They remain historical records, not claims that all current acceptance gates pass.

## Open acceptance gates

The branch remains draft until these obligations have evidence:

- Full root and example checks, with every unchanged golden failure classified.
- Matched source, unchanged-before, and current-after visual and motion review.
- Accessible PR screenshots and recordings. Local-only paths do not satisfy this gate.
- Native interaction checks and calibrated performance evidence.
- Complete family inventory and variant acceptance.
- Approved six-target audio backend and integration, tracked separately.
- Exact pushed-head review and hosted CI, followed by root integration review.

No family or release PR can merge on focused-test evidence alone.
