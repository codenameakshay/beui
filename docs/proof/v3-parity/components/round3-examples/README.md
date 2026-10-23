# Button, slider and table example repairs

Exact parity is not certified. This directory retains the original native observations, recordings, failures, served JavaScript, and raw RGB differences. No existing golden changed.

The pinned source is `a76e57c9bbc2837e96420b2610e9c82a3271bb05`. These are isolated executions of its exact preview functions. The live beui.dev deployment revision is unknown. This evidence does not identify the pinned source with the live deployment.

Both fixtures explicitly select Blue in light and dark mode, through source `THEMES.blue` and candidate `BeuiColorTheme.blue`. Blue is not the source's `default` palette. These runs do not certify source-default colors or the integrated gallery's theme selection. Shared theme/default integration remains parent-owned.

## Scope and implementation

The 13 source examples are mapped in [inventory.mjs](inventory.mjs). [report.json](report.json) records the actual checks, failures, capture cadence, and pixel results. [FOOTAGE.md](FOOTAGE.md) links each original before/source/after video. [footage.html](footage.html) labels the three players without changing their frames.

The local implementation commits are:

- `fb88b230` matches both Stateful preview lifecycles, Base/Magnetic variants, and Metallic content padding, reflection extents, gradient direction, drift period, and hover reversal.
- `ade59aeb` matches Inline ownership and PageUp/PageDown behavior, shared slider page steps, immediate pointer-down feedback, transformed Fluid coordinates, and Ruler initial displacement.
- `2af952c5` matches the editable viewport and async columns, restores native header and body keys, and keeps an open table menu reachable. Table handles and entries support native keyboard activation.
- `4935b8de` retains the initial resize/reorder displacement and labels those handles. It also adds a positive empty-state API regression.
- `4162ac76` guards the stepped slider's drag-start callback when disabled. This is a supplemental API repair; the exact source examples are enabled. Earlier native captures retain their earlier served-JS hashes rather than being relabeled as this follow-up.
- `69d0030c` sets the small Metallic preview's Sparkles icon to the source's 14 px. The previous 16 px icon made that control 2 px too wide.
- `6a8ed389c` extends the disabled drag-start guard to Wave and Bubble. Paired enabled/disabled regression tests first reproduce both publishing `10.0` while disabled, then pass after the guard. This is supplemental API proof; the exact source previews remain enabled.

`frozen-head-disabled-rest` captures all 13 examples at `4162ac76`. `guard-final` reruns the exact enabled Stepped preview and its native keys against the pinned source. `frozen-head-metallic-size-rest` captures all 13 examples at `69d0030c`. `metallic-head-light`, `metallic-head-dark`, and `metallic-head-reduce` rerun Metallic against the pinned source after the icon correction. The earlier full matrices remain tied to their original builds in [build-provenance.json](build-provenance.json).

`frozen-head-wave-bubble-guard-rest` captures all 13 examples at `6a8ed389c`. The `slider-guard-head-light`, `slider-guard-head-dark`, and `slider-guard-head-reduce` batches rerun both enabled previews and every source-supported arrow/page/bound key after the guard follow-up.

All 12 final follow-up native flows pass their value and keyboard checks. Wave releases at 85 and Bubble at 89 on both implementations in all three modes. The portable verifier asserts those literal outcomes and recorder exit codes. The 78 corresponding state-image comparisons and 24 first-post-event frame comparisons still have nonzero RGB differences.

No catalog, shared theme/font, Tooltip, engine, or existing recorder file changed. The server uses only port 18120. Its listener was checked before each replacement of this task's own server.

## Observed outcomes

