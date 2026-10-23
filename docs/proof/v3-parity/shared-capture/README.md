# Shared capture conditions

The gallery preview now paints the existing page background instead of a
40% card-color fill. The isolated visual harness accepts the same opt-in
`previewWidth` query as the gallery. `captureProbe=1` observes the actual demo
constraints and effective Flutter motion preference without changing either.
No theme, font, widget implementation, demo, or original baseline changed.

## Use the shared settings

Use these candidate URLs after building the corresponding entrypoint.

```text
/?slug=tooltip&theme=light&previewWidth=592&captureProbe=1
/visual/?slug=tooltip&theme=light&previewWidth=592&captureProbe=1
```

`previewWidth` is the maximum available inner width in logical pixels. It is
not the viewport, demo width, or frame width. Missing and invalid values retain
normal layout. The existing parser accepts only finite positive numbers.
Narrow parents can deliver less width. Demo width caps remain effective.

At a 1280px viewport, both entrypoints deliver a loose maximum width of 592px.
The gallery frame is still 658px wide, including its padding and border.
At 390px, the isolated harness delivers 294px with its existing 48px outer pad.
The gallery's existing narrow test delivers 284px because its insets differ.
Without `previewWidth`, the isolated harness delivers 1184px at viewport 1280px.
These measurements are constraints, not a claim that every demo fills them.
The Tooltip demo itself measures 264px wide in these runs.

Read `globalThis.__beuiCapture` from the browser. It contains incoming
constraints, the laid-out demo rectangle, background token ARGB,
`disableAnimations`, `platformDisableAnimations`, and `motionOverride`.
The render proxy forwards child constraints without changing them. Observation
is disabled unless `captureProbe=1` is present.

See [recorder usage](RECORDER.md) for action events, reduced-motion config,
effective preference enforcement, and served JavaScript checks.

## Background evidence

The clean source checkout is pinned to
`a76e57c9bbc2837e96420b2610e9c82a3271bb05`. File hashes and the inspected
stage behavior are in [pinned-source.json](pinned-source.json).
Normal source stages are transparent. Expanded stages use `bg-background`.
There is no card-color preview fill in either condition.

The live Tooltip stage is also transparent and measures 592px wide. Its page
background converts to RGB 252/252/252 in light mode and 21/21/21 in dark mode.
Direct samples from retained source and candidate PNGs match those values.
The source and candidate use different sample coordinates inside their own
preview backgrounds. This verifies the wrapper background, not component
placement or pixel parity. No screenshot recoloring or resampling occurred.

## Effective reduced motion

The release browser measurements cover `reduce` and `no-preference` contexts.
Browser `matchMedia`, Flutter platform `disableAnimations`, and the demo's
`MediaQuery.disableAnimations` are all true for `reduce`. All three are false
for `no-preference`. The visual harness also reports true for `reduce`.
`motionOverride` is null throughout. No query override was added because native
propagation works in the installed Flutter 3.47.1 and Chrome 155.0.8059.86 runtime.
Other runtimes must pass the effective-value check before claiming this proof.

## Inspect the recordings

[summary.json](run-20261023-1/summary.json) records background sample pixels,
effective settings, URLs, script fingerprints, frame counts, cadence, and
original screenshot dimensions. The directory retains every original PNG,
timestamp, config, script hash, FFmpeg log, and FFprobe result.

The reduced-motion recordings are
[live light reference](run-20261023-1/reference-light-reduce/capture.mp4),
[light gallery](run-20261023-1/gallery-light-reduce/capture.mp4),
[live dark reference](run-20261023-1/reference-dark-reduce/capture.mp4),
[dark gallery](run-20261023-1/gallery-dark-reduce/capture.mp4), and
[isolated light harness](run-20261023-1/visual-light-reduce/capture.mp4).
The light reference and gallery also have `no-preference` recordings.
Inspected hover frames show the real Top tooltip in all three reduced-motion
light recordings. This is capture feasibility evidence, not a tooltip parity
verdict or an assertion that every intermediate transform matches.

All seven recorded DOM viewports are 1280 by 1000 at DPR 1. All original PNGs
and encoded videos are 1280 by 913. This Chrome capture-height discrepancy is
retained. No image was stretched to make the dimensions agree.
Measured delivered cadence spans 15.02 to 47.90fps, with a worst gap of 74.18ms.
Native 60fps remains unresolved. No duplicate or interpolated frames were added.

The gallery JavaScript SHA-256 is
`daab605ca2d02d6e5ccef7127e938e30229f4288a10bc8a91613625f979683a1`.
The isolated harness JavaScript SHA-256 is
`188fdaf20cb382e42c973e6845d45f837bf0c93b2e5f8d80bf03188a9cb922e8`.
The recorder verifies actual response bytes before the first frame.
The captured build is accurately labeled as base `1b267f6` plus the shared
capture source changes hashed in `run-20261023-1/build-inputs.json`. Its wrapper
source matches this change. The recording predates the recovery dispatcher
cherry-pick and exercises only mouse movement. Its manifests remain unchanged.
The separate recorder fixture tests verify the combined click/key/text and
reduced-motion recorder. Live deployment revision remains unknown.

## Reproduce the proof

Build the gallery and isolated entrypoint from `example/`.

```sh
flutter build web --release --no-pub --output build/shared-capture-gallery
flutter build web --release --no-pub -t lib/visual_harness.dart --base-href /visual/ --output build/shared-capture-gallery/visual
```

Check that 8111 is free, then serve from the repository root. Stop this server
when the capture finishes. Do not use another worker's server.

```sh
lsof -nP -iTCP:8111 -sTCP:LISTEN
python3 -m http.server 8111 --bind 127.0.0.1 --directory example/build/shared-capture-gallery
```

In a second terminal at the repository root, use a new output directory.

```sh
export PARITY_PLAYWRIGHT=/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs
node docs/proof/v3-parity/shared-capture/verify.mjs /absolute/new-shared-capture-run
node docs/proof/v3-parity/shared-capture/summarize.mjs /absolute/new-shared-capture-run
```

`verify.mjs` checks served release hashes before capture, measures nine browser
conditions, and records seven. `summarize.mjs` checks every PNG hash and native
dimension, encoded frame counts, and actual background pixels. Both retain
existing run data. No baseline wrapper patch was applied to `5ec78ac`.

## Verification and remaining failure

The focused Flutter run passes all 20 tests. Its original two failing background assertions
are retained in `tests-before.txt`, and passing results are in `tests-after.txt`.
Both the focused analyzer and full example analyzer report no issues.
Both release builds pass with the existing missing Cupertino-font warning.

The full gallery run reports 22 passing tests and one failure. The unrelated
image-viewer demo loses its 576px cap under a tight 824px parent in
`demo_width_cap_test.dart`. That test directly mounts catalog demos without
the edited preview wrappers. No demo fix is included. The exact assertion and
network-image warnings are retained in `gallery-tests.txt`.

The original recordings, baseline, prior config manifests, and worker files
remain unchanged. This work does not establish exact one-to-one parity.
