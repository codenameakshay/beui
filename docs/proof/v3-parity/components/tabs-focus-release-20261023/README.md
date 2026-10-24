# Tabs native focus release evidence

The native pointer focus defect is repaired in `bd6df4189ebcfee751c453d1ff575b07bb417fbc`.
This evidence does not certify exact source pixel, spring, or timing parity.
The production commit changes only `lib/src/motion/tabs.dart` and dedicated Tabs tests.
This evidence directory adds no production, theme, font, API, layout-default, or golden changes.

## Delivered recordings

- [Light, normal motion, before and after](videos-native/light-no-preference-before-after.mp4).
- [Dark, normal motion, before and after](videos-native/dark-no-preference-before-after.mp4).
- [Light, reduced motion, before and after](videos-native/light-reduce-before-after.mp4).
- [Dark, reduced motion, before and after](videos-native/dark-reduce-before-after.mp4).
- [Live source light](source-light-no-preference/capture.mp4) and [dark](source-dark-no-preference/capture.mp4).
- [Live source reduced-motion light](source-light-reduce/capture.mp4) and [dark](source-dark-reduce/capture.mp4).
- [Verification manifest](manifest.json), [file hashes](hashes.json), and [presentation proof](videos-native/manifest.json).

Original PNGs, frame hashes, request and receipt timestamps, input dispatch intervals, JS hashes, and environments remain beside each raw recording.
The labeled videos add a 140px caption without scaling the footage.
Each labeled part preserves every decoded input frame and PTS, with zero measured timestamp difference.
The joined videos contain 300 light-normal, 372 dark-normal, 362 light-reduced, and 310 dark-reduced frames.
They concatenate before then after without interpolation, duplicated frames, or cadence normalization.
The original PNGs are authoritative for exact RGB measurements.

## Frozen builds and endpoints

| Build | Revision | Verified endpoint | Served `main.dart.js` SHA256 |
| --- | --- | --- | --- |
| Before | `ce5564d267cc4bb98b258bbf27f4689ee48db8e9` | `http://127.0.0.1:8112/?slug=tabs&theme=light&color=Blue&previewWidth=592&captureProbe=1` | `1b87458ec6040fb267d6d695967e51caaba9a1fc37ac83092e99d1cc288c88fb` |
| After | `bd6df4189ebcfee751c453d1ff575b07bb417fbc` | `http://127.0.0.1:8113/?slug=tabs&theme=light&color=Blue&previewWidth=592&captureProbe=1` | `bfea9e04faa0cf53f9fc715445ff36034130a4f1403d08ff0aa73a6218d83863` |

Both endpoints also passed dark and both browser motion preferences.
The recorder enforced JS hashes against response bytes from the actual browser load.
`verify.mjs` fetched both served scripts again and verified their hashes.
These endpoints identify isolated frozen builds, not the parent's integrated HEAD.
The before output remains `/tmp/beui-tabs-release-dbLua8/after-frozen-web`.
The new after output is `/tmp/beui-tabs-focus-release-Vt4CcG/web`.
Port 8113 was free before binding. Ports 8108, 8109, 8110, and the earlier evidence remain untouched.

Build inputs came from separate `git archive` exports.
`builds/` retains build logs and resolved lockfiles.
The manifest verifies commit-matching input hashes for Tabs, the demo, the wrapper, and Geist Medium.
Flutter is 3.47.1 stable with Dart 3.13.1.
Both candidates use the unchanged wrapper, 592px preview, and 448px demo.
The effective probe rectangle is x344, y48, width592, height904.
Both Flutter animation-preference fields equal the requested browser preference. No motion override is active.

## Defect, cause, and correction

The retained build selected the middle tab on native pointer release but did not give its Flutter FocusNode keyboard focus.
Immediate End and ArrowLeft therefore left that middle tab selected.
Enabling semantics before interaction masked this defect by providing a focusable DOM button.

The fix requests the existing trigger FocusNode on pointer down and release.
Pointer down does not select. Release selects, and immediate keyboard input reaches that control.
Existing FocusNodes now expose one traversable tab per control, following selection with a first-tab fallback.
The source control's End and arrow selection semantics remain unchanged.

The filled rectangle came from the component's solid, zero-blur `BoxShadow`, not an extra Material overlay.
The fix replaces that shadow with a non-layout-changing foreground outline using the existing focus-ring token.
Pointer activation suppresses the keyboard outline. Keyboard input restores it, and blur clears pointer focus tracking.
This local tracking accounts for Flutter's traditional highlight mode remaining active after mouse input.

## Source correspondence and limits

The pinned correspondence is `a76e57c9bbc2837e96420b2610e9c82a3271bb05`, `components/motion/tabs.tsx`.
The live reference is `https://beui.dev/components/motion/tabs`. Its deployment revision is unknown.
All observed live JS response hashes remain in each source recording's `scripts.json`.
The pinned source uses native buttons, one roving tab stop, and native pointer focus.
Its underline has no filled focus background or shadow. Pill and segment specify `outline-none`.

