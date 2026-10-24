# Native tooltip dismissal diagnosis

Read-only investigation, 2026-10-23. No repository, git, golden, production, or prior evidence edits; no children, test suites, or builds. Only /tmp diagnostics and owned HTTP server port 18125. Existing documented Playwright capture runtime used per round4-composition-funnel README. Bump focus ancestry/sort-key experiment is unrelated and was not applied.

## Identity and outcome

Candidate /tmp/beui-round4-composition-funnel-quick-final-20261023, archived input HEAD 13ae06ed4c92f7b96f4f675753061ae8c8f86424. Direct served main.dart.js SHA256 b6527f0157297703e13efb51b271045c74077ed69fd081e35d0a3306fd20d1e5. Current shared lib/src/motion/tooltip.dart blob verified 54c1fa7a899bd52ddb0e9e89b7858eab3077c425. Pinned source a76e57c9bbc2837e96420b2610e9c82a3271bb05 was not rebuilt or rerun: source passing behavior is existing worker evidence, not new evidence from this investigation.

The untouched candidate reproduces mouse hover then click remaining open, and first touch tap then second tap remaining open, under both motion preferences. baseline/results.json and its eight PNGs are the unchanged-code control. assert-dismissal.log exits 1 with all four failures.

## Actual ordering

Observational instrumentation of exact compiled callbacks was injected through Playwright response routing, never written to the build directory. engine/results.json contains DOM trusted-event timestamps, Tooltip callback state at callback entry, and the engine's semantic tap dispatch. engine/instrumented-main.dart.js retains exact instrumentation; original and instrumented hashes are in results.json. trace.mjs/results.json are an earlier independent instrumented run. Counters show tooltip instance identity, not semantic node ID.

Mouse, no-preference, engine/results.json:

1. Hover commits true at 5098.9ms.
2. Native pointerdown hits flt-semantic-node-40, the tooltip overlay semantics node. It has tabindex=0, pointer-events:auto and a full 1000x1400 viewport rectangle. The Signed up trigger underneath is node 16 at x124/y589.5, 752x72. Full HTML and rectangles are in states[].hit.
3. Raw trigger-down runs at 5522.5ms, sets pointerFocus/suppressed and commits false. The chart's pointer-acquired focus callback follows with true while pointerFocus is true, so this first callback does NOT reopen.
4. Browser default focus goes to overlay semantic node 40. Trigger focus-change(false) at 5523.4ms clears pointerFocus in tooltip.dart:579.
5. Overlay exit/unmount causes focus to return to the previous trigger. Focus-change(true) at 5673.9ms sees pointerFocus=false and commits true at 5674.6ms. Mouse suppression is still true but the focus-opening path does not consult it.

Touch, no-preference:

1. First tap hits the actual tappable stage semantic node 16. DOM pointerdown/up occur, but Tooltip trigger-down/up do not. Focus-change(true) at 4955.0ms opens the readout. The engine dispatches SemanticsAction.tap at 4955.3ms; commit(true) follows at 4964.3ms. This is native semantic activation, not the Tooltip touch toggler.
2. Second tap hits viewport-sized overlay node 40. Raw trigger-down at 5510.0ms sees open=true; trigger-up at 5510.5ms commits false as intended.
3. Browser compatibility mouse focus moves to overlay node 40. Trigger loses focus at 5512.0ms and clears pointerFocus. Closing the overlay restores trigger focus at 5661.8ms and commits true at 5662.5ms.

Reduced motion has the same sequence with a shorter reopen delay: mouse false at 5487.6ms, true at 5510.9ms; touch false at 5480.8ms, true at 5516.1ms. These are two independent causes in shared input/overlay handling, not funnel geometry or Bump's focused-ancestor insertBefore issue.

## Causal controls, not shipped fixes

