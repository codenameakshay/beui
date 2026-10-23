# Bump native focus repair research, 2026-10-23

## Recommendation

Keep the focused semantics ancestor stationary. When Flutter asks to move an already-connected same-parent ancestor of document.activeElement, perform the identical sibling permutation by moving the intervening siblings instead. Never blur/refocus, defer restoration, or modify the FocusNode. This repairs the DOM reconciliation operation that loses focus; it is independent of chart timing.

The proper permanent home is Flutter web SemanticsObject.updateChildren. For beUI's current supported SDK range, a narrowly gated web compatibility adapter is feasible. It uses longstanding DOM insertBefore operations, not moveBefore, current-only Flutter APIs, or SDK edits. It is NOT a public Flutter reconciliation extension: the integration depends on Flutter's private semantics DOM convention and must be treated as a compatibility adapter with version/browser tests. No claim that an existing supported Flutter widget option guarantees stationary native ancestors is justified by this investigation.

## Current evidence

The served candidate is the parent's unchanged /tmp/beui-bump-tooltip-final at port 18127 /after/. No build or repository mutation occurred. The fresh baseline /tmp/beui-focus-research-after-baseline1 fails at legend-tab, 14 recorded states. It logs active-ancestor-insertBefore followed by native blur and BODY focus.

/tmp/beui-focus-research-after-rotate2 passes all 16 states and exercises the intervention exactly once. The attempted move is flt-semantic-node-2 before flt-semantic-node-140 under flt-semantic-node-1; Highlight Studio (node-114) is focused. Rotation records from=1,to=0. The app ancestor stays connected and focused while the tooltip sibling moves after it. rotate1 and rotate3 also pass 16 states but have zero interventions; they are intermittent controls, not causal repair evidence. rotate-reduced1 passes 16 states but also has zero interventions.

The reproducer /tmp/beui-focus-research-reproduce.mjs is a copy of the archived diagnosis reproducer with output redirected to /tmp, URL changed to 18127, and its opt-in moveBefore intervention replaced by sibling rotation. All baseline keyboard input and assertions remain. Screenshots, states, event traces and response hashes are in each run directory. Run with PRESERVE_MOVE=1 for rotation. Diagnostic code is deliberately broader than the proposed production guard; do not ship it verbatim.

/tmp/beui-focus-rotate-contract.mjs tests all 240 source/reference positions for sibling lists of lengths 1..8 in Chrome 155. All produce the exact native insertBefore order with no blur of the active descendant. Controls prove native relocation blurs, newer explicit focus is preserved, and detached targets are not refocused. Results: /tmp/beui-focus-rotate-contract-results.json. This is browser DOM proof, not Flutter widget or assistive-technology proof.

## Why another sort-key wrapper is not the answer

Flutter 3.44.0 already contains OverlayPortal's Semantics(traversalParentIdentifier: this) and the overlay's traversalChildIdentifier. Current SDK has the same mechanism. Source copies downloaded read-only into /tmp/beui-research-overlay-344.dart and /tmp/beui-research-basic-344.dart confirm availability. Setting these again is not a missing feature repair.

SemanticsObject.updateChildren renders traversal order in the DOM, sets z-index separately for hit testing, computes a longest increasing stationary subsequence, then calls insertBefore or append for nonstationary children. The same algorithm exists in 3.44.0, downloaded as /tmp/beui-research-semantics-344.dart. Its optimization maximizes stationary node count without privileging the active descendant. A tooltip-local sortKey cannot guarantee which app ancestor wins that selection. Changing whole-app traversal order would also impose an accessibility contract on the host app. The retained named-sortkey experiment already falsifies that particular proposal.

Excluding tooltip content from semantics is not an acceptable generic fix. BeuiChartTooltip passes rich content around an empty trigger; its body contains information not duplicated by the Bump node's rank label, such as previous-rank text. Exclusion would remove accessible information. A separately designed description-on-trigger representation could avoid overlay semantic nodes for text-only tooltips, but is not a drop-in repair for the current public rich-content API.

## Exact implementation boundary proposed to parent

