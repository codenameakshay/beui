# Candle and volume round four

Implementation base is `a2942181`. Pinned source is `a76e57c9bbc2837e96420b2610e9c82a3271bb05`. The live deployment SHA is unknown.

Owned files are `lib/src/charts/candlestick_chart.dart`, `lib/src/charts/volume_profile.dart`, their two gallery demos, their dedicated tests, and this directory. Shared Tooltip, recorder, font, theme, and all other charts remain parent-owned. Original evidence and golden baselines remain unchanged.

The data shape stays unchanged. Candle inspection resolves a stable candle ID and optional pointer price. Its opacity target has a cancellable index-delayed update. Volume inspection separates the selected bin ID, open state, pointer ownership, and keyboard ownership. Replacement discards removed uncontrolled identities without selecting a neighbor. Tooltip layout uses a chart-owned external anchor with the parent-owned Tooltip.

Throughput checkpoint: two implementation units, each followed by focused tests. Native source, before, and after captures use only port 18114. Static differences and frame cadence remain failures or inconclusive measurements until recorded and reviewed.

The native preview opened, but two snapshot attempts each returned `Preview automation snapshot timed out after 15000ms.` Capture therefore uses the documented unchanged `tool/parity_capture.mjs` fallback. No children, push, PR creation, or merge are authorized. PR26 is linked to this thread.

## Owned implementation

The assigned source differences are implemented. Exact visual parity is not certified. All 56 final static chart comparisons remain nonzero.

| Commit | Owned change |
| --- | --- |
| `528d3e83` | Candle legend palette, spacing, exact price/volume/change formatting, static last-price tag, focus-visible ring, repeated opacity delay, and source touch behavior. |
| `978df1f2` | Volume shared floating Tooltip call, summary grid, hover tint, opacity entrance, and removed-identity behavior. |
| `986d42e1` | Dedicated source regressions and touch-hover guards. |
| `9306882b` | Volume fractional CSS geometry, multiplied alpha, touch release, trailing margin, and empty candle spacing. |
| `3db9e977` | Scrollable volume demo and constrained-view regression. |
| `8f746e8d` | Pointer gap 12px, keyboard gap 8px, and medium-weight tooltip numbers. |
| `a5749867` | Horizontally scaled elliptical volume corners and source outline radius. |
| `13be22c9` | Immediate pending inspector focus application. This alone did not repair native Home after hover. |
| `6566b2e9` | Explicit candle/volume semantic focus, source `followCursor`, and non-focusable volume readout. |
| `b8f4eee3` | Regression uses the active render view's semantics owner without a deprecated API. |

Only these production/demo/test paths change from `a2942181`.

```text
lib/src/charts/candlestick_chart.dart
lib/src/charts/volume_profile.dart
example/lib/demos/candlestick_chart_demo.dart
example/lib/demos/volume_profile_demo.dart
test/charts/candlestick_chart_test.dart
test/charts/volume_profile_test.dart
test/charts/candle_volume_round4_test.dart
test/charts/candle_volume_round4_demo_test.dart
```

The audit inputs are `../../audit/inventory.json` entries `charts/candlestick-chart` and `charts/volume-profile`, plus `../round3/README.md`. The inventory's aggregate unverified verdict is not changed. Pinned component implementations, submodules, preview compositions, and native behavior determine the derived expectations.

## Native focus failure and repair

Fresh click without prior hover passed 12 trials. Hover A, hover B, exit, native click A, exit, and immediate Home failed 12 trials. The selected value stayed at POC. `native-focus-hover-sequence.json` retains that failure.

`native-focus-diagnostic.json` shows chart primary focus on pointer-down and lost focus before pointer-up. Home then bubbles unhandled. `native-focus-diagnostic3.json` identifies the replacement target as focusable, skipped during traversal, and included in semantics. This matches the parent-owned `BeuiOverlay` focus wrapper. It is not a stale Home value or insufficient delay.

`semantic-focus-before-2.log` fails the explicit semantic-focus regression. Binding `Semantics.onFocus` to the inspector fixes that separate accessibility defect. It does not alone fix native hover/click. `native-focus-semantic-after.json` retains 12 failed native trials.

`tooltip-focus-before-3.log` reproduces the readout stealing focus and Home staying on `c`, instead of `a`. The volume call site now wraps its display-only Tooltip in `ExcludeFocus`. No shared Tooltip or overlay implementation changes. `tooltip-focus-after.log` passes all 17 dedicated tests. `native-focus-final-v13.json` passes the original native sequence 12/12, without extra input waits or root keyboard interception.

## Effective artifacts

| Artifact | Revision and actual served JavaScript SHA-256 |
| --- | --- |
| Matched pinned source | `a76e57c9bbc2837e96420b2610e9c82a3271bb05`, `91efa14dca91279a59255519b75086c5b8f37d16eff82f5aa2c425c21253f77e` |
| Final fixture v13 | Production through `6566b2e9`, `78daec8f6ae2b8f145e62583686bac46a17a1b1bbaea2c595db6e64f54007b86` |
| Final gallery v13 | Same production bytes, test-only HEAD `b8f4eee3`, `5681dccb0ea158bfef97d2487b35078a07c7175243ee96ec7a4aebe1977b2890` |

