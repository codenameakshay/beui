# Record inspectable browser transitions

The paired Tooltip recordings in `reference-run2/capture.mp4` and `baseline-run2/capture.mp4` contain real Top, Right, Top, and exit states. Their original PNG frames, event timelines, and FFprobe results are committed beside them. The baseline video was decoded and inspected too. Its Right tooltip is visible in decoded frame 42.

This recovers recording, not parity. There is no repaired-head after capture here. Native 60 FPS is unresolved. The baseline is a debug build, so this pair is not final release proof. See [the measured results](RESULTS.md).

## Run the recorder

Install Playwright outside the repository. Use the installed Chrome executable. No package or implementation change is required.

```sh
npm install --prefix /tmp/beui-parity-capture-runtime playwright-core@1.58.2 --no-audit --no-fund
export PARITY_PLAYWRIGHT=/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs
node tool/parity_capture.mjs docs/proof/v3-parity/capture-recovery/reference.json /tmp/beui-tooltip-reference-new
node tool/parity_capture.mjs docs/proof/v3-parity/capture-recovery/baseline.json /tmp/beui-tooltip-baseline-new
```

Each output directory must be new. Existing directories fail with `EEXIST` before a browser starts. Keep every failed run. Record sequentially when possible to reduce capture contention.

The config contains the URL, viewport, theme, provenance, named pointer targets, and scheduled events. The live reference uses accessible button names. Baseline coordinates came from the rendered 80 by 40 pixel triggers at this viewport. Re-measure coordinates for every other route or layout. Do not reuse Tooltip coordinates for another widget.

Use `backend: "screenshots"` for Flutter CanvasKit. This calls `Page.captureScreenshot` repeatedly with no fixed-rate resampler. Each image retains its request and response timestamps. A screenshot's exact exposure time is unknown inside that interval. The alternative compositor backend calls `Page.startScreencast` with `everyNthFrame: 1` and keeps Chrome's compositor timestamps. Its delivered timestamps can arrive out of order, so encoding sorts by timestamp while preserving original delivery order in the timeline.

Start with the baseline config for a repaired candidate. Change its URL, provenance, and measured targets, then use a fresh output directory. Run each capture from reset. The recorder currently supports pointer movement only. It does not validate an agent submit, edit, approval, or cancellation flow. Those need route-specific actions and observable outcomes.

## Verify pixels and timestamps

```sh
ffprobe -v error -count_frames -show_streams -show_format -of json /tmp/beui-tooltip-baseline-new/capture.mp4
ffmpeg -nostdin -v error -i /tmp/beui-tooltip-baseline-new/capture.mp4 -vf 'select=eq(n\,42)' -frames:v 1 /tmp/beui-tooltip-baseline-frame42-new.png
```

Inspect decoded video frames during entry, transfer, reversal, and exit. Reject a uniform or blank Flutter canvas even when its duration and frame count look reasonable. The recorder's frame-count check detects encoding loss, not missing widget content. An expected-state string in config is a protocol description, not an assertion that the state appeared.

Read `timeline.json`, not just nominal FPS. `measuredFps` uses delivered frames and their elapsed timestamps. `maxIntervalMs` exposes gaps. Repeated PNG hashes during a stationary state are allowed because those are separately captured images. The encoder adds no frames. It uses concat durations, `-fps_mode passthrough`, and lossless H.264 settings. PNGs are the original lossless pixel evidence. The MP4 is a derived, color-converted viewing artifact.

Both paired runs measured a DOM viewport of 1440 by 900 at DPR 1, but Chrome's captured surface was 1440 by 813. This discrepancy is retained, not stretched away. Both videos and their comparison crops have matching physical dimensions. Check the actual output dimensions before copying this setup elsewhere.

## Compare matching crops

```sh
node tool/parity_capture_roi.mjs docs/proof/v3-parity/capture-recovery/reference-run2 docs/proof/v3-parity/capture-recovery/baseline-run2 /tmp/beui-tooltip-wide-new 520:460:420:300 552:296:420:300
node tool/parity_capture_roi.mjs docs/proof/v3-parity/capture-recovery/reference-run2 docs/proof/v3-parity/capture-recovery/baseline-run2 /tmp/beui-tooltip-tight-new 600:472:160:112 632:308:160:112
```

The wide crop includes both anchors and the right-hand tooltip. The tight crop isolates the Top trigger and its tooltip. Keep both. The tight crop must not replace the wide crop's placement evidence.

The extraction tool selects existing original frames on a 100 ms grid relative to the first pointer event's dispatch midpoint. It uses the compositor clock for reference frames and the screenshot request/response midpoint for baseline frames. It rejects reused frames, nearest samples more than 49 ms away, unequal crop dimensions, and out-of-bounds crops. If either side lacks a bin, both sides omit it. `selection.json` retains the omitted bins, selected originals, actual timestamps, and timing uncertainty. These are sparse diagnostic samples, not an exact-timing sequence.

Call Design Compare `compare_motion` with the two resulting frame directories. Read `motion_status` before the score. Preserve the raw response. The current wide and tight raw results are in `tooltip-roi-run1/motion-result.json` and `tooltip-tight-run1/motion-result.json`.

## Preserve originals

Do not overwrite existing captures or the other workers' SHA-256 manifests. Each original PNG has a SHA-256 in its timeline. `media-manifest.json` records the videos and pinned Tooltip source hashes.

All run videos and metadata are committed. Original frame directories for the canonical run2 pair are committed. Supplementary original frames from reference runs 1, 3, and 4 and baseline run3 remain untouched at their existing absolute worktree paths, but are ignored to avoid committing repeated full-viewport PNG sets. They are not required to replay the canonical pair. The independent native desktop probe remains at `/tmp/beui-native-cadence-probe.mkv`; it is not committed because it includes unrelated desktop content.
