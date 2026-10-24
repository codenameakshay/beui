# Rapid Bump Tab focus diagnosis

The integrated candidate reproduces the archived rapid-Tab focus loss. The immediate cause is a Flutter web semantics DOM reorder that moves the focused element's ancestor with `insertBefore`. Chromium blurs the descendant during that move. This is a product focus defect exposed by input cadence, not an assertion that reads focus too early.

No production fix is included. No exact parity pass is claimed. Original evidence, goldens, and production files remain unchanged.

## Identity and reproduction

Candidate checkout: `f9a35c2faa4f622d08b860cfaa1ad3038377aadb`, containing integrated worker `e586d084`. The Bump implementation has no diff against that worker. Source checkout: `a76e57c9bbc2837e96420b2610e9c82a3271bb05` at `/tmp/beui-charts-reference-20261023`.

Flutter 3.47.1, framework `6655482ec0`, engine revision `5d53178869`, Dart 3.13.1. `inputs.json` records build and relevant source hashes. `build.log` records the fresh integrated release build. The source fixture uses the archived source-v2 build whose script hash matches the round-four README.

Run from the repository root. Build the candidate from `example/`:

```sh
flutter build web --release --target ../test/charts/bump_parity_fixture.dart --output /tmp/beui-bump-focus-diagnosis-integrated
```

`serve.mjs` serves only port 18122. It maps `source` to the preserved pinned source build, `after` to the fresh integrated build, and `archived` to the v12 build. Rebuild a missing source fixture with the original `round4-bump/build-source.mjs` into a new directory and update only this diagnosis server's mapping.

```sh
node docs/proof/v3-parity/resume-20261023/bump-focus-diagnosis/serve.mjs
node docs/proof/v3-parity/resume-20261023/bump-focus-diagnosis/reproduce.mjs after new-burst
node docs/proof/v3-parity/resume-20261023/bump-focus-diagnosis/reproduce.mjs source new-burst
PACE=60 node docs/proof/v3-parity/resume-20261023/bump-focus-diagnosis/reproduce.mjs after new-paced
PRESERVE_MOVE=1 node docs/proof/v3-parity/resume-20261023/bump-focus-diagnosis/reproduce.mjs after new-intervention
```

Use a new suffix each time. Output creation is exclusive. `MOTION=reduce` selects reduced motion. `RECOVER=1` adds delayed and next-Tab observations only after the legend assertion would fail. The assertion still fails against the original recorded state.

The reproducer derives from the archived `interactions.mjs`. It preserves the keyboard sequence, 250ms state waits, screenshots, and assertions. It removes only the added 60ms waits within the 28-Tab burst. Each run selects one motion preference and omits the unrelated touch branch. Native Playwright keyboard events remain trusted. The existing repository Playwright workflow is explicitly authorized for this task.

The sequence is plot Tab, first-dot Tab, next-dot Tab, Home, End, Down, Right, Enter, Space down/up, Escape, Enter, next-dot Tab, then 28 Tabs. Expected target is Highlight Studio, followed by Highlight Canvas and Escape. The initial semantics-placeholder click remains the original setup step. No focus injection is added to baseline runs. Diagnostic wrappers observe focus calls and DOM mutations; the explicit intervention changes only ancestor movement.

## Observations

See `results.json` for every run, including successful intermittent runs. Each run preserves states, PNGs, and focus/event traces. Later runs also record served response hashes on failure. Initial runs predate ancestor-call instrumentation; burst2 adds it, and burst3 adds sibling-order logging. All original run outputs remain intact.

- `source-burst1` passes all 16 keyboard states with unpaced input.
- `after-burst1`, `after-burst2`, and `after-burst3` fail at state 14, `legend-tab`.
- `after-paced1` passes all 16 states with the archived 60ms cadence.
- `after-preserve1` passes all 16 states with unpaced input and the diagnostic state-preserving move.
- `after-reduced-burst1`, `after-recovery1`, and `after-recovery2` pass unpaced. `source-reduced-burst1` also passes. This remains timing-dependent; these passes do not invalidate the captured failures.

