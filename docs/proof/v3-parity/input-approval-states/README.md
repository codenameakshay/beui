# Approval input state follow-up

This follows integrated input commit `819ae5350c1b1773411b8d58f92ab70178cb831f` for parent PR26.
It repairs approval placeholder and fill semantics. It does not certify exact visual parity.
All earlier proof, source snapshots, and golden files remain unchanged.

## Scoped changes

`BeuiInputStyle` gains nullable `placeholderColor`, `backgroundColor`, and `focusedBackgroundColor` overrides.
An omitted focus fill falls back to the idle fill.
Shared defaults remain a full-strength muted placeholder and no fill.
Existing typography, padding, focus ring, error, and success behavior remain unchanged.

Approval opts into the pinned source's `placeholder:text-muted-foreground/60`, `bg-background/70`, and `focus-within:bg-background` semantics.
Its existing 14px text, 20px line height, 12px horizontal padding, 40px height, and zero border remain.
The fill now belongs to the input, inside the disabled 60% opacity, rather than an outer decoration.

## Palette provenance

The clean local source is pinned to `a76e57c9bbc2837e96420b2610e9c82a3271bb05`.
The audit reads both complete default token sets in `lib/themes.ts`, their consumer definitions in `lib/theme-css.ts`, and `app/globals.css`.
All 18 public semantic tokens have literal expectations in `example/test/approval_capture_palette_test.dart`, in light and dark modes.
The source dark browser's resolved RGBA values are retained in [matched-run3/records.json](matched-run3/records.json).

The source default primary is `#0285f7`, with white primary foreground, in both modes.
The separate source Blue preset changes primary, accent, and ring to a hue ramp. It is not the default.
The Flutter gallery's historical `defaultMono` primary is neutral.
That recorded palette choice caused the earlier blue-source versus gray-candidate action. It was not a local approval theme lookup error.

The agent-owned capture wrapper now accepts `palette=source-default-a76e57c9` and labels the effective palette in its semantics.
It uses the existing mono base for the other 16 public tokens, which match the pinned defaults at 8-bit sRGB precision.
It overrides primary, primary foreground, and corresponding Material colors only within this wrapper.
Unknown or absent palette values retain historical mono behavior. No public theme file changes.
This is an explicitly labeled capture palette, not a claim that the public Blue palette equals source default.

## Final matched observation

[Run3 source](matched-run3/source/capture.mp4) and [candidate](matched-run3/candidate/capture.mp4) use fresh browser contexts, dark mode, DPR 1, and no reduced motion.
The source has no `data-theme` override. The candidate explicitly requests the pinned source-default palette.
The observed Flutter rectangle is 752 by 1000, with `motionOverride: null` and both animation-disable values false.
The source stage is scrolled into view. Both crops contain the full 512 by 470 approval stage without scaling.
Native screenshots decode to 1440 by 913 despite the 1440 by 1000 CSS viewport.
The crop fits inside that raster. The historical clipped comparison is not overwritten.

The browser-loaded candidate `main.dart.js` SHA256 is `9dd359ffdc981feba598b9d613b0e3afcaac8ba26472d495d7eaa8e3675964bf`.
The recorder asserts this against the actual build bytes before recording.
It also asserts focus and literal keyboard entry of `Keep the release focused.` in both implementations.
Every loaded source JavaScript hash, candidate probe, still hash, native frame hash, and dispatch timestamp remains in the run records.
[inputs.json](inputs.json) identifies the implementation, wrapper, scripts, source files, and capture settings.

[Final pixel results](matched-run3-comparison-final/results.json) use exact RGB inequality, with no tolerance or excluded glyph pixels.

| State | Full stage changed / 240,640 | Input changed / 17,760 | Next changed / 1,024 |
|---|---:|---:|---:|
| Idle | 10,383 | 842 | 786 |
| Focus | 10,443 | 886 | 786 |
| Text entry | 9,900 | 1,002 | 127 |

All three comparisons fail exact parity.
The sampled field background is RGB 23 in both idle crops and RGB 21 in both focused and typed crops.
The source computed placeholder alpha is 0.6. The candidate rendered placeholder style has the same alpha.
These observations establish the repaired state settings, not identical placeholder glyph pixels.

Residual observations and limits are as follows.

