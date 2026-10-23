Independent r2 review: one demonstrated P2 owner-focus precedence issue remains.

Production SHA-256: dba8218b7d836f7a7d48994417a7573ca3682ef2daf5f62a27058aa49beafa12
Test SHA-256: 289355115e3a370e0f4a6e637857a8bcec307212972d2ff37f1a275403b244ee
Candidate main.dart.js SHA-256: f544c4de16cc8f6de38c90cb34d7d4f018ce21bb64719b864d0bf3e18922f25f

Before tests, copied production/test and complete multiselect-focus archive into this directory. Tests execute run/ copied from archived candidate, not shared checkout. Post-test production/test hashes remain identical.

P2: unchanged previous external focus bypasses owner precedence, production.dart:237-243.
Repro: an external TextField already has focus; tap Remove Alpha; owner's onChanged explicitly calls external.requestFocus(); flush microtasks before next frame. External remains primary focus. Pump/settle: deferred callback steals focus to beui_multi_select because focus == previousFocus bypasses rejection. This is widget-level demonstrated behavior, not a browser claim. A different external focused node is correctly protected. The guard cannot distinguish unchanged previous focus from an explicit owner request to retain that same node.
Run from run/: flutter test test/precedence_test.dart --plain-name 'same previous owner'
Evidence: precedence-confirmed.log; test/precedence_test.dart. Reproduced twice. BEFORE primary=external external=true; AFTER primary=beui_multi_select external=false.

Passed: 24 supplied non-golden tests plus five prior independent review tests, with only tooltip finders adapted to semantics labels. Original external pointer-before-frame regression now passes. Existing owner disposal, replacement, disable, close and different-node focus cases pass. Four added tests pass: synchronous new external owner focus, same-frame outside blank pointer cancellation, explicit owner unfocus, and removal-button exact semantics label / button flag / tap action / no Tooltip. Initial semantics test had a handle teardown error; explicit disposal corrects the test harness and passes. No separate demonstrated null-focus failure; null remains a broad allowed state, and widget owner-unfocus resolves to a scope node and is respected.

Native archive: reran archive/verify.py successfully, including input hashes, exact served JS identity, screenshot/frame hashes, RGB-exact replay decoding, trusted-input restrictions and independent behavior assertions. All 374 final candidate checks pass across four owner/motion combinations. Source recheck passes; documented original source chip-count discrepancy remains. Inspected baseline/final DOM traces: baseline ends BODY with empty query/closed, final retains INPUT through mutation tail and ends query xy/open with queries z,zz,'',x,xy. Saved native evidence supports repaired chip -> zz -> Escape -> xy behavior; no fresh browser run performed. Accessible removal name is independently verified in widget semantics, not a screen-reader session. No full native parity claim.

Logs: tests.log, precedence-confirmed.log, verify.log. No repo, old proof or git edits; no builds, children, broad suites or goldens. Known Tab mismatch excluded from new findings. Scoped acceptance withheld for owner-focus precedence above.
