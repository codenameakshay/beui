# Tabs underline release evidence

This capture observes the one-pixel underline correction in a real release build. It does not establish exact source parity.
No production files, theme files, font files, or golden baselines changed in this evidence commit.

## Videos and originals

- [Light before and after](videos-native/light-before-after.mp4).
- [Dark before and after](videos-native/dark-before-after.mp4).
- [Live source light](source-light-final/capture.mp4).
- [Live source dark](source-dark-final/capture.mp4).
- [Verification manifest](manifest.json), [file hashes](hashes.json), and [presentation timestamp proof](videos-native/manifest.json).

Every recording retains its original PNGs, request and receipt timestamps, event dispatch intervals, JS response hashes, environment, and decoded-video metadata.
The labeled videos add a 140px caption without scaling the footage. Each labeled part preserves every decoded frame and PTS exactly.
The combined videos contain 527 light frames and 332 dark frames. They concatenate before then after without interpolation, duplicate frames, or cadence normalization.
PNG originals, rather than RGB-to-YUV video conversions, are authoritative for exact color measurements.

## Frozen candidates and endpoints

| Build | Revision | Verified endpoint | Served `main.dart.js` SHA256 |
| --- | --- | --- | --- |
| Before | `a4685504` | `http://127.0.0.1:8111/?slug=tabs&theme=light&color=Blue&previewWidth=592&captureProbe=1` | `cdac2cb6859a5f51a9c82df1e1e2ba8d08185ea329b85517279d929ee272c4db` |
| After | `ce5564d267cc4bb98b258bbf27f4689ee48db8e9` | `http://127.0.0.1:8112/?slug=tabs&theme=light&color=Blue&previewWidth=592&captureProbe=1` | `1b87458ec6040fb267d6d695967e51caaba9a1fc37ac83092e99d1cc288c88fb` |

Both endpoints also passed the dark query. The recorder enforced these hashes against bytes from the actual browser load.
`verify.mjs` fetched both endpoints again and verified the same hashes. These are isolated frozen builds, not a claim about the parent's integrated HEAD.
The servers use separate ports and outputs under `/tmp/beui-tabs-release-dbLua8`. Ports 8108, 8109, and 8110 were untouched.

The build inputs came from `git archive` exports. Build logs, resolved lockfiles, font hashes, and commit-matching input hashes are in `builds/` and `manifest.json`.
Flutter is 3.47.1 stable with Dart 3.13.1. Both builds use the unchanged `visual_harness.dart` and Tabs demo.
The candidate wrapper constrains the preview to 592px and centers the 448px demo. Its probe rectangle is x344, y48, width592, height904.
The effective probe reports `disableAnimations=false`, `platformDisableAnimations=false`, and no motion override in every candidate capture.

## Source correspondence and measured geometry

The live reference is `https://beui.dev/components/motion/tabs`. Its deployment revision is unknown. Every observed JS response hash is retained.
The pinned source correspondence is `a76e57c9bbc2837e96420b2610e9c82a3271bb05`, `components/motion/tabs.tsx`.
Its underline uses `absolute bottom-0 left-0 right-0 h-px bg-primary`.
The Flutter correction changes only `rect.bottom` to `rect.bottom - 1` and removes obsolete comments.

The source uses Geist 500, font-size14px, line-height20px, padding top4px, horizontal12px, bottom10px, and minimum height44px.
Both implementations render 44px triggers. The browser measurements below retain fractional differences instead of rounding them into equality.

| Control | Source width | Candidate semantics width | Source position | Candidate position |
| --- | --- | --- | --- | --- |
| All | 41.109375 | 41.09375 | x376, y795 | x416, y695.5 |
| Open | 59.09375 | 59.078125 | x421.109375, y795 | x461.093933, y695.5 |
| Closed | 69.59375 | 69.578125 | x484.203125, y795 | x524.177795, y695.5 |

The source stage is x304, y320, width592, height559. Both demos are 448px wide.
Page placement and stage height differ. Control-local geometry is the comparison target. No wrapper adjustment hides those differences.

Source paints one fully covered primary pixel at y838, inside the trigger's bottom839.
The candidate row starts on y695.5. Its corrected line spans y738.5 to739.5, so native rasterization covers two rows partially.
At x430, light before has RGBA245/245/245/255 on rows738 and739. After has124/178/230/255 on both rows.
The source line is RGB2/133/247 on a single row in both themes. Candidate colors and half-pixel placement are not exact source matches.

