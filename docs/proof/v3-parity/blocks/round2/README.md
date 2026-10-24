# Blocks round2 evidence

## Verdict

Exact visual and motion parity still fails. No route receives a certification.
The implementation fixes specific source-backed defects. The original Card Folder SSIM `0.643388` and recovered motion score `23.3` remain failures.
No score, screenshot dispatch, passing widget test, or config value replaces the missing proof.

The owned implementation commits are `82f12dbe002f3f588c97d7730592d49ae4dc3319`, `997292260409b270fed1a8cec35ac1b1e05e3778` and `e5930c376a1f1d54d542e623677049faef6a2b69`.
The second commit fixes the SVG sizing defect discovered in actual recording review.
The third isolates the source button's press transform from the front pocket and optional action.
The next evidence commit contains only block evidence and documentation.
There was no push, PR creation, merge, or golden update.

## Integration boundary

Only the owned implementation and round2 evidence commits need integration.
Two prerequisite cherry-picks already exist in the parent and must not be applied twice.

| Local prerequisite | Parent equivalent | Purpose |
| --- | --- | --- |
| `03687b296a54c5b6ac53d74e6beaf79d57f15b53` | `065a4d2` | Restore the round1 evidence that was absent from this local base. |
| `21faa8bad761750b6a9fe0277e29199ced535e75` | `d831524e86ecb1703362b1dccd149325f05c50cc` | Use the parent's shared wrapper and effective-motion probe. |

No shared font, theme, engine, shell, app, catalog, or barrel implementation was authored here.
The shared wrapper change is an unmodified prerequisite, not an owned widget fix.

## Source-backed fixes

The source checkout is `/tmp/beui-charts-reference-20261023` at `a76e57c9bbc2837e96420b2610e9c82a3271bb05`.
Live beui.dev supplies the reference pixels. Its deployment revision is unknown.

| Surface | Source and observed defect | Implemented change |
| --- | --- | --- |
| Card artwork | `components/previews/blocks/card-folder.preview.tsx` specifies CSS 135-degree and farthest-corner radial gradients. The previous radial glow was absent. | Compute the CSS gradient endpoints, 78%/8% radial center and 32% transparent stop. Match the chip's gradient stops, thirds, side contacts and relative corners. |
| Card pocket | `components/motion/card-folder.tsx` defines 5% insets, 16px vertical padding, metadata spacing and baseline alignment. | Match these dimensions, text sizes, card aspect ratio, card-relative lift and foreground/10 borders. Expiry artwork remains static. CVV has reveal/mask keys and direction. |
| Card privacy | Material Tooltip was the wrong primitive. The source separates privacy activation from opening. | Use the shared `BeuiTooltip` as requested. Separate privacy semantics and preserve independent activation. Normal and reduced-motion hover and keyboard tests pass. |
| Card focus | A pointer click did not give the folder keyboard control. The source is a native button. | Request folder focus on pointer activation. A click followed by Enter produces `[true, false]`. Paint a 2px ring beyond a 4px gap. |
| Card held press | The source `motion.button` contains only the back and card. The port scaled the front pocket and optional action with them. | Scale the full-root back/card layer and its focus ring only. Leave the pocket and action as stationary siblings. Normal and reduced-motion tests assert held geometry, independent actions, privacy and release followed by Enter. |
| Native SVG | The source rates icon is an actual Wikimedia SVG. `Image.network` cannot decode that format on native Flutter. Its 1x1 intrinsic viewBox also shrinks inside loose constraints. | Use `SvgPicture.network` and fill the source artwork slot. Preserve the raster image strategy. Add the unchanged 838,281-byte source SVG fixture, native decoding, and actual 48px slot and 40px content assertions. |
| Digit Swap | `components/motion/digit-swap.tsx` uses actual `1ch`, `.7ch` spaces and `Array.from` glyphs. The port estimated widths and split surrogate pairs. | Measure the active zero glyph, respect text scaling and iterate Unicode runes. Preserve the source's suffix-index quirk and the round1 motion/stagger repairs. |
| Feedback | The source preview leaves sentiment off. The error view exposes an independent retry button. | Remove the extra sentiment UI. Prevent the live-region container from merging the retry button's name with error copy. Retry resubmits the original message and reaches success. |
| Search Chips | `components/previews/blocks/morphing-search-chips.preview.tsx` uses six translucent gradients and a full two-row grid. | Remove the extra outer inset, restore the gradient pairs and opacity, and size cells to fill the two rows. At a 592px stage, cells measure 178 by 197 with 12px gaps. |

