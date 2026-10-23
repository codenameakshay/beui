# Capture source, before, and after parity evidence

## Fix the three inputs

1. Keep the source checkout at `a76e57c9bbc2837e96420b2610e9c82a3271bb05` clean.
2. Keep the before gallery at `5ec78ac30e1274727ddd185a883346e4d908e6c8` on port 8105.
3. Serve the repaired head on a different port from its own worktree.
4. Record its full SHA, dirty-file manifest, build mode, Flutter version, renderer, browser version, and OS.
5. Use a release or profile web build for final proof.
6. Record any visual difference that only occurs in debug mode separately.
7. Fetch each source page's Markdown and registry install targets.
8. Copy its exact preview data and props into the candidate demo.
9. Use the preview paths in `inventory.json` and the registry's usage paths to locate the canonical demo files.
10. Record their SHA-256 hashes in the capture manifest.

The live site is the visual authority. A pinned local source preview makes scripted data and time repeatable, but does not replace live-site correspondence. When deployed revision cannot be established, preserve the live screenshots and registry digests. Label the deployment SHA unknown. Never assign the local SHA to a live screenshot without evidence.

## Match display and data

1. Set identical CSS viewport dimensions and record the measured viewport.
2. Record screenshot pixel dimensions, device pixel ratio, browser zoom, scroll position, locale, timezone, and text scale.
3. Match source appearance, theme palette, fonts, font weights, and loaded images.
4. Wait for Inter, JetBrains Mono, images, and the renderer to load.
5. Use each source demo's exact dataset, dates, numeric format, units, initial selection, series order, and aspect ratio.
6. Freeze dates and randomness through documented fixture inputs in a separate capture setup.
7. Record every override and keep the live-source reference unchanged.
8. Exclude documentation chrome from the comparison crop.
9. Keep before and after capture conditions identical.

Theme mismatches, different datasets, placeholders, missing controls, and crop aspect mismatches are errors or blockers. They are not reasons to discount a low score. No automatic rescaling, recoloring, blur, masks, or golden replacement is part of this procedure.

## Record an event timeline

1. Load the widget and reset its state before every run.
2. Start recording before the first event.
3. Hold the idle state for 500 milliseconds.
4. Record each event's monotonic timestamp, semantic target, requested value, pointer coordinates, and expected visible state.
5. Enter the target, move between two distinct states, reverse once, and leave the whole target region.
6. Hold the final state for 500 milliseconds after all exits complete.
7. Stop recording and preserve the returned file without transcoding the original.
8. Inspect the file with FFprobe for native cadence, actual frame count, dimensions, and duration.
9. Record at least 60 real frames per second for final short spring or text transitions.
10. If the recorder cannot deliver that cadence, mark fast-motion assessment inconclusive.

A rest screenshot does not prove hover entry. A hover screenshot does not prove exit, focus, or an animated tooltip number. Begin each one-shot capture before the event. Do not wait for the animation to settle before recording it.

For every chart, execute the following sequence:

1. Identify point A and point B by exact datum ID and expected label, date, and value.
2. Enter A and hold through tooltip entrance.
3. Move to B without leaving the plot.
4. Capture ticker characters, sign, decimal places, separators, tooltip anchor, crosshair, and series emphasis through the transition.
5. Move back to A to capture reversal.
6. Leave the plot and verify the tooltip exits and the resting readout returns.
7. Keep keyboard focus in the chart and inspect the next datum after pointer exit.
8. Verify that keyboard inspection remains visible and matches the source value.
9. Repeat after data replacement, empty data, and restoration where the matrix names those states.

For each focusable widget, use Tab to enter from a different control. Use the source's actual arrow, Home, End, Enter, Space, and Escape bindings where applicable. Capture focus-visible independently from pointer focus. For pure display widgets, record keyboard traversal and cite the source's lack of interactive controls. Do not invent a binding to satisfy a checkbox.

For reduced motion, set the source browser's actual `prefers-reduced-motion` and the Flutter gallery's actual `MediaQuery.disableAnimations`. Record both effective values. T3 currently exposes no dedicated reduced-motion control. A generic user-agent or viewport change does not enable it. Capture final-target placement and per-frame geometry separately. Expected static movement is acceptable only with direct no-intermediate-movement, final-target, and opacity-policy measurements. A static motion score alone proves none of these.

## Select the region of interest

1. Measure the widget's bounding rectangle in the source preview iframe and candidate gallery.
2. Add the union of its maximum entry, exit, tooltip, shadow, and pointer-follow extents.
3. Add 8 to 16 pixels of margin and record the exact crop rectangle.
4. Keep the crop fixed throughout the sequence.
5. Use a second tight crop for animated tooltip text or a small indicator.
6. Keep the whole chart crop for crosshair, legend, geometry, and tooltip placement.
7. Compare the same physical crop size at the same pixel ratio.
8. If dimensions differ, fix the display setup instead of stretching either image.

