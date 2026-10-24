# Independent Returns Calendar revision

Only lib/src/charts/returns_calendar.dart and test/charts/returns_calendar_native_regression_test.dart were intentionally edited in the shared checkout. No commits, pushes, children, shared Tooltip/overlay edits, or old proof edits. Native evidence is under /tmp/returns-revision on port 18157.

## Mechanism

Row keys and focus registry identities now include the zero-based occurrence of a year. Distinct years retain the prior identity across reorder; duplicate labels get deterministic distinct identities without a new public restriction. Selection, hover and controlled callbacks remain row-index based.

Permanent data removal is handled in the calendar owner's didUpdateWidget before descendants detach. It compares old and new occurrence identities and only clears scope history/sets the traversal anchor when an actually removed cell has primary focus. Cells no longer unfocus on deactivate, allowing Flutter's normal GlobalKey reparent lifecycle to retain focus. Missing months keep their row/cell identity. Outside focus does not satisfy the removal condition.

Disposal removes a registry entry only when it still points to that cell's exact FocusNode. Old keyed-grid disposal therefore cannot erase a replacement grid's newer registration.

## Tests

red.log preserves the initial reviewer repro failures. red-final.log tests the final expanded regression file against before.dart in red-final-project: exactly three failures (grid replacement, GlobalKey move, duplicate years). green-1.log preserves the first candidate pass. affected-no-golden.log reports 18 passing affected tests (11 native regression widgets plus seven existing tests). analyze.log reports no issues in the two owned files.

The final regressions cover reverse traversal after replacement, custom grid remount followed by forward/reverse replacement, retained March identity/focus across GlobalKey moves and subsequent April Tab, duplicate occurrence identities through reorder/removal, outside focus cancellation, missing-month continuity, empty traversal history, controlled index-based selection, annual identity and teardown.

## Preserved verification mistakes

The first affected-suite command used --exclude-tags golden, but the existing golden test is untagged. It ran and failed; no golden was updated. affected.log and accidental-golden-failure retain that failure. The explicit --name '^(?!.*golden)' rerun passed. Generated Returns Calendar failure images were copied from test/charts/failures; other existing failure images were not touched intentionally.

Native attempt-1 completed source sessions but candidate startup timed out because build 1 had base href '/'. build.log, native-1.log, attempt-1, and attempt-1 input/hash manifests retain that failure. Build 2 uses --base-href /candidate/example/build/web/. No production code changed between builds.

Native attempt-2 completed all four sessions but the extended checks failed. It used only aria-label even though focused Flutter cells expose text content. Its extra scenario transitions also lacked settling before clicks/Tab: move-before shows the grid anchor rather than March, and remount-forward sends Tab before row replacement has settled. capture-attempt-2.mjs, native-2.log, attempt-2, and attempt-2-input-hashes.json preserve this unsuccessful verification. Attempt 3 adds a 500ms pre-click settling interval, a captured settling checkpoint before remount forward Tab, and label-or-text checks. There are no programmatic focus calls or production changes in response.

## Native evidence

Attempt 3 and verify.log pass for source/candidate in both motion modes: 26 source checkpoints and 35 candidate checkpoints per mode, 122 total. Forward replacement reaches Jan 2030; restoring reaches Jan 2025; reverse replacement reaches annual 2024. Emptying clears the previous control history and next Tab reaches initial. Missing months retain March identity and zero readout. Candidate GlobalKey movement retains the native focused March element, next Tab reaches April, and moving back retains April. Custom grid remount disconnects old identity, and subsequent replacement reaches annual 2024 in reverse and Jan 2030 forward. Trusted keyboard/pointer logs and served script hash checks pass. Screenshots replacement-next and move-after were also visually inspected.

The source represents removal with BODY focus, while Flutter uses its non-tabbable grid anchor or FLUTTER-VIEW. This proves traversal behavior, not identical DOM structure, screen reader certification, pixel parity or release readiness. Duplicate-year compatibility has widget regression coverage; no React duplicate-key parity claim is made. Native lifecycle checks are candidate-specific. Port 18157 is closed after capture. capture.mjs extends the original handoff workflow in a separate directory. It uses native pointer/keyboard input, never browser programmatic focus. The inherited accessibility-bootstrap click is the only allowed synthetic event. The source files are byte-for-byte copies of the original pinned-source served build. Candidate fixture adds G to replace the custom grid key and P to move the GlobalKey calendar under a Padding and back. These extra lifecycle exercises are candidate-only because React does not expose Flutter GlobalKey semantics.

final-input-hashes.json binds library, fixture, assets, locks, source files and final served builds. exact-final.json binds the shared production and test files and confirms no library-copy differences. Raw input/focus/identity observations, screenshots, original compositor frames and lossless video are retained per session. verify.py checks the expected behaviors and the hash binding offline.

## Exact SHA-256 hashes

- lib/src/charts/returns_calendar.dart: `06f1735b30b80ff8add8c37c33071b5c1dce6983f626d6fac6d70e8ece0688ab`
- test/charts/returns_calendar_native_regression_test.dart: `25ec1115a8bf9e337f9627dc0eb44709f13c9569ab9c3bb692b5d8c9be47aa00`
- candidateSource: `06f1735b30b80ff8add8c37c33071b5c1dce6983f626d6fac6d70e8ece0688ab`
- servedMain: `5620aa2fa13209772cde782bcdf8905b0144f56a0f3ebf099dfc9c7962bbfd02`