- Input and heading glyph rasterization differ visibly. Font weight, font shaping, and renderer contributions are not isolated by this comparison.
- The focused source caret has one bright column with an 18px vertical streak. The candidate has two columns with 22px streaks.
  Typed caret positions also differ by one pixel. These are measured raster differences, not a temporal-alignment claim.
- The options region differs by 5,846 pixels. It includes radio outlines, text, and descriptions. No radio or typography repair is attempted here.
- Replay differs by 500 pixels. Its accessibility bounds begin 7px lower in the candidate, and the images show lower glyph placement.
  Accessibility bounds are not a direct measurement of painted button bounds.
- Next has matching 32px accessibility bounds relative to the stage.
  Its disabled interior sample is source `[15,81,137]` versus candidate `[15,81,138]`.
  The enabled sample matches `[2,133,247]`. The one-channel disabled delta is consistent with opacity/compositing rounding, not a remaining gray palette.
  The remaining enabled differences include arrow rasterization. Their complete cause is not isolated.
- Flutter reports 452 by 46 textbox accessibility bounds, while the source input is 444 by 40.
  These are not equivalent layout probes. Existing rendered geometry tests establish the candidate's 40px visual field and 12px text insets.

Source recording delivers 49 decoded samples at 14.40 FPS, with a maximum 131.11ms gap.
Candidate recording delivers 60 samples at 27.25 FPS, with a maximum 81.62ms gap.
There is no interpolation, synchronized-mount proof, temporal-equivalence claim, or native-60-FPS claim.

## Tests and preserved failures

[final-focused-nongolden-tests.txt](final-focused-nongolden-tests.txt) reports 55 passing input, style, state, and approval tests.
The new state tests sample rendered pixels in light and dark idle, focused, and disabled states.
They check rendered placeholder colors in each state, disabled opacity, retained defaults, copied overrides, and entered text.
Expected idle/focus/disabled grayscale pixels are 250/252/248 in light mode and 23/21/25 in dark mode.
[final-input-golden.txt](final-input-golden.txt) passes the existing input golden without regeneration.
[final-palette-tests.txt](final-palette-tests.txt) reports two passing palette tests.
Both scoped analyzer runs pass in [final-analyze.txt](final-analyze.txt) and [final-example-analyze.txt](final-example-analyze.txt).
[related-tests.txt](related-tests.txt) reports 42 passing related signup, agents, and demo tests.
[web-build.txt](web-build.txt) records a successful release web build and its existing Cupertino font warning.

[final-focused-tests.txt](final-focused-tests.txt) deliberately retains the broader run's existing approval golden failure of 448 pixels.
Its other 56 tests pass. That golden remains unchanged and the failure is not waived.
`baseline-red.txt` retains the initial failing placeholder/fill reproduction.
`first-green.txt` is a failed attempt despite its filename. The focus transition had not settled in that test.
The later green logs use an explicit frame and transition duration.
`comparison-run3.txt` retains a premature comparison that ran before `records.json` existed.
Its empty output directory remains. `comparison-run3-final.txt` is the successful comparison in a new namespace.

## Reproduction commands

The capture script uses the repository's existing Playwright runtime at `/tmp/beui-parity-capture-runtime` and installed Google Chrome.
It expects the clean pinned source server on port 18128 and the release build server on port 18127.
These task-owned servers are stopped after the handoff checks.

```sh
# From example.
flutter build web --release --target=lib/demos/agents_capture.dart --output=build/approval-states-a76 --base-href=/approval-states-a76/

# From the repository root, with both servers running. Use new run names.
node docs/proof/v3-parity/input-approval-states/capture.mjs matched-rerun
node docs/proof/v3-parity/input-approval-states/compare.mjs matched-rerun matched-rerun-comparison
flutter test --reporter expanded test/motion/input_test.dart test/motion/input_style_parity_test.dart test/motion/input_approval_states_test.dart test/motion/approval_card_test.dart --name '^(?!.*golden)'
flutter test --reporter expanded test/motion/input_test.dart --plain-name 'rest-state golden'
git diff --exit-code 819ae535 -- test/motion/goldens docs/proof/v3-parity/agents docs/proof/v3-parity/input-approval-followup
```

No children, push, PR mutation, or merge occurred.
The unavailable `control-ui` and `deslop` skills are replaced by the repository Chromium workflow and direct scoped diff inspection.
Prove It Works required actual loaded-script hashes, effective probes, and nonzero pixel verdicts.
Test Behavior, Not Implementation required rendered pixels and actual keyboard text rather than constructor-only checks.
