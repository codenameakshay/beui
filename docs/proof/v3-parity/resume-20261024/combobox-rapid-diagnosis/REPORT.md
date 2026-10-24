# Actual-gallery rapid Escape/type diagnosis

Read-only investigation, 2026-10-24. No production/evidence edits, children, builds, browser captures, copies, tests, or Git mutations. Only this report was written.

## Identity and conclusion

Workspace `/Users/codenameakshay/.t3/worktrees/beui/t3-df4b55e2` is at `594d607a196d7607997946facf6e7362ce250a02`. Independently hashed current `lib/src/motion/combobox.dart`: `4d3d7dcccb86162b198182488cdaa022c8da61ef3d739d075f9eb1c377ca1fca`. This is a file SHA-256, not a Git commit. The gallery REPORT.md:7,17 identifies accepted production commit `ee5b755599cead69fabf30079af1be9634f80280` and the same file hash.

The strongest repair direction is a stale captured open-state check in `BeuiComboboxInput.onChanged`, combined with synchronous controller resets on close. It can skip reopening when typing arrives after Escape but before the input rebuilds. This is a concrete code path, not a proven runtime attribution. An internal event trace is needed before assigning the observed empty field to it.

A separate correction to interpretation: `Pro` is NOT a selective query for this gallery. All four options legitimately match the current and pinned-source subsequence filter. The follow-up full list therefore does not establish incorrect filtering, although its Product-presence assertion still cannot certify that filtering ran. The run-1 empty/closed outcome and the reduced initial empty field remain unresolved failures.

## Proven saved observations

All evidence paths below are relative to `docs/proof/v3-parity/resume-20261024/three-components-native/` unless stated otherwise. JSON references use zero-based array indices.

- `run-1/combobox-{no-preference,reduce}/results.json`, `states[1..6]`: Product leaves Product team only; Escape restores Design studio and removes the popup; Play leaves Playground only; ArrowDown/Enter selects Playground; zzzz gives No workspaces found. `states[7]` (`rapid-reopen`) has empty field values, focused INPUT, and no Workspaces popup in the accessibility snapshot. This is retained failure evidence regardless of the empty checks failure list.
- The last Escape keyup and P keydown are separated by 0.4 ms in normal motion (4798.0 / 4798.4 ms) and 0.5 ms in reduce (4755.3 / 4755.8 ms). Each P, r, o has trusted keydown, input, keyup records targeting INPUT. These prove browser input delivery, not Dart onChanged delivery or retained text.
- `combobox-followup/combobox-{no-preference,reduce}/results.json`, `states[4]` and `[5]`: input Pro and all four options after immediate typing and settled retyping. Normal `states[1]` already has Pro and all four options. Reduced `states[1]` is empty but its popup contains all four options. Thus initial click/type can also lose text, without an immediately preceding Escape.
- Follow-up final Escape keyup to P keydown is 5.7 ms normal (3297.2 / 3302.9) and 3.8 ms reduce (3241.8 / 3245.6). These differ from run-1, but the sequences also differ in selection/history. This is not a controlled timing comparison.
- All four logs have no recorded focusin/focusout after the initial INPUT focus. The eventual failed state is also focused INPUT. This argues against a sustained focus loss; it does not prove native element identity or Flutter primary focus/text-input-connection continuity. Logs record tag/label, not node identity. Labels change between null and Search workspaces… without recorded focus transitions.
- Escape keydown is absent from these document-level logs, while its keyup is present; ArrowDown/Enter keydowns are similarly absent. The scripts issue keyboard.press for those keys. Do not interpret the incomplete document log as proof that no keydown occurred or as proof of which Flutter handler ran.

## Capture protocol and filtering

`capture.mjs:9,13-18,28-33` and `capture-combobox-followup.mjs:9,13-18,28-32` use Playwright `keyboard.type`, not `keyboard.insertText`, fill, or DOM value assignment. ASCII P/r/o keydown/input/keyup records corroborate that distinction. Keys are browser-generated trusted automation events, not physical-device typing. The sole documented synthetic activation is the semantics bootstrap click.

There is no explicit delay or frame barrier between Escape and type. The scripts await automation commands, which does not certify a Flutter rebuild. `capture()` then waits a fixed 450 ms before reading DOM state, followed separately by ariaSnapshot and screenshot. It does not wait for a semantic predicate, record Flutter frame IDs, or atomically sample model, DOM, semantics, and pixels. The fixed delay is a sampling policy, not evidence that the input was processed correctly. CDP screencast timestamps are not Flutter rendering cadence or native60 proof. Event logs omit input data/value, selection, beforeinput, composition, node IDs, Dart callbacks, and controller writes. They cannot reconstruct the write that erased text.

`lib/src/motion/combobox.dart:15-29,127-133` matches an ordered subsequence across value, label, and keywords joined together. `example/lib/demos/combobox_demo.dart:20-59,116-122` supplies detail and group as keywords. Therefore Pro matches:

- Design studio: `projects` in `12 projects`.
- Product team: `product`.
- Playground: p, r, o in `playground`.
- Component archive: p in `component`, r in `archive`, o in the later `components` keyword.

Pinned source `components/motion/combobox/context.tsx:36-46,210-214` uses the same joined subsequence rule. An all-options Pro snapshot is compatible with correct filtering. Product is the useful discriminator already observed in run-1; exact visible option-set assertions should replace presence-only checks. This does not convert the follow-up into a filtering pass.

## Code-derived lifecycle explanation

Current `lib/src/motion/combobox.dart`:

