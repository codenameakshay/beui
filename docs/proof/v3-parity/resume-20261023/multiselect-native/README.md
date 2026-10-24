# MultiSelect bounded native verification

This archive compares supplemental public-API fixtures using React pin `a76e57c9bbc2837e96420b2610e9c82a3271bb05` and an isolated Flutter snapshot from `1254bfa63a70298061c557616abeb9c6a67db372`. It does not modify production or widget-test files. No commits, push, children, broad tests, goldens or existing evidence were changed by this worker.

## Contract and fixture

The fixed options are Alpha, Disabled, Beta, Gamma and Delta, with IDs `alpha`, `disabled`, `beta`, `gamma`, `delta`. Disabled is not selectable. Initial controlled selection is `[alpha,beta,gamma]`. Query starts empty and native typing enters `zz`. Selection owners either accept each proposal or record and reject it. Query and popup state remain component-owned, with observational public callbacks. This is a supplemental composition, not the unchanged gallery preview. Both `no-preference` and `reduce` run at 1000 by 800, DPR 1, light scheme, using installed Chrome and the documented Playwright runtime.

Pinned source expectations come from `components/motion/multi-select/trigger.tsx:138-254`, `context.tsx:235-270`, and `list.tsx`. Empty-query Backspace removes the final selected ID once. Nonempty-query Backspace edits input text without a selection proposal. Chip click removes its ID and focuses the input; input focus opens the popup. Controlled rejection retains visible values. Disabled rows reject selection, and enabled-option traversal skips them. The source input dependency bytes, including `use-active-option.ts`, are retained in `source-inputs/` and mapped by `source-input-bindings.json`.

## Demonstrated discrepancy

With the popup open, clicking the Alpha chip's remove button in Flutter closes the popup without invoking `onChanged`. Alpha remains selected even with the accepting owner. React emits the removal proposal, updates chips when accepted, retains chips when rejected, and keeps the popup open. Both retain native input focus. This repeats under both motion preferences.

Reproduce on the accepting fixture: click the input, press Backspace once, type `zz`, press Backspace twice, then click Alpha's X while the popup is open. Immediately before the click, selected IDs are `[alpha,beta]`, query is empty and the callback history is `[[alpha,beta]]`. React adds `[beta]`; Flutter adds nothing and closes the popup. With rejection, React proposes `[beta,gamma]` while retaining all three chips; Flutter again adds nothing.

The candidate uses `BeuiOverlay` with its default barrier enabled in `multi_select.dart`; `beui_overlay.dart` builds an opaque-hit-test full-screen dismiss gesture behind the popup content. This is consistent with the click being consumed as dismissal. This task establishes the behavior, not a reviewed repair. Do not change shared overlay behavior solely from this report.

## Attempts and recorder corrections

All original PNG frames, checkpoint PNGs, timestamp videos and frame-index replays are retained, including unsuccessful attempts.

- Attempt 1 established the chip discrepancy, then timed out looking for a disabled row after the popup had closed.
- Attempt 2 reopened the candidate popup but used the source-style exact accessible name `Disabled`. Flutter's observed name is `Disabled Disabled`, so the locator timed out. It also clicked the input again before keyboard traversal, which was unsuitable for testing the candidate with its popup open.
- Attempt 3 removed that input click. The source's disabled-row pointer click left native focus on BODY, so its keyboard inputs did not exercise the combobox. Its failed keyboard assertions are recorder precondition failures, not source component defects. The candidate still hit the disabled-name timeout.
- Attempt 4 uses the observed disabled locator and explicitly presses Escape, waits for close, and clicks the input to start the independent keyboard sequence. Home, ArrowDown and Enter are recorded separately. After the demonstrated pointer discrepancy, only the independent disabled checks rebase on the observed owner selection and callback history. The pointer discrepancy remains a failed assertion.

`capture-attempt1.mjs`, `capture-attempt2.mjs`, `capture-attempt3.mjs` and `capture.mjs` preserve each recorder version. `source-build.log` retains the initial missing-script error after setup stopped because `pubspec.lock` is untracked. Setup was corrected to export committed production and copy the local dependency lock separately. `source-build-r2.log` retains the missing `lucide-react` build error; `source-build-r3.log` is the successful build with a task-local icon dependency. No footage existed for these setup failures.