| Exact example | Native observed outcome |
| --- | --- |
| button-metallic/metallic | Three controls. Hover, held press, release, exit, and keyboard states have original PNGs and footage. Painted differences remain. |
| button-base/base | Ten controls cover the source variants, sizes, ripple, and custom tap scale. Original held/released states remain available. |
| button-stateful/stateful | Save reaches disabled Saving, Saved, then idle. Submit reaches disabled Submitting, Failed, then idle. Both source and repaired candidate pass these checks. |
| button-magnetic/magnetic | Three controls use strengths .35, .25, and .5. Follow, held press, exit, and keyboard footage remain available. Exact trajectories are not certified. |
| range-slider-inline/inline | Seed 48. Native drag commits 112. Home/End reach 8/128. PageUp/PageDown reach 128/8. All four arrows follow the source's uneven rounded stops. |
| range-slider/stepped | Seed 40. Drag commits 85. Home/End reach 0/100. Page keys move 50; arrows move 5. |
| range-slider-fluid/fluid | Seed 35. Normal-motion drag commits 84; reduced-motion source drag commits 85. Keys reach bounds and move 10 per page or 1 per arrow. |
| range-slider-wave/wave | Seed 45. Drag commits 85. Bounds and all arrow/page keys have literal outcome checks. |
| range-slider-bubble/bubble | Seed 28. Drag commits 89. Bounds and all arrow/page keys have literal outcome checks. |
| range-slider-ruler/ruler | Seed 72.5. Rightward drag lowers the value. Home/End reach 40/120; pages move 5; arrows move .5. Native momentum cadence remains unapproved. |
| table/data | Name click sorts Ava Cole first; native Enter sorts Zoe Bose first. Row and select-all captions reach 1 and 10,000 selected. Resize and reorder have separate final pointer observations. |
| table-editable/editable | Typing commits immediately. Escape retains the edit; read-only shows it. Rename, column insert/delete, row insert/delete, and Escape menu dismissal run natively. The exact shrinking preview fails before its final deletion and empty recovery. |
| table-async/async | Initial 0/loading, first 20, subsequent End-triggered pages, and 160/All loaded are observed. Source and candidate pass the literal page checks. |

The final Metallic follow-up measures Generate at 97.328125 px in the candidate and 97.34375 px in the source. Before the icon repair, the candidate measured 99.328125 px. The 2 px icon error is removed, but the remaining 0.015625 px geometry difference is not an exact match. All 18 settled/held follow-up comparisons and all nine first-post-release original-frame comparisons still have nonzero RGB differences.

The source previews do not contain disabled controls or controlled-rejection examples. Existing dedicated slider tests cover those APIs. They are supplemental tests, not footage of an invented source preview. The empty-state API regression uses a 240 px viewport and proves deletion plus restoration. It does not certify the shrinking exact editable preview.

## Remaining exact failures

Every nonzero RGB comparison is a failure. The measurement reports include both the whole 1280x1000 observation PNG and the unchanged-coordinate rectangle `[344, 0, 936, 478]`. There is no registration, resizing, mask, or pixel tolerance. Same-named states are compared across separate native runs; they are not synchronized trajectory measurements.

The Data table's browser intrinsic column sizing differs from Flutter's fixed/flex sizing. A 50 px input moved the source resize handle 73.546875 px and the repaired candidate handle 50.375 px in the light diagnostic. The 50 px equality hypothesis fails on both. Reorder does put Email first on both. No screenshot-specific widths were substituted to hide the layout difference.

The editable preview derives total table height from row count. At one row, the 48 px header consumes that height. The last source row input remains in DOM overscan outside the visible viewport; the candidate has no remaining body input. The recorded native flow cannot delete the final row or reach empty recovery. The source failure is `Menu entry Delete row`; the candidate failure is `row hover target`. These are retained, not silently converted to passing steps.

Native60 is not established. Recordings retain actual frame timestamps, original PNGs, per-event dispatch/exposure data, ffprobe output, and variable-frame-rate encodes. No frame interpolation or synthetic 60 fps file exists here. Observation checks and recorder replays are separate runs; a successful dispatch log is not an outcome assertion.

Shared rendering, color, icon, and font effects are not isolated by these residuals. Their ownership stays with the parent. Focused local tests, frozen example captures, the integrated parent head, hosted CI, and live deployment remain separate proof layers.

## Verification and historical failures

The dedicated regression file passes 18 tests at `6a8ed389c`. The demo file passes 4 tests at that head. The existing Slider and Inline files pass 46 tests at that head. Focused Wave/Bubble/test analysis reports no issues at `6a8ed389c`. Button demo analysis reports no issues after the final icon change. The earlier full final analysis also reports no issues. The focused run before the disabled follow-up has 97 passes and two golden failures.

The broad run on `2af952c5` completed with 2,333 passes and 55 golden failures. All 55 failures report pixel differences. It does not establish that unrelated failures predate this task. The focused run reports Metallic at 2,309 differing pixels and Table at 138. The Table difference also occurred before the implementation repairs. Golden originals and failure artifacts are retained under `verification/`; generated masked-difference files from Flutter are archival only and are not the RGB parity method.

Earlier attempts remain immutable:

