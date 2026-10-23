# Agent parity round two

This is an implementation and evidence delta for parent PR26. It does not certify exact parity or release readiness.
The inventory remains 19 routes and 152 state or example obligations. The original audit files remain historical records.
Implementation commit `7527cde` contains only owned agent library, demo, capture-wrapper, and test changes.
Commit `8a0337b` restores original evidence byte-for-byte from `91e8ca1`. The parent can skip this duplicate restoration.

## Delivered repairs

| Area | Source correspondence | Implemented result |
|---|---|---|
| File diff | `components/previews/agents/file-diff.preview.tsx` | Five literal rows, final old/new lines 20/21, full copy text, 360ms row cadence, completion at 2280ms. Invented gap and generated context removed. |
| Approval questions | `approval-card-question.preview.tsx`, `components/agents/approval-card/index.tsx` | All three descriptions restored. Radio and checkbox descriptions select the associated value. Questions and review are separate examples. |
| Prompt notice | `prompt-input.preview.tsx` | Sent notice has priority over action notices. Entry moves 3px over 180ms. Replacement waits for fade-only exit. Reduced motion bypasses movement and delay. |
| Provider logos | `prompt-input.preview.tsx`, `lib/hooks/use-favicon.ts`, `lib/favicon.ts` | Exact five provider origins and `/favicon.ico`. Web images set `no-referrer` before `src`, check `decode()`, use 16px bounds, contain fit, 2px corners, and Bot fallback. Decorative images preserve button semantics and do not intercept pointer input. |
| Canonical compositions | Source preview files in `source-snapshots/components/previews/agents` | Extra API specimens no longer appear in canonical citations, code, todo, streaming, tool approval, tool result, message bubble, loading, activity, or approval examples. They remain explicitly selectable as `?example=api-specimens`. |
| Independent examples | Message bubble, loading states, activity, request result, review source previews | Eleven additional examples have independent URLs and guarded videos. Six activity examples include the canonical default. Source search marks use the original filled paths. |
| Chat submit and stop | `chat-app.preview.tsx` | A separate pending row lasts 420ms before assistant mount. Pending-stop creates no assistant response. The 92-character-per-second stream uses elapsed timer ticks and the exact source reply. |
| Chat resume and retry | Additive API composition, not a source-equivalent Retry claim | Continue resumes the same response. Retry in `?example=api-specimens` resets that response without another user turn. Continue is a separately named semantic action. |
| Chat shell | `components/agents/chat-app.tsx` and its preview | 12px preview padding and the source 600px minimum docked width. Narrow layout no longer collapses to zero width. The demo opens the existing mobile drawer and returns trigger focus on dismissal. |
| Orb silhouette | `voice-orb.tsx`, `lib/ease.ts`, source `bun.lock` | A nonzero initial activity now springs from rest. Five deterministic samples match Motion 12.43.0. No unsynchronized material-score tuning. |

The three restored descriptions are exact source copy.

- `Ship a few polished pieces first.`
- `Cover more ground with lighter depth.`
- `Pour everything into a single showcase.`

## Visible changes and videos

[CHANGE_MANIFEST.md](CHANGE_MANIFEST.md) links all 19 labeled side-by-side videos and their native candidate inputs.
The [approval still](side-by-side-v3/approval-card.png) visibly shows the restored descriptions and isolated example.
The [diff row still](side-by-side-v3/file-diff-visible-rows.png) samples the streaming rows instead of the initial partial frame.

The left input uses baseline library `5ec78ac` plus a capture-only wrapper. It is not a pristine checkout recording.
The right input uses the frozen `handoff` build. That build precedes the Continue semantics and provider-adapter follow-ups.
The original baseline footage remains untouched. Wrapper text, hashes, and checkout state are in [baseline-wrapper-provenance.json](baseline-wrapper-provenance.json).

The new shared-recorder batch contains 32 guarded captures.

- Nineteen canonical route videos are under `shared-guarded/<slug>/capture.mp4`.
- Eleven independent examples use `shared-guarded/<slug>-<example>/capture.mp4`.
- Prompt and orb reduced-motion videos use the `-reduced` suffix and measured 592px stages.
- The latest provider adapter has replacement idle videos in `shared-guarded-providers/prompt-input` and `prompt-input-reduced`.
- [provider-held-pointer/capture.mp4](provider-held-pointer/capture.mp4) records down, held move, release, ArrowDown, and Enter with recorder revision `d53695f`.

