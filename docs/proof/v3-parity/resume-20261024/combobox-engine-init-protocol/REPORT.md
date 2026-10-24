# Initialization protocol boundary

Stopped at the ownership/initialization design gate. No repair candidate is safe to build or deploy from this experiment. An extension added only at `setClient` cannot satisfy the specified contract for an already editable semantic field, including edits before client availability. This is a boundary of that minimal design, not a proof that every engine/framework redesign is impossible.

## Contract and existing metadata

`CONTRACT.md` was written before running the experiment. A field lifetime and connection generation must be bound explicitly and authoritative initialization must finish before ordinary browser editing begins. Later owner commands remain authoritative. Dropping keys during a readiness interval would violate input preservation. Capturing a snapshot after the browser edits would repeat the rejected r9 approach.

The pinned source audit found:

- `TextInputConfiguration.toJson` carries view ID, input configuration and optional autofill data, but no semantic node, field lifetime, connection generation or readiness marker. A view identifies many fields. Autofill is optional, can operate on disconnected clients, and has no semantics-generation contract.
- `RenderEditable.describeSemanticsConfiguration` supplies text, selection, focus, actions and input type. It does not publish a text-client generation or an authoritative initialization commit. The generic semantics identifier is not assigned as a text connection identity. Reusing it would require a new coordinated contract, not demonstrate existing metadata sufficient.
- `_PlatformTextInputControl.attach` sends the numeric connection ID and configuration. `setEditingState` sends a value alone. Clear and show are also untagged. `TextInputSetClient.run` only stops editing when the numeric ID changes. Same-ID replacement cannot invalidate old callbacks under the requested generation contract.
- `EditableTextState._openInputConnection` captures the local value, attaches, sends that value, and shows. It does not wait for a component's opening state or expose an owner initialization transaction. A command named initialize could label that captured value, but would not prove it is the final opening value.
- `SemanticTextField` creates and exposes an enabled input before a client exists. DOM focus dispatches a semantic focus action. The editing strategy stores configuration at enable and installs handlers only when focused semantics calls activate. The r10 native trace already demonstrates trusted input in this interval.
- `SemanticsTextEditingStrategy.addEventHandlers` omits the ordinary strategy's `beforeinput` and composition handlers. Initialization ordering alone cannot qualify delta or IME behavior.

All audited files are copied under `inputs/r10/`, with original paths and hashes in `input-references.json`. The r10 compile recipe is retained there. No r10 source or artifact was modified.

## Executed experiment

The isolated engine, Dart SDK and resolved dependencies were copied from r9 using filesystem copy-on-write into `/tmp/beui-engine-init-r11`. The r9 snapshot repair was immediately replaced with its original instrumented semantics source. Package configuration was rebased inside r11; there was no dependency resolution, SDK installation or shared cache write.

The first test run retained all 22 r9 cases and added six active lifecycle cases. It ran the existing semantics text-field and general text-editing suites too. Result: 156 pass, 12 fail, 5 skip, exit 1. The first repeat restored both behavioral engine files byte-for-byte from the archived r8 original sources, moved the trace recorder into a test helper, and added active backward-selection coverage. Result: 157 pass, 12 fail, 5 skip, exit 1.

The final run corrects the new active IME setup so compositionstart, compositionupdate and beforeinput precede the first DOM input; it also specifies composition-end and duplicate-delivery assertions. Its result is recorded in `results.json` and `logs/final-uninstrumented.log`. The old preactivation IME case is retained unchanged for comparison. Assertions after a failing assertion are unqualified, including the new composition-end assertions.

The final original-source run comprises 29 boundary/lifecycle cases plus the two existing suites. The 11 boundary failures are the four original retention contracts, pre-client retention, preactivation backward selection/delta/composition, active delta, active composition, and same-ID replacement. The opposite explicit-owner-empty cases pass. The empty-retention and explicit-empty-rejection cases intentionally encode opposite meanings on identical legacy commands; they are evidence for needing a discriminator, not a satisfiable legacy-protocol gate.

