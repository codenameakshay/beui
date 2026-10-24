# Independent read-only combobox review

Verdict: scoped acceptance; no blocking finding in the two production changes.

Reviewed working bytes against HEAD 8fd89f601014e069e6258bd0575453e5a179ebee and React source pin a76e57c9bbc2837e96420b2610e9c82a3271bb05. HEAD combobox SHA256 is 2e89491d93b309e30fdb0847b570bbdf0f7191581ce10da6f599f31b52dc5a39. HEAD contains the sampled-opacity dependency, but was not separately built or exercised natively by this review.

Exact candidate identities:
- lib/src/motion/combobox.dart: 4d3d7dcccb86162b198182488cdaa022c8da61ef3d739d075f9eb1c377ca1fca
- test/motion/combobox_test.dart: af6be0fe80755361e1dcc12438207f6e6fd6c38440f18d02725cce217a3db1fe
- source-build/source.js: 5334af13db05dfdaacba8bd2a569a791bc542cbf1d0660a04977b4eaea5d97e1
- baseline-build/main.dart.js: b4363be82f600ecaff0f0e37d7ff1e41bf7a761f37b8a1f19ebcfa4d354e85d1
- candidate-build/main.dart.js: c869b255209659a044043eb700ad7f6f44f15a9d94b27287e76a927c7f82141a

Live owned files, isolated tested copies and archived candidate inputs match. All five exact-hashes.json entries were independently hashed. Checked 2651 archive-lock entries excluding frame-directory files and video containers, zero mismatches. Checked all 1992 source input hashes and compared nine reference repository inputs byte-for-byte to git objects at the source pin. Eight raw observations identify matching served bundle hashes; reduced baseline ends with input apl and no panel; both final candidates and both final sources end with apl, Apple-only rows and input focus. Final reduced candidate reopened.png was visually inspected. The sole untrusted event per candidate is the disclosed FLT-SEMANTICS-PLACEHOLDER click. identity-review.log records raw final samples and script hashes. Parent owns full archive/frame/replay verification; this review did not decode videos.

Source contract review:
- openQuery is initialized from effective query and updated only on open renders, as in source context.tsx. Closed list filtering retains the last rendered open query while input text remains based on effective state/selection.
- Registered-option visibility, row visibility, group visibility and empty-state lookup all use listQuery. Inherited notification includes listQuery. Controlled owner acceptance/rejection is respected; rejected close keeps effective open filtering current.
- FadeTransition takes the overlay AnimationController directly, so opacity updates no longer require movement builder rebuilds. The supplied controller is bounded 0..1, so removing the sample clamp is safe. No shared overlay modification.
- Item registration and disposal logic was reviewed; independent tests exercise value, label, keyword and disabled changes during exit and subsequent reopen/selection.

Commands run in /tmp/beui-combobox-review-20261024-fudo0o_d:

flutter --version > sdk.log
flutter pub get --offline > pub-get.log 2>&1
flutter test --no-pub test/motion/combobox_test.dart --name 'BeuiCombobox interactions|exit filtering' > supplied.log 2>&1
flutter test --no-pub test/motion/combobox_independent_test.dart > independent-final.log 2>&1
flutter analyze --no-pub lib/src/motion/combobox.dart test/motion/combobox_test.dart > analyze.log 2>&1

Flutter 3.47.1 / Dart 3.13.1: supplied 23/23, independent 5/5, analyzer clean. Independent tests cover both motion preferences, repeated controlled interruption gaps 0/1/25/79/80/150/299/301ms, fresh query, nonzero panel geometry and full opacity, dynamic item metadata and identity changes, disabled rejection then enabled selection, exit teardown, and release of focus to a replacement field.

Initial independent-first.log is retained: four passed, the focus test setup failed because tapping an initially-open controlled combobox hit its existing overlay barrier. The corrected setup focuses while closed before opening. This setup failure is not claimed as a product regression or native reproduction.

Actual minimum SDK commands:
/tmp/beui-min-sdk-3442-20261023-evidence/flutter/bin/flutter --version > minimum-sdk.log
/tmp/beui-min-sdk-3442-20261023-evidence/flutter/bin/flutter pub get --offline > minimum-pub.log 2>&1
/tmp/beui-min-sdk-3442-20261023-evidence/flutter/bin/flutter test --no-pub test/motion/combobox_test.dart test/motion/combobox_independent_test.dart --name 'BeuiCombobox interactions|exit filtering|independent' > minimum-tests.log 2>&1

Flutter 3.44.2 / Dart 3.12.2, framework c9a6c484230f8b5e408ec57be1ef71dee1e77020: 28/28 passed. FadeTransition constructor and RenderAnimatedOpacity wiring also inspected directly in this SDK's transitions.dart:589-625. This is actual widget execution at minimum SDK, not minimum-SDK native browser proof.

Limits: no new native run or release build, no goldens, broad suites, children, Git mutation, repository or evidence writes. Historical native build execution is assessed from archived inputs/build log, not independently recompiled. Archived candidate library differs from live checkout in Collapsible and scheduler copy files as disclosed; focused widget tests here used the live library snapshot. Native fixture is uncontrolled; controlled ownership is widget-only. Widget probes including archived red-named logs are not failing-first opacity evidence. Known source/candidate no-results differences and duplicate rejected-close callbacks remain outside this repair. No full parity, timing, performance, pixel parity, accessibility, physical-device, cross-browser, CI or release-readiness claim.