The SVG dependency is a gallery dependency and a root dev dependency for existing root tests that import gallery demos.
It is not a new published library runtime dependency. The fixture parser reports unsupported metadata elements in the raw test log.
The native test paints real decoded SVG bytes. It is not a simulator or physical-device application recording.

## Build and capture provenance

The final served `main.dart.js` SHA-256 is `1053446b12eb61b657eee4f2ac55ebc47df0a41261081be8dcd46916a465849f`.
The final release contains the code committed as `e5930c3`, plus the parent-owned `d831524` wrapper.
The native SVG release and held-press before captures use `e3bf35755216290ce0691d866fbddd66cb31529ae7476fb715e56ed7ba2402ee` at `9972922`.
The earlier shared-probe release hash is `542e923cd875c1834eca60c68e0ca8a6f508740307cc3bc24ad619430265ead7`.
Its card, feedback and chips implementations are unchanged by the later SVG-only fix.
Earlier batches retain their own different script hashes and complete code diffs.

The owned server uses `127.0.0.1:8108`. No other worker's port was used.
Every batch hashes the served script before any recording. New combined-recorder candidate runs also enforce the actual page response hash before the first frame.
The recorder path and its SHA-256 remain in each config.

The initial recorder was the parent's click/key/text recovery in `t3-6e9ab891`.
After the parent supplied the tested combined recorder, new batches use `t3-655688e6/tool/parity_capture.mjs`.
The shared recorder source was not edited here.
`run.mjs` and `flow-check.mjs` provide route protocols and assertions, not a replacement recorder.
The recorder contract is the parent's `shared-capture/RECORDER.md` at `a88d982`.
Held-press batches use the parent's pointer recorder at `d53695ffca9e4c9d1403e75712a9ff8e2ceed8ed` from `t3-f7137276`.
Its exact file SHA-256 is `2aa405da2051b7a59a3010f7b0e3291108e3c51c65f6e1e76bf73bca120709ca`.
`press-check.mjs` records measured upper-card targets, a real left down, a 2px held move, left up and Enter.
Effective button defaults, target coordinates and actual dispatch intervals remain in every timeline.

All recordings use the `screenshots` backend. Original request and response timestamps, PNGs, hashes and encoding counts remain available.
Exposure time is unknown inside each request-response interval. Cadence gaps remain inconclusive for fast motion.
No frames were interpolated, duplicated or resized.

The initial captures request 1280 by 900. Their CDP PNGs are 1280 by 813.
The combined-recorder flows request 1280 by 1200. Their PNGs are 1280 by 1113.
The secondary captures request 1280 by 1800. Their actual dimensions remain in each timeline and probe.
These discrepancies are not normalized away.

Both old and new candidates use `previewWidth=592`.
The new `d831524` wrapper paints the source background and publishes the effective Flutter settings when `captureProbe=1` is present.
It does not change the original `5ec78ac30e1274727ddd185a883346e4d908e6c8` baseline.
The new configs label that wrapper. Viewing edits label their different viewports and wrappers.

## Flow assertions and recordings

| Evidence | Actual asserted flow |
| --- | --- |
| `flows-normal` | Card reveal, mask, pointer open and Enter close, in dark and light. Search Chips typing, Enter-to-add and Escape, in dark and light. Source recordings use the same protocols. |
| `flows-final-feedback` | Open, enter a literal message, submit, observe rejection, activate the independently named retry button and observe success. Source and candidate pass in dark and light. |
| `flows-reduced` | Card, feedback and chips flows pass on source and candidate in dark mode. Browser preference and both Flutter motion values are observed and true. No override is present. |
| `after-secondary` | Tall candidate recordings expose the rates SVG, all number examples, additional text examples, wheel/bracket composition and trade ticket. Their coverage is not an all-example visual approval. |
| `after-svg-final` | Replacement dark and light listing captures show the rates seal at its actual source slot size. The earlier dot remains a failed sizing observation. |
| `press-before` | Source and candidate dark/light held upper-card press, release to open and Enter to close. The candidate privacy control shrinks from 40px to 38.4px and moves about 6.91px horizontally. Source stays fixed. |
| `press-after` | The same source/candidate geometry and event protocol in dark and light. Candidate privacy bounds stay 40px with exactly zero displacement, matching the source assertions. |
| `press-reduced` | Source and candidate dark held protocol passes with actual Flutter reduced motion. One recorded candidate run visibly loses icon glyphs. Its separate assertion screenshots render them. This rendering failure remains open. |