- `pixels-table-reduce` ran before the final async screenshot existed. `pixels-table-reduce-final` supersedes that premature missing-image result. It does not establish an app defect.
- `baseline` and `native-before-v3` retain the frozen original candidate. Their source fixture v1 lacked font weights and mounted before font readiness. That source geometry is superseded, not canonical.
- The frozen before bundle adds independent example selection around original component behavior. It is not the untouched gallery bundle. `first-reproduction` retains the original-gallery Submit observation; both bundles are archived under `served-js/`.
- Source fixture v2 waits for Geist 400/500/600/700 before mounting. Its input hashes and actual served bundle are retained under `served-js/`.
- `native-source-v4` stopped when Homebrew replaced the running Node executable. Missing recordings from that attempt do not demonstrate component defects.
- Earlier Stateful checks searched for complete unspaced labels during a letter cascade. Flutter exposed spaced letters. Earlier press checks compared semantics rectangles, which do not measure painted scale. These assertions are superseded by native settled-label checks and raw PNG comparisons.
- Early menu probes selected a large aggregate semantics node with the same text as the button. `menu-final-v3` filters actual buttons and confirms open, Escape, Enter reopen, Tab, and Enter insertion on both implementations.
- The chained `slider-guard-head` source command was interrupted after its dark native observations, video, timeline, and recorder exit code 0 had all been written. The reduced-motion source batch then ran independently. Completed originals remain unchanged. This command-level stall does not establish a component defect.

## Verify the archive offline

Use Python 3 and Pillow 12.2.0. No app server, source checkout, browser, or absolute capture path is required for archive verification.

```sh
python3 docs/proof/v3-parity/components/round3-examples/verify.py
python3 docs/proof/v3-parity/components/round3-examples/verify.py --ffprobe
python3 docs/proof/v3-parity/components/round3-examples/verify.py --assert-parity
```

The first command checks every manifest byte, every original-frame hash and all recorded RGB measurements. `--ffprobe` also decodes each video to verify its frame count. `--assert-parity` must exit nonzero while exact pixel failures remain. Archive integrity is not a parity approval.

The verifier also checks each recording's actual application-JS response hash and effective browser/Flutter motion against its config. Historical unfinished recordings are listed separately, without an app-defect inference. Every configured application-JS hash has its original bytes under `served-js/`. Two intermediate candidate bundles were built before their implementation commits. Their recorded config revision labels are not committed-head proof; the build catalog labels them as uncommitted intermediates.

The final pre-seal verification checks 166 videos and 166 actual served-JS/motion configs with no provenance mismatches. It asserts all 12 final native Slider flows and recomputes 880 RGB comparisons. All are nonzero; eight historical missing-state results bring the retained exact failure count to 888. The verifier lists 11 unfinished historical recording configs separately. [verification/archive-verification-slider-guard-preseal.log](verification/archive-verification-slider-guard-preseal.log) preserves that result. [verification/archive-verification-preseal.log](verification/archive-verification-preseal.log) retains the earlier 154-video result. The directory-local ignore exception includes recorder and test logs in the archive. Raw log whitespace remains unchanged.

## Reproduce native observations

Use Flutter 3.47.1/Dart 3.13.1 and Chrome. Capture dependencies were Playwright Core 1.58.2, esbuild 0.28.2, Tailwind/@tailwindcss/cli 4.3.3, and ffmpeg 9.0.2. The source checkout must be at the pinned revision with its lockfile dependencies installed.

```sh
export PARITY_PLAYWRIGHT=/your/runtime/node_modules/playwright-core/index.mjs
export BEUI_BUILD_RUNTIME=/your/runtime
export BEUI_SOURCE=/your/pinned/source
node docs/proof/v3-parity/components/round3-examples/build-source.mjs /new/source/output
cd example
flutter build web --release --no-web-resources-cdn --no-wasm-dry-run --target=../docs/proof/v3-parity/components/round3-examples/candidate.dart
```

Preserve each generated build in a new directory. From the repository root, serve the frozen before/source/after directories with `serve.mjs`. Check port 18120 first. Do not replace another worker's listener.

```sh
node docs/proof/v3-parity/components/round3-examples/serve.mjs /before/build /source/build /after/build
node docs/proof/v3-parity/components/round3-examples/run.mjs after NEW_BATCH light no-preference
node docs/proof/v3-parity/components/round3-examples/menu-keyboard.mjs after NEW_MENU_BATCH light reduce
node docs/proof/v3-parity/components/round3-examples/replay.mjs path/to/record-config.json /new/replay/output
```

`CHROME`, `NODE_BINARY`, and the dependency environment variables replace machine-specific defaults. Replay rejects a changed served-JS hash. Existing capture directories must not be reused or overwritten.

Poteto's Model the Domain kept lifecycle and menu ownership explicit. Build the Lever produced the repeatable capture and verification scripts. Prove It Works and Test Behavior, Not Implementation required literal native outcomes and retained failed measurements instead of approvals from dispatch alone.
