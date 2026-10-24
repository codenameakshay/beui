# Combobox rapid-input repair and remaining delivery failure

Partial repair, pending independent parent review. The component's stale-open callback defect is reproduced, traced and repaired. Initial native click/type can lose characters before Dart receives an editing update; that separate failure is preserved and is not declared fixed. No full gallery acceptance or release-readiness claim is made.

## Production change

`onChanged` now always requests open before query, matching the source trigger read at pin `a76e57c9bbc2837e96420b2610e9c82a3271bb05`. The input callback no longer consults an inherited scope's captured open value. `_setOpen` skips the deferred focus request when the input already has focus, preventing each edit from reclaiming focus that the user moves before the next frame. Controlled owners retain acceptance/rejection of open and query; callbacks remain open then query. Existing exit-list query freezing and FadeTransition opacity wiring are unchanged.

HEAD remains `6a9e699d8d8473829b8c569b30e6f5fa00741a62`. There were no Git mutations, children, shared overlay changes, golden updates or broad suites. Only the two assigned Dart files, this new proof directory and new scratch were authored. Normal focused-test tool caches were used.

| File | SHA-256 |
| --- | --- |
| Original component | `4d3d7dcccb86162b198182488cdaa022c8da61ef3d739d075f9eb1c377ca1fca` |
| Original tests | `af6be0fe80755361e1dcc12438207f6e6fd6c38440f18d02725cce217a3db1fe` |
| Final component | `ef7c79680a7208f9c593287a50fc30949b78e359b640a97aa78f9f7e4d316d97` |
| Final tests | `008bee629eded2697d5c29b9e873418bc3c886fe967c97401c6b4ecd75a34f95` |

`baseline/` holds pre-edit source/test bytes and diagnostic component variants. `final-source/` holds final source/test bytes. `identity.json` records SDK source identity as well. The pinned source path was available for the initial trigger read but disappeared later; it was not modified by this task.

## Causal evidence

`captures/trace-baseline-2/combobox-no-preference/results.json` reproduces the exact original Product/Escape/Play/ArrowDown/Enter/zzzz/Escape/Pro sequence. The trace after `setQuery("zzzz")` shows all grouped options unregistering. The item map is empty by frame 149. The overlay dismissal callback runs first on Escape, closes the model and writes empty text because the selected label is no longer registered. The local Escape handler then sees closed state. Each P/r/o editing update reaches the controller and `onChanged` in that same frame with captured open=true and live open=false. The callback skips reopening; `_setQuery` writes empty text again. There is no later dismissal needed to explain the loss. The browser input node remains node 4, connected and focused. The ArrowDown control subsequently reopens. This discriminates the captured callback/controller path from a portal-opacity failure or missing Dart delivery in this sequence.

`trace-product-1` repeats with selective `Product`. Normal motion again fails with empty text; reduced motion passes. `trace-baseline-2` reduced motion also passes. Thus the traced stale-callback failure is timing-dependent and is not represented as failing every repetition. The original sealed run-1 failures under both preferences remain untouched in `three-components-native/`.

Two widget tests send an editing update after Escape without pumping a rebuild. Both fail against original production with expected `ban`, actual empty text (`failing-first.log`). Both pass after repair. This is failing-first evidence for the stale callback, not for initial native editor delivery.

## Separate initial-entry boundary

The first uninstrumented candidate, with unconditional reopening but before the focus guard, loses `Pro` from initial `Product`, leaving `duct` in `captures/final-pro-1/combobox-no-preference/`. Trusted beforeinput/input events prove P/r/o reached connected DOM node 4; no node replacement or blur occurred. Its DOM value is empty by the subsequent d keydown. This candidate had no Dart trace and cannot by itself identify the controller or engine write.

Buffered instrumentation then reproduces reduced initial entry in `captures/buffer-sequence-2/combobox-reduce/`, leaving `roduct`. Browser `input` records P at 1823.9 ms. Dart logs the P keydown, but no controller update or `onChanged` for P. The next component build still has query empty and controller `Design studio`, then writes empty text. Later r/o/d/u/c/t updates reach Dart normally. The same browser input remains focused/connected. The screenshot visibly shows `roduct` and Product team. Exact option-set assertions alone would miss this failure; the retained-text assertion catches it.

