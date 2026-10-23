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
The 20 original failure images are copied unchanged to `golden-failures/`.

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

## Retained failed runs

`release-measurements` and `release-measurements-run2` retain the exploratory
1440px measurements. The first run used a Tooltip-specific stage selector and
did not measure other stages. The second used a broader stage selector but
still missed multi-example routes. `release-measurements-run3` measures all 28
source stages at 1280px. Every measured width is 592px.

The first `release-recordings` attempt passed a DOM role and the DOM's doubled
text content through to the recorder. The recorder interpreted that pair as an
accessible locator. Alert failed with the raw error below. The run and its
`failure.json` remain untouched. The second run passes the measured rectangle
without a locator role. This is a capture-config correction, not a widget or
comparison change.

```text
locator.boundingBox: Timeout 20000ms exceeded.
  - waiting for getByRole('tab', { name: 'SuccessSuccess', exact: true })
```

The second run uses screenshot capture for both implementations. Early runs
measure roughly 12 to 15 FPS. They do not prove 60 FPS or resolve short entry
and exit timing. Each final run retains its own measured cadence and maximum
frame interval. The video dimensions, not the requested viewport dimensions,
are authoritative for crop bounds.

All 74 default-route captures in `release-recordings-run2` completed with exit
code zero. Reference cadence ranges from 9.03 to 20.00 FPS. Candidate cadence
ranges from 18.28 to 59.83 FPS. The largest delivered-frame gaps are 269.52ms
and 617.72ms respectively. None of these ranges establishes native 60 FPS.
Every run's own timeline remains the authority for its gaps.

The final evidence audit rechecked all 300 original baseline records and all
74 final video hashes. It decoded the originals and all 18 labeled change
videos with FFprobe and found no missing or added frames. All 96 video-index
links resolve locally. All 48 pinned source-file hashes still match.
The final `flutter analyze` reports no issues. See `FINAL_AUDIT.md`.