The live source observations cover all three variants, both themes, and both motion preferences.
Pointer activation followed by End selects the last tab. ArrowLeft returns to the middle tab.
Each observed source control has one tab stop and keyboard focus on the selected trigger.
Focused underline uses a browser `auto 1px` outline, zero outline offset, square corners, transparent background, and no shadow.
The live pill and segment observations have no outline, a transparent trigger background, and no shadow.

Flutter deliberately retains an accessible 2px outline in every variant.
Its pill, segment, and underline radii are 9999, 6, and 0 respectively.
This outline differs from source focus pixels, especially where source suppresses outlines. It is not an exact-parity claim.
The source uses Geist 500, 14px text, and a 20px line box. No font or padding changed in this task.
The retained source/candidate geometry remains different in fractional widths, placement, stage height, and colors.
The source underline is 44px high with widths 41.109375, 59.09375, and 69.59375.
Candidate widths are 41.09375, 59.078125, and 69.578125 at y695.5, also 44px high.
The half-pixel candidate origin still spreads the 1px underline over two raster rows. That gap is outside this fix.

## Native outcome assertions and paint

`native-checkpoints-reverse/results.json` contains 72 authoritative fresh-context checkpoints.
They cover before and after, light and dark, both motion preferences, all three variants, and three input sequences.
Native pointer activation followed by End leaves the middle tab selected before the fix and selects the last tab after it.
The subsequent ArrowLeft returns to the middle tab after the fix. Keyboard-only End selects the last tab in both builds.

Every screenshot and native input sequence precedes semantics activation.
The retained active-element HTML has no semantics descendants before observation.
Only then does the observer enable semantics and assert the resulting selection.
The scripts never focus semantic buttons before the native sequence.
Keyboard-only pill entry uses one Tab. Segment entry uses seven reverse Tabs before and three after; underline uses one reverse Tab.
Each preparation key has a 100ms wait. The different segment counts reflect the old multiple-tab-stop behavior and intervening controls.

The original and paced forward-Tab attempts remain under `native-checkpoints/` and `native-checkpoints-paced/`.
Their segment setup did not reach that control, and their assertions failed. They are not authoritative results.
The unscoped source-locator attempt remains under `source-observations/`.
`source-observations-scoped/` scopes the preview stage and contains all 12 successful source cases.
`native-crops/` retains original-pixel event and keyboard-focus crops. The manifest records sample pixels without resampling.
At x535, y700, the focused underline interior changes from RGB127/182/234 to RGB252/252/252 in light mode.
In dark mode it changes from RGB58/97/146 to RGB21/21/21. Both motion preferences produce the same sampled colors.
The verifier asserts these native pixels and unchanged before/after trigger rectangles across all variants and motion preferences.

## Cadence and verification

| Recording | Frames | Average fps | Largest interval ms |
| --- | --- | --- | --- |
| Source light normal | 76 | 15.00 | 74.36 |
| Source dark normal | 76 | 15.00 | 72.03 |
| Source light reduced | 143 | 28.65 | 53.15 |
| Source dark reduced | 143 | 28.45 | 60.72 |
| Before light normal | 127 | 31.52 | 39.85 |
| After light normal | 173 | 43.23 | 77.31 |
| Before dark normal | 132 | 32.86 | 39.78 |
| After dark normal | 240 | 60.06 | 23.17 |
| Before light reduced | 240 | 60.00 | 20.86 |
| After light reduced | 122 | 30.21 | 45.13 |
| Before dark reduced | 172 | 42.68 | 65.75 |
| After dark reduced | 138 | 34.21 | 44.54 |

The CSS viewport is 1280x1000 at DPR1.
The recorder screenshot backend delivered native 1280x913 PNGs and video. Direct checkpoint screenshots are 1280x1000.
All Tabs controls remain visible. No output is resized to imply a different native resolution.
Source theme selection occurs after hydration as the first recorded action. Settled native pixels verify the requested theme.
Frame exposure lies within each request-response interval. The manifest retains per-event gaps and dispatch delays.
Average fps does not establish native 60fps, matching spring trajectories, or fast-motion parity.

The corrected baseline run failed all 30 new focus tests. The fixed run passed all 30.
All 65 non-golden Tabs tests pass. The complete focused run reports 65 passes and one preserved rest-state golden failure.
Focused analysis and formatting pass. Test logs remain in `tests/`.
The two broad demo checks fail on both this build and the retained baseline with NetworkImage HTTP400 errors.
Those checks are not green caller proof.
The golden remains unchanged with SHA256 `e2eb1d6214b68489aea42ba9e16626033b0621d62b0196f073218dac9b08a57d`.
This focus correction does not explain away or approve that existing golden mismatch.

The documented capture workflow is `tool/parity_capture.mjs` from `shared-capture/RECORDER.md`.
`capture.mjs` records new directories; `observe.mjs native-checkpoints-reverse` and `source.mjs source-observations-scoped` require new output names on rerun.
`present.mjs` generates labeled videos and verifies frame counts and timestamps.
`verify.mjs` verifies original hashes, live endpoints, effective probes, native outcomes, build inputs, and the preserved golden.
The scripts require the explicit temporary Playwright and Sharp paths plus Chrome and ffmpeg.
