# Collapsible focus precedence

The review P2 is fixed. Restoration now checks the content's complete public focus-scope path as well as `hasFocus`. Flutter records a focus request in `FocusScopeNode.focusedChild` before it delivers primary-focus notifications. If an owner has already requested focus outside that path, closing the panel leaves that request intact. The same arbitration applies to uncontrolled closure. There are no timers, delayed restoration callbacks, private FocusManager reads, or global patches.

The existing controlled acceptance/rejection fix remains. A rejected proposal keeps content focus; an accepted close restores the trigger only while content still owns the requested focus path. No measurement, growth, animation, semantics, or traversal implementation changed. `production.patch` is the diff against the supplied production file, not against Git HEAD.

## Reproduction and tests

- Supplied originals are in `originals/`, including the independent test and both review logs. `reproduce.log` freshly reproduces exactly 14 passes and two `pending-build` failures against production SHA-256 `e4a3fbf525e2534ebff073919d07e367b3d3c6bbae0ed3a13d2a7d12150d1614`.
- `original16-independent16.log` passes all 32 tests: the original 16 non-golden tests plus the unchanged 16 independent cases. This includes accepted/rejected controlled requests, pending-before and pending-during-build requests, removal, reparenting, disabled controls and multiple Collapsibles under both motion preferences.
- `regressions-before.log` has six passes and ten failures from the 16 new tests on the original production file. Its exact test input is `originals/regressions-before-test.dart`. These tests cover owner requests during the parent rebuild, nested outside scopes, removal, reparenting, disabled controls, another Collapsible, owner callback requests before the next frame, and uncontrolled closure with an already pending outside request.
- `widget-exact-final.log` passes all 32 current non-golden tests. `tests/motion/collapsible_test.dart` is the exact final test file. `analyze-final.log` reports no issues for the two owned files.
- Earlier logs remain. `attempt1.log` was an invocation from the wrong working directory. `attempt1-run.log` records a Dart syntax error in a trial while-pattern. `attempt2.log` passes the independent 16 with the public scope-path check. `widget-all.log` records two test-locator errors, corrected by selecting the Semantics widget with a non-null onTap. `analyze.log` records a braces lint, corrected in the final test. None is represented as a product regression. Two preparation commands also used a wrong working directory; they failed to find their intended path and were rerun from the correct directory.

Commands used, excluding goldens:

```
flutter test --no-pub test/motion/independent_review_test.dart --reporter expanded
flutter test --no-pub test/motion/collapsible_test.dart test/motion/independent_review_test.dart --name '^(?!.*golden)' --reporter expanded
flutter test --no-pub test/motion/collapsible_test.dart --plain-name 'pending rebuild focus' --reporter expanded
flutter test --no-pub test/motion/collapsible_test.dart --name '^(?!.*golden)' --reporter expanded
flutter analyze --no-pub lib/src/motion/collapsible.dart test/motion/collapsible_test.dart
```

The independent and failing-original runs used isolated copies under `/tmp/collapsible-focus-precedence-20261024/tests`. Original tests were restored into that copy for the 16+16 run. The final owned-file run used the working repository. No broad suite, golden, child agent, commit or push was used.

## New native evidence

`native/{source,candidate}-{no-preference,reduce}/results.json` each passes 27 checks. These are new supplemental public compositions, built and captured for this fix. Source pin is `a76e57c9bbc2837e96420b2610e9c82a3271bb05`. `source-bindings.json` archives all bundler inputs, hashes and source Git paths checked against that pin. Candidate inputs, fixture, SDK version, dependency locks, build outputs and build logs are retained. `build-lock.json` binds the candidate library to its exact input hash. Network response bodies are in `served/`, with `served-lock.json`; every capture records its served script hashes and browser version.

Both ports 18189 and 18190 had no listeners before the task started its own servers. `ports-before.txt` is the empty lsof output. T3 preview opening twice returned `Too many server browser tabs are open. Close one with t3_preview_close, or reuse a tabId from preview_status tabs.` Both status/list APIs exposed no usable tab. Capture therefore used the retained Playwright/CDP workflow with native trusted pointer and keyboard events. The only synthetic input enables Flutter's semantics placeholder. No focus is injected by the recorder.

All four runs retain external-close trigger focus, no proposal on external closure, hidden content, next Tab to Outside, outside ownership across reopening/closing, later outside focus, disabled behavior, removal, controlled rejection callback/content behavior, uncontrolled closure and growth/shrink/width/hidden-growth behavior.

A new native Alt+P action starts with Inside focused. In the candidate fixture it closes the panel and sets a flag; the parent build consumes the flag and calls `outside.requestFocus()` before building the closing Collapsible. The captured final focus is Outside. In the source fixture the same trusted shortcut closes and focuses Outside in the same keyboard callback before React commits. These are explicit fixture behaviors, not claims that framework scheduling is identical.

The onOpenChange callback-before-next-frame ordering case and rejection's precise Flutter child-focus retention remain widget evidence. Native rejection proves callback and visible-content behavior. The native Alt+P case proves the separate parent-build owner request in the candidate, not the onOpenChange callback ordering case.

## Exact SHA-256

| File | SHA-256 |
| --- | --- |
| Original production | `e4a3fbf525e2534ebff073919d07e367b3d3c6bbae0ed3a13d2a7d12150d1614` |
| Original tests | `de27502a714bf23b8e3ee3e44cf964888152337089b5fc250cbd3fee6590f0d0` |
| Final production | `298d69810e2a002fc96518e62cc81fc33fa49c6f4df7cc7bcbc633e3df414f53` |
| Final tests | `331ef5a58cd1fa86a5196bb0f0a3994afb4ad0dcd7bcf2984bef6dee5b3b91e4` |
| Candidate main.dart.js | `7eae17fe4683a879f9332e88c23f6f0eba54f7ab77fd0b2485587dbf8676b78d` |
| Source source.js | `05939be3630c82b5dfa92d074927b8d6fb51a18c857cbcdf880aeb525e30dfd2` |

## Portable verification and export

Run `python3 verify.py` from any location. It needs Python with Pillow and ffmpeg. It resolves paths from its own location, validates the archive manifest, input/build/served hashes, test outcomes, motion preferences, native checks and trusted events, decodes every PNG and video, and compares every FFV1 replay frame's RGB bytes with its original captured PNG. It needs neither the repository nor task scratch. `manifest.json` covers all proof files except itself and verification output reports.

Run `python3 export-regular.py /absolute/new/directory` to export only regular files and directories. macOS uses copy-on-write clones, other platforms copy bytes. No full duplicate of the old proof was made, and no originals or unowned directories were deleted. The export at `/tmp/beui-collapsible-focus-precedence-export-20261024` was independently verified; its report is `verification-export.json`.

## Limits

The 267 original CDP frames have variable cadence. Timestamp MP4s preserve the recorded timing; FFV1 files are 25 fps frame-index replays, not native60 proof. Source/candidate close durations and resting geometry remain different as before. This work does not claim trajectory, raster, screen-reader, integrated-gallery, CI, release or merge parity. The parent independent review remains outstanding.
