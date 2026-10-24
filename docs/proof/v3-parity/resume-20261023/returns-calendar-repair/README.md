# Returns Calendar identity and focus repair

The patch preserves year identity through reordering and replaces cell state when a year changes. Duplicate year values receive distinct occurrence identities without adding a public uniqueness restriction. Permanent row removal is handled by the calendar owner before detach, preventing focus history from restoring a previously visited external control. A non-tabbable grid anchor preserves the next forward/reverse traversal position. Missing-month updates retain cell identity and the source's positional hover behavior.

Focus-node registrations belong to the current calendar owner. Disposal removes only the exact node registered by that cell. Retained cells transfer registrations when a GlobalKey grid moves between owners. Temporary reparenting no longer triggers permanent-removal behavior. Selection callbacks remain index-based and controlled values remain owner-driven.

Three review rounds are retained. First review exposed map-disposal, GlobalKey and duplicate-year regressions. Second review exposed stale registrations after moving a grid between calendar owners. Both failures and successful narrower tests remain preserved. Round three accepted the ownership correction with19 focused checks. Parent chart suite passes302 tests with BEUI_SKIP_GOLDENS=1; targeted analysis is clean. The accidental untagged golden failure is retained under worker-r2, with no golden update.

Worker-r1 and worker-r2 contain exact original manifests, builds, failed captures and replay scripts. Parent-final contains the rebuilt final source and replacement capture. Run python3 verify.py with ffprobe installed after sealing. It checks hashes, input bindings, recorded behavior, original PNG/frame hashes and decoded video counts. Original scripts retain historical local paths; the offline verifiers use archive-relative paths.

Native source and Flutter focus tags differ after removal: source reports BODY; Flutter uses a non-tabbable anchor or FLUTTER-VIEW. Matching subsequent traversal is a bounded behavior claim. Source/candidate default checks cover both motion preferences. GlobalKey/remount checks are Flutter-specific. Duplicate-year compatibility has widget coverage, not a source duplicate-key parity claim. Exact pixels, native60, screen-reader behavior, mobile, full-gallery and general range arithmetic remain unverified.

Production commit d8688c53f passed bounded independent review. Final parent native capture passes122 checkpoints across both motion preferences, with exact source/build binding. Parent inspected the replacement-next screenshot showing January2030 focus and+7.0%. Archive clean-export verification is recorded in RUN_STATE.

## Integrated checks and media limitation

Fresh integrated root run at production d8688c53f:2,553 passes and56 golden failures. The exact failure identities match the earlier56-failure baseline. Full gallery:66 passes. No golden was updated.

One final parent timestamp video contains559 decoded frames for560 original PNGs. The verifier explicitly records it, alongside one rejected intermediate mismatch. All PNGs are hashed. A separate25 fps frame-index replay preserves all560 original RGB frames exactly; it is not timing evidence. See parent-final/attempt-final/candidate-reduce/MEDIA_LIMIT.md. Verification requires ffmpeg, ffprobe and Pillow.