- no-overlay-focus/results.json: remove only tabindex from the existing viewport overlay semantic element immediately before dismissal. All four cases close and remain closed. Raw pointer callbacks still run; trigger no longer has the false/true focus round trip. This isolates overlay focus acquisition as the cause of reopening.
- no-overlay-hit/results.json: set only that overlay semantic node's pointer-events to none before dismissal. All four cases remain open. The trigger-down/up callbacks are now absent, because input lands on the tappable child and follows semantic activation instead. Removing the intercepting overlay alone is insufficient.
- Those two DOM interventions are diagnostic only. They are not accessibility-safe proposed production patches and do not certify any implementation repair.

## Justified repair locations

1. lib/src/overlay/beui_overlay.dart:345-350 wraps the full overlay Stack in Focus with default canRequestFocus/includeSemantics true even when trapFocus=false. skipTraversal=true on _overlayFocus only removes keyboard traversal; it does not prevent browser click focus or a full-viewport focusable semantic node. Give nonmodal tooltip overlays a non-focus-acquiring wrapper and avoid merging the tooltip label into a viewport-sized hit target. Preserve actual content semantics and independently interactive descendants; modal focus trapping must remain intact. If generic nonmodal overlays require distinct behavior, expose/configure the policy at BeuiTooltip's BeuiOverlay call instead of changing every overlay indiscriminately.
2. lib/src/motion/tooltip.dart:574-600 owns reopening and dismissal. Its modality state is erased by blur, and all mouse/touch dismissal behavior depends on Listener pointer callbacks. A unified activation/dismissal path must handle native semantic activation as well as pointer activation, preserve the child's action, and prevent pointer-related focus restoration from reopening. Merely checking _suppressed in onFocusChange fixes neither touch nor semantic-only activation. Merely ignoring all focus changes would regress keyboard tooltips.
3. lib/src/charts/funnel_chart.dart:259 and :378 show a shared Tooltip wrapping a native-semantic TextButton whose onPressed is empty. Any trigger callback composition needed to deliver semantic activation belongs in the shared Tooltip/trigger contract, with the funnel consumer wired through that contract. Do not solve this with chart geometry, semantics sort keys, or removal of accessibility.

Framework confirmation: Flutter 3.47.1 pointer_binding.dart:245-320 queues pointer events for flt-tappable targets and substitutes SemanticsAction.tap when a click arrives. The exact compiled engine a6J.a7i is traced. focus_scope.dart:718-731 exposes focusable semantics and onFocus for requestable Focus nodes. focus_manager.dart:223-234 unfocuses detached primary focus with previouslyFocusedChild, explaining restoration after overlay removal.

Sankey existing native-r3/results.json reports Outside click intercepted by tooltip semantic node 30 under 29 for both motion preferences. The newly measured viewport overlay node in this funnel run supplies a shared implementation explanation for that hit interception. Sankey was not rerun here. Its r4 Tab success does not establish pointer pass-through. Keep its pointer blocker separate from its passing keyboard case.

## Minimal reproduction

Start only the owned server, if 18125 is free:

    python3 -m http.server 18125 --bind 127.0.0.1 --directory /tmp/beui-round4-composition-funnel-quick-final-20261023

In another terminal, provide a NEW output directory:

    node /tmp/beui-dismissal-research-20261023/repro.mjs /tmp/beui-dismissal-repro-NEW

The compact reproduction uses untouched JavaScript and trusted mouse/touch input, verifies the positive opening readout, then asserts dismissal. It writes four screenshots and results.json and is expected to exit 1. The equivalent already-executed unchanged-code evidence is baseline/results.json plus assert-dismissal.log; the compact standalone extraction was not separately rerun.

Detailed tracing commands: node /tmp/beui-dismissal-research-20261023/probe-engine.mjs engine. Diagnostic controls: node /tmp/beui-dismissal-research-20261023/probe.mjs no-overlay-focus or no-overlay-hit. Those commands write their fixed diagnostic subdirectories; copy the script and change its /tmp root for an append-only rerun.

Repair verification should cover native semantics enabled hover/click, touch toggle on actual child tappable nodes, Outside click reaching its handler, no full-viewport tooltip hit target, and real Tab/Shift-Tab/Escape focus behavior under both motion preferences. Also test semantics-disabled raw input. No claim of a validated production fix, root/chart regression green, or final parity is made here.