## Evidence and replay

`attempt-4/*/results.json` contains native active-element details, actual DOM input values, rendered chip labels, accessibility snapshots, callback payloads/counts, popup observations, trusted event logs, browser version and served-resource hashes. The source exposes a DOM listbox; candidate popup presence is observed through the Flutter accessibility Options group and rows, not an invented listbox role. `__fixture` reports only fixture-owned values and public callbacks. There are no recorder calls to focus, component internals or event dispatch. The sole synthetic click activates Flutter's semantics placeholder before the behavioral sequence, following the existing repository workflow; it is explicitly identified in the event log and excluded from trusted behavioral-input claims.

`identity.json` verifies every candidate Dart library file against the specified commit and each bundled reference component against the pinned Git source. `input-lock.json` locks fixture inputs, library snapshots, built assets and dependencies. `served/` retains response bytes; the offline verifier requires the observed main bundle to match the archived build. `source/inputs.json` and the bindings file retain bundler input identities. Font CSS and fixture layout are supplemental and are not an exact-pixel comparison.

Run `python3 verify.py` from any regular-file export with Python, Pillow, ffmpeg and ffprobe installed. It checks archive bytes, input/source bindings, served bundle identities, every checkpoint/frame hash, decoded video counts, and RGB equality of every frame in the lossless frame-index replay. Timestamp-video count differences are reported rather than hidden. The 25 fps replay proves frame preservation, not original timing. `archive-sha256.json` excludes itself and verification output logs.

No general parity, native60, exact pixels, screen-reader, mobile, hosted CI or release-readiness claim is made. Native here means trusted browser keyboard/pointer behavior, not an iOS/Android device certification.

## Final bounded observations

Attempt 4 completes all eight runs. Empty-query Backspace, `zz` to `z` editing without token removal, accepted/rejected selection ownership, disabled pointer exclusion, and Home/ArrowDown/Enter skipping Disabled behave as expected in this fixture under both motion preferences. The open-popup pointer-removal discrepancy fails in all four candidate runs. Candidate post-failure disabled checks deliberately start from its actual retained selection; callback payloads therefore differ from the already-updated accepting source sequence for a documented reason.

An additional closed-popup check emits the correct removal callback on candidate, but its native active element settles on FLUTTER-VIEW or FLT-SEMANTICS and the popup stays closed. Source rejecting-owner runs settle on INPUT and reopen the popup. `supplemental-checks.json` asserts this discrepancy against the source focus/popup expectation and validates exact callback payload, chips and actual query. This is a demonstrated native focus/popup difference; subsequent typing after this closed-pointer check was not measured, so no claim about lost keyboard input is made. The source accepting sequence had already removed Alpha, so this extra closed-pointer comparison uses rejecting owners on both sides. Candidate accepting closed-pointer observations are supplementary.

Disabled pointer input does not retain input focus on either side: source reports BODY and candidate FLT-SEMANTICS. Both retain selection, callback history, query and popup. These distinct native tags are preserved, not described as identical focus. `analyze.py` rechecks these facts from retained observations.

## Export verification result

The regular-file export at `/tmp/beui-multiselect-native-export-20261023` passes the portable verifier across 32 retained runs, 4,761 original frames and 340 checkpoint PNGs. All lossless frame-index replays decode to the exact original RGB bytes. Attempt 4 source/no-preference/accept has 274 PNGs but 273 decoded timestamp-video frames. Its 274-frame replay is complete; timestamp timing is not certified. The final recorder has 342 checks with 12 failures, all for the demonstrated open-popup removal discrepancy. The supplemental analyzer records eight closed-pointer focus/popup expectation failures. Verification validates these recorded discrepancies rather than turning them into passing behavior. See `verification-summary.json` and `verify-export.json`.

Ports 18161 and 18162 were free before startup. Only this task's matching server processes were stopped after capture. No listeners remained at the final check.
