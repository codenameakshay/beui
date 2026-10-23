# Input and approval follow-up

This repairs the shared-input limitation reported in `agents/round2/README.md`.
It does not certify exact parity. All earlier evidence and goldens remain unchanged.
The implementation starts from `8342f731c83d7e9fe42416623f3a7e990b93db4e`, which includes the integrated agent repairs.

## Source and implementation

The clean source checkout at `/tmp/beui-v3-parity-components-source` is pinned to
`a76e57c9bbc2837e96420b2610e9c82a3271bb05`.
Its approval `Input` requests `px-3 text-sm` and `h-10 rounded-xl border-0`.
The source `cn` uses `tailwind-merge`. The final class list removes the input's
default `leading-6`, so the computed line height is 20px, not 24px.
[live-source-style.json](live-source-style.json) records the observed 14px font,
20px line height, 12px horizontal padding, 40px field, 12px radius, and zero border.
That live deployment has an unknown revision. Its 1280x800 DPR-2 diagnostic session
is separate from the historical DPR-1 pixel comparison.

`BeuiInputStyle` now accepts nullable `textStyle`, `contentPadding`, and `borderWidth` overrides.
They participate in `copyWith`. The existing style object owns these settings;
no replacement input or new wrapper is introduced.
The default remains 16px text, 24px line height, 44px field height, a 1px border,
and 14px content insets on sides without icons. Existing icon-slot spacing stays unchanged.
The placeholder receives the text typography but keeps its existing muted color.

Approval alone requests 14px text with `height: 20 / 14`, horizontal padding 12,
and border width zero. The zero-width override matters because a transparent
1px border still adds an unwanted layout inset in Flutter.

Model the Domain kept these options in the existing typed style object.
Laziness Protocol ruled out an approval-specific replacement field.
Test Behavior, Not Implementation required rendered text metrics and rectangles.
Prove It Works required an unchanged input golden and a fresh served-build capture.

## Next action theme diagnosis

The pinned public `lib/themes.ts` and `lib/theme-css.ts` define source default
`--primary: #0285f7` and `--primary-foreground: #ffffff` in both brightness modes.
The preferences provider starts with color theme `default`, with no `data-theme` attribute.
The live dark-page measurement confirms those tokens and a disabled Next opacity of 0.5.

The historical recorded config requests `theme=dark`. Its unchanged
`example/lib/demos/agents_capture.dart` explicitly chooses `BeuiColorTheme.defaultMono`.
Flutter's mono dark primary is `#f2f2f2` with foreground `#151515`.
Approval's Next button reads the supplied palette correctly. A rendered-decoration
regression proves both blue and mono primary values reach that button.
There is no approval-local wrong-theme selection to repair.

For a source-default Next comparison, use source dark brightness, source color
theme `default`, and no `data-theme` attribute. The candidate capture needs a
capture-only `BeuiColors` extension with `primary: Color(0xFF0285F7)` and
`primaryForeground: Colors.white`, derived from the dark palette.
This describes the Next action settings, not full-palette equivalence.
`color=blue` is not equivalent because the public Blue brand has a different ramp.
The agent capture wrapper also ignores that query parameter.
The capture-wrapper owner must supply these settings for a theme-matched recapture.
No library theme, demo, capture wrapper, or global default was changed here.

## Verification

- `baseline-red-run2.txt` reproduces the approval defect with `Expected: <14>` and `Actual: <16.0>`. The default-input case passes.
- `baseline-red.txt` is an invalid first test attempt. It used a widget render-object cast that this Flutter version does not support. The test now reads `EditableTextState.renderEditable`.
- `focused-tests.txt` reports 49 passing input, approval, and dedicated style tests with goldens excluded.
- `related-tests.txt` reports 42 passing signup, round-two agent, and agent-demo tests with goldens excluded.
- `input-golden.txt` reports the existing input golden passing without regeneration.
- `consumer-tests-with-goldens.txt` reports 61 passes and two failures. Approval differs by 448 pixels and signup by 110,541 pixels.
- `baseline-consumer-goldens.txt` reproduces both failures with exactly those counts in an isolated archive of untouched `8342f731`. Neither is introduced by this change.
- `analyze.txt` reports no issues in both owned library files and the dedicated test file.
- `web-build.txt` records a successful release build. The unused Cupertino font warning remains visible.
- `preservation.txt` checks that all existing agent evidence, goldens, and example analysis configuration are unchanged.

The dedicated tests observe `RenderEditable` typography and line height, editable
rectangles, placeholder `RenderParagraph` typography, typed text, directional padding,
copied style settings, default icon and success spacing, and Next's rendered decoration.

Reproduce the focused checks from the repository root.

```sh
flutter test test/motion/input_style_parity_test.dart test/motion/input_test.dart test/motion/approval_card_test.dart --name '^(?!.*golden)' --reporter expanded
flutter analyze lib/src/motion/input.dart lib/src/motion/approval_card.dart test/motion/input_style_parity_test.dart
```

The capture build command runs from `example`.

```sh
flutter build web --release --target=lib/demos/agents_capture.dart --output=build/input-approval-followup --base-href=/input-approval-followup/
```

## Pixel evidence and remaining differences

`capture.config.json` and `candidate-capture` retain a new guarded idle capture.
The recorder verifies the browser-loaded script hash, 752px Flutter stage,
dark brightness, and effective reduced motion false with no override.
The release script SHA-256 is `9626b32cacc965d72b49b7ebbc3b57833d52323525f90f9eb8790064e3989414`.
The native raster remains 1440x913 despite a requested 1440x1000 CSS viewport.
Nineteen native samples and their hashes remain preserved. No interaction or 60 FPS claim is made.

`compare.mjs` compares the same top 512x421 crop against the preserved historical reference.
It writes only to a new output directory. Run `node docs/proof/v3-parity/input-approval-followup/compare.mjs NEW_RUN_DIRECTORY`.
[crop-comparison/results.json](crop-comparison/results.json) reports 10,341 changed pixels
out of 215,552 and absolute channel delta 1,206,302. This is a failure.
The historical comparison reported 10,847 changed pixels. These counts do not certify equivalence.

The gray-versus-blue Next difference remains because the capture palettes differ.
The placeholder also remains visibly stronger than the source's `muted-foreground/60`.
The shared input deliberately retains its existing full-strength placeholder default.
The approval background's focus-state change from 70% to full background is not implemented here.
Other text, control, color, focus, and state differences are not certified by this idle crop.
The historical source stage loses its bottom 49px, and its deployment revision is unknown.

The preview snapshot operation twice returned `Preview automation snapshot timed out after 15000ms.`
Live style measurements succeeded through the preview. The repository's existing Chromium
recorder supplied the pixel capture without any recorder or baseline changes.
The control-ui and deslop skills are unavailable. Direct diff review supplied the local fallback.
No children, push, PR creation or update, or merge was performed. PR26 was registered with the local thread metadata.
