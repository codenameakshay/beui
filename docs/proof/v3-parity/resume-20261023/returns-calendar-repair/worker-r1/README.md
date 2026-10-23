# Returns Calendar implementation handoff

Only lib/src/charts/returns_calendar.dart and the new test/charts/returns_calendar_native_regression_test.dart are edited in the shared checkout. No commit or push. Port 18156 is closed. All other implementation artifacts are here in /tmp/returns-repair. Existing proof archives were read only.

## Diagnosis and patch

Pinned source a76e57c9bbc2837e96420b2610e9c82a3271bb05: grid.tsx lines 60 and 85 key rows by year and month wrappers by year/month. context.ts lines 38–58 retain hover as a row index, clearing only an out-of-bounds coordinate. Replacement does not invalidate a same-position hover. Removing the focused DOM element does not fire the normal React blur handler, so restoring 2025 after January 2030 focus retains the January readout. Final source sessions reproduce that behavior.

Flutter FocusAttachment.detach (SDK focus_manager.dart line 233) unfocuses with previouslyFocusedChild. That restored the fixture missing button when the grid emptied. The patch unfocuses with the scope disposition before detachment, clearing that history. Keyed Rows now replace the cell states when years change and retain them on reorder. The existing positional test keys move below InkWell so changing a row index cannot recreate its focus attachment. Selection coordinates and controlled ownership remain index-based.

Native attempt-1 demonstrated that year keys plus clearing scope history alone still restarted Tab at initial. Browser removal retains a sequential traversal position at the removed row. The final patch retains the removed row index on a non-tabbable grid FocusNode; a native Tab routes to January at that position. No remaining row means ordinary scope traversal resumes at initial. The map of year/month focus nodes is private and cleaned on cell disposal. Hover is only cleared when its row no longer exists. No shared Tooltip, overlay or recorder code changed.

## Verification

- red-exact-final-2.log: final five regressions fail on a regular-file project with the original returns_calendar.dart. Earlier red logs and all intermediate failures remain intact.
- green-exact-final-2.log: all five final regressions pass. Both motion settings cover replacement identity, missing-month focus/value continuity, January readout persistence, and empty-grid focus history. Other assertions cover year reordering, annual identity/removal, custom Grid/Tooltip composition, and controlled index-based selection after the hover preview is dismissed.
- existing-focused.log: seven existing Returns Calendar tests pass; the golden test was explicitly excluded.
- analyze-final.log: targeted analysis of the two owned files.
- attempt-2: four final native source/candidate sessions, each with 23 checkpoints, original compositor frames, screenshots, lossless video, raw input/focus/identity logs and served JavaScript hashes.
- verify-final.py / verify-final.log: independent assertions on exact next-Tab targets, disconnection, missing-month continuity, preserved January readout, trusted input, screenshot hashes and served JS binding. Run python3 /tmp/returns-repair/verify-final.py offline.
- final-input-hashes.json binds all copied library/assets/shaders, fixtures, locks and served builds. exact-final.json binds the shared production file to the actual native-build input and identifies the final regression file and served main.dart.js. The source scripts also exactly match the original pinned archive's served scripts.
- attempt-1 and attempt-1-build.tar.gz preserve the unsuccessful native traversal patch and its served files. Capture completion flags alone are not parity assertions. verify-first-failed.log preserves an overly strict verifier assertion requiring document-level Tab keydown; Flutter consumes keydown before that listener, while all seven trusted Tab keyups remain recorded. The capture script is unchanged except port 18155 to 18156.

## Bounded outcome and limits

Both motion modes: replacing 2025 disconnects March; next Tab is January 2030. Restoring disconnects the replacement; next Tab is January 2025. Emptying after March 2024 does not restore missing; next Tab is initial. Missing months retain March and the zero readout. Restoring 2025 retains the January readout before Tab. Annual removal and reinsertion preserve initial/missing next-Tab behavior.

The source uses BODY after row removal; Flutter uses a non-tabbable grid anchor for replacement and FLUTTER-VIEW after emptying. This is behavioral traversal parity, not identical DOM focus tags or screen-reader certification. No exact-pixel, full-gallery, general selection arithmetic, mobile, CI, deployment or release claim. Reverse traversal from a removed row is implemented but not separately certified by this forward-Tab native sequence. No programmatic browser focus was used; the archived zero-coordinate accessibility bootstrap click remains the only synthetic event.
