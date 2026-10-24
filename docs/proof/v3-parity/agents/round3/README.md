# Agent parity round three

This implements local source corrections for parent [PR26](https://github.com/codenameakshay/beui/pull/26), starting at `a2942181`.
Exact parity is not complete. All 106 final image comparisons have nonzero differences.
The source checkout is clean at `a76e57c9bbc2837e96420b2610e9c82a3271bb05`. The live deployment revision remains unknown.

## Completed local repairs

| Commit | Repair |
|---|---|
| `0a8c3f4e` | Move diff copy into the disclosed body. Restore source header, gutter, tint, and footer geometry. Wait for the outgoing approval question before mounting the next body. Align described controls with the first text line. |
| `f1aae393` | Flatten the diff body fill to avoid CanvasKit alpha rounding. Restore simple TypeScript constant-binding and assignment colors. Give the two approval examples and diff an agent-local 24px Replay control with a 6px icon gap. |
| `095f0b80` | Verify 19 repeated orb retarget samples against the actual pinned Motion 12.43.0 generator. Verify switching to reduced motion during a question exit. |
| `96f8c7d9` | Restore the badge's inherited 20/14 line-height ratio. Restore the counter's 16px line height and 65% muted foreground. |
| `b299ef96` | Default narrow diffs to source-style horizontal scrolling. Keep explicit wrapping and adaptive wrapping available. |
| `426de8f3` | Add a separately requested orb renderer-error demo. Record the actual error callback and fallback, not the fixture request alone. |
| `695572e5` | Scope the deliberate test-hook use to that opt-in fixture. No shared analyzer configuration changes. |

No material or spring tuning was justified by the orb observations.
The lightweight syntax scanner now covers the canonical diff's roles, ordinary constant values, mutable bindings, and simple arrow initializers.
It is not a full Shiki grammar. Typed declarations, destructuring, multiline state, and general TSX remain separate fidelity limits.

## Measured images

[STATE_RESULTS.md](final-audit/STATE_RESULTS.md) lists all 106 per-state counts and links the exact source, candidate, and difference images.
The comparison uses exact RGB inequality. It does not rescale images, exclude glyphs, or apply tolerance.
The comparator rejects fractional or out-of-raster crops.

| Final settled state | Dark changed pixels | Light changed pixels | Pixels compared |
|---|---:|---:|---:|
| Diff collapsed | 1,057 | 1,052 | 153,600 |
| Diff expanded | 5,245 | 5,200 | 153,600 |
| Approval questions idle | 9,907 | 9,551 | 240,640 |
| Approval typed constraint | 4,640 | 4,668 | 240,640 |
| Approval answered | 6,114 | 6,146 | 240,640 |
| Orb reduced static | 348 | 331 | 82,944 |
| Orb renderer error | 1,611 | 1,523 | 82,944 |

The initial dark expanded diff changed 68,885 pixels. After the structural repair it still changed 68,239 pixels.
Flattening the body fill reduced that to 5,370. The final token and Replay corrections reduced it to 5,245.
The narrow expanded comparison improved from 43,596 to 5,147 changed pixels after restoring single-line scrolling.
The source stage is 358px wide in a 390px CSS viewport. The matching candidate explicitly requests `previewWidth=358`.

The terminal badge repair reduces the dark answered comparison from 7,717 to 6,114 pixels.
[source-approval-layout.json](source-approval-layout.json) records its actual computed 15.7143px line height and 21.703125px bordered height.
Flutter rounds the corresponding test paragraph to 16px and the badge to 22px. That rounding is not exact browser box equivalence.

`row-N`, `after-next-dispatch`, and `submitting` are unsynchronized sample labels.
Source and candidate can show different row counts or transition phases under those labels. Their recorded semantics and timestamps take precedence.
Keyboard screenshots can include a real focus ring. Their counts must not be presented as settled pointer-only equivalence.

## Actual browser outcomes

All `verified-*` captures use the final `agents-round3-after6` artifact. Its browser-loaded JavaScript hash is asserted before completion.
The post-commit `after7` rebuild produces identical JavaScript bytes at code head `695572e5`.
Both SHA256 values are `844fc1470486a6418bf636de77963babf0a573cc9e0f67456d5a5f008ccae43c`.
Each run contains original native PNG frames, a lossless variable-rate MP4, decoded frame counts, stills, and a `record.json`.
[captures.json](final-audit/captures.json) indexes every run, its effective environment, font responses, state labels, and any rejection.

The final 16 scenarios establish the following outcomes.

- Diff disclosure, literal clipboard payload, Replay, incremental rows, and terminal collapse work in dark, light, narrow, reduced-motion, and keyboard runs.
- Questions select the actual radio value, check both options, accept the literal `Keep the release focused.`, and reach the answered result.
- Review independently reaches approved, revision-requested, and rejected results in both themes, with Replay between outcomes.
- The keyboard runs use actual Tab and Shift+Tab focus transitions, Space activation, checked-state assertions, literal text entry, and terminal results.
- Reduced orb captures observe effective browser and Flutter reduced motion. Error captures observe the actual fallback and its stationary held image.

[Question keyboard video](verified-approval-keyboard-run1/capture.mp4), [diff keyboard video](verified-diff-keyboard-run1/capture.mp4),
[review video](verified-review-dark-run1/capture.mp4), and [orb failure video](verified-orb-error-dark-run1/capture.mp4) retain their native inputs alongside them.

The source error fixture denies WebGL context creation without editing source files.
The candidate uses the explicitly selected `orbFixture=renderer-error` demo and the existing library load-failure hook.
Its semantic observation is produced by the actual `onError` callback. The retained images show the painted fallback.
These are two labeled renderer-failure fixtures, not identical low-level failure causes.

## Environment and preservation

The candidate explicitly requests `palette=source-default-a76e57c9`. Source primary is `#0285f7` in both themes.
The historical mono gallery's gray primary was a capture palette choice, not an approval implementation defect.
No public palette, shared input, theme, font, Tooltip, engine, catalog, or shared recorder file was edited.
The agent-local Replay implementation leaves the shared gallery Replay control unchanged.

Records include actual loaded script hashes, font asset hashes, `document.fonts`, browser version, effective browser reduced motion,
Flutter animation-disable settings, `motionOverride: null`, wrapper bounds, and control-local accessibility geometry.
The rendered field and glyph bounds are not inferred from accessibility rectangles. Widget geometry tests provide those separate measurements.
Older exploratory runs predate font-response recording and must not be treated as equally complete provenance.

The native browser raster is 1440 by 913 for desktop and 500 by 913 for the 390px CSS viewport.
Every final stage fits the native raster. No final stage is silently shifted to fit.
Latest candidate videos deliver 16.33 to 43.54 measured samples per second, with a largest gap of 266.42ms.
There is no interpolation, sustained native-60-FPS proof, synchronized mounting, or full material-trajectory equivalence.

`frozen-javascript` retains the actual initial and final served Dart JavaScript bytes.
`flutter-version.json` records the build SDK. Build logs retain the existing Cupertino font metadata warning.
The task used only port 18117, checked it before each bind, and ran source and candidate servers sequentially. Both task-owned servers are stopped.

[preservation-final.txt](preservation-final.txt) is the empty successful diff against `a2942181` for all historical goldens,
round-two evidence, original inventories, GAPS, input-approval states, and audit files.
The source checkout remains clean and pinned. No original golden, image, video, or hash was regenerated.
The unrelated dirty `example/analysis_options.yaml` is excluded from these commits.

Parent changes `ea2024e3` and `e81e9cc2` were reported during this run. No dependency adoption was needed for these repairs.
They are not included in the captured build, and their reported tests are not counted as this slice's proof.

## Tests and rejected attempts

[all-related-final.txt](all-related-final.txt) reports 227 passing non-golden tests across ten files.
The focused command is reproduced below. Scoped library/test analysis passes in [analyze-last.txt](analyze-last.txt).
Demo analysis passes in [example-analyze-last2.txt](example-analyze-last2.txt).

[final-goldens-unchanged.txt](final-goldens-unchanged.txt) retains two failures against untouched goldens.
Approval differs by 9,175 pixels. Diff differs by 72,348 pixels. Neither failure is waived or hidden by the non-golden command.
Original generated failure PNGs are retained in `golden-failure-attempt1` and `golden-failure-final`.
Historical round-two golden counts are not current results after these source corrections.

The first diff test run required the old 14% wash, stronger gutter, and collapsed header copy.
Its failures remain in [existing-diff-tests-attempt1.txt](existing-diff-tests-attempt1.txt). Dedicated expectations now match the pinned source.
The syntax and narrow-row red tests reproduce plain-colored declarations and a wrapped 80px row before their repairs.

All 15 rejected capture attempts remain in the archive, including their original frames.
Earlier approval captures had clipped late-stage source crops. They are listed in `captures.json` and are not final comparisons.
The first field typing attempts lost an initial character. Later captures require actual focus, a settling interval, and literal text assertions.
The first review-light outcome wait missed Flutter's text-bearing semantics element despite the approved pixels. The corrected selector observes that element.
Initial keyboard attempts accepted a pre-focused semantics node without a new Tab event. Later runs require a real Tab transition before activation.
The first candidate orb error attempt aborted a nonexistent shader asset request. It failed the actual-outcome assertion and remains rejected.
The explicit error demo replaces that failed fixture rather than marking dispatch as success.
`capture-v1.mjs` through `capture-v6.mjs` retain recorder checkpoints. Early exploratory recorder revisions before these checkpoints are not reconstructible from a final script alone.
Raw test logs retain their original whitespace. Code-only diff checks pass.

## Outstanding obligations

[obligations.json](final-audit/obligations.json) enumerates every one of the original 19 routes and 152 obligations with current and inherited evidence.
No exact-parity obligation is upgraded. Agent theme has no source route and remains a separate functional composition.

| Route | Still-open gate |
|---|---|
| prompt-input | Full matched hover, picker, attachment, keyboard, light, and reduced-motion equivalence. Shared input remains parent-owned. |
| message | Grouping, metadata, hover exit, live markers, and every terminal state. |
| message-bubble | Matched tones, all three independent examples, actions, attachment layout, and incremental growth. |
| message-scroller | Unread recovery, live-edge following, resize, completed anchors, and keyboard return. |
| streaming-response | Synchronized chunks, source expansion, hover exit, copy, retry, cancellation, and Continue. |
| image-generation | Matched timed phases, dither motion, error/retry/cancel, and applicable media actions. |
| citations | Progressive rows, favicon behavior, marker focus/hover exit, links, truncation, and disclosure. |
| loading-states | All independent examples, elapsed progress timing, phrase cycles, and native reduced-motion behavior. |
| todo-list | All progress steps, collapse reversal, marks, insertion, removal, reorder, and failure/cancel states. |
| agent-activity | All six examples, progressive overflow, disclosure interruption, and complete status coverage. |
| tool-result | Both examples, chunk timing, failure/cancel, scrolling/focus, and exact copy feedback geometry. |
| code-block | Full Shiki fidelity, timed line mounts, stable identity, wrap/scroll, and copy feedback. |
| file-diff | Nonzero settled pixels, synchronized row timing, hover exit, reversal, and browser gap/navigation API states. |
| tool-approval | Exact permission outcomes, destructive/error variants, focus order, timing, and collapse. |
| approval-card | Nonzero pixels, synchronized transitions, controlled rejection, Back/Next interruption, complete hover/focus-return, and additive editor coverage. |
| ai-sidebar | Nested keyboard navigation, rename commit/cancel, optimistic move rollback, and safe delete affordance. |
| chat-app | Full integrated media/tool/approval paths, navigation, retry/error, unread recovery, and matched mobile focus behavior. |
| voice-orb | Synchronized zero/ramp/peak/release/repeat material at native 60 FPS. Matched custom pigments, size, and browser offscreen pause/resume. Repeated analytical silhouette samples now pass, but do not close these gates. |
| agent-theme | Local-only complete light/dark statuses, custom typography/icon bounds, keyboard traversal, and focus return. No source-equivalence claim. |

Needed shared work is reported, not edited here.
The source file icon is `FileCode2`; shared `BeuiAgentIcons.file` still defaults to `LucideIcons.file_code` rather than the corresponding corner glyph.
Font shaping, weight, and raster differences remain visible across headings, body text, and Replay.
The shared Tooltip can still produce a repeated submit accessible name in this build. The recorder accepts that observed name but does not repair it.
The shared input's glyph/caret differences and source-versus-Flutter line-box rounding remain separate from the repaired local fill and typography settings.

## Reproduction

These commands use the repository's documented Playwright Chromium runtime at `/tmp/beui-parity-capture-runtime` and installed Google Chrome.
The unavailable `control-ui` and `deslop` skills were replaced by that repository workflow and direct scoped diff inspection.
No child agent, push, new PR, or merge occurred.

```sh
flutter test --reporter expanded test/motion/agents_round3_test.dart test/motion/agents_round3_orb_test.dart test/motion/agents_round3_syntax_test.dart test/motion/_syntax_test.dart test/motion/file_diff_test.dart test/motion/agents_round2_test.dart test/motion/approval_card_test.dart test/motion/voice_orb_test.dart test/motion/code_block_test.dart test/motion/tool_result_test.dart --name '^(?!.*golden)'
flutter test --reporter expanded test/motion/file_diff_test.dart test/motion/approval_card_test.dart --name golden
node docs/proof/v3-parity/agents/round3/verify-archive.mjs
node docs/proof/v3-parity/agents/round3/audit.mjs new-audit-name
node docs/proof/v3-parity/agents/round3/compare.mjs source-diff-dark-run1 verified-diff-dark-run1 new-comparison-name
```

To capture again, first confirm port 18117 is free, then serve the clean pinned source or the immutable candidate build on that port.
The source command is `bun run dev --hostname 127.0.0.1 --port 18117` from its checkout.
The candidate command is `python3 -m http.server 18117 --bind 127.0.0.1 --directory example/build` from this repository.
Run only one server at a time. Use a new run name, never overwrite an old directory.

```sh
BEUI_CAPTURE_BUILD=agents-round3-after6 node docs/proof/v3-parity/agents/round3/capture.mjs after approval-card fresh-candidate dark normal 1440
BEUI_CAPTURE_PREVIEW_WIDTH=358 BEUI_CAPTURE_BUILD=agents-round3-after6 node docs/proof/v3-parity/agents/round3/capture.mjs after file-diff fresh-narrow dark normal 390
BEUI_CAPTURE_KEYBOARD=1 BEUI_CAPTURE_BUILD=agents-round3-after6 node docs/proof/v3-parity/agents/round3/capture.mjs after approval-card fresh-keyboard dark normal 1440
BEUI_CAPTURE_ORB_ERROR=1 BEUI_CAPTURE_BUILD=agents-round3-after6 node docs/proof/v3-parity/agents/round3/capture.mjs after voice-orb fresh-error dark normal 1440
```

Fix Root Causes required the narrow-row correction instead of adjusting its crop.
Model the Domain kept the question transition in explicit exit, enter, and settled phases.
Test Behavior, Not Implementation required rendered geometry, checked values, literal text, clipboard content, and terminal outcomes.
Prove It Works required actual served-byte hashes, effective motion settings, native images, and nonzero pixel verdicts.