`fixture-v13-inputs.json` and `gallery-v13-inputs.json` hash the actual library, demo, font, and fixture inputs. The fixture build is `/tmp/beui-round4-candle-volume-fixture-after-v13-20261023`. The gallery build is `/tmp/beui-round4-candle-volume-gallery-after-v13-20261023`. Flutter is 3.47.1, Dart 3.13.1, CanvasKit, DPR 1. Browser motion and actual Flutter `disableAnimations` agree in every accepted final capture. No motion override is used.

The source bundle is `/tmp/beui-round4-candle-volume-source-v2-20261023`. `source-inputs.json` and `source-package-lock.json` retain its consumer wrapper and transitive inputs. The pinned checkout stays clean. Live captures remain separately labeled `live-*`; the live deployment revision is unknown.

## Native recording index

Each recording retains its MP4, every native PNG frame, effective event timeline, per-frame hashes, actual served script responses, environment, observations, and SRT captions. The final eight recordings contain 1,535 original frames. Native output is 1280 by 913, from the 1280 by 1000 CSS viewport. No original is resized or interpolated.

| Comparison | Before | Pinned source | Final after |
| --- | --- | --- | --- |
| Candle mouse, keys, update, empty | `before-candle-*` | `source-candle-*` | `after-v13-candle-*` |
| Volume mouse, keys, replacement, empty | `before-volume-*` | `source-volume-*` | `after-v13-volume-*` |
| Candle trusted taps | No matching before tap recording | `source-candle-*-touch` | `after-v13-candle-*-touch` |
| Volume trusted taps | No matching before tap recording | `source-volume-*-touch` | `after-v13-volume-*-touch` |
| Settled mouse, key, touch move/release states | `stills-before-v2-*` | `stills-source-v2-*` | `stills-after-v13-*` |

Every `*` preference includes dark/no-preference and light/reduce. `native-state-review-v13.json` compares all 56 settled accessible values, with zero mismatches. `native-motion-review-v13.json` compares all 52 recorded key/tap observations, with zero mismatches. Native PNGs additionally show the visible focus ring, floating tooltip, hover tint, replacement closure, and touch release. A matching accessible value alone is not a visual verdict.

Flutter semantics activation produces one synthetic zero-coordinate bootstrap click before recording. The observer verifies that exact bootstrap shape separately. Every pointer/key action that establishes the tested sequence is trusted. The initial over-strict observer failure remains in `native-motion-review-v13.log`; `native-motion-review-v13-2.log` explicitly separates the bootstrap from native actions.

Final measured cadence is 30.00 to 51.26fps, with a maximum 90.87ms gap. Short motion timing and native 60fps parity remain inconclusive. `probe_opacity.mjs` and `source-opacity-interruption-probe.log` separately establish the source's interrupted opacity hold and repeated delay. Dedicated tests cover cancellation and reduced-motion retargeting. These do not certify native frame trajectories.

Older `stills-source-*` and `stills-before-*` used a coarse-pointer context. They remain diagnostics, not desktop-hover proof. V9/v10/v12 volume Home claims are superseded by v13. All failed builds, logs, stress trials, and earlier captures remain present. The interim `archive-v13.json` was sealed before the last final capture finished. The final archive seal supersedes its coverage.

## Exact static differences

`pixels-static-v13/metrics.json` compares untouched native RGB at identical coordinates. There is no alignment, scaling, recoloring, or excluded pixel mask. Counts above 1 and 8 are supplementary, not pass thresholds. The candle ROI is 584 by 364. The volume ROI is 584 by 470. The comparison also reports fixed legend, plot, and summary subregions. `comparison-v13.html` labels before, pinned source, after, and absolute differences.

| Resting chart | Before differing pixels | Final differing pixels | Final verdict |
| --- | ---: | ---: | --- |
| Candle dark | 21,244 / 212,576 | 21,829 / 212,576 | FAIL |
| Candle light | 21,863 / 212,576 | 22,421 / 212,576 | FAIL |
| Volume dark | 76,374 / 274,480 | 41,484 / 274,480 | FAIL |
| Volume light | 72,300 / 274,480 | 22,587 / 274,480 | FAIL |

Across all 14 states, final candle dark differences range from 2,155 to 25,287 pixels. Candle light ranges from 5,521 to 25,852. Volume dark ranges from 1,939 to 49,688. Volume light ranges from 1,954 to 33,367. None is zero. Final candle rest is worse than the before image; it is not presented as a pixel improvement.

## Parent-owned follow-up

