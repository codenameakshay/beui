# Measured capture results

## Paired Tooltip capture

Canonical inputs are `reference-run2` and `baseline-run2`. Both videos decode at 1440 by 813. Both browsers used a measured 1440 by 900 CSS viewport, DPR 1, light appearance, en-US, Asia/Kolkata, no reduced motion, and Chrome 155.0.8059.86. No screenshot was resized or recolored.

The source was the live `https://beui.dev/components/motion/tooltip` page. Its deployment SHA is unknown. The local source clone remains pinned to `a76e57c9bbc2837e96420b2610e9c82a3271bb05`. The preview hash is `35e18f30efb482a138064b49a5fdb1cc50894122ec517b255c1f85940c552072`. The component hash is `05aa29e1cac3ac96d2ea5f1320e48cc65f905b26ccee8044971d6a0318c776b4`. These hashes identify local source, not deployment provenance.

Port 8105 serves checkout `bf4f49b753170f2874497609731b1613b1bdaebd`. Its `git diff 5ec78ac -- lib example/lib` was empty and its working tree was clean. The implementation therefore matches baseline `5ec78ac30e1274727ddd185a883346e4d908e6c8` for this gallery route. Its runtime bootstrap advertised `compileTarget: dartdevc` and `renderer: canvaskit`. Flutter was 3.47.1, Dart 3.13.1, engine revision `5d531788691ec3404cac0cee66ead4007b177363`. The OS was macOS Darwin 27.0.0 arm64.

Both demos use Top, Left, Right, and Bottom, 80 by 40 pixel triggers, arrowed tooltips, and the literal content `More context`. No dates, random data, or fixtures were overridden. Source trigger gaps differ from the baseline's gaps. That is an observed layout difference, not permission to stretch either crop. This setup has matched data and appearance, but it does not establish exact layout parity.

Reference run2 contains 205 decoded frames over a 3986.493 ms first-to-last timestamp span. Its measured cadence is 51.173 FPS, median gap 16.692 ms, maximum gap 234.456 ms, and 20 deliveries needed timestamp reordering. Baseline run2 contains 81 decoded frames over 4021.778 ms. Its measured screenshot cadence is 19.892 FPS, median gap 46.446 ms, and maximum gap 265.799 ms. Baseline has 23 distinct full-viewport PNG hashes across 81 separate captures. Reference has 205 distinct hashes, partly because unrelated documentation chrome animates.

The baseline's original frames 25, 42, and 74 were inspected. They show Top's tooltip, Right's tooltip, and exit respectively. MP4 decoded frame 42 also shows the right-hand tooltip. The reference's original frame 50 shows Top's tooltip. The cropped sequences preserve entry, transfer away from Top, reversal, and exit. This is actual widget content rather than a near-uniform Flutter canvas.

The protocol scheduled Top at 600 ms, Right at 1500 ms, Top at 2400 ms, and exit at 3300 ms. Both timelines include actual dispatch bounds. Capture starts before these events and continues for 800 ms after exit. These are pointer states only. Keyboard, reduced motion, additional Tooltip examples, repaired-head capture, and full-route obligations remain outside this result.

## Cropped Design Compare

Both crops contain 31 distinct selected frames per side. Grid bins at relative 300, 500, 1100, 1200, and 2000 ms were omitted because at least one side lacked a nearby unused frame. Actual exposure uncertainty and omitted bins prevent a short-transition timing verdict.

The 420 by 300 crop returned `motion_status: static` and `motion_score: null`. Its reference energy was 0.00043, candidate energy 0.00061, and correlation 0.35844. The correct verdict is inconclusive.

The 160 by 112 Top-tooltip crop returned `motion_status: compared`, `motion_score: 59.2`, reference energy 0.00187, candidate energy 0.00316, and correlation 0.31875. The smaller crop detects real motion signal. This is not a pass. The score and low correlation do not certify equal geometry, timing, springs, placement, or content behavior. The wide crop remains available to inspect the Right target.

## Failed and supplementary runs

The supplied T3 failures were `Preview automation recordingStart timed out after 15000ms.`, `Preview automation client server-browser disconnected during recordingStart.`, and `No preview automation host is available for snapshot in environment e23d8eea-cfe5-4e10-8c25-ad814f8c088e.` The supplied CUA failure was `Browser is not available: iab`. This task used the authorized direct Chrome fallback; it did not repair T3 transport.

Baseline run1 had fewer than two compositor frames at validation and failed `No usable compositor timestamps`. Its failure record contains one frame, and two original PNGs ultimately reached disk because of the late-delivery race. Its first original PNG was inspected and was blank white. It produced no usable transition video. The screenshot backend then captured the same CanvasKit route. This isolates a recorder-path problem, but does not prove the underlying cause of Chrome's missing compositor transitions. Other workers reported near-static Flutter content inside otherwise valid Playwright WebM; those videos need their own decoded-pixel checks.

Reference run3 saved 218 encoded frames but received another frame after the stop/encode boundary, causing `Encoded frame count differs from delivered frame count`. The late-listener race was removed. Reference run4 then completed with 223 encoded frames, 54.615 measured FPS, and a 183.930 ms maximum gap. Baseline run3 repeated successfully with 93 encoded frames, 22.654 measured FPS, and a 1002.574 ms maximum gap. The repeat is not better motion proof just because average FPS rose.

The native AVFoundation command requested 60 FPS and produced a real desktop video. It decoded 79 frames over a 1.983 second container duration, about 39.8 frames per second. FFprobe reported `r_frame_rate: 60/1` and `avg_frame_rate: 30000/1`; neither describes its observed delivered count. The raw warnings included `Configuration of video device failed, falling back to default.` and `Selected pixel format (yuv420p) is not supported by the input device.` It fell back to UYVY and completed. Native 60 FPS is therefore unproven, not unavailable by assertion.

No frame interpolation, `fps=60`, duplicate-frame insertion, or favorable-frame-only acceptance was used. No implementation, PR, existing proof, or other worker's original recording was changed.

The later shared-width wrapper commit was not applied in this checkout. These baseline captures use the real explorer, not `visual_harness.dart`. They have no `previewWidth` query parameter and no modified stage wrapper. Equal physical crop sizes do not establish equal stage or widget layout. Repaired-head captures using a new wrapper need explicit new provenance and fresh runs; they must not replace these originals.

## Tooling decisions and checks

Model the Domain shaped the config and timeline records instead of route-specific recorder forks. Prove It Works required decoded widget pixels, native timestamps, frame-count checks, and real cropped comparisons rather than recorder success alone. The how/architect work was performed locally because the user explicitly forbade children. The chosen design preserves raw PNGs and derives VFR video; a fixed-25-FPS recorder would hide delivery cadence. Native whole-desktop capture also worked, but its measured cadence and unrelated desktop content made it unsuitable as the canonical pair.

Syntax checks passed for both new tools. Reusing an output path failed with `EEXIST`. An out-of-bounds ROI failed with `Crop exceeds original PNG dimensions`. The final capture tool was exercised by successful reference run4 and screenshot baseline run3. No independent child review ran. The poteto-mode `deslop` dependency is not installed, so a local scoped diff and comment check replaced it. No comments were added to the tools. No package tests were needed because no Dart implementation changed.