Installed Flutter 3.47.1's `sdk-semantics-text-field.dart` explains the relevant boundary: `enable` stores editing callbacks; the native focus handler invokes the semantics focus action; `update` activates the editing strategy when semantics reports focus; `activate` installs editing behavior via `super.enable`. That is consistent with the observed pre-activation input gap. We did not instrument SDK listener registration directly, so this is a localized delivery boundary, not a fully proven SDK patch. No DOM-value recovery, synthetic focus, printable-key emulation, engine mutation or speculative portal change was added. A component callback cannot recover characters it never receives without an additional design decision. This remaining issue needs parent follow-up rather than being hidden by a wait or weaker oracle.

The console-logging trace passed three initial-entry repetitions per preference. The buffered trace passed three standalone initial repetitions per preference, then one of three full-sequence repetitions per preference reproduced the reduced initial failure. Instrumentation changes scheduling; none of those pass counts proves absence of the bug.

## Tests and build

Flutter 3.47.1 / Dart 3.13.1: 30 focused non-golden tests pass (`final-focused.log`), covering interactions and exit filtering. Seven new cases comprise two no-rebuild Escape regressions, four controlled-owner combinations with exact callback order, and one focus-precedence regression. The focus case failed against the first one-line candidate (`focus-candidate.log`), then passed with the focus guard. That is a candidate regression, not an original-production failing-first claim. Final targeted analysis is clean (`final-analyzer.log`).

Actual minimum Flutter 3.44.2 could not be rerun: the previously documented `/tmp/beui-min-sdk-3442-20261023-evidence/flutter/bin/flutter` is absent. Available version directories do not contain 3.44.2. Prior review results are not substituted for this final diff. No golden, broad-suite, hosted-CI or physical-device claim is made.

Fresh final command is `flutter build web --release --no-pub`, in the isolated actual-gallery copy. `final2-inputs/` and `final2-inputs.json` contain exact package/gallery sources, assets, manifests, locks and resolved configuration used; `final2-build-command.json` records command, duration, status and input stability. `final2-web/` contains complete output. `final2-build-manifest.json` hashes every output, and `served-final2.json` verifies every HTTP-served output against it. External SDK/pub-cache dependencies are referenced by the retained package configuration, not bundled as a portable rebuild environment. Earlier trace, buffered and first-candidate builds are separately retained.

## Capture workflow and limits

Installed Google Chrome is driven with Playwright-core 1.58.2, matching the recorded prior capture dependency. The old runtime had been removed; this task installed a new scratch runtime and preserves its lock. The copied old package-lock had external-path entries and failed `npm ci`; that failure and the exact-version replacement install are retained. Real gallery route `?slug=combobox&theme=light&captureProbe=1`, 1440x1100, device scale 1, light theme. Both motion preferences are checked against the gallery/platform probe. Native keyboard.type, keyboard.press and pointer clicks are used. Only the semantics-placeholder bootstrap click is synthetic. No fill, insertText, DOM value assignment or synthetic focus is used.

Browser records include stable node identity, connectedness, values, selections, beforeinput/input inputType/data, keys and focus events. Dart diagnostics are bounded to 1200 events per instance; console and buffered versions preserve open/query/value/controller/registration/frame-counter/focus information. Frame counters and CDP timestamps are not native60 or animation-cadence proof. Screenshots/semantics sample after the inherited 450 ms policy, not an atomic model/render snapshot. Diagnostic logging was removed from final production/build.

The initial trace attempt accessed `currentFrameTimeStamp` outside a frame and failed to render the component. Those aborted captures and build attempts are retained; they establish no behavior. The corrected trace uses a persistent-frame counter. The later turn interruption stopped the owned server; the first final2 batch records connection-refused failures. Retry captures use a freshly allocated port. All original failures remain preserved. Final retry batch: all 6 rapid Escape/type sequences pass (2 Product and 1 Pro per preference), and all 12 ArrowDown controls pass. Standalone initial entry passes 5/6; reduced Product loses Pro and retains duct with Design studio plus Product team, in `captures/final2-retry-initial-product-1/combobox-reduce/`. This reproduces the unresolved failure on final uninstrumented production bytes. Final main.dart.js SHA-256 is `67e0df9436486b4e733caa45b726f70867e1bb0cbe778d154acb450b0b07fe2c`. See the per-case records in `acceptance.json`. The owned restarted server was stopped and its port closure verified in `server-stopped.json`.

## Portable verification

Run `python3 verify.py` from a regular-file export with Pillow and ffmpeg installed. It checks archive hashes, input/build/served hashes, original screenshots/frames, trusted-event exceptions, effective preferences, the exact retained failure set and lossless replay RGB equality. It does not need browser/network/cache access. Integrity and behavioral acceptance are separate. The known initial-entry delivery failure remains a blocker even if the bounded final retry batch passes.