1. `_onKey` at 302-304 handles Escape while open by `_setOpen(false, restoreFocus: true)`.
2. `_setOpen` at 166-184 changes internal open synchronously, clears query through `_setQuery('')`, clears active value, and queues a post-frame input focus request. `_setQuery` at 155-163 writes the selected label to the controller whenever live `_open` is false.
3. The existing input callback at 650-653 checks `if (!scope.open)`, where scope was captured at the last build. If Escape has changed live `_open` to false but the input still has an open scope, the next onChanged skips `_setOpen(true)`. `_setQuery(query)` then stores a query but writes the selected label because live `_open` is false. No other code here reopens on printable keydown; the input can remain closed. This path does not require focus to leave the input.
4. A callback installed after a closed rebuild sees scope.open false and requests reopening first. That supplies a specific reason different event/rebuild ordering could produce different results, but saved evidence lacks build/callback timing to prove it.
5. Input build at 633-639 also writes the controller to query or selected label. `_register` at 218-230 schedules a closed-state selected-label write. These are additional overwrite sites to trace. Offstage content registers options even while the popup is closed (345-367); registrants are owner-counted (204-241). A missing selected registration would make the closed label empty, but the logs do not record registration state. The stale-scope path alone predicts a selected-label reset when registration is intact, so it does not fully explain the observed empty value. Do not claim it does.
6. The reduced initial empty result has no preceding Escape. Opening/build-time controller synchronization or Flutter web editing/semantics synchronization is an additional candidate. A single Escape-only fix must not be called complete until this case is reproduced and checked.

Overlay involvement is plausible but less directly supported. The combobox uses `trapFocus:false`, onDismiss `_setOpen(false)` (332-340). `beui_overlay.dart:248-268` installs a global HardwareKeyboard Escape handler, which stands down only when focus is within the overlay content. Input focus is in the trigger branch. The combobox focus handler and global handler can both participate in the same Escape dispatch; returning handled is not exclusive across HardwareKeyboard handlers. The local Flutter SDK `packages/flutter/lib/src/services/hardware_keyboard.dart:615-626` iterates all handlers and combines their results. Overlay deregistration happens on widget update (188-203), not on the combobox's immediate setState. Trace actual order and callback counts before blaming duplicate dismissal. Both handlers respond synchronously to the same Escape; that alone does not establish a later close after typing.

Portal show/hide is separately deferred and guarded (`beui_overlay.dart:157-184`); an already showing portal forwards its animation on reopen. The existing FadeTransition directly subscribes to opacity (`combobox.dart:446-453`). The earlier frozen-opacity defect cannot by itself explain empty input/model state. `combobox-reopen/README.md:3-13` reports fixture reopen success after that repair and explicitly distinguishes fixture from gallery qualification. Its 20 ms wait plus ArrowDown gives an explicit reopening path absent from run-1's direct type sequence.

## Pinned-source comparison

`/tmp/beui-charts-reference-20261023` HEAD is `a76e57c9bbc2837e96420b2610e9c82a3271bb05`; read-only git diff against that commit for `components/motion/combobox/` was empty.

Source `trigger.tsx:161,170-181` derives display value from open/query versus selected label and ALWAYS calls setOpen(true) before setQuery on change. Candidate's captured-scope guard is a material difference. Source `context.tsx:160-169` clears query on close and schedules focus restoration via requestAnimationFrame. It also freezes the last open list query (202-214), matching the candidate's intended exit-list behavior. Source has both local and window Escape handlers (`trigger.tsx:133-135`, `context.tsx:281-288`), so two potential handlers alone are not a sufficient parity diagnosis. Source content animates opacity from effective open with zero-duration reduced transitions (`content.tsx:117-125,153-155`). No new source runtime comparison was performed.

## Next discriminating experiment, pending parent authorization and disk recovery

Use the actual gallery and current production bytes as a baseline. Add only a bounded diagnostic trace in an authorized isolated candidate, preserving original evidence. Record monotonic time plus Flutter frame/build sequence, live open/query/listQuery/value, captured scope.open at onChanged entry, controller text/selection before and after every write, option-registration keys, FocusNode/primary focus, global/local Escape callback order, and portal/animation status. Pair this with window-level capture listeners recording stable DOM node IDs, connectedness, input value/selection/data/inputType, beforeinput/input, and focus changes. Avoid synthetic focus restoration.

First reproduce exactly run-1's selection/no-results/Escape/type sequence with Pro, then repeat using Product for a selective oracle. Also reproduce the reduced initial click/Meta+A/Pro case. Compare immediate type with a single explicit completed Flutter rebuild boundary after Escape, keeping all other actions fixed; do not merely increase arbitrary sleeps. Keep both motion preferences and a small fixed repetition count. Separately compare the previous ArrowDown reopening control. Capture actual event/frame intervals rather than requested delay values.

Discriminators:

- onChanged sees captured open=true but live open=false and skips reopen: stale-scope path confirmed. A bounded candidate can then try unconditional reopen before query, as in source, or a live-state condition; retain ownership semantics and retest.
- Browser input arrives but Dart onChanged does not: investigate Flutter web editing connection/semantics routing before changing overlay animation.
- onChanged reopens and accepts Product, then a later close/controller write erases it: identify that exact caller and frame; fix that lifecycle path.
- Model is open with Product and exactly Product team visible, but portal/semantics remains absent: investigate portal visibility/rendering separately.

Acceptance must assert retained text, focus identity, effective open state, and exact visible option set. Product should leave Product team only; zzzz should show the empty state; Pro may correctly show all four. Use bounded failure timeouts, preserve failures, and keep the baseline distinction between screenshot/semantics observations and instrumented internal state. No root cause is declared proven by this report.
