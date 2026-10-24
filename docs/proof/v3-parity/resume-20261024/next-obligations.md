# Next obligations after the component repairs

Read-only reconciliation, 2026-10-24. Candidate root: `/Users/codenameakshay/.t3/worktrees/beui/t3-df4b55e2`. Source paths below are relative to `/tmp/beui-charts-reference-20261023`, the source checkout identified by the existing proof as pin `a76e57c9bbc2837e96420b2610e9c82a3271bb05`. I inspected current files, not Git history or a fresh checkout identity. No tests, builds, browsers, servers, child tasks or repository/Git writes were performed. This report is the only write.

## Recommendation 1: scheduler copy-menu keyboard outcomes

This is the strongest next assignment: current code contains a direct keyboard callback disconnect in a real workflow. It is demonstrated by code inspection, not a newly executed regression or native reproduction.

Candidate `lib/src/motion/availability_scheduler/copy_menu.dart:275-296` gives the outer day-row GestureDetector the real `widget.onToggle`, but wraps an independently focusable BeuiCheckbox in IgnorePointer and passes `onChanged: (_) {}`. IgnorePointer does not disable keyboard focus. `lib/src/motion/checkbox.dart:115-117,205-219` routes Space/Enter through that no-op callback. Pointer row selection can work while keyboard checkbox activation cannot change `_picked`.

The same copy menu's `_FooterButton` at lines 327-390 has Semantics and GestureDetector but no Focus/Shortcuts/Actions or keyboard-capable button. Its native reachability and activation need direct observation; a semantic tap is not evidence that normal Tab/Enter works. Source `components/motion/availability-scheduler/copy-menu.tsx:89-114` wires `onCheckedChange` to `toggle` and uses native buttons for Every day and Apply.

Scope:

- `lib/src/motion/availability_scheduler/copy_menu.dart` for the correction; inspect `icon_button.dart` and `availability_scheduler.dart:90-115` for entry and callback ownership. Do not begin with shared Checkbox or overlay changes.
- `test/motion/availability_scheduler_test.dart` currently checks render/toggle/add/remove/motion/golden cases, but has no copy-menu outcome or keyboard case.
- Actual composition: `example/lib/demos/availability_scheduler_demo.dart` and source `components/previews/blocks/availability-scheduler.preview.tsx`.
- Source ownership: `components/motion/availability-scheduler/index.tsx`, `copy-menu.tsx`, `icon-button.tsx`; source checkbox behavior in `components/motion/checkbox.tsx`.

Bounded acceptance for the parent to assign:

1. Establish a failing-first keyboard regression using the real menu. Open Monday's Copy menu, Tab to a destination, press Space, observe its checked state and Apply becoming enabled. No semantics-action substitution for the keyboard path.
2. Reach and activate Apply and Every day using native input. Assert exactly one full-week callback, correct destination hours/enabled state, unchanged source and non-target days, panel closure and source-observed focus continuation. Check actual values, not only the copied checkmark.
3. Preserve pointer row activation exactly once, disabled Apply with no destination, Escape/cancel without a week update, and reopen selection policy. With a controlled owner rejecting the proposed week, displayed hours must remain owner-supplied; compare source policy before judging the transient copied icon.
4. Capture the bounded sequence on source and candidate under both motion preferences, with explicit input/build identities. Full time-range validation, every scheduler transition and exact morph geometry remain separate obligations.

The historical coverage ledger at lines 627-639 describes recorder dispatch rather than copy outcomes. The current implementation inspection above is the reason to prioritize this slice now.

## Recommendation 2: Collapsible controlled closure and content growth

There is a concrete ownership mismatch in focus restoration, plus an independent measurement risk that needs reproduction.

Candidate `lib/src/motion/collapsible.dart:70-77` restores content focus to the trigger only inside `setOpen`. A parent changing controlled `open` from true to false bypasses that method. The root has no didUpdateWidget closure handling. The content merely applies ExcludeFocus when closed at lines 279-289. Source `components/motion/collapsible.tsx`, in CollapsibleContent's layout effect, explicitly restores trigger focus whenever effective `context.open` becomes false while the content contains the active element. The candidate's exact resulting native focus is unverified; do not claim BODY focus or any specific fallback without observing it.

Current `test/motion/collapsible_test.dart:139-158` closes by tapping the trigger, so it does not cover external owner closure. Its controlled-state test covers a rejected toggle proposal, not an externally accepted close with a descendant focused.

Candidate content measurement at lines 217-237 runs only on its own init/update. A nested stateful child changing its own height, or constraints changing without an updated content widget, has no explicit size notification to this measurement. Source uses ResizeObserver on the inner content. This is a source-backed risk, not a reproduced clipping defect. Keep it as a second small case within the same lifecycle assignment, and drop the repair if a focused regression shows existing layout already handles it.

Scope: `lib/src/motion/collapsible.dart`, `test/motion/collapsible_test.dart`, `example/lib/demos/collapsible_demo.dart`; source `components/motion/collapsible.tsx`, `components/previews/motion/collapsible.preview.tsx` and `collapsible.usage.tsx`.

Bounded acceptance:

