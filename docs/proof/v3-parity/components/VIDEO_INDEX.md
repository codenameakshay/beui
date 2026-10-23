# Component video index

All 28 required routes are listed. A video is not a parity verdict. These are default previews, not all 223 state and example obligations.

The source checkout is `a76e57c9bbc2837e96420b2610e9c82a3271bb05`. The live deployment SHA is unknown. The repaired release is `8ccb169`.

Every video uses real captured frames. Cadence and maximum gaps are in the neighboring `timeline.json`. No frame interpolation is used.

| Route | Audit new badge | Repaired light | Repaired dark | Reference light, dark | Verdict | Coverage limit |
|---|---|---|---|---|---|---|
| timeline | yes | [video](release-recordings-run2/candidate-light-timeline/capture.mp4) | [video](release-recordings-run2/candidate-dark-timeline/capture.mp4) | [video](release-recordings-run2/reference-light-timeline/capture.mp4), [video](release-recordings-run2/reference-dark-timeline/capture.mp4) | Inconclusive | Default preview only |
| alert | yes | [video](release-recordings-run2/candidate-light-alert/capture.mp4) | [video](release-recordings-run2/candidate-dark-alert/capture.mp4) | [video](release-recordings-run2/reference-light-alert/capture.mp4), [video](release-recordings-run2/reference-dark-alert/capture.mp4) | Known mismatch or failed visual gate | Tone colors and height trajectory remain unmatched. Existing golden comparison fails. Default preview only |
| collapsible | yes | [video](release-recordings-run2/candidate-light-collapsible/capture.mp4) | [video](release-recordings-run2/candidate-dark-collapsible/capture.mp4) | missing, missing | Inconclusive | Default preview only |
| aspect-ratio | yes | [video](release-recordings-run2/candidate-light-aspect-ratio/capture.mp4) | [video](release-recordings-run2/candidate-dark-aspect-ratio/capture.mp4) | missing, missing | Inconclusive | Default preview only |
| arc-picker | yes | [video](release-recordings-run2/candidate-light-arc-picker/capture.mp4) | [video](release-recordings-run2/candidate-dark-arc-picker/capture.mp4) | [video](release-recordings-run2/reference-light-arc-picker/capture.mp4), [video](release-recordings-run2/reference-dark-arc-picker/capture.mp4) | Inconclusive | Default preview only |
| sortable-stack | yes | [video](release-recordings-run2/candidate-light-sortable-stack/capture.mp4) | [video](release-recordings-run2/candidate-dark-sortable-stack/capture.mp4) | missing, missing | Inconclusive | Default preview only |
| image-viewer | yes | [video](release-recordings-run2/candidate-light-image-viewer/capture.mp4) | [video](release-recordings-run2/candidate-dark-image-viewer/capture.mp4) | [video](release-recordings-run2/reference-light-image-viewer/capture.mp4), [video](release-recordings-run2/reference-dark-image-viewer/capture.mp4) | Known mismatch or failed visual gate | Existing golden comparison fails. Modal zoom, pan, swipe, and focus sequences remain unverified. Default preview only |
| date-range-picker | yes | [video](release-recordings-run2/candidate-light-date-range-picker/capture.mp4) | [video](release-recordings-run2/candidate-dark-date-range-picker/capture.mp4) | missing, missing | Known mismatch or failed visual gate | Trigger includes weekdays and omits the year, unlike the reference. Default preview only |
| card | yes | [video](release-recordings-run2/candidate-light-card/capture.mp4) | [video](release-recordings-run2/candidate-dark-card/capture.mp4) | [video](release-recordings-run2/reference-light-card/capture.mp4), [video](release-recordings-run2/reference-dark-card/capture.mp4) | Known mismatch or failed visual gate | Existing golden comparison fails. Reference pixel parity remains unverified. Default preview only |
| color-picker | yes | [video](release-recordings-run2/candidate-light-color-picker/capture.mp4) | [video](release-recordings-run2/candidate-dark-color-picker/capture.mp4) | missing, missing | Known mismatch or failed visual gate | Trigger-to-area morph is absent. Default preview only |
| color-selector | yes | [video](release-recordings-run2/candidate-light-color-selector/capture.mp4) | [video](release-recordings-run2/candidate-dark-color-selector/capture.mp4) | [video](release-recordings-run2/reference-light-color-selector/capture.mp4), [video](release-recordings-run2/reference-dark-color-selector/capture.mp4) | Known mismatch or failed visual gate | Selected ring does not share the swatch press scale. Existing golden comparison fails. Default preview only |
| breadcrumb | yes | [video](release-recordings-run2/candidate-light-breadcrumb/capture.mp4) | [video](release-recordings-run2/candidate-dark-breadcrumb/capture.mp4) | [video](release-recordings-run2/reference-light-breadcrumb/capture.mp4), [video](release-recordings-run2/reference-dark-breadcrumb/capture.mp4) | Known mismatch or failed visual gate | Item exit retention and ellipsis morph remain unmatched. Existing golden comparison fails. Default preview only |
| button | no | [video](release-recordings-run2/candidate-light-button/capture.mp4) | [video](release-recordings-run2/candidate-dark-button/capture.mp4) | missing, missing | Inconclusive | Default preview only |
| expandable-control | yes | [video](release-recordings-run2/candidate-light-expandable-control/capture.mp4) | [video](release-recordings-run2/candidate-dark-expandable-control/capture.mp4) | missing, missing | Inconclusive | Default preview only |
| adaptive-stepper | yes | [video](release-recordings-run2/candidate-light-adaptive-stepper/capture.mp4) | [video](release-recordings-run2/candidate-dark-adaptive-stepper/capture.mp4) | missing, missing | Known mismatch or failed visual gate | Liquid blur/contrast silhouette and 600ms overshooting geometry are absent. Default preview only |
| tabs | no | [video](release-recordings-run2/candidate-light-tabs/capture.mp4) | [video](release-recordings-run2/candidate-dark-tabs/capture.mp4) | [video](release-recordings-run2/reference-light-tabs/capture.mp4), [video](release-recordings-run2/reference-dark-tabs/capture.mp4) | Inconclusive | Default preview only |
| input | no | [video](release-recordings-run2/candidate-light-input/capture.mp4) | [video](release-recordings-run2/candidate-dark-input/capture.mp4) | missing, missing | Inconclusive | Default preview only |
| combobox | yes | [video](release-recordings-run2/candidate-light-combobox/capture.mp4) | [video](release-recordings-run2/candidate-dark-combobox/capture.mp4) | missing, missing | Known mismatch or failed visual gate | Workspace label, 48px trigger, and true 28px icon marks differ. Planned search target was missing. Missing planned targets: Search workspaces |
| multi-select | yes | [video](release-recordings-run2/candidate-light-multi-select/capture.mp4) | [video](release-recordings-run2/candidate-dark-multi-select/capture.mp4) | missing, missing | Inconclusive | Default preview only |
| shared-layout-bg | no | [video](release-recordings-run2/candidate-light-shared-layout-bg/capture.mp4) | [video](release-recordings-run2/candidate-dark-shared-layout-bg/capture.mp4) | missing, missing | Inconclusive | Missing planned targets: /^Drafts/ |
| animated-sidebar | no | [video](release-recordings-run2/candidate-light-animated-sidebar/capture.mp4) | [video](release-recordings-run2/candidate-dark-animated-sidebar/capture.mp4) | missing, missing | Inconclusive | Default preview only |
| file-tree | yes | [video](release-recordings-run2/candidate-light-file-tree/capture.mp4) | [video](release-recordings-run2/candidate-dark-file-tree/capture.mp4) | missing, missing | Inconclusive | Default preview only |
| dock | no | [video](release-recordings-run2/candidate-light-dock/capture.mp4) | [video](release-recordings-run2/candidate-dark-dock/capture.mp4) | missing, missing | Inconclusive | Default preview only |
| tooltip | no | [video](release-recordings-run2/candidate-light-tooltip/capture.mp4) | [video](release-recordings-run2/candidate-dark-tooltip/capture.mp4) | [video](release-recordings-run2/reference-light-tooltip/capture.mp4), [video](release-recordings-run2/reference-dark-tooltip/capture.mp4) | Known mismatch or failed visual gate | Failed pixel and temporal comparison, gallery focus mismatch, incomplete composition and animated text. Default preview only |
| text-animation | no | [video](release-recordings-run2/candidate-light-text-animation/capture.mp4) | [video](release-recordings-run2/candidate-dark-text-animation/capture.mp4) | missing, missing | Inconclusive | Default preview only |
| number | no | [video](release-recordings-run2/candidate-light-number/capture.mp4) | [video](release-recordings-run2/candidate-dark-number/capture.mp4) | missing, missing | Inconclusive | Default preview only |
| range-slider | no | [video](release-recordings-run2/candidate-light-range-slider/capture.mp4) | [video](release-recordings-run2/candidate-dark-range-slider/capture.mp4) | missing, missing | Inconclusive | Default preview only |
| table | no | [video](release-recordings-run2/candidate-light-table/capture.mp4) | [video](release-recordings-run2/candidate-dark-table/capture.mp4) | missing, missing | Inconclusive | Default preview only |