Every capture retains its config, native PNG frames, frame hashes, requested times, actual dispatch times, loaded script hashes, and decoded frame counts.
The recorder SHA is in each config's provenance. Existing batches retain their older recorder SHA.
The held-pointer recording proves dispatch and visible pixels. Provider selection is asserted separately by the runtime test.

## Actual interaction evidence

| Recording | Assertions that passed |
|---|---|
| [Desktop chat](flows/flow-fix/chat-app-api-specimens-run4/capture.mp4) | Actual composer keyboard entry, user echo, pending row, pending-stop, incremental output, streamed-stop, Continue, completion, Retry without duplicate user text, tool denial. |
| [Mobile chat](flows/flow-fix/chat-app-api-specimens-mobile-run1/capture.mp4) | Open and dismiss the actual sidebar, then the complete desktop chat sequence. Trigger focus return also passes the widget regression. |
| [Source chat](flows/reference/chat-app-source-run3/capture.mp4) | Actual source submit, pending-stop, stream-stop, another submit, full completion, tool denial. The live deployment revision is unknown. |
| [Prompt](flows/handoff/prompt-input-source-run2/capture.mp4) | Actual keyboard submission, loading, completion notice, action selection, sent-notice priority. |
| [Reduced prompt](flows/favicons-final/prompt-input-source-reduced-run1/capture.mp4) | Same prompt flow with browser and Flutter reduced motion observed as true, no override. This precedes only decorative-logo semantics exclusion. |
| [Approval](flows/handoff/approval-card-source-run2/capture.mp4) | All descriptions, single-choice auto-advance, two checks, freeform keyboard entry, submission, answered state after 750ms. |
| [Favicon results](favicon-runtime-selected/results.json) | Actual live image decoding, five-provider success fixture, failed-decoding fixture, policy before source assignment, retained button roles, provider selection, and picker dismissal. |

The first chat captures failed before they established a workflow. Their PNGs and logs remain in `flows`.
Fast keyboard delivery could update Flutter's accessibility textarea without updating the composer controller.
The rerun uses actual focus changes, 35ms key delivery, a settling interval, and literal focused-text assertions before Enter.
No app workaround was added for this recorder race.
The actual component defects were the early assistant mount, narrow Stack width, missing mobile wiring, and merged Continue semantics.

The favicon runtime used deterministic image-source substitution only in its two labeled fixtures.
The live case uses the real remote URLs. Four providers decoded, while OpenAI used Bot fallback in that run.
Detached platform-image loads did not emit Playwright request events. The proof observes `referrerPolicy` before `src`, not outgoing request headers.
Earlier failed favicon tests remain labeled by their run directories and logs.

## Provenance and geometry

The source checkout is clean at `a76e57c9bbc2837e96420b2610e9c82a3271bb05`.
[source-hashes.json](source-hashes.json) pins 47 source files, including preview data, orb renderer, favicon hook, ease tokens, and dependency lock.
[source-snapshots](source-snapshots) retains those bytes. Live reference geometry is under `reference/<slug>/geometry.json`.
The source checkout pin is not assigned to the unknown live deployment.

[frozen-build-hashes.json](frozen-build-hashes.json) identifies each frozen JavaScript artifact.
The exact script bytes and index base paths remain in `frozen-javascript`, including the explicitly invalid packaging attempts.
The capture scripts verify the index base path, fetch the expected script, and hash the actual browser-loaded response before frame capture.
The shared recorder also checks actual browser and Flutter motion settings before its first frame.
[effective-environments.json](effective-environments.json) contains measured 752px or 592px Flutter rectangles and `motionOverride: null` for all 32 captures.

The agent-owned wrapper uses the shared probe schema from `d831524` without changing the shared shell or theme.
Its root background is RGB 252 in light mode and RGB 21 in dark mode. Existing component theme tokens remain parent-owned.
The older capture-only wrapper used the unchanged gallery background and an explicit `reduce=true` MediaQuery override.
Those older captures are not relabeled as browser-derived motion proof.

Port 8107 belongs to an unrelated Python server. It was not stopped or overwritten.
The capture server uses port 18107 after a free-port check. Every delivery batch verifies the frozen build response independently.
The `verified` and `complete` build directories had an incorrect `/` base path. Their blank failed attempts remain invalid evidence.

