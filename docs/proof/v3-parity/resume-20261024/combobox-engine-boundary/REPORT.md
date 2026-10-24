# Initial semantics editing boundary regression

The deterministic engine test reproduces initial text loss on the installed Flutter 3.47.1 sources. All four retention contracts fail. All four old-behavior characterizations and the activated-before-input control pass. The same result holds with the engine instrumentation removed. This proves the deferred listener/activation overwrite mechanism for the imposed ordering. It does not prove that every archived native failure followed that ordering, and it is not a native-input capture or an engine fix.

## Executed inputs and scope

Framework `6655482ec06e547f90abf8ae7590466f4415978d`; installed engine stamp `5d531788691ec3404cac0cee66ead4007b177363`; copied Dart 3.13.1; Google Chrome `156.0.8078.48` on macOS arm64. Source was copied from that installed framework checkout into `/tmp/beui-initial-edit-engine-r8/engine`, rather than fetched at an unverified newer revision. The engine stamp is an installed artifact identifier, not a claim that it was checked out as a Git commit. The SDK's engine files had no Git changes. `inputs.json`, `input-references.json`, and `engine-source-manifest.json` pin the relevant files and complete copied engine source inventory. The cached semantics runtime differs from the source only in packaging imports; text-editing runtime also strips annotations. No behavior-changing differences were found in these two files.

Only the new proof directory and disposable source/tools were authored in the workspace and scratch. No production code, shared SDK, prior archive, commit, push, issue, child task, SDK upgrade, gallery build, or broad suite was changed/run. One scope deviation: the first disposable `dart pub get` used the default user pub cache and may have populated it. Subsequent resolution and runs used a copied, isolated `PUB_CACHE` under the owned scratch directory. No SDK files were changed by that resolution. This cache mistake is recorded rather than claiming that every write was within the two owned paths.

## Experiment

`source/test/engine/semantics/initial_edit_boundary_test.dart` imports the existing `text_field_test.dart` semantics builder and text-input-channel helper. It creates an enabled unfocused node 0, focuses its existing DOM input, and sends setClient for client 42, a valid initial editing state, then show. It injects synthetic DOM input P with selection 1 before releasing the focused semantics update. It optionally sends a framework empty state after P and before activation. A second synthetic edit inserts r at the actual resulting selection. A repeated focused semantics update and selectionchange check duplicate delivery. No timer or scheduling probability is required within a case.

The four cases combine empty or `Design studio` initial state with absence or presence of that empty update. Each has a desired retention contract and a separate characterization of the old engine. The retention contract checks P delivery exactly once by activation completion, DOM P and selection 1, then Pr with selection 2 and exactly `[P, Pr]` delivered to client 42. It allows either early delivery or buffered delivery of P. Characterization cases intentionally describe the bug and must be removed or updated when a fix changes that behavior.

Observed results in both final runs:

- Empty initial state, no additional update: P delivery count 0, activation clears P, selection becomes 0, r produces `r`.
- Empty initial state, framework empty update: the same result.
- Selected-label initial state, no additional update: P delivery count 0, activation restores `Design studio`, selection becomes 13, r produces `Design studior`.
- Selected-label initial state, framework empty update: activation clears P, selection becomes 0, r produces `r`.
- Activated-before-input control: P and Pr each arrive once on client 42, with DOM/selection preserved. The repeated semantic/selection notification does not duplicate delivery.

Both final invocations compile the single new test file with dart2js and execute it using the engine's felt Chrome test runner. Each exits 1 with **5 passing tests and 4 expected retention failures**. This is successful reproduction of an unresolved defect, not a green regression suite. `logs/run-final.log` is instrumented; `logs/run-uninstrumented.log` uses the original two engine source files byte-for-byte. Its test-only recorder remains active. The original-source run differs only by importing that recorder from a test helper. `run_uninstrumented.py` performs and records the source swap and restores the instrumented copy afterward.

## Cause established by the buffered trace

`run-final-trace.json` contains at most 200 entries per case, emitted after interaction through teardown. One Stopwatch supplies timestamps; list order disambiguates equal timestamps. IDs are the same retained semantic node 0 and text client 42. The recorder observes focus action dispatch, framework commands and client identity before/after them, semantics enable/activate/disable, listener addition and subscription counts, handleChange entry/equality, editing-state application to DOM, and decoded client receipt. It does not log during the input interaction.