## Labeled before and after videos

These are presentation copies. They preserve original image dimensions inside a padded frame. The captions label the unmatched original baseline width.

- [tooltip, light](change-videos/tooltip-light-before-after.mp4). Immediate keyboard reveal, touch toggle, pointer grace, overlapping arrow, and source scale/fade timing.
- [tooltip, dark](change-videos/tooltip-dark-before-after.mp4). Immediate keyboard reveal, touch toggle, pointer grace, overlapping arrow, and source scale/fade timing.
- [timeline, light](change-videos/timeline-light-before-after.mp4). Replace invented media with the real source chart data, SVG/CSS tiles, theme colors, and captions.
- [timeline, dark](change-videos/timeline-dark-before-after.mp4). Replace invented media with the real source chart data, SVG/CSS tiles, theme colors, and captions.
- [alert, light](change-videos/alert-light-before-after.mp4). Use four source variants, upward entry/exit without scale, settled initial mount, and retained exiting icons.
- [alert, dark](change-videos/alert-dark-before-after.mp4). Use four source variants, upward entry/exit without scale, settled initial mount, and retained exiting icons.
- [color-selector, light](change-videos/color-selector-light-before-after.mp4). Restore the vertical label, low selection arc, press spring, disabled choices, and radio keyboard behavior.
- [color-selector, dark](change-videos/color-selector-dark-before-after.mp4). Restore the vertical label, low selection arc, press spring, disabled choices, and radio keyboard behavior.
- [arc-picker, light](change-videos/arc-picker-light-before-after.mp4). Expand bracket spacing by 6px and compress height by 8% during drag and wheel activity.
- [arc-picker, dark](change-videos/arc-picker-dark-before-after.mp4). Expand bracket spacing by 6px and compress height by 8% during drag and wheel activity.
- [tabs, light](change-videos/tabs-light-before-after.mp4). Use the pinned source indicator spring. The blocks worker owns overflow and panel-layout corrections.
- [tabs, dark](change-videos/tabs-dark-before-after.mp4). Use the pinned source indicator spring. The blocks worker owns overflow and panel-layout corrections.
- [card, light](change-videos/card-light-before-after.mp4). Restore full-card checkbox activation, source spacing and copy, transparent muted border, and the true Studio media card.
- [card, dark](change-videos/card-dark-before-after.mp4). Restore full-card checkbox activation, source spacing and copy, transparent muted border, and the true Studio media card.
- [breadcrumb, light](change-videos/breadcrumb-light-before-after.mp4). Restore source width, spacing, forward navigation row, link metrics, and current-page focus restoration.
- [breadcrumb, dark](change-videos/breadcrumb-dark-before-after.mp4). Restore source width, spacing, forward navigation row, link metrics, and current-page focus restoration.
- [image-viewer, light](change-videos/image-viewer-light-before-after.mp4). Restore the exact photos, equal-width gallery columns, source copy, and press scale. Remove invented hover effects.
- [image-viewer, dark](change-videos/image-viewer-dark-before-after.mp4). Restore the exact photos, equal-width gallery columns, source copy, and press scale. Remove invented hover effects.