The combined recorder verifies `requireFlutterProbe: true` for candidates.
Their actual `MediaQuery.disableAnimations`, platform accessibility value, browser preference, 592px constraint and background token remain in `environment.json`.
Normal runs report false motion values. Reduced runs report true motion values and `motionOverride: null`.
Source runs record browser preference only. They do not have a Flutter probe.

Flow assertions run separately from recording and do not certify the recording's visible state.
`frame-review-final.json` selects untouched originals with request-response intervals for manual inspection.
Those selected frames, not dispatch success alone, support the visible-state observations.
`press-frame-review.json` selects actual held, released-open and keyboard-closed originals for all ten press recordings.
[Manual frame review](manual-review.md) records what was actually seen and the reduced-run glyph failure.

The press-only fix leaves both full dark and light rest PNGs byte-identical to their before screenshots.
This narrow regression result does not change any source parity verdict.

## Image and motion results

| Diagnostic | Before | After | Result |
| --- | --- | --- | --- |
| Round1 original card rest | Original result retained | `0.643388` | Failed parity. |
| Round1 recovered card motion | Original result retained | `23.3` | Failed parity. Sparse capture is not timing proof. |
| Round2 dark card, pre-wrapper | `0.711085` | `0.806077` | Nonzero difference. Failed parity. |
| Round2 light card, pre-wrapper | `0.704531` | `0.806116` | Nonzero difference. Failed parity. |
| Round2 dark card, shared wrapper | `0.711107` | `0.811485` | Nonzero difference. Failed parity. |
| Round2 light card, shared wrapper | `0.704531` | `0.808448` | Nonzero difference. Failed parity. |

These round2 crops use a newly documented origin and a frozen round1 implementation, not the pristine task baseline.
They do not supersede the original baseline comparison or permit direct score comparison with `0.643388`.
Each is a native 416 by 340 interaction crop with no masks or resampling.
Origins use integer floors of measured card bounds. Half-pixel and other fractional remainders remain explicit in `result.json`.
The surrounding original stage backgrounds remain in the crops.

`compare-card` contains the pre-wrapper comparison.
`compare-card-shared` contains the new shared-wrapper comparison.
The font difference remains visible. Parent font work is separate.
No new motion score replaces the existing failed result. All recording cadence remains insufficient for the native 60fps gate.

## Labeled viewing videos

`labeled-final/manifest.json` names every final input, label, hash and decoded frame count.
The earlier `labeled` set remains supplementary and predates the SVG sizing repair.
The output frame count must equal the sum of input frame counts.
The title band and black padding are the only pixel additions.
These are sequential viewing edits, not synchronized comparisons.

- [Card artwork, privacy and keyboard](labeled-final/card-folder.mp4).
- [Card shared-tooltip hover](labeled-final/card-tooltip.mp4).
- [Feedback default and retry](labeled-final/feedback-widget.mp4).
- [Search Chips backdrop and flow](labeled-final/morphing-search-chips.mp4).
- [Digit metrics and number examples](labeled-final/number.mp4).
- [Native SVG artwork](labeled-final/prediction-market-card.mp4).
- [Native SVG failed sizing and repair](labeled-final/svg-sizing.mp4).
- [Held press in dark mode](labeled-press/card-held-press-dark.mp4).
- [Held press in light mode](labeled-press/card-held-press-light.mp4).

The two `labeled-press` edits retain the same viewport, wrapper, recorder and event protocol on both sides.
Their output frame counts are 279 and 273, exactly the respective sums of input frame counts.
`labeled-review` and `labeled-press-review` retain decoded inspection frames, not replacement originals.

The pristine baseline videos remain at their original round1 paths and in their original labeled viewing edits.
The new clips label their before input as round1, not as `5ec78ac`.
The SVG sizing clip instead labels both inputs as round2 with the same viewport and wrapper.

## Tests and local gates

- `checks-press-final/owned-tests.log` reports 277 passing non-golden tests across 26 explicit files at `e5930c3`. `commands.json` records the exact arguments and implementation head.
- `checks-press-final/example-tests.log` reports 10 passing native-engine demo tests, including real slot sizing after decode.
- `checks-press-final/root-analysis.log` and `checks-press-final/example-analysis.log` report no issues.
- `logs/critical-press-final.log` reports 30 passing focused market and native-width tab tests.
- `logs/release-press-final.log` reports a successful final release build. The existing missing Cupertino font warning remains.
- `logs/full-tests-press-final.log` reports 2,124 passes and 48 golden failures. There are no non-golden failures in that run.
- `logs/press-red.log` preserves the valid stationary-pocket regression failure. `logs/press-green-final.log` reports all 16 card behavioral tests passing.