In burst1 the candidate processes 28 trusted Tab keydowns between 6353.5ms and 6435.9ms. It focuses Highlight Studio at 6451.6ms, then blurs it at 6462.2ms. The assertion reads after a 250ms wait and observes BODY. There is no extra Tab after the legend acquires focus.

Burst3 directly captures the responsible call. The engine moves `flt-semantic-node-2`, containing focused `flt-semantic-node-114` (Highlight Studio), inside `flt-semantic-node-1`. Before movement, siblings are `[138, 2, 148]`. It executes `insertBefore(node2, node138)`. The following native blur leaves BODY active. Node 114 remains connected and retains its identity.

The intervention records the same ancestor reorder, then calls `Element.moveBefore` instead. The native focus survives, and the next Tab reaches Highlight Canvas. This is a causal browser experiment, not a production repair or a cross-browser certification.

## Ownership and cause

`lib/src/charts/bump_chart.dart` owns persistent FocusNodes in the plot, dot, and legend State objects. Native semantics focus calls `_focus.requestFocus`. FocusableActionDetector callbacks update highlight/readout state. `_nodeFocus` clears highlight only when the losing node is the recorded owner. No chart callback explicitly blurs the DOM legend. Stable semantics keys and unchanged DOM IDs rule out legend identity replacement in these captured failures.

Tab is ignored by the chart key handler and reaches Flutter's default `NextFocusIntent`. Multiple rapid presses advance Flutter focus before the next semantics frame. The trace therefore shows several keydowns on an old DOM dot, followed by a focus call to the latest dot. This frame batching is observable, but the final logical traversal target is correct: the engine explicitly focuses Highlight Studio.

Dot focus opens `BeuiChartTooltip`, which delegates to `BeuiTooltip` and root `BeuiOverlay` portals. Losing focus closes it. Tooltip exits take 120ms; the portal hides when its exit controller finishes. Rapid traversal overlaps tooltip lifetimes and changes the root semantics children. The observed ancestor movement occurs during this semantics reconciliation, after focus has already reached the legend.

The installed engine's `_updateChildrenInRenderOrder` implementation in `semantics.dart` chooses stationary children using a longest-increasing-subsequence calculation. Other children move with `append` or `insertBefore`. It does not protect the child containing native focus. In the failing call, it moves the whole app semantics subtree around an overlay sibling. The compiled call is `main.dart.js:25719` in the recorded candidate.

`AccessibilityFocusManager.changeFocus` in `focusable.dart` returns immediately when the new focused value equals `_lastSetValue`. Its post-update callback focuses the target only after a focused-value transition. `_didReceiveDomBlur` only records `receivedDomBlur`; it does not dispatch a framework focus-loss action. Thus the reparenting blur leaves native and Flutter focus ownership out of sync. Rebuilding with the same focused flag does not restore native focus. The compiled focus callback is `main.dart.js:24775`.

The FocusNode conclusion follows from these source paths and the surviving native node. This release build does not expose a live Dart FocusManager snapshot. The evidence directly proves the destructive DOM operation and its effect, without requiring a claim that a FocusNode was disposed.

## Minimal proposed fix

Fix native focus preservation at the web semantics reconciliation boundary. Prefer leaving the subtree containing the active element stationary while reordering its siblings. Alternatively, use a state-preserving DOM move where supported. The latter operation is isolated by the passing diagnostic intervention.

A fallback can capture the active descendant before a destructive move and restore it after reconciliation, but only if it remains connected and no newer explicit focus request supersedes it. Blindly requesting focus from every chart callback can steal focus and does not address the shared cause. Any production engine/adapter change needs tests for overlay close, rapid forward/reverse Tab, explicit competing focus requests, detached targets, and supported browsers.

A chart-only single-tooltip owner might reduce overlapping portal changes, but this experiment does not establish it as the minimal correct repair. Adding delays to the test only avoids the observed interleaving.

No production changes, pushes, merges, child agents, golden updates, or combined-suite runs occurred here. The parent owns broader verification. The build tool automatically prepended analyzer exclusions to `example/analysis_options.yaml`; that generated change was removed before the proof commit.
