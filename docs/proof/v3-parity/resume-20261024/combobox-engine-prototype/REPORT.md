# Rejected engine prototype

No safe repair was demonstrated. Do not ship this patch. Parent component initial-entry remains blocked pending native evidence. This experiment uses synthetic DOM events in the pinned engine's Chrome test runner, not native input or actual EditableText owner acceptance.

## Design and authority boundary

The candidate adds a listener to each semantic input. While the text client is editing but semantics has not activated, it saves one EditingState and the exact SemanticTextField object. Activation consumes only that field's saved state, performs existing initialization, restores the snapshot, and calls the existing handleChange path. Repeated activation consumes nothing. Every setEditingState invalidates the snapshot. Blur, disposal and disable invalidate it too, including disable before listeners have been installed.

This separates the engine's internal replay of an earlier initialization value from a later explicit framework command. It does not guess whether an explicit command is stale. The two original optional-empty retention oracles remain red deliberately. Their event sequence is indistinguishable from an owner intentionally rejecting P with an empty state: setClient(42), initial state, show, DOM P, setEditingState(empty), activate. The channel has no owner revision, acknowledgment, source tag, or semantic-node association in that command. The added authoritative-empty tests impose the opposite expected result on the same engine-visible sequence and pass. Ignoring that write would make the original oracle green by breaking legitimate owner rejection.

The old-behavior characterizations were removed from the new test suite. The four retention contracts remain unchanged; separate authoritative-write tests explain why two cannot be satisfied under this policy. Active owner acceptance, rejection, and programmatic replacement tests verify that P is delivered once, the owner write applies, and the next input is delivered once without selectionchange duplication. The sink is an engine platform-message callback, not a framework widget.

## Results

Final candidate expanded suite: 16 pass, 6 fail, exit 1. Existing semantics/text_field_test.dart: 22 pass, exit 0. Baseline with the same expanded suite: 14 pass, 8 fail, exit 1. Only the two no-later-write retention cases change from red to green. See results.json and the retained logs. The original-source comparison retains r8 instrumentation; r8 separately proved that instrumentation did not change the original four failures.

Candidate failures:

- Both optional-empty retention cases. Explicit later writes win; the matching authoritative-empty cases pass.
- Input before client availability. The listener cannot safely attribute that input to a future client and does not buffer it. Desired retention fails.
- Backward selection. EditingState reads base/extent direction, but applyToDomElement writes min/max without direction; restoration changes backward to none. The direction assertion fails before the subsequent base/extent assertions can establish preservation.
- Delta delivery. Reconstructed channel deltas yield empty then P instead of P then Pr. The test includes synthetic beforeinput with insertText data for both edits. Reusing handleChange alone does not preserve the necessary beforeinput/delta history.
- IME composition. Synthetic compositionstart/update before activation produces composingBase -1 instead of 0. The snapshot does not retain composition event history. This is not native IME proof.

The two no-later-write retention cases and activated control pass. Clear-client/rebind, changed-client replacement, switching focus to another semantic node, blur/refocus, and disposal cases pass. The switch case verifies old-node input does not reach client 43 and new-node input arrives exactly once. These cases establish only those explicit orderings. They do not establish a general client/node association protocol.

The existing narrow suite passed both during a combined invocation and in a standalone invocation. The combined invocation could not compile the new focus-switch test because it used the wrong test-helper argument. This is preserved in prototype-final.log, not presented as a clean combined run. Correcting childIds to children fixed the test setup. prototype-corrected.log is the 19-case intermediate run; prototype-expanded.log adds the three active-owner cases. No broad suite ran.

## Why this candidate is rejected

Restoring a DOM snapshot after initialization momentarily overwrites the live DOM and cannot preserve direction, composition, or delta history. It also coalesces multiple pre-activation inputs into one snapshot; that behavior has not been accepted as an exactly-once contract. The field listener remains attached for the DOM element's lifetime, and detached-element events after disposal have not been qualified. Client replacement with the same numeric ID, reentrant owner commands during activation, multiline inputs, and all browser/platform variants remain unqualified.

There is no explicit relationship between a text-channel client and a semantic node before focused semantics arrives. owner.isEditing plus DOM focus is not sufficient proof for all focus/client races. The pre-client failure is a design limit, not permission to attach an edit to whichever client appears next. Passing the switch test does not resolve this limit.

Rejected alternatives:

- Ignore all owner writes while a pending edit exists. This breaks intentional empty rejection and programmatic replacement.
- Treat an empty value, or a value equal to initialization, as stale. A legitimate reset has the same bytes.
- Activate whichever DOM input is focused when show arrives. The text channel supplies no semantic node identity; delayed commands can bind the wrong field.
- Restore text alone or synthesize a full-state update for a delta client. This drops selection/composition or changes the negotiated protocol.
- Buffer without ownership or lifecycle boundaries. This can replay edits into a replacement client or reused node.

A next design needs a precise ownership/ordering contract, either existing information demonstrated sufficient with adversarial races or an explicit protocol change. It must capture editing events before activation with their selection, composition and delta history, and avoid stale initialization replay without suppressing later authoritative commands. This investigation does not claim that a protocol change is always necessary for the narrower no-later-write defect. It establishes that the two opposing optional-empty meanings cannot be distinguished from these inputs alone.

## Scope and evidence

Only /tmp/beui-initial-edit-engine-r9 and this new proof directory were written. The engine, Dart SDK and pub cache were copied from sealed r8; package_config paths were rebased to r9 before execution. No pub resolution, shared SDK changes, beUI source edits, Git mutations, child agents, external posts or native runs occurred. Source revisions and installed engine stamp are inherited from r8-inputs.json. The stamp identifies an installed artifact, not a checked-out engine commit.

candidate.patch is the exact behavioral experiment relative to r8's instrumented semantics file. source/ includes the candidate and instrumented text-editing dependency plus final test. r8-regression-and-trace.patch preserves the earlier instrumentation for fresh setup. All trace buffers retain at most 200 entries and print only in teardown. results.json reports the observed maximum. No SDK caches are archived. SHA256SUMS.json and verify.py verify the small artifact set; process-cleanup.json records the owned-process check.