Active ordinary full-state input, acceptance, programmatic replacement, intentional empty rejection, synchronous reentrant rejection, P/Pr/Pro ordering, backward selection, disposal with subsequent detached-element events, and duplicate semantics/selection notifications pass in their tested orderings. The inherited clear/rebind, changed-client switch and focus cases also pass. These are synthetic engine cases; none demonstrates framework owner acceptance in a real widget or native IME.

The existing semantics text-field suite has 22 passes. The existing general text-editing suite has 117 passes, 1 failure and 5 skips. Its `text editing styles invisible element` case expects CSS border width `none` or `medium`, but Chrome returns an empty string. That failure occurs on original sources in every run and is retained, not waived as a green suite. Its cause was not investigated within this ownership task.

## Why the minimal extension stops here

Consider a semantic input exposed at time A, first browser edit at B, and setClient at C, with A < B < C. Adding `(field, generation, initialValue)` at C cannot make initialization precede B. Reading the focused element at C still guesses ownership. Replaying its value loses the event history. Preventing the edit until C loses real user input unless a different event-routing architecture preserves it. Deferring focus or typing would violate the requested experiment.

Even for C < B, merely moving activation to setClient still initializes the value captured by EditableText before the component's later opening write. Keeping that later empty write authoritative can erase input; suppressing it breaks intentional rejection. The engine cannot infer owner intent from the bytes. A readiness flag set by the same attach/show sequence does not add that information.

For these reasons no attach-only engine/framework patch was authored. There is no candidate patch, patched gallery build, candidate served trace, screenshot or frame hash. Native initial-entry and Escape/type repetitions were deliberately not run because the safe-test prerequisite was unmet. The preserved r10 baseline and native causal results remain prior evidence, not results for r11.

## Reviewable alternative

A prospective upstream design needs a pre-publication editing transaction, not an after-input repair:

1. Framework allocates a field-lifetime token before publishing its editable semantic element. It publishes a matching token through semantics and a dedicated engine preparation message; it does not repurpose an optional accessibility identifier. Engine keys it by view and field lifetime, independently of numeric text client ID.
2. Owner participates in a defined initialization transaction. Any focus/open-derived text change must finish before the transaction commits. Commit carries full text, directional selection, composition, configuration and a monotonically changing connection generation. Existing arbitrary later controller writes cannot silently count as unfinished initialization.
3. Before exposing the field as editable, engine resolves the exact binding, applies the committed initial state once, and installs the complete ordinary event pipeline. Browser edits then arrive normally; no snapshot replay, key delay or readiness-window key discard is allowed. This requires preparatory per-field state before the current single active-client attach lifecycle. If a field must already be editable during preparation, this alternative is not yet sufficient and must be rejected too.
4. Owner commands and engine notifications carry that generation. Replacement, clear, disposal, and view teardown revoke it. Same-ID replacement creates a new generation. Later explicit writes, including empty, apply in protocol order. Reentrant delivery must not change the generation for an event already in flight.
5. Delta and composition handlers must be qualified in the semantic strategy, with backward selection preserved without reconstructing the DOM after input. Protocol tests must cover unmatched tokens, late commits, stale commands, node reuse, same-ID replacement, reentrancy and teardown, in addition to this retained suite.

This is an architectural proposal, not an implemented or validated alternative. It crosses framework rendering/semantics serialization, EditableText/text input, engine field lifecycle and owner initialization semantics. A general Flutter repair needs compatibility and accessibility review. A component-specific decision to preinitialize its query or change its focus/open contract would be a production workaround and requires user approval. No such change, automatic SDK pin, installation or deployment is authorized by this result.

## Evidence and scope

`tests.patch` is the test-only difference from r9. `source/` contains final tests and byte-for-byte original behavioral engine files. `results.json` lists every observed failure. Logs and decoded traces retain all runs, including the intermediate IME setup. `run.py` records the narrow command; its paths intentionally target the disposable r11 toolchain. `SHA256SUMS.json` and `verify.py` check archived integrity, original source identity, expected test outcomes and the legacy-command ambiguity. Verification success means the red evidence is intact, not that a candidate passed.

All authored files are confined to the two authorized new paths. There were no children, Git mutations, production beUI edits, shared SDK changes, commits, pushes, merges or external messages. No server or native browser session was started; the test runner's Chrome processes exited.
