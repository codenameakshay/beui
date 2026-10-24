# Collapsible lifecycle recovery

Bounded behavioral verification completed on 2026-10-24. The production change is the existing 10 additions and one deletion in `lib/src/motion/collapsible.dart`; recovery did not change it. The existing test change adds 251 lines. No commits, pushes, shared component edits, goldens or broad suites were performed.

## Recovery checkpoint

`recovery-checkpoint.json` hashes every file present in this archive before recovery and the current production/test files. The verifier checks those original hashes. All earlier attempts, failures, captures and builds remain unchanged. Additional final3 files and partial replays were recovered from task scratch. Ports 18185 and 18186 had no listeners at recovery start; no old task process was reused or stopped. Recovery served the saved after-build on 18186 with its own Python process.

The preceding final2/final3 captures and final2 widget run encountered ENOSPC. About 310 MiB was available at recovery start. No unrelated files were deleted. `widget-recovery-all.log` also preserves an unsuccessful isolated test invocation: the build fixture pubspec lacks flutter_test. The successful focused runs used the current repository test file.

## Change and tests

External controlled closure now restores trigger focus in didUpdateWidget when content owns focus. It makes no onOpenChange proposal. Uncontrolled closure retains synchronous restoration in setOpen. Rejected controlled proposals no longer restore focus before the owner accepts closure.

`widget-before-tolerance.log` preserves failing-first external closure under both preferences, with actual focus `_ModalScopeState<dynamic> Focus Scope`. It also records passing size cases after correcting the settled-height numeric tolerance. The original strict tolerance failure remains in `widget-before.log`; it is not evidence of a content-growth defect. `widget-rejection-before.log` records the rejected-proposal regression. `widget-final.log` has the prior 16 passes; `widget-pending-focus.log` has two passes for later/pending outside focus.

Recovery commands, with no golden execution:

```
flutter test --no-pub test/motion/collapsible_test.dart --exclude-tags golden --plain-name lifecycle
flutter test --no-pub test/motion/collapsible_test.dart --name '^(?!.*golden)'
```

`widget-recovery.log`: 8 lifecycle passes. `widget-recovery-full.log`: all 16 non-golden Collapsible tests pass. The current test is archived as `recovery-current-test.dart`. Prior `analyze.log` reports no issues; analysis was not rerun during recovery.

## Native evidence

These are supplemental public compositions, not the integrated gallery. Source pin is `a76e57c9bbc2837e96420b2610e9c82a3271bb05`. Source inputs are bound to that pin by `source-bindings.json`. Candidate build inputs are in `inputs/candidate`, with hashes in `candidate-identity.json` and `build-lock.json`. Results record browser version, OS motion preference as seen by the fixture, native input events, DOM focus, accessibility snapshots, geometry, callbacks, screenshots and served script bytes. The only synthetic input exception enables Flutter's semantics placeholder; scenario pointer and keyboard events are trusted browser input.

Retained source acceptance is `final/source-no-preference` and `final/source-reduce`, 24/24 checks each. Valid source captures were not rerun. Candidate acceptance combines `recovery5/candidate-*` with `recovery-disposal2/candidate-*` for both preferences:

- Recovery5 passes 23/24 checks per preference. It proves focused descendant external closure restores Toggle, emits no proposal, hides content, and sends next Tab to Outside. Outside closure and later outside focus remain outside. Rejection emits one false proposal and stays open. Uncontrolled closure emits one proposal and restores Toggle. Disabled trigger emits no proposal.
- Recovery5's remaining failed disposal check is retained. Clicking the disabled semantics node left the shortcut unable to reach the fixture. The separate disposal2 sequence waits for disabled state, tests the disabled click, natively focuses Grow, then sends Alt+x. All 8 checks pass per preference, including removal and zero proposals. This does not certify shortcut delivery while focus remains on the disabled semantics node.
- Recovery4 failures remain. Its Outside pointer action dropped native focus before the owner shortcut. Recovery5 uses Tab to reach and verify Outside instead. The earlier final candidate trigger-focus checker incorrectly rejected the recorded FLT-SEMANTICS Toggle node. No production fix was inferred from those recorder failures.

Measured source and candidate wrapper heights settle near 100, 200, 80, 160 and 280 pixels for initial, grown, shrunk, narrow and hidden-growth reopen states, tolerance 0.05 pixels. Inner extents are 40, 140, 20, 100 and 220 pixels. Hidden growth remains closed, then reopens to the measured new extent. Stable widget identity is asserted by widget tests; the native fixture holds its content instance stable. This does not reproduce a content measurement defect, so no measurement or motion rewrite was made.

## Exact identity

SHA-256:

```
production collapsible.dart  e4a3fbf525e2534ebff073919d07e367b3d3c6bbae0ed3a13d2a7d12150d1614
current collapsible_test.dart  de27502a714bf23b8e3ee3e44cf964888152337089b5fc250cbd3fee6590f0d0
after-build/main.dart.js  fe520f24bf8172b1afd41aa07ddab1dd317eaec1cc40996c9fe400e24aa9270f
before-build/main.dart.js  79627afe45d1901ebfc16e19bfa19781f7aad99bc9ba843eee28a7df3b1de15b
source/source.js  42d05cf79875236d0d3fe68f413ebc137847872d27bf879d9eb68f51ec479ac8
```

## Portable verification

Run `python3 verify-recovery.py` from any location. It resolves files relative to itself and requires Python with Pillow, ffmpeg and ffprobe. It verifies original checkpoint hashes, archive hashes, input/build/served identity, the accepted behavioral observations and preference flags, every PNG decode, every video decode, and every FFV1 replay frame against original PNG RGB bytes. `verify.py` is the untouched unfinished historical verifier; use `verify-recovery.py`.

The initial recovery verification decoded all 2,844 PNGs and all 43 videos and matched 2,546 original frames exactly against frame-index replay RGB. No invalid PNGs were found. Interrupted folders without completed results received additional frame-index replays from retained valid originals; their missing timestamps and missing observations were not reconstructed. Timestamp MP4 counts are reported separately and are not used as proof of exact original RGB or timing. FFV1's 25 fps replay is a frame-index view, not native recording cadence. The original CDP captures are variable cadence and not native60 proof.

`python3 export-regular.py /absolute/new/directory` exports only regular files and directories. On macOS it uses copy-on-write clones; elsewhere it copies bytes. The verifier requires neither task scratch nor repository access. A regular-file export is verified at `/tmp/beui-collapsible-regular-export-recovery-20261024`; its report is archived as `verification-regular-export.json`.

## Limits

Source close duration remains 120 ms versus candidate 180 ms, and source closed height is 1 px versus candidate approximately 0 px. Open duration is 180 ms. These parameter and geometry differences remain separate from behavioral acceptance. No exact motion trajectory, raster parity, native60, screen-reader interoperability, integrated-gallery, CI, release or merge claim follows. Controlled rejected-close focus retention and same-frame pending outside-focus precedence have widget proof; native rejection proves callback/content behavior, not identical pointer focus policy across frameworks.
