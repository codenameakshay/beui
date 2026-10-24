# Heat Calendar native behavior supplement

This is a bounded deterministic fixture comparison of the current Flutter library and pinned React source a76e57c9. It does not close Heat Calendar parity. Native legend filtering differs. No production repair was made.

## Inputs and scope

The candidate copied current regular files from the shared checkout. `base-head.txt` identifies the base commit; `candidate-inputs.json` identifies the effective copied inputs, including any uncommitted content. `candidate-input-originals.tar.gz` retains library, demo, shaders, fonts, fixture, web inputs and dependency locks. The source transitive input archive, manifest, npm lock and pinned-input check identify the actual bundled source. Served JavaScript response bodies and their hashes are retained. `served-builds.tar.gz` contains both complete served trees as regular files.

Both wrappers read the same snapshots.json with four weeks ending October 23, 2026 and maxCount 10. Each initial column contains [0,.2,.4,.6,.8,1,0]. Blank uses an empty values array. Refresh uses one minus each initial value. Date changes the end to October 19; shrink changes weeks to one. Keyboard i/b/r/d/s changes fixture state without clicking away from the focused day. This tests public input replacement, not a gallery refresh control. The real gallery demo was read: it uses 16 weeks and a sine-based deterministic value formula with current UTC date. Its exact layout and data are outside this fixture.

## Observed behavior

Both motion preferences preserve native focus on Tuesday September 29 when values become blank, showing zero commits. Tab moves to Wednesday September 30 with zero. Refresh retains that Wednesday and changes the readout to six; Shift+Tab returns to Tuesday with eight. These are raw focused element identities and settled readouts, with screenshots and original compositor recordings.

The legend filter is a reproduced defect. Native hover activates source level 2 and dims other levels; the candidate does not activate it on hover. Native click followed by pointer exit leaves the candidate visibly filtered, including its selected legend outline, while source clears. Source uses pointer-enter/leave, focus/blur and click. Candidate BeuiHeatCalendarLegend uses a GestureDetector with only onTap. The proposed repair belongs in that legend's interaction and keyboard-focus handling. No repair was attempted here.

`evidence-supplement.json` indexes each final observation against the bounded ledger obligations. Capture summary pass flags describe sequence completion, motion preference agreement, input trust and video encoding only. They do not mean source/candidate parity. The verifier checks archive identity and selected common behavior; failing parity evidence stays in the archive.

## Reproduce and verify

Run `python3 /absolute/path/to/heat-calendar-native/verify.py` from any directory. It requires Python and ffprobe. It reads only the exported regular-file proof folder, validates input and media hashes, confirms archive entries are files/directories, checks decoded video frame counts and native input trust, and recomputes the bounded focus/readout expectations.

For native replay, run `python3 replay.py` in this folder, then `node capture.mjs NEW-UNUSED-ATTEMPT`. Replay extracts the archived builds into a new temporary directory and serves only port 18149. The capture uses the permitted Chrome executable and Playwright runtime at /tmp/beui-parity-capture-runtime. Stop replay with Ctrl+C. Offline verification does not use that runtime or the original temporary checkout.

## Attempts and limits

Attempt 1 preserves two complete source sessions and a candidate startup timeout. The fixture omitted its snapshots asset declaration. startup-diagnosis.log records the 404. Build 2 failed because an asset insertion also modified the dependency section; its malformed pubspec and error log remain. Build 3 corrected only the temporary fixture manifest. Attempt 2 completed, but immediate click/key sequences and one tooltip interception made its later focus-lifecycle evidence insufficient. Attempt 3 adds input settling and explicit pre-removal focus captures; all earlier files remain.

Flutter semantics bootstrap uses one synthetic zero-coordinate click on its accessibility placeholder; every subsequent pointer and keyboard event must be trusted. No programmatic focus is used as proof. Browser reduced-motion and effective Flutter MediaQuery.disableAnimations are recorded independently. Sessions use light theme, 1000x800 CSS viewport and DPR 1. Original native screenshots/compositor frames are not rescaled; their delivered dimensions may differ from CSS viewport.

No exact-pixel, native60, spring trajectory, interrupted ticker timing, full-gallery, dark theme, mobile, minimum-SDK, assistive-technology, range-total, controlled-selection, broad-test, CI, deployment or merge claim is made. The source and candidate have visible typography, month-label, geometry and theme differences. Frames arrive when Chrome emits compositor updates, not at a guaranteed frame rate. Videos use original frames and passthrough timestamps with no interpolation. The historical ledger and old evidence were not edited, and its aggregate count is not reduced by this supplement.

## Focus lifecycle findings from the settled rerun

Attempt 3 captures October 23 focused before Tab in both implementations. Source moves to legend level 0, then level 1. Candidate moves backwards in date order to October 3, then October 4. This reproduces in both preferences despite 250 ms settling after each pointer action and a separate 450 ms pre-Tab observation. The candidate's row-major semantics tree, Flutter OrderedTraversalPolicy and native browser Tab handling are a proposed investigation area, not a proven internal cause. The legend also lacks a Flutter focusable control.

Before changing endDate, both focus October 23. Both remove that day's focused element when endDate becomes October 19. Candidate then displays a stale zero-commit October 4 readout, while source has no readout. This occurs in both preferences. Candidate hover/focus bookkeeping retains the previously traversed day; investigate synchronization between semantic focus and the Flutter FocusNode/onFocusChange state. The exact cause is not yet established. The next Tab reaches source legend level 0 but candidate October 5. Before shrinking weeks, both focus October 22. Shrinking removes that focus and readout; next Tab reaches source legend level 0 but candidate fixture control initial. The scope establishes native removal and different continuation, not a universal desired fallback policy.

The first verifier checked only the ARIA tooltip role on removal and missed Flutter readout text merged into a button. Visual review found the stale October 4 readout. The final verifier asserts that observed divergence explicitly. Earlier verifier scripts/logs remain as superseded evidence; their passing integrity status was not proof that all readouts cleared.
