# Blocks integration and policy follow-up

This round fixes concrete Card, Feedback, and gallery SVG regressions. It does not establish exact parity across the 19 routes.
The original Card rest SSIM of `0.643388` and recovered motion score of `23.3` remain failed diagnostics.
The original baseline `5ec78ac30e1274727ddd185a883346e4d908e6c8`, its 185 before hashes, and all foreign-build records remain unchanged.

## Implementation and integration fixes

| Change | Source or runtime evidence | Result |
| --- | --- | --- |
| One actionable privacy control | The parent's Tooltip composition produced two accessible names after reveal. The actual semantics tree had an outer state node and a redundant tooltip name. | Card owns one labeled, enabled toggle with a tap action. Decorative child and repeated tooltip text do not add accessible names. Original finders remain strict. |
| SVG failure containment | `SvgPicture.network` with an error builder still leaked invalid-data errors. `flutter_svg` 2.3.0 cache attaches an unhandled success-only derived future. | A gallery-local bytes loader fetches and compiles source SVGs without that cache. The picture error builder retains an empty decorative slot. HTTP errors never enter compilation. |
| Deterministic failure-state test | Parent's full gallery reported 47 passes and one missing failure-slot assertion for invalid HTTP 200. The test used a fixed 100ms delay. | The test pumps real asynchronous work until the actual failure widget appears, with a bounded timeout. No error handler suppresses exceptions. A deferred-response test proves that `pumpAndSettle` alone can finish while loading remains pending. |
| Empty Feedback submit | Pinned `components/motion/feedback-widget.tsx` rejects `message.trim().length === 0` and disables the button. | Empty and whitespace submit are disabled. No invented validation error replaces the source policy. |
| Feedback close policy | Source `close` clears the message. Rejected submission preserves it for retry. | Cancel, Close, Escape, and outside dismissal discard drafts. Rejected messages remain available for retry. `emptyMessage` stays as a documented legacy constructor argument. |
| Independent Card controls | Source `components/motion/card-folder.tsx` puts the folder button behind sibling privacy and optional action controls. | Holding privacy or the optional action no longer presses the whole folder. Noninteractive pocket text still activates the folder behind it. |
| Privacy eye transition | Source uses opacity, scale `0.25` to `1`, CSS blur `4px`, and a 300ms zero-bounce spring. Reduced motion uses a 120ms opacity fade. | The eye keeps incoming and outgoing layers through reversal. It has no initial swap. Normal and reduced paths have direct intermediate-state tests. |
| Disabled and optional action states | Source controls are 40px. Disabled card layers and controls have 50% opacity. Front copy remains opaque. | Disabled controls emit no callbacks. Action hover, press, keyboard activation, and the outside white focus ring are covered. |
| Semantic activation focus | Real browser click followed by Enter initially emitted one action callback. Flutter's semantic tap bypassed the gesture's focus request. | Semantic and physical activation request the same focus node. The fixture now shows two callbacks after click and Enter. |

Native rendering still requests and paints the real 838,281-byte Federal Reserve SVG.
Its regression checks the source 48px slot, 40px content, decoded pixels, and requested URL.
Failed HTTP 400, malformed HTTP 200, and HTTP 503 with valid SVG content retain the slot without an invented icon or error message.
The existing generic width and unbounded-height tests pass without error swallowing.

## Shared Tooltip dependency and held release

The shared Tooltip fix is `12155d8e1fa7776086e6f1b9334fecbf1ccd414e`. It is a dependency, not an owned implementation commit.
Its exact file blob is `54c1fa7a899bd52ddb0e9e89b7858eab3077c425`.
Only a temporary copy was used here. No shared Tooltip, font, theme, or engine edit belongs to this handoff.

The pre-fix Tooltip's mouse long-press recognizer stole privacy release after about 500ms.
The earlier 350ms press test did not cover this failure.
Two new 750ms tests failed before the dependency change with this literal result:

```text
Expected: [true]
  Actual: []
```

Both normal and reduced-motion tests pass with the dependency.
The 46-test Card and Feedback behavioral batch passes too.
Browser assertions on the new served hash observe reveal after release, followed by hide on Enter.
Actual assertion-run hold intervals were 790ms in dark and 791ms in light/reduced motion.
The matched live source uses the same scheduled pointer and keyboard protocol.
These state assertions and decoded samples do not establish an exact trajectory or timing match.

## Missing glyph diagnosis

The failed original remains at `../round2/press-reduced/candidate-dark-reduce`.
Its eye and shell icons are tofu, and its masked monospace digits have incorrect spacing.

`glyph-same-hash` repeats the old recorder config against the exact original served JavaScript hash:

```text
1053446b12eb61b657eee4f2ac55ebc47df0a41261081be8dcd46916a465849f
```

That rerun renders the glyphs correctly without a font or app change.
Direct CDP and Playwright screenshots also render correctly before and after semantic activation.
Their network trace records successful font responses with no request failures.
This rules out a deterministic missing-glyph defect in that JavaScript artifact.