## Tooltip keyboard attempts

These videos expose failed gallery focus parity. After clicking Top, source Tab focuses Left. Candidate Tab starts at the header logo. See `MOTION_REVIEW.md`.

- [reference, light](tooltip-keyboard-recordings/reference-light-tooltip/capture.mp4).
- [reference, dark](tooltip-keyboard-recordings/reference-dark-tooltip/capture.mp4).
- [candidate, light](tooltip-keyboard-recordings/candidate-light-tooltip/capture.mp4).
- [candidate, dark](tooltip-keyboard-recordings/candidate-dark-tooltip/capture.mp4).

## Evidence limits

- Original before files remain unchanged. Their hashes are in `before-sha256.json`.
- Card, breadcrumb, and image-viewer before clips are static inventory recordings. Their captions state that limit.
- Native 60 FPS is unresolved. The observed cadence cannot settle short transition timing.
- The requested layout viewport is 1280 by 1000. The recorded surface is 1280 by 913. Long demos are vertically cropped in the videos. The full measurement PNGs remain available.
- Tooltip light reference and repaired original PNGs are committed. Other original PNGs remain locally at the exact run directories and are hashed by their timelines.
- Additional examples, reduced-motion branches, complete drag flows, focus traps, and interruption sequences remain incomplete.
- The five unsuppressed golden failures remain open. See `VERIFICATION.md`.