For the existing candidate tooltip enter pair, `460,370,220,100` isolates the left tooltip and its trigger. This example applies only to those 1440 by 900 files. New captures require new measured rectangles. The full viewport diluted its motion energy by about 59 times. A crop must not remove a defect or a missing tooltip merely to improve the score.

## Extract and compare

Use a new output directory for every extraction. The script refuses to replace a directory and refuses to upsample native cadence.

```sh
sh tool/parity_roi.sh source.mp4 source-roi 460 370 220 100 60
sh tool/parity_roi.sh before.mp4 before-roi 460 370 220 100 60
sh tool/parity_roi.sh after.mp4 after-roi 460 370 220 100 60
```

These commands require real 60 FPS input. Existing eight FPS assets require an extraction rate of eight or less and remain insufficient for short-transition timing proof.

For a settled static frame, run a cropped pixel comparison and preserve its raw output. FFmpeg is available even though a static Design Compare endpoint is not exposed.

```sh
ffmpeg -nostdin -i source-roi/frame_000001.png -i after-roi/frame_000001.png \
  -lavfi ssim -f null -
ffmpeg -nostdin -i source-roi/frame_000001.png -i after-roi/frame_000001.png \
  -lavfi psnr -f null -
ffmpeg -nostdin -i source-roi/frame_000001.png -i after-roi/frame_000001.png \
  -filter_complex blend=all_mode=difference -frames:v 1 difference.png
```

Inspect the difference image and the matched crops. Nonzero visual differences are unresolved until the judge explains each difference against the exact-parity requirement. SSIM is diagnostic, not an acceptance threshold. No old overall score is a substitute for this comparison.

Call Design Compare `compare_motion` with the extracted source and after directories. Also compare source with before to establish what changed. Preserve the raw responses and the motion-signature chart when available.

Use equal native sampling cadence and align both sequences on the event timestamp. Match their duration and frame count. Split long recordings into event windows below the tool's default 240-frame limit. Never duplicate or interpolate frames to invent missing detail. Do not select only favorable frames.

Read `motion_status` before the score. `static`, `capture_unreliable`, or a null score means no motion verdict. A high energy score with negative temporal correlation does not prove matched timing. Inspect synchronized frames for onset, overshoot, settling, clipping, text sequence, and exit completion. A seeded or scripted voice level is required for a meaningful orb response comparison. A breathing field's random phase is a separate comparison from its level-response silhouette.

## Index each result

Each record in `evidence.json.captures` uses an `id` from `inventory.json` and an exact `state` from `states.json`. Common states are `rest`, `hover-exit`, `keyboard`, and `reduced-motion`. Each source example also uses `example/<installSlug>/<exampleSlug>`.

The record contains these fields:

- `widgetParts` lists every exercised `Beui*` part. The readable widget index maps parts to their owning route.
- `changes` states the visible or interaction change in plain text.
- `displayMatched` and `dataMatched` record the judge's setup review.
- `reference`, `before`, and `after` each contain `revision`, `url`, `protocol`, `environment`, `roi`, `fps`, `frames`, and `durationMs`.
- Each capture also contains local `video`, `still`, `framesDirectory`, and `events` paths. Paths are relative to the repository or absolute environment-local paths.
- `environment` contains the effective display, input, motion, locale, build, and renderer settings.
- `protocol` identifies the event sequence and datum identities.
- `roi` contains `x`, `y`, `width`, and `height` in screenshot pixels.
- `static.reviewed` and `static.rawResult` record crop-diff review.
- `motion` contains the unmodified Design Compare result. Scores are not invented for unavailable methods.
- `temporalReviewed` records the judge's frame-sequence review.
- `restGeometryReviewed` is required for settled rest records.
- `reducedMotion` records `noIntermediateMovement`, `targetReached`, `opacityPolicyMatched`, and `rawMeasurements` for that state.
- `verdict` is `pass`, `fail`, `inconclusive`, or `blocked`. The judge supplies it after reviewing the artifacts.

Run the following checks:

```sh
NODE_NO_WARNINGS=1 node tool/parity_audit.mjs inventory /tmp/beui-v3-parity-components-source
node tool/parity_audit.mjs reference /tmp/beui-v3-parity-components-source
node tool/parity_audit.mjs assets
node tool/parity_audit.mjs self-test
node tool/parity_audit.mjs check
```

The inventory command writes JSON to stdout and changes no baseline. It requires Node's `stripTypeScriptTypes` support, available in the installed Node 26.12.0. The check returns exit code 1 while evidence is missing. A complete index still requires independent visual review. This script does not certify image fidelity from metadata.

Keep all repaired-family evidence in the consolidated PR #26. Preserve original captures, append new results, and link each failure to its repair or explicit unresolved objection. Do not replace the baseline or open per-family PRs for this audit.
