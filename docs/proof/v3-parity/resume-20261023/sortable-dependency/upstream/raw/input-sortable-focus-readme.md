# Sortable focus investigation and partial repair

Undo focus is repaired with component-owned Flutter focus nodes. Native movement focus is **not repaired**. Strict parity remains failed. No engine, shared overlay, global DOM guard, or browser focus patch was made.

## Change and scope

The starting component SHA-256 was `2cd852ea3cbf4e377708c1043e6eadca06e12f20735ffdb06ef194c9850736af`. Its order-based `_canUndo` predicate and action guard remain intact. The component now owns one handle FocusNode per stable item ID, removes and disposes nodes when IDs leave controlled membership, and disposes all nodes with the root. Undo requests the first differing saved ID's attached, enabled node before publishing the restored order. A controlled owner's explicit focus request therefore takes precedence. There is no scheduled refocus, autofocus heuristic, global DOM change, or external-focus listener.

The previous `_focusedId` plus `autofocus` could not transfer keyboard ownership between already-mounted handles. `red-undo-focus.log` records the initial failing-first tests under both motion preferences. `red-final-input-replay.log` reruns the exact final test input against the preserved starting component and fails both Undo ownership tests. `test-exact-final.log` passes all 22 non-golden Sortable tests; `analyze-clean.log` has no issues. Tests exercise the next ArrowDown on restored B, external owner focus precedence, reparenting, removal/reintroduction, disposal during Undo, disabled handles, and the prior acceptance/rejection/Undo eligibility guards. Widget tests do not establish DOM focus retention.

Only `lib/src/motion/sortable_list.dart`, `test/motion/sortable_list_test.dart`, this new evidence directory, and scratch files under /tmp were changed for this task. The prior sortable-undo archive was read only. The MultiSelect worker's files were not edited. No children, commit, push, merge, broad suite, or golden updates were performed. PR26 was linked to this thread.

## Actual native mechanism

The original fixtures and capture sequence were copied from sortable-undo attempt 4. Source remains pinned at `a76e57c9bbc2837e96420b2610e9c82a3271bb05`. The only candidate fixture additions are read-only Flutter focus probes and focus-change logging. The recorder adds a MutationObserver; it does not wrap or replace DOM methods or change focus. The source and candidate supplemental compositions are behavioral comparisons, not visual or upstream-deployment replicas.

The trace separates two transitions. In `attempt-2-focus-nodes/candidate-no-preference/results.json`, `accept-focused` has Flutter primary node 901516279 and DOM Reorder A. At the subsequent semantics mutation, node 901516279 is still attached and primary, while the browser active element is already BODY. The same focused subtree is removed from one semantics parent and inserted under another. By `accept-move`, Flutter primary is node 139204620, the unattached scope seen at startup. Both motion preferences show this sequence.

The archived SDK files explain the causal chain:

- `engine-reference/semantics.dart` moves semantics children with append/insertBefore and reparents semantics wrappers. Removing the focused DOM ancestor causes native focusout.
- `engine-reference/view_focus_binding.dart` handles focusout with BODY active and no related target as a view-unfocused event.
- `engine-reference/view.dart` responds to a view-unfocused event by requesting root-scope focus. That parks keyboard input outside every handle.
- `engine-reference/focusable.dart` suppresses repeated focus values and schedules new focus values after the semantics DOM update. A same-node Flutter request is not a reliable DOM retention operation.
- `engine-reference/semantics_event.dart` explicitly documents FocusSemanticEvent as Android/iOS-only; it is not a supported web repair.

The initial outer FocusableActionDetector focus has no IconButton ancestor, so its probe `handle` is null. This does not mean there was no Flutter focus: primary identity, attachment, DOM label and native events are recorded separately. After repaired Home/Undo, the owned B node is primary and the active DOM node's text is Reorder B. Release-mode runtime type descriptions are minified and are not used as identity evidence.

## Native outcome

All keyboard and pointer inputs in completed reports are trusted. No driver calls `.focus()`, dispatches keyboard events, performs DOM clicks, or synthesizes semantics actions. Attempt 2 retains the original explicit native Tab recovery between certain checkpoints, so those later checkpoints do not claim uninterrupted retention. Attempt 3 removes every recovery after the initial native Tab setup.

