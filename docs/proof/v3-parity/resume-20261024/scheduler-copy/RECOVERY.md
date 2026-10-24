# Recovery after provider failure

The original README, manifests, logs, captures, and candidate build remain unchanged. `recovery-checkpoint.json` records the recovered starting files. This note supersedes the old handoff only for the new runs identified below.

## Repair and tests

The recovered day-checkbox callback and keyboard footer implementation are retained. CopyMenu now passes `trapFocus: false` to the existing overlay so its existing Escape handler dismisses the popup even when browser pointer activation leaves focus outside it. Applying also clears the primary focus so the next Tab starts at Monday, matching the source. No shared overlay code changed. The new regression clears focus after one pointer selection, presses Escape, and checks closure without a callback, retained selection on reopening, one Apply callback, and cleared selection after Apply. It failed before the local option change in `recovery-red.log`.

`recovery-final2-focused.log` passes all 24 focused tests, including next-Tab focus continuation for each keyboard action, owner and motion preference. `recovery-final2-analyze.log` is clean. Earlier focused passes remain archived. Tests ran against the isolated clone with the exact archived owned file bytes. The initial red invocation used the workspace package resolution; subsequent checks and build used the isolated candidate checkout.

Execution deviation: the first recovery test invocation used `--exclude-tags golden`, but the golden test is untagged. That invocation accidentally ran it in the isolated clone and failed because its baseline was absent. `recovery-green.log` retains the result. No golden was updated. The corrected runs use explicit test names. No broad suite, child agent, commit, push, or other worker source edit was performed.

## Evidence integrity

The original input lock verifies exactly. The original archive manifest has two stale entries, `focus-final.log` and `focus-retry.log`. Both logs finished writing after that manifest was generated. Their recorded and recovered hashes are preserved in `recovery-manifest-audit.json`. The original verifier failure is retained in `recovery-original-verification.log`. `verify-recovery.py` accepts only those two explicitly recorded recovered hashes; it does not silently replace the original manifest.

The source is pinned to a76e57c9bbc2837e96420b2610e9c82a3271bb05. Recovery reuses the original source build and verifies the five relevant archived source files against Git objects at that pin. The candidate is the original archived base 1c980497a2af1295d7d16f032f99adad746ee597 plus the owned repair and the same fixed-week fixture. Current concurrent workspace HEAD is not the build identity. `recovery/final-identity.json` and `recovery/final-input-lock.json` bind the final code, tests, build inputs, and outputs. The earlier recovery identity and lock retain the intermediate Escape-only repair. Attempt 7 exposed its focus-continuation regression in all four candidate runs. A new focus-continuation widget assertion fails in `recovery-focus-red.log`. Unfocusing the enclosing scope did not fix it; `recovery-final-focused.log` and `recovery/failed-focus-scope/` preserve that failed experiment. Clearing the primary focus passes.

## Native verification

All eight final comparison runs pass: source recovery/attempt-7 and candidate recovery/attempt-8, each with both motion preferences and both owners. `recovery/final-outcomes.json` lists the checks and result hashes. Empty Apply is disabled; pointer selection toggles once; Escape closes without updating; reopen retains canceled selections; Space toggles the target; Apply emits exactly one correct full week; successful apply resets selections; Every day emits the second correct full week; and the next Tab after both actions focuses Monday. Uses the archived documented installed-Chrome Playwright workflow, page.keyboard and page.mouse, both motion preferences and accepting/rejecting owners. No scripted focus calls. The Flutter semantics placeholder is programmatically activated solely to expose semantics. Screenshots and trusted input records cover the interaction sequence. This supplemental run does not record video or claim animation timing.

## Limits

This is a fixed-week public scheduler composition, not the combined gallery. No native60, exact spring trajectory, device, broad suite, release, or visual-golden completeness is claimed. Original failed and interrupted attempts remain failures. The original lossless replay verifies RGB pixels and frame order at artificial 25 fps; it does not restore missing browser frames or actual capture timing.

## Portable verification and hashes

Run `python3 verify-recovery.py` from any working directory, using its absolute path if necessary. Python 3, Pillow, ffmpeg and ffprobe are required. The verifier checks all original and new manifests, served JS identities, screenshot and frame hashes, trusted input, all eight final native outcomes, and original completed FFV1 replay RGB bytes. Earlier behavior failures remain listed separately. `recovery-archive-sha256.json` additionally freezes every retained file except itself and verification outputs.

Independent regular-file export: `/tmp/beui-scheduler-copy-recovery-export-20261024`, created with APFS clones. It contains no symlinks or hardlinks. Only the two owned Python HTTP servers on 18183 and 18184 were stopped after capture.

Final SHA256 values:

- copy_menu.dart: e988d873c612ef92f277ed05d0457d999c7cda46a7ff41745115bda9a4a9d6ae
- availability_scheduler_test.dart: 59f859745bdc709dde7fe386a838e26f84474400093f90b5956e606d1a46c3b7
- Source JS, build and served: 0b87fd81afd9b8507f984e6965c8fa9f8f39b75ad8a786ae9d7b782756e27ddc
- Final candidate JS, build and served: ef4a11fb997f733e088d2e0e639c6ccff639df5497f995bf7946f142c19392eb

The build reports a Cupertino font-family warning inherited from the fixture/package setup. The tested scheduler renders with its Material/Lucide assets; this does not establish unrelated icon coverage.