The default native before/after underline changes 84 pixels at x416 through457, y738 through739 in each theme.
The light full-frame diff contains only those 84 pixels. The dark full-frame diff contains407 pixels, including323 outside the underline.
Those additional differences are around the overflow and icon examples. Their cause is unverified. All original frames and pixel deltas remain in the manifest.

## Observed interactions

Each raw candidate recording includes default, Open hover, pointer down, pointer up, pointer exit, End, and ArrowLeft.
It then uses Shift+Tab for keyboard focus entry, followed by Home, End, and ArrowLeft.
The source recordings select the requested theme after hydration, then exercise the same pointer path and immediate End and ArrowLeft.

The source keeps All selected during pointer down, selects Open on release, selects Closed on End, and returns to Open on ArrowLeft.
The native candidate selects Open on pointer release, but pointer input does not give the trigger Flutter keyboard focus.
Immediate End and ArrowLeft therefore leave Open selected. This existing gap occurs before and after the underline fix.
After native keyboard focus entry, Home selects All, End selects Closed, and ArrowLeft selects Open in both builds and both themes.
Candidate keyboard focus paints a filled blue rectangle unlike the source focus treatment. This gap also remains unchanged.

`native-replay.mjs` verifies 20 checkpoints in fresh browser contexts. It enables semantics only after each input sequence and screenshot, then asserts selection.
The separate semantics-enabled replay reports immediate pointer-to-keyboard success because the DOM overlay gives focus to the clicked button.
That replay is diagnostic only. It does not override the native recording or the 20 native-input assertions.

## Cadence and capture limits

| Authoritative recording | Frames | Measured average fps | Largest interval ms |
| --- | --- | --- | --- |
| Source light final | 101 | 19.50 | 90.51 |
| Source dark final | 105 | 19.95 | 60.70 |
| Before light | 342 | 47.41 | 69.45 |
| After light | 185 | 25.82 | 252.19 |
| Before dark | 166 | 23.41 | 183.49 |
| After dark | 166 | 22.78 | 219.21 |

The requested and observed CSS viewport is 1280x1000 at DPR1. Chrome 155.0.8059.86 delivered 1280x913 screenshots through CDP's screenshot backend.
The complete underline and all interactions remain visible. Neither the recorder nor presentation resizes these frames to claim 1000 encoded pixels.
Timestamps describe response receipt. Exposure lies inside each request-response interval. Per-event gaps are in `manifest.json`.
These recordings do not establish native 60fps, matching spring trajectories, or exact fast-motion timing.
Reduced motion was `no-preference`. Reduced-motion behavior was not captured in this followup.

## Preserved attempts and verification

`source-light/` is the first attempt. Its pre-hydration theme click had no effect, so it actually records dark and is not light proof.
`source-light-verified/` and `source-dark-verified/` retain valid but lower-cadence attempts. The `*-final/` runs are authoritative source footage.
The first `videos/` export preserves frame count but rounds PTS. It failed verification and is not the delivered presentation.
`videos-native/` sets the encoder time base explicitly. All four parts have zero measured PTS difference from their input videos.
Earlier observations and configs remain unchanged. The corrected source observations and configs are under `verified/`.

Recorder config tests pass 6/6. The real Chrome recorder fixture passes both motion preferences, native pointer events, input replacement, and Enter submission.
`verify.mjs` verifies every authoritative PNG hash, served candidate JS, effective Flutter probe, native theme pixels, geometry, 20 checkpoints, and presentation frame counts.
The native event crops use original frames whose entire request-response interval follows dispatch and precedes the next event. Their hashes and intervals are retained.
The golden SHA256 remains `e2eb1d6214b68489aea42ba9e16626033b0621d62b0196f073218dac9b08a57d`.
The parent independently reported 35 passing Tabs tests and one preserved golden failure after the fix. Those tests are not browser parity proof.

The documented workflow is `tool/parity_capture.mjs`, screenshot backend, from `shared-capture/RECORDER.md`.
`collect.mjs` creates separate observations and recorder configs. `final-source.mjs` records source after hydration. Each recorder output directory must be new.
`present.mjs` produces labeled videos in a new directory. `verify.mjs` verifies evidence and refreshes the hash manifest while the frozen servers remain available.
The temporary Playwright and Sharp package locations are explicit prerequisites in these scripts. No shared recorder or production source changed.
