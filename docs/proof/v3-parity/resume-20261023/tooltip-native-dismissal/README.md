# Native tooltip dismissal repair

Production f59e909b2 fixes native mouse and semantic touch dismissal. A nonmodal overlay wrapper no longer acquires focus or contributes a viewport-sized focusable semantics node. Actual content keeps its semantics; descendants remain focusable. Modal focus behavior is unchanged.

Tooltip observes native semantic tap actions scoped by a unique semantics tag. It updates visibility before Flutter invokes the existing child action, preserving the callback rather than replacing it. Mouse activation suppresses pending hover. Touch/accessibility activation toggles visibility. Keyboard input clears pointer modality; the existing focus-in and Escape behavior remains. The lookup uses public semantics-tree traversal compatible with the declared Flutter baseline rather than the newer getSemanticsNode API.

## Evidence

- `diagnosis/` preserves every original trace, screenshot, instrumentation and causal control. The untouched build fails all four dismissal cases. Removing only overlay tabindex works; merely removing pointer interception does not.
- `native-initial/` records the first repaired build, before the semantic quick-mouse-click correction and compatibility lookup change. It is not the final build.
- `native-final/` verifies final f59e909b2 mouse and touch under both motion preferences. Mouse click closes; a repeated click stays closed; native Tab reaches Activated and opens its readout; Escape closes. Four touch taps alternate open/closed/open/closed. Original screenshots, actual response SHA256 and effective browser/Flutter motion settings are retained. These are state checks, not timing or pixel certification.
- `sankey-pointer-final/` reruns the previously failed pointer version, including a real Outside click while the B tooltip is open. All 12 source/candidate scenarios pass across both motion preferences. It now covers pointer pass-through as well as the earlier keyboard lifecycle repairs.
- `bump-after-burst1/` and `bump-after-reduced1/` pass all 16 native checkpoints. Repeated normal `burst2` and `burst3` fail at legend-tab with BODY active. This repair does not fix Bump's semantics ancestor reorder. All failed traces remain unchanged. A separate read-only repair-design task is active.

## Local gates

Five new semantic activation tests pass, including pending mouse-hover cancellation, child action preservation, instance ownership and listener disposal. The initial red tests fail on original behavior; the first green run exposed a test-owned semantics-handle cleanup error, retained in its log. The corrected suite passes. The wider Tooltip/overlay/chart batch passes 317 tests with goldens disabled.

Full root at f59e909b2: 2,454 pass / 56 golden failures, no non-golden failures. Goldens remain untouched. Gallery: 56 pass. Production/test analyzer is clean. Release succeeds. Additional c89fcbcd7 tests nonmodal child focus, Enter activation and Escape; its eight-test overlay suite passes. The first release command mistakenly ran at the package root and failed before compilation; the corrected example build succeeds, and both logs are retained.

`build-identity.json` identifies all three fresh candidate builds. `verify.py` checks all archived bytes, passing native dismissal and Sankey assertions, served hashes and motion probes. It also requires the retained Bump failures; archive verification does not turn them into passing cases. No engine patch, native-60fps claim, or exact-parity sign-off.