`glyph-induced-font-failure` deliberately aborts Lucide and Geist Mono requests.
Its inspected PNG reproduces the missing icons and compressed masks.
That experiment supports a font-availability mechanism, but the old failed recording has no font response trace.
Its historical trigger remains unproven. This report does not claim an app-font fix or a definite capture-only cause.

`font-observer.mjs` observes actual HTTP font bodies without changing the app or recorder.
Before the first CDP screenshot, it requires HTTP 200 and nonempty Lucide, Geist Mono Regular, and Geist Regular responses.
`glyph-head-ready/font-responses.json` records response hashes and completion times.
The decoded replacement sample visibly contains the eye, shell icons, and spaced masks.
Successful HTTP bodies do not expose CanvasKit's internal font registration. Decoded inspection remains necessary.
`document.fonts.ready` and the recorder's empty DOM font list are not CanvasKit readiness proof.

## Provenance

| Input | Identity |
| --- | --- |
| Pinned source checkout | `a76e57c9bbc2837e96420b2610e9c82a3271bb05` at `/tmp/beui-charts-reference-20261023` |
| Live source | `https://beui.dev`, deployment revision unknown |
| Owned app endpoint | `bdd7ea07`, followed only by test commits `fabdd710` and `86bd7f59` |
| Pre-fix shared prerequisite | Parent Tooltip blob `d12867eac1ed7a24e1708448f079161cebe12482` |
| Updated shared prerequisite | Dependency `12155d8e`, Tooltip blob `54c1fa7a899bd52ddb0e9e89b7858eab3077c425` |
| Final gallery before dependency update | JS SHA-256 `ba6028d3cb2de432fe44fdf17bffe2bae9afdf06dc1ecfda49a567a79b4a3b1d` |
| Final gallery with dependency update | JS SHA-256 `4a569eff30943ab8948631516c5bd4bd505a2dd597a0bb24f2f7052051dba38d` |
| Standalone controls fixture | JS SHA-256 `c9ef53b01a8e4bb85c8216404085959217d5d35bc5d5135ad5cefc8b491d4b8c` |
| Recorder | `d53695ffca9e4c9d1403e75712a9ff8e2ceed8ed`, file SHA-256 `2aa405da2051b7a59a3010f7b0e3291108e3c51c65f6e1e76bf73bca120709ca` |
| Candidate server | Existing Python server on distinct port 8108, serving this worktree's `example/build/web` |

Every batch fetches the served JavaScript before starting.
Every candidate recorder config also checks the script response actually loaded by Chrome before the first captured frame.
Each output directory retains its actual config, script hashes, effective motion probe, original PNGs, event dispatch intervals, and timeline.
The recorder uses its screenshot backend without interpolation.

The gallery URL uses `previewWidth=592&captureProbe=1`.
The wrapper uses source-matched background RGB 21 in dark and 252 in light, from dependency `d831524`.
These wrapper changes are not widget fixes or changes to the original `5ec78ac` baseline.
Requested viewport is 1280 by 1200 at DPR 1. Chrome's encoded capture is 1280 by 1113.
The separate `block_parity_probe.dart` is a 592px behavioral fixture with placeholder card artwork, not the source preview or original wrapper.

## Labeled videos and decoded checks

The viewing edits add a black 64px title band and padding only.
They do not resize original pixels, interpolate frames, or synchronize source and candidate trajectories.
Their manifests check that output frame counts equal the summed inputs.

- [Feedback policy before and after, dark](labeled-head/feedback-policy-dark.mp4).
- [Card privacy before and after, dark](labeled-head/card-privacy-dark.mp4).
- [Source and candidate Feedback, light/reduced](labeled-head/feedback-source-light-reduced.mp4).
- [Source and candidate Card, light/reduced](labeled-head/card-source-light-reduced.mp4).
- [Failed original and font-observed replacement](labeled-head/glyph-readiness.mp4).
- [Optional action, keyboard, disabled controls, and failed SVG fixture, dark](labeled-head/controls-dark.mp4).
- [The same fixture, light/reduced](labeled-head/controls-light-reduced.mp4).
- [750ms privacy release before and after shared dependency, dark](labeled-hold750/privacy-hold750-dark.mp4).
- [750ms privacy release with shared dependency, light/reduced](labeled-hold750/privacy-hold750-light-reduced.mp4).
- [Matched source 750ms privacy release](labeled-hold750/privacy-hold750-source.mp4).

`decoded-head`, `decoded-states`, and `decoded-held` retain exact decoded frame indices and original frame intervals.
Inspected samples show the reopened empty Feedback field, correct glyphs, revealed card number and CVV, independent held action, callback count two, and zero disabled callbacks.
The action keyboard sample shows the white outside focus ring.
The white empty SVG slot remains in the standalone fixture.
These samples establish visible states, not complete motion fidelity.

## Verification gates

With the updated Tooltip dependency:

