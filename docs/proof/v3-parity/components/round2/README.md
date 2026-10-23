# Round2 component evidence

This is functional and geometry evidence, not an exact-parity approval.
The pinned source is `a76e57c9bbc2837e96420b2610e9c82a3271bb05`.
The live deployment revision is unknown.

## Verified repairs

The implementation covers the Liquid stepper silhouette and 600ms overshoot,
ColorPicker trigger-area morph, Tooltip ownership and composition, selected-ring
press scale, Alert tone and height, Breadcrumb exits and overflow, ImageViewer
zoom and gestures, Combobox source trigger, and DateRange trigger copy.
The later lifecycle repairs preserve controlled ownership, focus return,
clipped zoom, inert exits, custom triggers, reduced-motion loupe behavior,
theme overrides, held-gesture dismissal, and retained-subtree keyboard focus.

The final two repairs came from actual browser failures, not an audit alone.

| Repair | Commit | Observed failure | Verified result |
|---|---|---|---|
| Combobox native editing | `1ba461a9` | Native input stayed read-only after opening. Product insertion left Design studio unchanged. | Always-editable source input accepts Product, filters Playground, and selects Product team. Controlled query remains authoritative. |
| Breadcrumb nonmodal hover | `dc564bd7` | Dismissal barrier covered the hovered trigger and caused exit, close, and reopen cycles. Reduced-motion capture lost Projects. | Grouped outside-pointer regions retain hover, accept the popup route, and dismiss outside. Held Projects released after Escape cannot navigate. |

The original fourteen independent review regressions remain unchanged.
Shared Tabs, chart-owned files, recorder, theme, engine, shell, and catalog were
not edited by these repairs. Alert uses caller-only 12px/16px labels and 6px/12px
trigger padding through the existing Tabs API. Shared Tabs defaults are intact.

## Controlled Tooltip contract

`externalAnchor: GlobalKey` and `anchorLink: LayerLink` accompany the existing
controlled `open` and `onOpenChange`. Both references must identify the same
mounted target. Missing, unmounted, and replaced targets, collision geometry,
repeated open/close, and controlled ownership have focused coverage.
The small API commit is `1dde262a`. Its parent integration has equivalent SHAs.
The chart adapter conversion is integrated separately. Generic Tooltip reopen
is focus-in-only in `7dfd8bd8`, not the old broad keyboard fallback.
The held-mouse fix is `12155d8e`. Touch and stylus long-press remain supported.

## Frozen builds and capture conditions

Every recorder batch checks the served script against the frozen build before
its first frame. Each run retains `config.json`, `environment.json`,
`scripts.json`, `timeline.json`, actual dispatch intervals, and frame hashes.

| Build | JavaScript SHA256 | Used evidence |
|---|---|---|
| `2e2aa803c55dbcec7eba6a0e110565d61dc5daad` | `37b90f6d43ec0b4d2f5ef5235e036a6a8306f5938b49a726b550ce265132ddb2` | Core functional sequences before the held-mouse and final Breadcrumb/Combobox repairs. |
| `12155d8e1fa7776086e6f1b9334fecbf1ccd414e` | `33eb2ec5c3ef34776686a31e58e682ea33e41617a24d17f30e4ae0b471e11d21` | Held-tooltip repair and nine additional new-widget default previews. |
| `55a819a2f531d04837131a6f997547261250c6cb` | `9b01e82b978db8f7837d55ee7ec10dda9e0da6a615bb3836570c92c4b36b6b06` | Final Tooltip controls and intermediate Breadcrumb control metrics. |
| `dc564bd78584f6ba9b3825b3b48ceb557f5a5944` | `dff2693a8194213a63b552ce778f8429c8fe1c753a9f533b57272128a2e2705f` | Final Combobox and Breadcrumb light, dark, and reduced-motion runs. |

Captures use owned port 8110, a 1280x1000 layout viewport, DPR1,
`previewWidth=592`, `color=Blue`, and `captureProbe=1`.
The screenshot backend's encoded video surface is 1280x913. Full observation
PNGs retain the 1280x1000 viewport. Do not infer that omitted bottom pixels
are visible in the video. Source and candidate pages have independent placement.

The recorder is unchanged, SHA256
`2aa405da2051b7a59a3010f7b0e3291108e3c51c65f6e1e76bf73bca120709ca`.
Its local revision `53bfc2c5` is equivalent to parent pointer support `d53695ff`.
The wrapper revision is `69721029`, equivalent to `d831524`.
Actual browser preference and Flutter MediaQuery are recorded, without an
override. Light background is RGB252 and dark background is RGB21.