| Attempt | Target | Checks per motion | Failures per motion |
| --- | --- | ---: | ---: |
| 1, starting component with trace | Source | 158 | 0 |
| 1, starting component with trace | Candidate | 158 | 10 |
| 2, owned focus nodes | Source | 158 | 0 |
| 2, owned focus nodes | Candidate | 158 | 8 |
| 3, uninterrupted ArrowDown/End/Home/Undo | Source | 24 | 0 |
| 3, uninterrupted ArrowDown/End/Home/Undo | Candidate | 24 | 10 |

Attempt 2 passes Home/Undo focus B in controlled and uncontrolled compositions under both motion preferences. Every order, callback, Undo eligibility, disabled-root, membership and reset check passes. The remaining eight focus failures per motion are accepted moves in the accept/reset/membership/uncontrolled scenarios and accepted End/Home in controlled/uncontrolled lists. Candidate passes 300/316 original-sequence assertions; source passes 316/316.

Attempt 3 proves the consequence without recovery. ArrowDown produces B/A/C once but loses focus. End and Home then produce no callbacks or order changes. Undo restores the actual saved A/B/C rather than the B/C/A expected from a functioning uninterrupted sequence. Those downstream failures are retained, not excused or reported as passing.

## Required wider boundary

The remaining issue needs a Flutter web semantics/view-focus fix with an explicit semantics-update transaction. A supported engine design should preserve native focused-node state during connected reparenting where the browser supports state-preserving DOM moves. Its fallback must distinguish reparent-induced focusout from a real user focus exit, resolve focus only after the final semantics tree exists, and respect removal, disabled nodes, view disposal, and a competing explicit focus request. This is a design direction requiring engine-level implementation and tests, not a validated patch. A component cannot safely infer whether BODY represents a real external focus transfer. No broad prototype interception, shared overlay/guard expansion, forced semantics flag toggling, temporary unfocus, or timed focus recovery was attempted.

## Archive and limitations

Run `python3 verify.py` in an exported copy. Run `python3 verify.py --require-parity` to enforce the behavioral outcome; it must exit 1 on the current evidence. In-place and copied-export integrity verification passed. The original sortable-undo archive still matches every preexisting manifest hash. Both owned server ports are released. Verification checks the full manifest, source pin/build bindings, served JavaScript identities, trusted events, every original PNG, decoded video frame counts, and independently recomputes final central outcomes from state records. `bindings.json` records exact hashes and SDK identity.

All 2,062 original screencast frames and all checkpoint PNGs/videos from the three new attempts are retained. Every timestamp video decodes exactly its original frame count in this run. `replay-mismatches.py` and the verifier support complete RGB-equal index replays if timestamp loss occurs; no replacement replay was needed here. The older archive's timestamp-loss evidence remains untouched. No native60, screen-reader, exact-pixel, hosted-CI, release, or deployment claim is made.

The uninterrupted driver completed all four reports and videos but remained alive after Chrome exited before writing its summary. Its owned PID was terminated; `capture-close-limit.json` records this and `summary-from-reports.json` is explicitly derived from completed reports. Both accidental root-directory build failures, the intermediate analyzer info, initial red logs, and every native failure are retained. Builds used the isolated fixture directory thereafter.

The candidate library snapshot comes from the original isolated Undo fixture, with only the owned Sortable file updated. Concurrent MultiSelect changes are deliberately absent from this native fixture. Source inputs, npm lock, original build script, candidate library/assets/shaders/locks/web inputs, baseline and final fixture probes, and both served builds are portable in this archive. Historical build scripts contain original /tmp paths; the offline verifier does not depend on those paths.

Exact final SHA-256:

- Component: `2ba3a4643a7fdeccc7521380a3749fb7ec9a4317f96ed2da3e2c24905a1068c4`
- Tests: `437d33d86ea8db87d12063a4ebddde3d57300c4f79b175ebb38e4bcc7026bfcf`
- Candidate served main.dart.js: `d6111750f882a6c894c5c58b4e429fbf219d026ae70541b5ecf426e30a713ec7`
- Baseline traced main.dart.js: `28c95f13682309e40be7dac62032ebaf5c031244cc212a92f8d5ce83ee828813`
- Source served source.js: `a461b82bed094f3566725f56ddb50014f7525e6d25b4dad8cc7e49add0a35928`
- Pinned source component: `740c2ae4c5d23455eb7ba61a60ab0ef2ee46d3bf986b0ff0e5ef6be329806027`
