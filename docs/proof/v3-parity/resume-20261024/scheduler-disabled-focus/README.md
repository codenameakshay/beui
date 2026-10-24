# Scheduler disabled Apply focus repair

The repair changes only `copy_menu.dart` and adds four tests to `availability_scheduler_test.dart`. The sealed `scheduler-copy` archive is unchanged. `repair.diff` compares production against the exact supplied input, not the moving workspace HEAD. The source pin is `a76e57c9bbc2837e96420b2610e9c82a3271bb05`.

## Cause and repair

`FocusableActionDetector(enabled: false)` makes its FocusNode unable to request focus. Flutter then unfocuses it with `UnfocusDisposition.previouslyFocusedChild`. With the copy menu's `trapFocus: false`, its controls shared the background route's focus scope. The traversal history returned focus to Friday's Remove time range button. Enter invoked that button while the copy menu stayed open. A rejecting owner still received the unwanted full-week proposal.

A component-owned FocusScope now encloses the panel inside its Align. This placement retains the panel's loose layout constraints and anchored 208-pixel width. Putting a scope around the shared root overlay would change the scope and layout boundary for its full-screen barrier/content stack. The shared overlay is unchanged, and `trapFocus: false` still provides its existing Escape fallback after pointer selection.

A scope alone is insufficient: the previous focus within the menu is Every day, which would copy on Enter. The footer owns its FocusNode and, when a focused enabled action becomes disabled, calls `unfocus()` synchronously in `didUpdateWidget`. That clears the menu scope's focus history and focuses its neutral scope rather than another action. There is no timer, post-frame refocus, global activation interception, or retained focus on a disabled button. The new focus nodes are disposed with their owners.

Apply clears both the current focus and the menu scope's parent traversal history before invoking the controlled owner. That preserves source-matching Monday focus on the next Tab, while an owner-requested focus takes precedence. Existing copy, selection-reset, Escape, and lifecycle behavior is retained.

## Widget evidence

- `unchanged-repro-red.log`: unchanged reviewer repro first, before production edits. Both motion preferences emit a proposal disabling and emptying Friday. The other three lifecycle/owner cases pass.
- `scope-tests.log`: scope-only experiment fails both defect cases by invoking another action. `boundary-tests.log` retains the failed requestFocus experiment. Calling scope requestFocus follows its focused-child history; unfocus clears that history.
- `added-regressions-red.log`: all four newly added owner/motion cases fail against the exact supplied production bytes.
- `final-all-focused.log`: 38 passing executions. These are the 24 supplied cases, five unchanged previously accepted independent cases, five unchanged repro-file cases, and four new owner/motion regressions. Three lifecycle/owner cases are deliberately duplicated between the two reviewer files.
- `final-analyze.log`: no issues in the two owned files.

The focused command uses `--name 'copy menu keyboard|independent|BeuiAvailabilityScheduler interaction|BeuiAvailabilityScheduler motion fidelity'` and the three explicit scheduler test files. No broad suite or golden was run. The first scope invocation used `--plain-name` with a regex and selected no tests; its log is retained and is not a passing gate.

## Native evidence

Fresh source and baseline candidate builds match the archived build hashes. The patched candidate was freshly compiled with Flutter 3.47.1 and Dart 3.13.1. `identity.json` binds the builds and owned source/test bytes. `source-pin-check.json` compares the five relevant source files to Git objects at the pin. `source-inputs.json` binds all bundled source inputs to portable copies.

The documented archived installed-Chrome Playwright workflow uses `page.keyboard` and `page.mouse`. No scripted focus calls are used. The Flutter semantics placeholder receives a synthetic click solely to expose semantics. Pointer/key records retain `isTrusted`, and the verifier checks both kinds of input. Source motion-dom synthesizes pointer press events from Enter under normal motion. The verifier accepts only zero-coordinate Copy Monday press events paired within 50ms with a trusted Enter of the matching type and target; all other key/pointer events must be trusted. The dependency implementation is included in the bundled source inputs. `verification-first-failure.json` preserves the initial verifier result that rejected these library-generated events.

`baseline-source` contains four passing source runs. `baseline-candidate-retry` contains four completed baseline reproductions: Enter emits one proposal with Friday disabled and empty; accepting owners render it and rejecting owners retain the original week. `final-candidate` contains four passing patched runs. Each matrix covers normal/reduced motion and accepting/rejecting owners. Each run includes focused Apply becoming disabled, Enter without a background mutation, Escape after pointer selection, cancel/reopen selection retention, exact-once copy, successful reset, Every day, and next Tab to Monday after both actions. Widget tests additionally verify re-enabling Apply in the same popup, owner focus precedence, disposal, and reparenting with updated source data.

Screenshots, accessibility snapshots, callback payloads, trusted input records, and served script bytes are retained. No video was recorded and no native60, spring-trajectory, animation-timing, device, gallery, or release claim is made.

## Preserved capture and setup failures

The first baseline native attempt remains in `baseline-candidate`. Its first run recorded a response-body error for a redirect, not a browser application exception. Its fourth run timed out after Flutter's copied build cache removed stale baseline output paths while building the patched clone. The retry starts after the baseline was rebuilt and filters redirect responses before reading bodies. Both attempts remain separate. The final candidate run uses the corrected capture reader and its own server/output tree.

The first baseline build lacked the web runner, then font assets. Both failed logs are retained. The runner and assets were cloned from the existing recovery scratch into this task's new scratch, then the build completed. No originals or unowned scratch were deleted. Only task-owned servers on ports 18213, 18214 and 18215 were used.

## Portable verification

Run `python3 /absolute/path/to/scheduler-disabled-focus/verify.py` from any working directory. Python 3 is sufficient. `manifest.json` freezes archived bytes independently of behavioral checks. The verifier checks input/build/served/screenshot hashes, the source pin checks, exact expected baseline failures, final recorded checks, payloads, and trusted inputs. It reports integrity and recorded behavior separately. It does not rerun Chrome or claim that file integrity alone proves behavior. `verification.json` and the external export verification output are excluded from the archive manifest because they are generated by verification.

The regular-file APFS clone export is `/tmp/beui-scheduler-disabled-focus-export-20261024`. It has no symlinks or hardlinks. Dependencies for rebuilding/browser replay remain environment-specific; portable verification of the retained evidence does not require those dependencies.

## Exact SHA256

- Supplied production: `e988d873c612ef92f277ed05d0457d999c7cda46a7ff41745115bda9a4a9d6ae`
- Supplied tests: `59f859745bdc709dde7fe386a838e26f84474400093f90b5956e606d1a46c3b7`
- Final production: `b3a48de0ac3adf9f824ada52a8a142bcc671f3369e7a575c6dd9cfe23cde9047`
- Final tests: `4fcd24ee754298800c488b09f39e55f30989cb9daf7e6233744aa37e9ecf90c8`
- Source JS: `0b87fd81afd9b8507f984e6965c8fa9f8f39b75ad8a786ae9d7b782756e27ddc`
- Baseline candidate JS: `ef4a11fb997f733e088d2e0e639c6ccff639df5497f995bf7946f142c19392eb`
- Patched candidate JS: `c4dd90dcdb0b5bd8bc4f5d0a88e49b04b0fcda2c0447ff6e5e6a0f6f73e0385f`

No child agents, git mutations, commit, or push were performed. Parent review remains independent.