The preceding `checks-final` and SVG-final logs remain their own earlier gates at `9972922`, with 275 owned passes and 2,122 full-suite passes respectively.

The critical regressions retain payout-to-CTA Tab order, pointer Lakers then Enter callbacks twice with `yes`, the 2px ring with 2px offset, and 128/170/280/528 tab constraints.
No baseline or golden was regenerated.
Compared with the retained round1 full-suite log, the additional failing names are the Digit Swap, Candlestick and Volume Profile goldens.
The chart implementations were not edited here. Those chart differences are not diagnosed by this slice.

Earlier raw runs include 266 passes, a wallet run that accidentally included its golden, two root compile failures before the SVG dev dependency, and a semantics-matcher development failure.
They are not the final gate. The raw failures remain separately labeled in `logs/`.

## Route obligations that remain open

Every row still owes zero-diff images, complete matching source examples, intermediate trajectories and native-cadence proof.
The following table lists specific remaining work, not certification.

| Required route | Round2 evidence added | Concrete remaining work |
| --- | --- | --- |
| Card Folder | Source gradient/chip geometry, privacy tooltip, focus regression, source button-only held press, paired themes, effective reduced flow. | Source eye scale/blur transition, disabled visuals, optional-action visual flow, stable icon rendering and zero-diff font/layout. |
| Morphing Tabs | Existing keyboard, focus and four-width regressions retained. | Drag reorder, close policies, all examples and paired transitions. |
| Prediction Market Card | Real native SVG decode and tall listing recording. Existing callback/focus regressions retained. | Native app/device image proof, complete bookmark/outcome/payout flows and exact tooltip/text trajectories. |
| Number | Actual zero-glyph widths and non-BMP glyph tests. Tall recording includes secondary examples. | Matched ticker and count-up rest/motion captures, all formats, font equality and controlled random updates. |
| Text Animation | Tests mount all five public widgets. Tall candidate recording adds secondary examples. | Paired source captures for all examples, replay and interruption trajectories, deterministic glyph protocol. No new scramble implementation change in round2. |
| Project Folder | Final owned behavioral suite passes. | Every file preview, drag, keyboard entry and paired source timing. |
| Notification Stack | Final owned behavioral suite passes. | Dismissal, action callbacks, stack sizes and paired focus/exit footage. |
| Dynamic Island | Final owned behavioral suite passes. | Every variant, rapid interruptions and matched enter/exit geometry. |
| Availability Scheduler | Final owned behavioral suite passes. | Copy selection, editing and validation flows with exact overlays. |
| Morphing Search | Final owned behavioral suite passes. | Both source examples, query reset, shortcut entry and visible selection outcomes. |
| Morphing Search Chips | Full two-row backdrop and source data. Paired add and close flows plus effective reduced motion. | Oklab gradient interpolation, removal/persistence/no-results browser flow and exact overlay motion. Flutter's current gradient interpolation is sRGB. |
| Prediction Market | Controlled ticket and quick-amount tests, tall Sell recording. | Paired trade submit/balance/position flow and all source examples. |
| Wallet Card | Nine focused non-golden tests pass. | Account selection, chart hover, action flows and exact animated balance. |
| Bloom Menu | Final owned behavioral suite passes. | Every item callback, keyboard traversal and exact anchor/exit geometry. |
| Feedback Widget | Source sentiment default, independent retry semantics, paired failure/retry/success and effective reduced motion. | Empty-submit and close/draft policies still differ from source. Sentiment opt-in and exact normal/reduced morph geometry remain. |
| Dock | Final owned behavioral suite passes. | Grouped examples, separators, active pill and paired pointer-follow/tooltip text timing. |
| Knockout Bracket | Tests include both wheel and bracket. Tall candidate recording includes more composition. | Matching source wheel/bracket captures, replacement data and fixture keyboard semantics. |
| Signup Form | Final owned behavioral suite passes. | Valid submission, validation, reveal and paired keyboard/theme/reduced flows. |
| Infinite Masonry | Final owned behavioral suite passes. | Real scrolling, virtualization, image loads and reversal. Pointer movement is not scrolling proof. |

## Evidence integrity