- `beui-round3-owned-tooltip12155.log` reports 292 passing non-golden tests across 26 explicitly named owned-route files.
- `beui-card-feedback-tooltip12155-behavior.log` reports 46 passing Card and Feedback behavioral tests.
- `beui-gallery-tooltip12155.log` reports 15 focused gallery passes before the final await test repair.
- `beui-round3-gallery-all-after-await.log` reports all 36 tests passing in this worktree's complete gallery.
- `beui-round3-gallery-parallel-after-await.log` reports all 36 tests passing with concurrency 12.
- `beui-round3-analyze-tooltip12155.log` and `beui-round3-example-analyze-await.log` record clean root and example analysis.
- `beui-round3-build-tooltip12155.log` records a successful release build. The existing missing Cupertino font warning remains visible.

The parent's gallery has additional integrated tests.
`beui-parent-gallery-svg-wait-fixed.log` reports its complete gallery passing all 50 tests after integration.
That raw log does not embed an exact Git head. It is local combined-gallery evidence, not an exact-head CI or parity verdict.
`beui-parent-gallery-donut-fixed.log` is the retained 47-pass, one-failure input to the await repair, not a green result.
The intermediate command using `--exclude-tags golden` did not exclude golden tests named by text.
It produced 46 behavioral passes and two golden failures. The corrected non-golden command uses `--name '^(?!.*golden)'`.
No golden baseline changed. The full root suite was not rerun in this round.

`verify.mjs` checks each new original PNG against its timeline, decoded video counts, script responses, effective preferences, and label manifests.
It also rechecks the original 2,710 round1 PNGs, all 6,878 round2 PNGs, and the 185 frozen-before entries without rewriting their reports.
`verification.json` contains the counts, cadence, full effective event protocols, preserved failed assertions, and diagnostic PNG hashes.
The final check verifies 30 new recordings, 4,851 new original PNGs, and 17 labeled videos including seven retained intermediate edits.
`logs/manifest.json` hashes the unedited raw logs.

The source motion requirement overrides generic animation simplification advice.
The [motion review](motion-review.md) retained the source's quarter-scale and blur transition rather than replacing it with a generic fade.
Prove It Works required actual served-response hashes, rendered state assertions, and decoded frame inspection instead of treating passing tests as parity.
No child agent was used. The delegated review steps in skills were skipped under the user's explicit restriction.
The optional `deslop` skill is unavailable in this session, so no such gate is claimed.

## Failed and intermediate attempts

- `policy-before-dark` retains the old tooltip overlay locator interception. `policy-before-recovered-dark` uses measured coordinates for both the assertion and recorder protocols.
- `controls-dark`, `controls-light-reduced`, and their `recovered` attempts retain failed static-text locator assumptions. The diagnostic exposed the real semantic focus-transfer defect too.
- `policy-head-light-reduced` retains a Card assertion attempt that lacked a Flutter probe after its fixed startup delay. The Feedback recording in that batch passed. `policy-head-light-reduced-ready` waits for the actual probe before interaction and passes both flows.
- `policy-after-dark`, `policy-final-dark`, `policy-final-light-reduced`, `glyph-ready-after`, and `glyph-ready-final` retain intermediate builds. The `head` directories use the final owned app endpoint before the shared dependency update.
- `labeled` and `decoded-review` are intermediate viewing artifacts. The old Card label incorrectly said "Material target" even though the pre-round3 implementation already used shared Tooltip. `labeled-head` corrects the label without replacing those files.
- `glyph-induced-font-failure` is intentional fault injection, not a naturally observed historical network failure.
- `hold750-before-dark` intentionally reproduces the cancelled release. It is not successful interaction parity.

## Remaining differences

No route receives an exact-parity pass. The complete example and state obligations in `../scope.json` and the original video index remain open.
Pixel differences, typography, full source motion trajectories, and native 60 FPS remain unproven.
Capture cadence gaps make fast-motion verdicts inconclusive. No frame interpolation fills those gaps.
The parent owns the shared typography discrepancy. No shared font or theme edits were made here.
The shell's old Feedback description still says that it keeps drafts and validates inline. That catalog copy is outside this worker's allowed files.
The standalone action fixture is behavioral proof, not a source screenshot comparison.
Parent-wide Donut and ColorPicker regressions and their repairs are separate work, not owned fixes in this report.

## Owned commits

The integration and policy implementation chain after round2 is:

```text
362b4549 test(blocks): cover integration regressions
2f875910 fix(card): expose one actionable privacy toggle
2b91ea0f fix(demos): contain SVG artwork load failures
6850fd1f test(feedback): pin source draft and submit policy
a43995d0 fix(feedback): reset drafts and disable empty submit
7d9dbc7c test(card): cover controls and privacy transitions
a7f72a15 fix(card): separate controls and animate privacy eye
09c45d4f test(demos): wait for feedback input state
001fd172 fix(card): focus controls on semantic activation
bdd7ea07 test(blocks): add standalone control flow fixture
fabdd710 test(card): cover held privacy release
86bd7f59 test(demos): await SVG failure state
```

The parent already integrated the chain through `bdd7ea07`.
Shared dependency `12155d8e` must not be duplicated as owned work.
No push, PR, or merge was performed.