The CSS viewport is 1440 by 1000 at DPR 1, but native screenshot pixels decode to 1440 by 913.
The bottom 87 CSS pixels are clipped by this screenshot backend. No recording is labeled as a full 1000px raster.
Side-by-side derivatives crop each measured 752px stage to its visible 913px height without scaling it.
They add a header and one padding pixel for even video dimensions. They hold native input samples without interpolation.
The inputs have unsynchronized mounts, so these derivatives do not establish temporal equivalence.

## Verification

[verified-nongolden-tests.txt](verified-nongolden-tests.txt) reports 227 passing focused tests.
The command covers round-two tests, parity demos, transcript announcements, streaming response, orb, chat, approval, prompt, diff, and todo.
It uses `--name '^(?!.*golden)'`. The earlier `--exclude-tags golden` attempt did not exclude untagged goldens and remains a failed attempt.
[verified-analyze-final.txt](verified-analyze-final.txt) reports no analyzer issues.
[providers-build.txt](providers-build.txt) records the successful final release capture build.
The build warning about unused Cupertino font metadata remains visible in the raw log.

The original completion regression remains green in both the 227-test run and [continue-semantics-green-run3.txt](continue-semantics-green-run3.txt).
The baseline-red reproduction is unchanged in the parent evidence directory.
No golden was regenerated. [current-nine-goldens.txt](current-nine-goldens.txt) reproduces all nine baseline failures with unchanged pixel counts.
The counts remain 6, 135, 156, 297, 8, 448, 10, 1701, and 210 in the original TESTING.md order.
[original-evidence-final-verification.txt](original-evidence-final-verification.txt) checks all 118 original video hashes and 18 original labeled derivatives.

The 32 shared captures average 27.04 to 56.03 delivered samples per second. The largest observed gap is 157.91ms.
Some older idle averages reach 60.09, but that does not establish sustained native 60 FPS.
[cadence-summary.json](cadence-summary.json) preserves per-recording rates, gaps, and failed-run labels.
No frame interpolation or native-60-FPS certification is claimed.
The new pointer recorder also passes all six config tests in [pointer-recorder-config-tests.txt](pointer-recorder-config-tests.txt).

## Remaining gaps and ownership

Exact parity remains blocked. [matched-crops/results.json](matched-crops/results.json) reports two nonzero comparisons.
The approval comparison changes 10,847 of 215,552 visible pixels. The settled diff comparison changes 1,660 of 153,600 pixels.
These are failures, not tolerances. The approval source crop contains only its visible top 421px because 49px of its stage falls outside the raster.
The diff crop checks the settled header, not row insertion or copied text.

The approval crop exposes a shared-input limitation. The source custom field requests `px-3 text-sm`.
`BeuiInput` fixes its field text at 16px and has no typography or content-padding override.
That shared primitive is outside this agent's ownership. This slice does not replace it with a new field to hide the comparison.
The live source's blue Next action versus the gallery's gray action is also a parent-owned theme difference.

Orb score 63.6 and temporal correlation -0.12340906577581237 remain unresolved.
[orb-source-trajectory.json](orb-source-trajectory.json) records the actual source activity producer, generator samples, transform, and shader-clock rule.
The start-state omission is repaired. Material correlation, velocity-preserving retargets, synchronized activity, and native 60 FPS remain unproven.

The full 152 obligations are not marked complete. Remaining evidence includes light and mobile states, full keyboard traversal, sidebar rename and rollback,
unread recovery, integrated tool-allow and media paths, and all hover, interruption, and renderer-error states.
Agent theme remains local-only, with no source equivalent. Original baseline failures remain failures.

## Execution boundaries

The blocking steps were source pinning, baseline preservation, actual flow reproduction, and served-build checks.
One agent owned the library, demos, tests, and evidence. No agents were spawned.
The smallest safe decomposition kept shared primitives, engine, theme, catalog, barrel, and shell outside this diff.
Capture batches ran independently against immutable builds. Shared writes were limited to this evidence directory.
No push, PR update, or merge occurred.

Model the Domain kept pending work separate from assistant turns.
Fix Root Causes changed the narrow Stack sizing and Continue semantics instead of adding recorder exceptions.
Test Behavior Not Implementation required actual composer text and resulting responses.
Prove It Works required hashes of the browser-loaded JavaScript and effective Flutter geometry.
The control-ui and deslop skills are unavailable in this environment. Repository Chromium tooling and direct diff review supplied the fallback.
