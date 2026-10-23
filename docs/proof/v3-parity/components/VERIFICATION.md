# Component verification

Implementation commits are `11ee280` and `8ccb169`. The second commit fixes a
Tooltip input-modality regression found by the full package test run.

## Local checks

- `flutter analyze` passed after the component repairs and after the keyboard
  modality repair.
- The focused component run passed 132 tests with `BEUI_SKIP_GOLDENS=1` before
  the final modality repair.
- The Tooltip and composition-chart regression run passed 38 tests with the
  same existing golden-skip environment variable after the modality repair.
- The example-package card demo run passed two tests. It checks activation
  through both the full card's text and its checkbox, plus the true source URL.
- The first full package run passed 2141 tests and failed one composition-chart
  keyboard-inspection regression. The final repair targets that regression.
- The final full package run at `8ccb169` passed all 2143 tests with
  `BEUI_SKIP_GOLDENS=1`. The chart regression and the new modality test pass.
- The unsuppressed focused golden run passed 119 tests and failed five pixel
  comparisons. The original golden files remain unchanged.

| Golden | Pixel delta | Different pixels |
|---|---:|---:|
| Card | 0.78% | 3744 |
| Breadcrumb | 0.40% | 1928 |
| Alert | 10.85% | 52063 |
| Color selector | 0.25% | 1220 |
| Image viewer | 0.85% | 4067 |

Behavioral success does not waive these visual failures. The existing
`BEUI_SKIP_GOLDENS` switch is only a way to run behavior independently.
No comparator, golden baseline, or comparison threshold changed in this slice.

## Source and capture boundaries

The source checkout revision is `a76e57c9bbc2837e96420b2610e9c82a3271bb05`.
The live deployment revision remains unknown. All 300 original before-video
and capture-metadata records matched `before-sha256.json` after implementation.

The 1440px exploratory measurements in `release-measurements-run2` exposed a
width constraint. The source's 752px inner stage cannot fit inside the
candidate's available stage once the candidate's right rail appears.
Those screenshots are retained as failed matching-width evidence.
The final measurement run uses 1280 by 1000 viewports. Every source route in
this slice measured a 592px preview stage at that viewport. The candidate uses
the separately owned `previewWidth=592` wrapper. It does not modify widget
internals. The original before videos have no wrapper and retain their original
1440 by 1000 dimensions.

The recorder is the recovery worker's shared script. It captures real screenshot
frames and preserves timestamps and hashes. The component script only prepares
route-specific configs and runs that recorder sequentially. Its missing-target
records are coverage gaps, not successful interactions. Dispatching a key does
not assert the visible result. The videos require frame inspection.

The full 28-route inventory includes 223 state and example obligations before
theme expansion. Default-route videos do not cover every install example,
reduced-motion branch, interruption, drag, or keyboard state. No route has an
exact-parity verdict.