`verification.json` verifies all 6,878 new original PNG hashes across 68 recordings and all 15 labeled videos.
Every decoded capture frame count matches its timeline. Every labeled output retains the sum of its input frame counts.
The verifier also rechecks all 2,710 original round1 PNGs across 25 recordings and all 185 frozen-before manifest entries.
Original round1 verification metadata remains unchanged.
The 87 raw command logs in `logs/manifest.json` retain their exact copied bytes and hashes.

Measured capture rates range from 5.18 to 43.37 samples per second. The largest request interval is 3,715.67ms.
These aggregate rates do not certify individual event trajectories, and the gaps remain inconclusive for fast motion.
No output claims native 60fps or repairs gaps with interpolation.

## Invalid and inconclusive attempts

No old foreign-build record was deleted or relabeled.

| New attempt | Disposition |
| --- | --- |
| `before` | Initial inspection failed to enable Flutter semantics. Not a valid behavior capture. Later frozen before batches remain separate. |
| `flow-probe` candidate feedback | Valid reproduction of the merged retry semantics defect. Repaired and covered by the final test and browser run. |
| `flow-probe` source feedback | Inspector incorrectly expected a return to the form. Source retry directly resubmits. The final protocol uses that source behavior. |
| `flow-probe` source chips | Input center was outside the 900px viewport. Not an observed add-chip result. The later 1200px flow asserts actual visible state. |
| `flows-normal` candidate feedback | Success was visible, but the inspector searched for an `aria-label` instead of Flutter's text node. Final feedback runs use the actual semantic output and pass. |
| `after-secondary` rates icon and initial `labeled` market clip | Actual native decoding succeeded, but the intrinsic 1x1 SVG shrank to a 9px artwork box. This is a failed visual state, not complete SVG rendering. `after-svg-final` and `labeled-final` show the repair. |
| `press-reduced/candidate-dark-reduce` | Actual motion preference and held flow pass, but original recorded PNGs show missing icon glyphs. The separately observed assertion run shows the icons. Neither overwrites or excuses the recorded rendering failure. Shared font/theme investigation belongs to the parent. |
| Every recording | Fast motion remains inconclusive because of capture cadence. No interpolation repairs missing evidence. |

## Reproduction

Run commands from the repository root. The scripts require the recorded external Playwright runtime and shared recorder paths.
Every batch and output directory must be new.

```sh
node docs/proof/v3-parity/blocks/round2/checks.mjs
EXPECTED_JS_SHA256=<exact-served-sha> THEMES=dark,light node docs/proof/v3-parity/blocks/round2/flow-check.mjs <new-normal-batch>
EXPECTED_JS_SHA256=<exact-served-sha> REDUCED=reduce node docs/proof/v3-parity/blocks/round2/flow-check.mjs <new-reduced-batch>
EXPECTED_JS_SHA256=<exact-served-sha> HEIGHT=1800 SLUGS=prediction-market-card,number,text-animation,prediction-market,knockout-bracket node docs/proof/v3-parity/blocks/round2/run.mjs <new-secondary-batch>
EXPECTED_JS_SHA256=<exact-served-sha> THEMES=dark,light EXPECT_STATIONARY=1 node docs/proof/v3-parity/blocks/round2/press-check.mjs <new-press-batch>
EXPECTED_JS_SHA256=<exact-served-sha> REDUCED=reduce EXPECT_STATIONARY=1 node docs/proof/v3-parity/blocks/round2/press-check.mjs <new-reduced-press-batch>
node docs/proof/v3-parity/blocks/round2/verify.mjs
```

`compare-card.mjs`, `label-videos.mjs` and `review-frames.mjs` intentionally name this immutable run's inputs.
Their output directories must be new when rerun. Do not overwrite committed captures.
The verifier hashes every new timeline PNG, checks decoded video counts, rechecks all 2,710 recovered round1 PNGs and checks all 185 frozen-before entries.
It writes only round2 verification metadata.

Poteto Mode's visual-parity playbook keeps the failed image verdicts explicit and the original baseline immutable.
Model the Domain keeps flow events, state assertions and provenance in separate records.
Prove It Works requires the served response hash, effective motion probe and observed flows.
Test Behavior, Not Implementation requires literal callback payloads, rendered glyphs and a real retry submission.
The UI and motion skills preserve the existing Flutter motion engine and identify the source's transform ownership. The press change adds no animation system.
The source root button is the press data boundary. One full-root transform around its back/card children preserves the source origin. Independent transforms on each child would change that origin.
The user prohibited child agents, so skill delegation steps were skipped. The unavailable `deslop` skill was not claimed as a completed gate.
