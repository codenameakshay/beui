# Preview stage capture condition

`previewWidth` requests the width available to a gallery demo in logical pixels.
It excludes the preview frame's padding and border. It does not resize the
browser, scale the demo, clip overflow, or change a demo's own width cap.

## Capture URL

The gallery launched for this change serves this URL:

`http://127.0.0.1:8103/?slug=expandable-tabs&theme=dark&previewWidth=592`

The expected available inner width is 592px when the shell has enough room.
The preview frame is 658px wide, including 32px padding and a 1px border on
each side. Replace the slug for any other family. The parameter persists
through in-gallery navigation and affects only the Preview tab.

The parameter accepts finite positive numbers. Missing, malformed, zero,
negative, NaN, and infinite values leave the default layout unchanged.
The separate `visual_harness.dart` entrypoint does not read this parameter.
Its existing `pad` parameter does not control the gallery shell.

## Sizing evidence

The source checkout is `/tmp/beui-v3-parity-components-source`, pinned to
`a76e57c9bbc2837e96420b2610e9c82a3271bb05`.
`app/components/[category]/[slug]/page.tsx` uses `PreviewExpandStage` with
`flex`, centered content, and `py-10`. The stage has no explicit horizontal
width setting. `components/app/docs/preview-fullscreen.tsx` passes those
classes through when not expanded. Its width therefore depends on the docs
container. The 592px source measurement comes from the family's reported
capture condition, not a new live-source measurement in this change.

`test/preview_stage_width_test.dart` mounts the real gallery shell with a
`LayoutBuilder` probe in place of a family demo. It measures both incoming
constraints and the laid-out child, with device pixel ratio 1.

- At viewport width 1280px, `previewWidth=592` delivers 592px inside a 658px frame.
- At viewport width 390px, the same request delivers 284px inside a 350px frame.
- At viewport width 1280px, the default delivers 869px inside a 935px frame.
- Invalid `previewWidth=NaN` produces the same default measurements.
- An inner demo capped at 320px still renders at 320px with `previewWidth=592`.

The 935px default figure is the frame width at this tested viewport, not its
inner width. Record viewport dimensions and measured inner width for each
capture rather than treating either figure as viewport-independent.
The width constraints remain loose, so existing demo caps still work.
Narrow viewports use normal layout constraints and can produce less than 592px.

## Baseline provenance

The original Flutter baseline is `5ec78ac`. Its files and existing captures
remain unchanged. It has no `previewWidth` support. Adding the query alone
to that revision does not establish a matched capture condition.

For a matched recapture, apply only this change's four shared-shell files
to a separate disposable copy of `5ec78ac`. Generate the wrapper patch with
the commit SHA returned by this worker:

```sh
git diff 5ec78ac <stage-width-commit> -- example/lib/explorer/explorer_app.dart example/lib/explorer/shell.dart example/lib/explorer/pages.dart example/lib/explorer/widgets.dart
```

Label that capture `5ec78ac + capture-only previewWidth wrapper`.
Record the wrapper commit SHA, patch hash, exact URL, viewport, device pixel
ratio, theme, and measured inner width alongside the new capture.
It is not a pristine baseline. Do not replace or relabel original baseline assets.
Apply the same `previewWidth=592` condition to the candidate capture.
These measurements establish the capture geometry, not widget parity.

## Verification

From `example/`, the following command passes all eight tests:

```sh
flutter test test/preview_stage_width_test.dart test/widget_test.dart --no-pub
```

The focused analyzer command reports no issues:

```sh
flutter analyze lib/explorer/explorer_app.dart lib/explorer/shell.dart lib/explorer/pages.dart lib/explorer/widgets.dart test/preview_stage_width_test.dart --no-pub
```

The web gallery compiles and serves on port 8103. Browser navigation to the
capture URL succeeds, but the browser snapshot times out. No browser screenshot
or live-source geometry proof is claimed here. The measured widths above come
from Flutter layout tests.