1. With a controlled owner and a focused child TextField, change open to false through the owner without clicking the trigger. Compare actual trigger focus, hidden-content exclusion and next Tab destination against source under both preferences. Closing through an owner must not synthesize an onOpenChange request.
2. If focus is already outside, external closure must not steal it. Preserve uncontrolled trigger close, rejected owner proposals, reopen and disabled trigger behavior.
3. Let a nested child grow and shrink while the parent and content widget identities remain stable. Assert visible content extent and final wrapper height. Check one constrained-width change and reopen after hidden content changes. Use a supplemental public composition and label it as such.
4. Keep timing separate: candidate currently uses a 180ms fade for both directions and a zero closed height; source specifies 180ms open/120ms close and a one-pixel closed box. These are inspected parameter/geometry differences, not new measured trajectory results. Do not silently call behavioral acceptance exact visual parity or broaden this assignment into a motion rewrite.

## Recommendation 3: Combobox filtered contents during exit

This is a narrow source-contract mismatch in current state handling, with its visible native consequence still unverified. It is more useful than another default filtering demonstration.

Source `components/motion/combobox/context.tsx:202-215` deliberately retains `openQuery` and filters the exiting list using `listQuery = open ? query : openQuery`, so clearing the input on close does not repopulate the panel mid-collapse. Candidate `lib/src/motion/combobox.dart:125-132,151-181,315-335` filters using current `_query`, clears that query in `_setOpen(false)`, passes it directly into the scope, and keeps an exit duration of 300ms or 80ms with reduced motion. Item and group filtering at lines 837 and 913 also reads that scope query. There is no retained last-open query. Shared overlay `lib/src/overlay/beui_overlay.dart:188-199` reverses on closure rather than immediately discarding the panel.

This establishes a code-level difference. Whether and when extra options are actually visible must be measured in the next task; no new native failure is claimed here.

Scope: `lib/src/motion/combobox.dart`, `test/motion/combobox_test.dart`, `example/lib/demos/combobox_demo.dart`; source `components/motion/combobox/context.tsx`, `content.tsx`, `list.tsx`, `trigger.tsx`, and `components/previews/motion/combobox.preview.tsx`. The overlay is a read-only dependency unless a separate demonstrated defect requires a new assignment.

Bounded acceptance:

1. Filter to one option, then close through Escape and selection. During the still-visible exit, assert the same source-filtered rows and group/empty-state visibility, then panel removal. Also close from a no-results query.
2. Reopen before exit finishes and type a different query. Observe that current filtering resumes without stale rows, duplicate selection callbacks or focus loss.
3. Cover accepted and rejected controlled query clearing/open proposals according to source. Preserve the already proven Product query/selection behavior; do not reassign native editing as missing implementation.
4. Add an intermediate-state behavioral regression, then native source/candidate observations with exact event order and both preferences. A captured exit does not certify native60 or the whole morph trajectory.

## Current-state reconciliation and exclusions

The leading RUN_STATE sections, read again before writing, supersede the old `/tmp/beui-next-after-calendars-20261023.md` shortlist. That report's Sortable Undo, FileTree navigation and MultiSelect removal proposals are no longer untouched work.

- Sortable scoped repairs are committed as `91819aa8e`. Native move retention remains blocked by Flutter semantics issue 194550. The recorded dependency research found no supported released fix in 3.47.1-3.47.8 or inspected main. Rejected topology experiments and global DOM focus workarounds are not next implementation recommendations.
- FileTree `a4bbd37ee` has bounded review acceptance. `filetree-review-r1/README.md` explicitly preserves list/tree role, current/selected, disabled-parent/nested-button and immediate-collapse-focus limitations. Exact tree roles are unavailable at the supported minimum SDK. Actual assistive-technology interoperability is unverified, not certified by the semantics tests.
- MultiSelect `8fdc8cb5f` has final scoped review acceptance and 804 archived isolated native checks. Same-node/same-frame owner-focus precedence remains widget-only where documented. Those gaps do not justify reopening accepted fixes without new evidence.
- `v3-components-integrated-native-20261024-r1` is ACTIVE and owns actual combined-gallery native interactions. None of this report's assignments duplicates it. Parent should consume that result before making an integration claim.
- `components-integration-20261024/README.md` records root 2609 passes with the same 56 golden failure identities and gallery 66 passes. These are reported existing outcomes, not tests rerun here, and not whole parity counts. The leading RUN_STATE still records push in progress; this report makes no remote-head or hosted-CI claim.
- Heat/Returns Calendar repairs, deterministic Order Book behavior, Table repairs, Sankey implementation/archive recovery, Tooltip and Bump follow-ups, component example delivery and agent fixes must be read from their newer durable proof. The a2942181 coverage ledger and its JSON companion are historical inventories, not live defect truth. The obsolete missing-originals and missing-Sankey assignments are superseded.

Raster residuals remain separate: the same 56 goldens, nonzero source/candidate crops, typography and focus-decoration differences have no waiver. Chart mono diagnosis did not reproduce the historical narrowing on fresh fixtures/gallery; it does not support speculative font or offset edits. Order Book live timer correspondence remains unverified beyond the accepted deterministic fixture. Native60, interruption trajectories, timestamp-video losses and screen-reader behavior remain their own proof boundaries. No new completeness count, original-pixel acceptance, release, deployment or merge conclusion follows from this research.