In the first empty/no-update case, the sequence is:

1. DOM focus invokes the semantics focus action. The test withholds the focused semantic update.
2. setClient binds client 42. setEditingState records empty text. show calls semantics enable, which stores configuration/callbacks without attaching editing handlers.
3. The input has P and selection 1 while strategy.isEnabled is false and subscriptions.length is zero. Dispatching input causes no handleChange or client update.
4. Releasing focused semantics calls activate on the same node. Listener installation occurs now.
5. The activation path through DefaultTextEditingStrategy.enable replays lastEditingState. `EditingState.applyToDomElement` records old P and new empty text. The selected-label/no-update case instead records old P and new `Design studio`.
6. The r edit enters handleChange, compares unequal, and sends its actual post-overwrite text to client 42. A later selectionchange compares equal and sends nothing.

This establishes listener absence followed by activation's stale-state DOM write. It does not depend on a component rebuild, connection teardown, wrong client, or callback rejection. No component exists in this engine test. The optional empty update changes the state replayed; it does not cause the listener gap. The test sink replaces the framework platform-message callback, so it proves engine channel emission to the expected client ID, not actual EditableText receipt or a component controller write.

The archived buffered capture still has its original evidentiary limit. It records trusted DOM P without a Dart controller/onChanged P, followed by the component's empty write and later r delivery. `archive-excerpt.json` preserves the relevant Dart events and original browser inputs; hashes point to the untouched full archive. The deterministic result establishes a matching engine mechanism, but adds no instrumentation retroactively to that native run. A new bare TextField/gallery capture was unnecessary for this engine boundary test and was not run.

## Prerequisites, failures, and reproducibility

The installed engine source is about 68 MB. Dart and the packaged web SDK were copied, avoiding gclient, ninja, a source SDK build, and upgrades. `felt --list` selected only `chrome-dart2js-canvaskit-engine` and the supplied test file. Chrome was provided using CHROME_EXECUTABLE.

Preserved failures:

- `compile-1.log` reports compilation failure; `compile-2.log` adds the concrete diagnostics. The test initially treated DOM selection doubles as ints. Conversion fixed the test.
- `artifacts-1.log` shows the stock copy-artifacts phase building its real host and copying primary fonts, then failing because `third_party/google_fonts_for_unit_tests/` is absent. No success is claimed for that phase. The needed flutter_js and CanvasKit artifacts were copied directly from the pinned packaged web SDK into `engine/src/out/web_tests/artifacts`. These semantics tests do not request fallback fonts or Skia test images. No placeholder assets or JavaScript imitation were substituted.
- `run-1.log` contains nine setup failures caused by the test configuration omitting required textCapitalization. Adding `TextCapitalization.none` fixed setup.
- `run-2.log` contains the first valid 5-pass/4-fail instrumented result. `run-final.log` has the final retention oracle, which allows P delivery before activation. The final original-source control is in `run-uninstrumented.log`.

`REPRODUCE.md` gives the exact narrow run and fresh-copy setup. `regression-and-trace.patch`, baseline/source files, lockfile, package configuration, logs and decoded traces are retained here. Package configuration contains the original absolute scratch paths. Portable reproduction needs the pinned SDK source/artifacts, Dart, Chrome, and dependency downloads or a populated cache; this is not a bundled SDK or hermetic offline artifact. No Flutter command was run against the shared installation.

The runner processes and owned Chrome instances exited. `process-cleanup.json` records no remaining process whose command includes the owned scratch root. No owned server remains running.

## Acceptance required for an engine fix

There is no speculative repair in this work. A fix must make the four retention cases pass and keep the activated control passing. Additional acceptance is still required for:

- Binding buffered/early edits to the correct semantic node and configured text client, including input before client availability, setClient/clearClient, switching focus between fields, and disposal.
- Preserving base/extent, directional selection and IME composition, with correct full-state and delta updates.
- Distinguishing stale initialization replay from an intentional authoritative owner write. The optional empty update here models the opening component's stale query; the test is not a rule that all later programmatic empty writes should be ignored.
- Exactly-once delivery across activation, repeated semantics, selectionchange, blur/re-enable and client replacement.
- Normal focused programmatic changes, owner acceptance/rejection and focus behavior remaining valid.

The parent component repair remains separately accepted. Initial editing delivery remains a blocker.
