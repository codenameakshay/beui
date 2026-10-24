# Independent Scheduler r2 review

Scoped acceptance: no demonstrated regression introduced by the disabled-Apply repair. The original destructive background activation is reproduced on the exact pre-repair bytes and absent on the final bytes. This is interaction/lifecycle acceptance, not complete source parity or release approval.

## Inputs

Read-only workspace `/Users/codenameakshay/.t3/worktrees/beui/t3-df4b55e2`; observed HEAD `b898cbd55f3cf7b4bef022f3f4076750763c91a8`. Reviewed production/test diff against HEAD and repair.diff against the exact pre-repair production. Reviewed React source at `a76e57c9bbc2837e96420b2610e9c82a3271bb05` in `/tmp/beui-charts-reference-20261023`; independently obtained all five relevant files with git show and matched their SHA256 values to source-pin-check.json.

Final production SHA256 `b3a48de0ac3adf9f824ada52a8a142bcc671f3369e7a575c6dd9cfe23cde9047`.
Final supplied tests SHA256 `4fcd24ee754298800c488b09f39e55f30989cb9daf7e6233744aa37e9ecf90c8`.
Pre-repair production SHA256 `e988d873c612ef92f277ed05d0457d999c7cda46a7ff41745115bda9a4a9d6ae`.
The original reviewer repro was copied byte-for-byte from scheduler-disabled-focus/independent-repro.dart; cmp confirms equality to /tmp/beui-scheduler-independent-review-20261024/test/motion/disabled_focus_repro_test.dart. No original tests or repository files were edited.

## Commands and results

All commands below run in isolated copies, with package resolution pointing to their own lib. No builds, broad suites, goldens, commits, children, browser replay, or repository writes.

Final command, run in both `/tmp/beui-scheduler-r2-20261024` and `/tmp/beui-scheduler-r2-min3442-20261024`:

```sh
FLUTTER test test/motion/availability_scheduler_test.dart test/motion/r1_repro_test.dart test/motion/r1_accepted_test.dart test/motion/r2_menu_focus_test.dart test/motion/r2_disabled_navigation_test.dart --name 'copy menu keyboard|independent|BeuiAvailabilityScheduler interaction|BeuiAvailabilityScheduler motion fidelity|r2 '
```

FLUTTER was `/Users/codenameakshay/fvm/default/bin/flutter` (3.47.1 / Dart 3.13.1), then `/tmp/beui-min-sdk-3442-20261023-evidence/flutter/bin/flutter` (3.44.2 / Dart 3.12.2). Both report 50 passing executions in final-focused-3471.log and final-focused-3442.log respectively. Counts include duplicated lifecycle/owner cases carried unchanged in the reviewer files and the derived navigation file; they are not 50 distinct cases. The first current-SDK run of the original three files alone passes 38 executions in focused-3471.log.

Minimum SDK resolution succeeded and changed eight transitive dependency versions in its isolated pubspec.lock, including Flutter-pinned clock, matcher, meta, stack_trace, test_api, vector_math, plus petitparser and web. The repository lock remains untouched. This is an actual minimum-SDK focused run, not merely API inspection.

Baseline command in `/tmp/beui-scheduler-r2-baseline-20261024`:

```sh
/Users/codenameakshay/fvm/default/bin/flutter test test/motion/r1_repro_test.dart test/motion/r2_probe_test.dart --name 'disabled transition|r2 multiple'
```

baseline-control.log records three expected failures: original disabled-focus repro under both preferences emits one proposal with Friday disabled and zero ranges; the initial multiple-menu probe also fails on this baseline. Final production passes the unchanged original repro.

## Additional probes and interpretation

- r2_menu_focus_test.dart tests owner callback requestFocus for both Apply and Every day, when focus is external to the requested owner node, already on that node, or a request to it is pending. All six pass. Owner focus is preserved after close.
- Its multiple-menu case opens Monday, selects Tuesday, programmatically focuses Tuesday's background trigger and activates it, then Tabs into the top menu. Escape closes only the top menu, another Escape closes the first; first-menu picks persist, second-menu picks remain independent, disposal leaves no Escape exception or callback. This is an explicitly programmatic multi-open stress case, not a claim that pointer barriers permit two menus to open.
- r2_disabled_navigation_test.dart extends a copy of the original repro: after neutral Enter, next Tab reaches the first checkbox; Escape closes without proposal; reopening keeps the empty selection; selecting and applying works. Both motion preferences pass.
- Supplied tests cover both owner policies and motion preferences, Enter/Space footer activation exactly once, pointer checkbox toggling, disabled pointer Apply, cancellation retention, reset after apply, next Tab to Monday, and existing scheduler interactions. Original independent probes cover reparenting an open scheduler with changed source data, owner removal during callback, timer/scope teardown and external owner focus.

Preserved unsuccessful probe: r2_probe_test.dart expected one Escape immediately after opening the second menu to close that menu. It left both menus open because a visible Copy times tooltip was topmost. multi-debug.log shows the tooltip and primary focus on the trigger. This also fails on the exact pre-repair baseline. r2_menu_focus_test.dart makes the intended focus-in-top-menu condition explicit and passes. Do not report this as a newly introduced regression or silently count the initial runs as green. The initial minimum run was 44 pass / 1 fail for the same probe; the corrected explicit-focus run is 50 pass.

## Evidence audit

```sh
python3 /Users/codenameakshay/.t3/worktrees/beui/t3-df4b55e2/docs/proof/v3-parity/resume-20261024/scheduler-disabled-focus/verify.py
```

archive-verification.json records successful integrity and recorded-behavior verification. Independently inspected source/baseline/final results.json outcomes: source four passes; baseline four expected defect reproductions (accepting owners mutate Friday; rejecting owners receive the proposal but retain display); patched four passes with no disabled-Enter proposal. Each batch covers both motion preferences and both owner policies. Build/served JS identities are tied to the recorded hashes. Trusted input verification has the documented narrow exception for motion-dom Enter-generated zero-coordinate pointer events; this is not a claim that every recorded event is trusted.

lock-audit.json independently recomputes SHA256 for 451 recovery final-input-lock entries and 9,013 recovery archive entries, with zero mismatches. The newer disabled-focus verifier checks its own manifest, source inputs, served bytes, screenshots, and checks. The archive retains failed setup/capture attempts; these are not passing runs.

## Limits

No fresh browser capture, native device run, motion decoding, animation timing/spring parity, native60, visual golden, gallery or release readiness claim. Parent is decoding the archive independently. Native conclusions above are about inspected recorded evidence, not a fresh native rerun. Extra owner-focus cases run under normal motion; original and supplied cases cover both preferences. Ordinary callback-triggered owner unmount is tested; arbitrary synchronous element destruction from inside callbacks is not established. No other component changes were made. Final repository source/test hashes were checked again and match the requested inputs.
