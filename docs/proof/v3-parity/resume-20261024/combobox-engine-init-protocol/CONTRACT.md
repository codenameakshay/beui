# Lifecycle contract, fixed before experiment

An editable semantic field must have a framework-issued (view, field lifetime, connection generation) binding and an authoritative initialization commit BEFORE the browser can accept its first ordinary edit. The commit contains full text, directional selection, composing range, input configuration and owner revision. Neither DOM focus, a numeric client ID, equal text nor an autofill identifier proves this binding.

Prepared -> initialized -> armed -> revoked. Initialization applies once before arming. All beforeinput/input/composition/selection events after arming use the ordinary editing pipeline, in order and exactly once. Focused semantics updates must not replay initialization. A later explicit owner write, including empty, is authoritative. Reentrant owner writes must remain ordered. Replacement, including the same numeric client ID, invalidates the old generation. Disposal and clear revoke it before future events or commands can deliver.

The contract does not permit dropping the first key while waiting for readiness, recovering DOM snapshots, or assigning pre-client input to a client selected later. It does not permit treating every empty owner write as initialization. An attach-time extension must explain how a field that was already editable before attach satisfies this requirement.

## Deterministic red/compatibility cases

Retain all 22 r9 test cases on the original instrumented engine, without its snapshot patch. They include the four r8 retention requirements and the opposing explicit owner-empty requirements. Those two interpretations intentionally remain incompatible without a new protocol discriminator. Do not count them as a satisfiable legacy-channel green gate.

Add active-before-input delta and composition cases to separate preactivation loss from missing ordinary event subscriptions. Add active same-ID replacement revocation, disposed-element delivery, reentrant owner rejection, and ordered P/Pr/Pro delivery. Existing semantics/text_field_test.dart and text_editing_test.dart remain independent compatibility controls. Synthetic events are deterministic engine tests, not trusted-input proof.

Stop before native builds if ownership or initialization cannot meet this contract. Report a safe architectural alternative and its prerequisites; do not implement a lossy gate merely to make the lifecycle assertion pass.