- Mono rendering is not stable across these artifacts. Final fixture candle text is visibly narrower than the source and the v6 fixture, while the v13 gallery renders mono glyphs. The v6/v13 library manifests show unchanged shared font/theme inputs. Their built FontManifest SHA-256 is the same `94709ae500d3812d4e346edadad1c08c8e845b1f7d00dceef94f2bee2c322c1d`. Geist Mono Regular bytes are the same `7022da390e9b401ea35b722f8ed2376948e70add10954bc798839b4bfe17ef3f`. Both named `Geist Mono` and `monospace` register the same assets. Registration/alias resolution needs parent investigation. The cause is not established by these images. No font/theme file changes here.
- `lib/src/motion/number_ticker.dart:323` still approximates digit width as `fontSize * 0.62`. The pinned source uses `1ch`. At 12px, candidate slots are 7.44px; Geist Mono zero is approximately 7.2px. This affects volume tooltip width and glyph alignment. No shared ticker changes here.
- Shared Tooltip placement does not visibly implement pinned `tooltip/use-position.ts` final DPR rounding. Fractional pointer anchors and collision rounding need parent review. No generic placement changes here.
- The shared overlay remains semantically focusable without a focus trap. The volume's display-only call site now excludes focus. A general overlay/Tooltip correction remains parent-owned.
- The mixed `chart_round2_test.dart` still expects removed `BeuiChartTooltipCard` inline content. It needs a parent-owned floating-tooltip expectation. The existing volume golden fixture also constrains authentic summary content to 420px with Ahem. Neither test nor its baseline is rewritten here.

Remaining bar alpha and raster-edge deltas are measured, not assigned a proven cause. A parent fix must produce a fresh served build and append-only captures. Earlier better-looking frames are not substituted for the final failure.

## Local verification

| Gate | Exact result and evidence |
| --- | --- |
| Focused owned behavior | 37 pass, `behavior-final-v13.log`. |
| Owned implementation/demo/test analyzer | No issues, `analyze-final-v13-2.log`. |
| Native stress | 12/12, `native-focus-final-v13.json`. |
| Native settled states | 56/56 accessible values match, `native-state-review-v13.json`. |
| Native recorded actions | 52/52 accessible observations match, `native-motion-review-v13.json`. |
| Native volume gallery | All three sessions pass native click and Home at widths 1280 and 375. Native wheel scrolling reaches the summary. `gallery-v13-native-5/` retains six labeled states and trusted input logs. |
| Native candle gallery | Pause holds the exact readout for 1.1 seconds. Step changes it. Home and End select first/latest. Both widths pass, `gallery-candle-v13-native/results.json`. |
| Full chart suite | 206 pass, 12 failures, `full-charts-final-v13.log`. Eleven frozen golden cases and the stale mixed tooltip test fail. |
| Chart suite with golden comparison disabled | 216 pass, 2 failures, `behavior-charts-final-v13.log`. The stale mixed tooltip expectation and volume golden fixture overflow still fail. |
| Release fixture and gallery | Both succeed, `build-fixture-after-v13.log`, `build-gallery-after-v13.log`. Existing missing Cupertino icon-font warning remains. |
| Original evidence | All 52 hashes pass, `original52-final-v13.log`. No golden update. |

The focused command excludes golden-named rest tests but does not waive their failures.

Gallery attempts 1 through 4 remain diagnostic failures. The first observer used a nonexistent tab role. Later attempts used an exact slider name absent from gallery DOM semantics, then hit Playwright's DOM-interception check. The final observer uses the observed button/slider bounds and trusted native mouse clicks. It does not dispatch DOM clicks to chart controls. Each session's literal volume and summary visibility must pass after the native action. These observer corrections do not change app or baseline inputs.

`archive-final-v14.json` seals final and superseded media plus capture metadata. `archive-verify-final-v14.log` verifies those bytes, every original frame hash, decoded video frame counts, served JavaScript, and effective motion settings. The Git archive also retains scripts, logs, strict pixel metrics, native gallery images, and source inputs. The interim seal is not the final coverage index.

The final seal verifies 11,710 files, 48 recordings, and 9,077 original frames. These counts include failed and superseded behavioral claims. Integrity does not promote them to passing evidence.

```sh
BEUI_SKIP_GOLDENS=1 flutter test test/charts/candlestick_chart_test.dart test/charts/volume_profile_test.dart test/charts/candle_volume_round4_test.dart test/charts/candle_volume_round4_demo_test.dart --name '^(?!.*rest-state golden)' --reporter expanded
flutter test test/charts --reporter expanded
BEUI_SKIP_GOLDENS=1 flutter test test/charts --reporter expanded
node docs/proof/v3-parity/charts/round4-candle-volume/review_states.mjs after-v13 native-state-review-NEW.json after-v13
python3 docs/proof/v3-parity/charts/round4-candle-volume/pixels.py pixels-NEW --stills --after after-v13 --after-volume after-v13 --before before-v2 --source source-v2
```

Poteto decisions are specific. Model the Domain keeps selected identity separate from tooltip visibility and input ownership. Attack the Premise replaced the failed key-delay theory with a native focus census. Prove It Works rejected passing widget tests when native Home still failed and reports nonzero pixels as failures. The unavailable control/deslop plugin is not claimed. The documented recorder and a manual diff/prose pass are used. Delegation and independent child review are skipped because the user forbids children. No hosted CI, deployment, or exact live revision is claimed.
