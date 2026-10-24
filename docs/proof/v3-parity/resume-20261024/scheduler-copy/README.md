# Scheduler copy keyboard repair

Bounded implementation handoff, 2026-10-24. Full acceptance is NOT complete: native Escape after pointer selection leaves the candidate panel open. No week callback fires. The focused widget Escape test passes. Shared Checkbox, scheduler ownership, icon button and overlay files were not edited.

## Change and tests

The day checkbox now calls the row toggle for keyboard activation. IgnorePointer still routes pointer hits to the outer row once. Footer controls now have FocusableActionDetector, Enter/Space actions, disabled gating and a visible focus border.

red-actual.log reproduces Space leaving the selected checkbox false. red-final.log independently demonstrates both checkbox failures and unreachable footer controls against the original component: 16 failed keyboard cases and one passing pointer/cancel/reopen case. The corrected tests pass 17 copy-menu cases in green-final.log, then 24 focused scheduler cases in focused-final.log. analyze.log is clean. No goldens or broad suite ran. Tests inspect full-week proposals, destination hours/enabled state, unchanged source/non-target values, exactly one callback, controlled accepting/rejecting owner values, panel closure, disabled empty Apply, pointer once, cancel and retained/reset selections.

A subsequent widget focus-continuation assertion could not compile due ENOSPC (focus-final.log, focus-retry.log). That assertion was withdrawn; final tests match the previously passing behavior suite. Focus continuation is instead recorded natively. All failed logs remain, including initial setup and locator mistakes.

## Identity and scope

Initial parent head: c39e7e8bf55095d9564f47c6e8fc5808fe8fdc63. Concurrent parent work advanced HEAD before the isolated candidate archive. git get-tar-commit-id establishes build base 1c980497a2af1295d7d16f032f99adad746ee597, with this task's copy-menu implementation overlaid and a supplemental main entry. identity.json records the distinction, final file hashes, source pin checks and exact build-copy matches.

Source pin: a76e57c9bbc2837e96420b2610e9c82a3271bb05. Copy-menu, index, icon-button, checkbox and actual source preview match this pin. reference-inputs retains them. source-input-bindings.json binds every bundled input to archived regular files. input-lock.json locks source build, candidate inputs/build and source dependencies. served stores fetched JS/CSS/WASM by SHA256; results bind served bytes to builds.

Implementation SHA256: c8f7af54dbbd458f02731efc37bcd69720fb460fb1804488905f8b77e50c94b3.
Source JS SHA256: 0b87fd81afd9b8507f984e6965c8fa9f8f39b75ad8a786ae9d7b782756e27ddc.
Candidate JS SHA256: fe4c7150924bf697f82b9bd27169d94c3401cff54ecc51d576e66cf14ea7cc22.

## Native outcomes

These are supplemental fixed-week public scheduler compositions, NOT actual combined-gallery results. They follow the bare centered scheduler in example/lib/demos/availability_scheduler_demo.dart and components/previews/blocks/availability-scheduler.preview.tsx, adding a controlled owner and read-only callback probe. Monday is 08:30–16:30; other days retain distinct 10:00–12:00 ranges; Tuesday and Saturday start disabled.

Chrome used the specified Playwright runtime and ports 18183/18184 after checking listeners. Keyboard operations use page.keyboard; pointer operations use page.mouse. No script calls focus(). Flutter's accessibility placeholder is clicked programmatically only to enable semantics. Motion itself synthesizes untrusted pointerdown/up events from trusted keyboard activation in source normal motion; attempt 1's overly strict trusted-input check flags those. All recorded keydown/keyup events are trusted.

bounded-outcomes.json verifies eight core runs: source attempt 1 and candidate attempt 4, each normal/reduced motion and accepting/rejecting owners. Space selects a checkbox; Tab/Enter Apply emits one full week with Tuesday copied and other values unchanged. Tab/Space Every day emits a second correct full week. Panels close, owner rejection retains supplied values, and callback counts are exact. Candidate uses fresh destination range IDs. An offline checkbox-specific checked-state assertion excludes the already-checked weekday switches.

Source closes to BODY; next Tab is Monday's switch for both actions and all four owner/motion cases. Candidate closes to FLUTTER-VIEW; next Tab is Monday's switch. Attempt 4 PNGs show its focus ring. Attempt 6 adds explicit DOM switch-index-zero checks: normal/accept and both reduced cases complete those checks; normal/reject is interrupted by disk exhaustion. Normal/accept also records an archive-write error, separate from passing behavior checks.

Attempt 5 exercises empty disabled Apply, pointer selection, Escape and reopening. Source normal accept/reject and reduced reject complete. Source reduced accept is interrupted by ENOSPC after Apply. Candidate normal accept/reject and reduced accept reproduce native Escape leaving the panel open after pointer selection; callbacks remain empty. The subsequent attempt to tab back to the trigger cannot complete while focus remains in the panel. Reduced reject is interrupted by ENOSPC before Escape. This unresolved native cancellation/focus-routing defect is not a passing acceptance item. The shared overlay trapped-focus Escape path needs investigation; it is not a proven root cause.

## Archive and replay

Every generated original PNG, successful video, input log, build lock and failed attempt remains. Attempt 2 has an interrupted source-reduced-accept screencast without finalized results/video; its partial PNGs remain in the archive manifest. Later incomplete snapshots and compiler failures remain. No partial run is promoted to a pass.

verify.py requires Python 3, Pillow, ffmpeg and ffprobe. It resolves evidence relative to itself, verifies manifests and served/build identities, and decodes each completed frame-index replay to compare RGB bytes with every original PNG. Screenshot-only attempts 5/6 have no video. Behavior failures are reported separately from archive integrity.

Timestamp MP4 and fixed-index FFV1 are distinct artifacts. The verifier reports original/decoded counts and timestamp-video frame loss for each completed recording. Equal counts do not prove exact timestamps or pixels in MP4. Lossless fixed-index replay preserves RGB pixels and order at artificial 25 fps; it cannot restore capture intervals, missing browser frames or native60 timing. Attempt 4 requests every third screencast frame and cannot establish native60 or exact trajectories.

The regular-file export uses APFS copy-on-write clones into /tmp to avoid duplicating scarce disk blocks. Files are independent regular files, not symlinks or hardlinks. The same portable verifier runs there. No old proof was altered. No children, commits, push, shared component edits, release or gallery completeness claim.