Older lowercase `color=blue` diagnostics in `measurements-1` are Mono, not Blue
proof. Other diagnostic and failed runs remain at their original paths.
`functional-final` Combobox recordings show the rejected Product query and
must not be called successful search proof. Their later ArrowDown selection
does not prove filtering. `final-repairs` replaces that claim with actual input
and filter assertions. Failed Breadcrumb runs are before proof, not final proof.

## Video and functional coverage

There are 36 labeled before/after videos in [the presentation manifest](presentations/index.json).
They cover nine repaired routes and nine additional new-badged routes, in light
and dark. Before clips retain their original viewport and inventory coverage.
After captions name the actual build and limitations. Presentation adds padding
only, without scaling, masks, interpolation, or synthetic duplicated frames.
The manifest verifies each part and concatenation against decoded frame counts.

[Browser outcomes](verification/browser-outcomes.json) contains 27 asserted
functional sequences across light, dark, and reduced motion. The observation
PNGs replay the same measured coordinate events separately from recording.
Successful event dispatch alone is not a successful outcome.

The nine additional new widgets have default-only footage. Their complete
interaction matrices are not certified here. Those routes are timeline,
collapsible, aspect-ratio, arc-picker, sortable-stack, card, expandable-control,
multi-select, and file-tree. Tooltip is the additional changed, non-new route.

Source/candidate spectrum samples match `#3a60a6` and `#265cbf` for the measured
held and dragged positions. Trigger hex is lowercase. Editable hex remains
uppercase. Raw ColorPicker DOM is preserved in [picker-dom.json](picker-dom.json).
The Flutter engine exposes the range label on an outer semantics node rather
than its inner native input. No named role was fabricated and no engine edit
was made to alter the proof.

## Tests and geometry

- [149 component tests passed](verification/beui-round2-latest-behavior.txt), with goldens disabled.
- [37 DateRange and chart compatibility tests passed](verification/beui-round2-date-chart-compat2.txt), with goldens disabled. These include adapter, composition, and bump behavior with the broad fallback removed.
- [Three owned gallery tests passed](verification/beui-round2-latest-gallery.txt), including ImageViewer width cap, actual-Geist Breadcrumb controls, and DateRange trigger metrics.
- [The final unsuppressed run](verification/beui-round2-final-unsuppressed.txt) has 139 passes and eight golden failures. All eight failure artifact sets are retained. No golden was updated.
- [Final browser assertions](verification/browser-outcomes.json) and original PNG hashes pass. The repeatable verifier is [verify-round2.mjs](verify-round2.mjs).

Actual-Geist measurements retain unscaled source and candidate PNGs and raw DOM
rectangles. [Final control measurements](measurements-final-dc564bd7/measurements.json)
follow the final two fixes. The [earlier complete measurement set](measurements-final-55a819a2/measurements.json)
remains labeled with its actual build.

Measured controls include Tooltip80x40, ImageViewer thumbnails184x230,
DateRange204.28125x36, Breadcrumb ellipsis32x32, forward control480x46,
and ancestor109.390625 versus source109.40625. Alert triggers are28px high.
Combobox visual outer is288x48. Its native semantics rectangle296x54 is not
the visual outer and must not be substituted for that measurement.

## Open proof gates

Exact pixel parity is not established. Eight unchanged golden comparisons fail
for stepper, Alert, Breadcrumb, ColorPicker, ColorSelector, Combobox, ImageViewer,
and DateRange. These are separate from functional behavior checks.

Some candidate footage visibly renders tiny missing-glyph boxes for Lucide
icons. The frozen font request returns200, the manifest names the package
family, and read-only font inspection confirms the subset contains the expected
codepoints and original outlines. The shared rendering cause is unresolved
and was relayed to the parent. These pixels remain visible in the evidence.

Fast-motion parity is inconclusive. Measured cadence across the36 selected
after clips ranges from7.855 to51.204fps, with maximum observed gap1503.922ms.
No native60fps claim is made. Motion curves and durations have code and widget
coverage, but that does not certify native browser timing or frame smoothness.

## Original evidence integrity and rerun

[Original integrity](original-integrity.json) verifies all300 original before
files and all74 original video byte sizes and hashes in the original checkout.
The expected inventories remain unchanged. Original PNG sequences for new
captures remain locally in each `original-frames` directory and are hashed by
their timelines. They are excluded from Git to avoid duplicating the payload.

```sh
node docs/proof/v3-parity/components/round2/verify-round2.mjs
node docs/proof/v3-parity/components/round2/audit-originals.mjs /Users/codenameakshay/.t3/worktrees/beui/t3-48d38279
```

The frame-hash verifier requires the retained local original PNG sequences.
Captures can be reproduced with [record-round2.mjs](record-round2.mjs) and the
unchanged shared recorder after rebuilding and verifying the named frozen build.
No push, PR mutation, or merge was performed by this implementation work.
