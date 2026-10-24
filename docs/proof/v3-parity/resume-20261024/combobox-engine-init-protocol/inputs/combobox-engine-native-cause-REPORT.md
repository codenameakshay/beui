# Native gallery listener-gap cause

The actual compiled Flutter web engine reproduces the listener-gap cause in the real gallery under trusted Chrome input. This closes the missing causal link for the captured failures. It does not establish a safe fix or approve the rejected r9 prototype.

## Pinned build

The copied workspace was HEAD `313a9627e97a148377dd8bd92c9e3920e950a0fd`. Combobox SHA-256 was `ef7c79680a7208f9c593287a50fc30949b78e359b640a97aa78f9f7e4d316d97`. `inputs/` and `copied-inputs.json` pin the complete gallery/package inputs copied before instrumentation, including the other source files the parent may subsequently format. The copy uses current workspace lib and example/lib plus the sealed final2 assets, manifests and lockfiles. Resolved dependency roots were copied and rebased inside the scratch directory.

Installed Flutter 3.47.1 framework `6655482ec06e547f90abf8ae7590466f4415978d`, engine artifact stamp `5d531788691ec3404cac0cee66ead4007b177363`, Dart 3.13.1. The engine stamp identifies installed artifacts, not a checked-out engine revision. The packaged dart:_engine sources, Dart SDK, Flutter tools and framework were copied to `/tmp/beui-gallery-engine-causal-r10/sdk`. The bundled kernel_worker_aot snapshot rebuilt dart2js_platform.dill with the same arguments specified by engine/web_sdk/BUILD.gn. Both the unmodified-source platform compilation and instrumented-source compilation exited 0. No gclient, ninja or shared SDK changes were needed.

The real gallery was built with the copied Flutter tools snapshot, `build web --release --no-pub`. It consumed the newly compiled instrumented platform dill. A second build restored all five diagnostic source files byte-for-byte and used the original installed platform dill. These are actual framework/engine builds, not JavaScript simulations of their behavior. Compiled output includes the trace calls at the real engine command dispatcher, handler registration and editing methods. `compiled-channel-dispatch.txt` preserves the release minifier mapping: aZq is setClient, aZs is setEditingState, aZv is show, aZi is clearClient. Client identity is recorded before and after every command. A minified type name alone is not treated as a protocol name.

## Native causal order

`instrumented-initial-3/combobox-reduce/results.json` and `causal-timeline.json` retain this ordering, in milliseconds from the same browser performance.now clock:

1. At 1767.2, setClient changes null to client 1. At 1768.0, semantics enable reports disabled editing and zero subscriptions.
2. Trusted input on DOM node 6 produces P at 1773.9, Pr at 1774.6, and Pro at 1775.2. The same node stays connected. No engine handleChange, channel update, EditableText update or Combobox onChanged receives these edits.
3. At 1794.3, the framework controller changes Design studio to empty. The engine receives that state while still disabled.
4. At 1799.7, semantics activation identifies semantic node 68 and the same DOM node 6, whose value is still Pro, selection 3, with zero editing subscriptions.
5. At 1799.9, the engine installs its input handler. At 1800.0, EditingState.applyToDomElement records old DOM Pro and new empty text, selection 0. The next trusted keyup observes empty text.
6. At 1811.5, trusted d reaches handleChange. It reaches channel client 1, EditableText, its controller, and Combobox onChanged. u/c/t then produce duct, visible in the screenshot and retained-text assertion.

Three other captures in the original 12-case instrumented batch show the same order. Normal-motion full run 2 loses Pro. Reduced-motion full run 2 loses all Product. Reduced-motion full run 3 loses Prod. The verifier independently checks each failed initial entry for early trusted edits, exact node identity, disabled activation with zero listeners, absence of delivery, late input subscription, and matching stale replay. Successful instrumented controls activate before their first input.

The result matches the r8 imposed mechanism and includes r8's optional later-empty ordering in an actual gallery. The framework's empty opening write is real; an engine repair cannot safely classify every later empty owner write as stale. The observation therefore does not rehabilitate r9's snapshot restoration or its six failing contracts.

## Controls and limits

The bounded batch has three initial-entry repetitions and three full-sequence repetitions per build, each under both motion preferences. Full sequences use initial Product, Escape, Play, ArrowDown, Enter, zzzz, Escape and Product. An additional full sequence per preference/build ends with Pro to retain the original archived sequence too. All interaction uses the archived native pointer/keyboard workflow. Only the inherited semantics-placeholder bootstrap click is synthetic. No fill, value assignment, synthetic focus, delayed typing, or imposed engine ordering is used.

The untouched baseline reproduces reduced initial loss, retaining roduct in initial run 3. The later Escape/type assertions pass in the bounded captures. Initial loss occurred in 5/14 instrumented captures and 1/14 untouched captures. All 8 later Escape/type sequences per build passed. Every failure is retained in expected-failures.json and verification.json. These are small sequential samples, not failure-rate estimates. Instrumented runs initially overlap the baseline compilation on the host; recording, compiler load, synchronous trace allocation/JSON encoding, and per-event performance.now reads all affect scheduling. The baseline shares browser event recording and screencast overhead but has no engine/framework/component diagnostics. Differences in frequency cannot be attributed solely to instrumentation.

The trace sink is a bounded 12,000-entry in-memory recorder. It only observes nodes and stores records; it does not install editing behavior or replay values. Engine calls and browser event recording share performance.now and one WeakMap node registry. They use separate arrays, so equal timestamps across those arrays have no claimed total order. The decisive lost-input versus activation/replay boundaries have distinct timestamps. Within the engine trace, array order is retained. No buffer drops or page exceptions occurred. Listener removal and client clearing are instrumented, but the requested sequences retain focus and do not qualify teardown/client-switch behavior. This is Chrome headless native trusted-event evidence, not physical typing, native IME, browser-matrix or performance proof.

## Next bounded design

No safe production patch is established. The next engine design should make the ownership transition explicit: bind a semantic field and client generation, finish authoritative initialization, and arm the ordinary editing pipeline before that field can accept trusted edits. It must preserve beforeinput/delta history, composition and directional selection through that transition, and keep later owner commands authoritative. Whether existing metadata can enforce that ordering safely remains a design question. Pre-client edits cannot be assigned to a future client by guesswork.

A disposable engine/framework protocol experiment should first establish this ownership/initialization ordering and test delayed focused semantics, intentional empty rejection, client replacement, disposal, backward selection, deltas and IME. Only then should it attempt native gallery qualification. The native causal evidence justifies that investigation; it does not justify suppressing writes, recovering DOM text in Combobox, or shipping r9. A production workaround still requires explicit user approval.

## Preservation and scope

All authored source/artifacts are confined to the owned scratch and proof directory. No production source, shared SDK, previous proof archive, commit, push, merge, external post, child task or broad suite was changed/run. The first gallery compile failed because diagnostic imports preceded a library directive; its log remains. Correcting directive placement produced a successful build. The first build process redirected its HOME into owned scratch; later builds used dedicated configuration variables instead. Default Flutter web builds also performed their standard Wasm dry-run compilation; there was no Wasm runtime qualification.

Both complete web outputs, served-file hashes, source snapshots, diagnostic scripts, raw traces, screenshots, original screencast frames and replay videos are preserved. All 68 HTTP-served files per build matched build hashes. `verify.py` checks archive integrity, copied inputs, build/served identity, captured frame/screenshot hashes, trusted-event exceptions, expected failures and native causal assertions. Verification success means the evidence is intact, not that initial entry passes. Owned servers are stopped and their ports checked in process-cleanup.json.
