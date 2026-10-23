Independent final r3 review: scoped acceptance. No demonstrated remaining finding in the requested chip-focus, owner-control and traversal scope.

Exact SHA-256 identities, verified against copied proof and unchanged after tests:
Production: b58e5bfb3c254357da25ae3af77ff22a0b5526160d77e8c3ec2e7496e87c95bb
Final tests: 3454dcecb1dc1cfaa8d94316018b5d678bd6dae25cb7b9a5720e4820c60d52b9
Candidate main.dart.js: a255b0c2d7cc003f37c41fe6e93208e10c952fed1a789889ae661ff5fe4bf0e8
Source source.js: d5cec73faa7b72a04322d99c9d8a0a963a8114edd534561a16073c702d0f4eaa
Source pin: a76e57c9bbc2837e96420b2610e9c82a3271bb05

Execution was confined to /tmp/multiselect-independent-r3, using run/ copied from the proof candidate and archive/ copied from the full proof. The shared production and test files matched these hashes before execution. No repo edits, git commands, native builds, broad suites, children, or goldens.

Executed:
1. flutter test test/precedence_test.dart --plain-name 'same previous owner': PASS, unchanged r2 repro. BEFORE and AFTER primary=external external=true. This directly closes the r2 demonstrated issue.
2. flutter test test/final_multi_select_test.dart test/precedence_test.dart test/prior_review_test.dart --name '^(?!.*golden).*$' --reporter expanded: 42 PASS. This comprises 32 final tests, five unchanged r2 controls, and five r1 controls with only removal tooltip finders adapted to semantics labels. Covers same-node and different-node owner requests, later external pointer before frame, outside blank pointer, explicit unfocus, disposal/replacement/disabled/close, semantic removal label/button/tap/no Tooltip, Escape callback counts and retyping, normal external-to-chip focus, forward/reverse traversal and controlled rejection, internal chip traversal and popup selection.
3. flutter test test/r3_test.dart --reporter expanded: four independent tests PASS. Verified input is already primary during onChanged, exact open:true -> selection callback order, owner override adds only open:false and remains external, no override retains select focus, controlled query/open rejection without any owner rebuild, and explicit focus on a popup option remains internal without close/query callbacks. Initial popup test used an unavailable optional Focus.widget.focusNode and failed in test lookup; corrected it to use the actual attached focus tree. Both logs retained. No production change.
4. python3 archive/verify.py: PASS. Eight recorded Chromium 156.0.8078.48 runs, normal/reduced motion and accepting/rejecting selection owners on source/candidate; 804 checks, 3749 original frames with RGB-exact frame-index replay. Hash locks, source bindings, exact served JS identity, screenshots, frame manifests, trusted-input exception restrictions and independent sequence assertions pass.

Read implementation and pinned context/trigger source behavior. External chip focus acquisition is synchronous before selection callback; focus destination changes and generation invalidate stale deferred intent. This deliberately changes open/focus callback ordering for externally started chip actions, now directly tested. Focus boundaries include both trigger and popup, skip null/scope-only transitions, and do not intercept Tab. Tab closes and clears, reverse return opens, and internal chip/popup focus does not close. Effective controlled query remains owner supplied.

Inspected recorded capture and verification assertions for full chip -> zz -> Escape -> xy -> Tab -> ShiftTab and direct-focus sequences. They check actual input destination/value, popup/query state, exact close/clear and return-open deltas, unchanged selection callbacks/values, rejecting close/query owners, later external pointer typing and disposal. Recorded native bundle hashes match the reviewed production proof. The fixture inherits isolated library inputs and is not an unchanged current gallery build, as disclosed in shared-checkout-differences.json.

Limits: exact same-frame/same-node owner precedence remains widget-only evidence. Saved native runs establish subsequent external pointer intent, not callback/microtask precedence. No fresh native/browser run. No screen-reader, full keyboard/exact parity, timing/60fps, physical-device, mobile, minimum-SDK, CI or release-readiness claim. Frame-index replay preserves content/order at synthetic timing; timestamp MP4 is not asserted frame-complete or RGB-exact. FileTree review is unrelated and excluded.

Evidence: same-node.log, tests.log, r3-tests.log, r3-tests-final.log, verify.log, run/test/r3_test.dart and copied archive/.