1. Add internal conditional-import files beside lib/src/overlay: semantics_move_guard.dart, semantics_move_guard_stub.dart, semantics_move_guard_web.dart. Use dart.library.js_interop and dart:js_interop, as the package's existing hover_web adapter does. No public SDK minimum change or app bootstrap script requirement.
2. In BeuiTooltip's existing tight Semantics(container:true, child: surface), add an instance-unique semantics identifier, with a reserved beUI tooltip prefix. Do not add a new full-screen semantics container or change sort keys. This provides ownership discrimination for tooltip sibling subtrees.
3. Install the adapter once per JS realm while at least one tooltip client exists, before its first portal can render. Keep it active through exit animation and disposal/reconciliation. A permanent idempotent installation with strict live-marker gating is simpler than restoring prototypes too early. If uninstalling, restore only when the current function is still this adapter's wrapper; never overwrite someone else's wrapper.
4. Capture the existing native insertBefore and the Element.append entry point used by Flutter's engine. Intercept only a single same-parent connected Element move whose node currently contains the active element. Require parent/node to be Flutter semantics elements within the same flutter-view, a valid null or direct-child reference, and every sibling that would be moved to be an owned beUI tooltip subtree. No hardcoded semantic numeric IDs. All unrelated operations, cross-parent moves, detached targets, invalid arguments and true removals retain their original behavior and return/throw semantics. Do not hook focus() or removeChild(). append(singleNode) uses the same operation with reference=null; preserve append's void return. Confirm emitted JS entry points on the minimum SDK, because Element.append does not necessarily call a patched appendChild.
5. Use sibling rotation described below on all supported browsers. moveBefore may be an optional feature-detected fast path, but is unnecessary for this same-parent case. Do not claim moveBefore support on every browser or polyfill it by moving the focused node.
6. Keep chart focus callbacks, tooltip timing and existing semantics content untouched.

The precise ownership guard is important: moving arbitrary siblings can disturb accessibility state elsewhere. If any intervening node is not an owned tooltip subtree, delegate unchanged. That intentionally limits this repair to the demonstrated tooltip/app reorder. An engine fix is preferable for general semantics reorder bugs.

## Rotation algorithm

Snapshot parent.childNodes, locate moving node index i, and reference index j (length for null).

- j == i: return node, no move.
- j < i: save movingNode.nextSibling; insert the original siblings [j,i) one by one before that saved node.
- j > i: insert original siblings (i,j) one by one before movingNode.

Use the captured original insertBefore for these operations to avoid recursion. The final order is exactly the requested order. The active subtree never detaches. No focus restore occurs, so later explicit focus and target deletion have nothing to cancel. Moving an inactive target after a newer focus request simply delegates normally. Do not schedule work that captures an older active element.

## Required regression and accessibility gates

- Deterministic native test: focus a descendant; request the exact [tooltip-old,app,tooltip-new] -> [app,tooltip-old,tooltip-new] reorder. Unadapted test must blur; adapted test must preserve native activeElement and final sibling order. The natural burst test is intermittent and cannot be the sole red test.
- Production-gated adapter test: same case with real ownership identifiers and Flutter tags, then unrelated DOM, unowned sibling, invalid reference, cross-parent, detached, no-op and append cases. Assert native behavior is preserved outside the guard.
- Explicit focus test: move request after another control takes focus; it must stay focused. Detachment test: removal followed by a later insertion must not resurrect old focus. Verify modal focus still transfers to its intended control.
- Flutter real fixture: original unpaced sequence plus Shift+Tab, Escape during exit, rapid reopen, pointer dismissal and route disposal. Require logged intervention counts; a passing run with zero interventions is not repair proof.
- SDK: 3.44.0 compile/API and emitted-DOM check, current SDK browser fixture. Source inspection confirms API presence only; no 3.44 build was run here.
- Chromium, Firefox and Safari/WebKit: basic rotation should be portable, but only Chromium 155 was tested here.
- Screen readers: verify VoiceOver/Safari and NVDA/Chrome browse order, description availability, no duplicate tooltip announcements, and focus/cursor retention while tooltips close. Rotation preserves final traversal order, labels, z-index and native focus, but it still moves inactive tooltip semantic subtrees; a screen reader's virtual cursor can be there even when document.activeElement is elsewhere. Native-focus proof alone does not close that risk.

No repository files, git state, goldens, existing evidence or SDK files were modified. No children were spawned. Parent server was not stopped. All new outputs are in /tmp. Parent owns implementation, final regression gates and archival.

Additional reverse-traversal probe: /tmp/beui-focus-research-after-rotate-reverse1 recorded {'states': 18, 'interventions': 1, 'last_states': [('legend-next', 'Highlight Canvas'), ('legend-reverse', 'Highlight Studio'), ('legend-forward', 'Highlight Canvas'), ('legend-escape', 'Highlight Canvas')]}
