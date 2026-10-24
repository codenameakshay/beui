# Component capture status

No route in this slice has an exact-parity verdict. The independent audit at
`fe9213f` remains the scope authority. `inventory.json` records all 28 required
component routes and 223 state/example obligations before theme expansion.
The text-animation and number routes coordinate with the blocks worker.

The final default-route run contains 74 original videos, with 56 repaired
candidate videos and 18 live-reference videos. There are 18 labeled change
videos and four separate failed Tooltip keyboard-parity attempts.
[VIDEO_INDEX.md](VIDEO_INDEX.md) links every route and presentation video.
[FINAL_AUDIT.md](FINAL_AUDIT.md) records the final integrity checks.

## Provenance

- Pristine component baseline is `5ec78ac30e1274727ddd185a883346e4d908e6c8`.
- The reference checkout is `/tmp/beui-v3-parity-components-source` at
  `a76e57c9bbc2837e96420b2610e9c82a3271bb05`.
- Live reference URLs use `https://beui.dev/components/motion/<slug>`.
  The live deployment SHA is unknown. The checkout SHA does not establish it.
- Baseline recordings used a release web-server build on port 8102. It remained
  compiled at the pristine baseline while source fixes were in progress.
- The capture viewport is 1440 by 1000 at device pixel ratio 1, with dark/light
  color schemes and `color=blue` on the candidate. These conditions do not prove
  that the live reference's effective palette, fonts, or dimensions matched.
- The source's tooltip preview uses a 12px horizontal gap, 20px vertical gap,
  and 32px instruction gap. The baseline candidate used 16px, 16px, and 48px.

## Original recordings

All originals remain under this directory without replacement or transcoding.
`before-sha256.json` hashes all 150 video files and their 150 capture records.

| Directory | Recorded content | Evidentiary limit |
|---|---|---|
| `before/` | Live reference and baseline candidate, 23 route names in both themes | Exploratory. Some route mappings and chosen targets were wrong. These are not motion success. |
| `before-verified/` | Corrected baseline candidate routes in both themes | Flutter semantics were enabled before readiness. Most action lists are empty. Static inventory only. |
| `before-interactions/` | Baseline tooltip, timeline, alert, color-selector, arc-picker, and tabs in both themes | Actual semantic targets and pointer actions are recorded. Native video is 25 FPS, not the audit's required 60 FPS. No exact timing verdict. |

For example, `before-interactions/candidate/dark/tooltip/recording.webm`
is VP8, 1440 by 1000, 25 FPS, and 9.44 seconds. Its SHA-256 is
`32e2c4262f5960aafbb376d645158f071f1ab7d5fba8da655e42f131bc45cf01`.
Each `capture.json` holds the actual labels, coordinates, URL, and actions.
The exploratory script is frozen in `capture.mjs`. It does not record a complete
monotonic event timeline or all required state reversals.

The `before/` directory and most `before-verified/` captures remain local and
excluded from Git. Their hashes are committed. The card, breadcrumb, and
image-viewer static originals in both themes are committed because they are
inputs to the labeled change videos. The six-route interaction originals are
also committed unchanged. No ignored exploratory original was deleted.

## T3 browser failures

`preview_status` and `preview_open` were called before using a fallback.
Owned reference tab was `tab_2_de45f4e8-31fc-4722-b9f5-f0b871f95dbb`.
Owned candidate tab was `tab_8_de45f4e8-31fc-4722-b9f5-f0b871f95dbb`.
Navigation and evaluation worked. Repeated snapshot and recording failures were:

```text
Preview automation snapshot timed out after 15000ms.
Preview automation recordingStart timed out after 15000ms.
No preview automation host is available for snapshot in environment e23d8eea-cfe5-4e10-8c25-ad814f8c088e. The server-owned browser may be starting or reconnecting. Retry preview_status, then call preview_open if no tab is available. If it remains unavailable, report the browser connection failure.
```

The announced fallback used installed Google Chrome through local Playwright.
Its recorder produced real video at 25 FPS. It cannot certify short spring or
tooltip-text timing. A dedicated capture-recovery worker now owns reliable
recording. This slice does not duplicate that worker's recorder infrastructure.

## Shared width setup

Shared commit `c119a9f3801f06d0bef7a0a344ed57a6c6fa4cc5` was cherry-picked locally
as `685b076`. It is not owned component work and must not be integrated twice.
It adds the opt-in `previewWidth` condition. Its README is one directory above
under `stage-width/README.md`.

Original videos above predate that wrapper. Do not relabel them as matched-width
captures. A new before capture needs a separately labeled pristine-baseline copy
with only the capture wrapper applied. Measure each live source preview before
choosing its candidate `previewWidth`; 592px is not a universal widget width.

## Open proof gates

- Measure reference and candidate regions per route and example. The explorer
  stage-width option only changes constraints, not proof of matching geometry.
- Capture reference, wrapped baseline, and repaired head with the same event
  protocol, exact data, theme, fonts, viewport, and effective reduced motion.
- Keep source assets unchanged. A failed photo request is a blocker, not a
  reason to substitute a different photo or discount the difference.
- Record every new/changed route, each named install example, and every public
  part in the audit. The existing six-route videos do not discharge that scope.
- Capture real 60 FPS and inspect frame cadence before short-motion review.
- Run cropped pixel differences and Design Compare motion on event-aligned
  sequences. `static` and `capture_unreliable` do not pass.
- The release-recording run now includes 56 repaired default-route videos and
  18 reference videos. The video index links the labeled presentation copies
  separately from the original recordings.
