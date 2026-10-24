# Sortable native focus topology research

No safe repair was demonstrated. Do not land either diagnostic diff. All work products are under this directory; repository, SDK source, old evidence, git state and MultiSelect files/servers were not edited. No child agents or broad builds were used.

## Controlled results

The exact starting component SHA-256 is 2ba3a4643a7fdeccc7521380a3749fb7ec9a4317f96ed2da3e2c24905a1068c4. The source comparison is the archived a76e57c9bbc2837e96420b2610e9c82a3271bb05 fixture. Each of two experiments reran source and candidate with no-preference and reduce. Chrome was 156.0.8078.48. Each report contains 24 checks, trusted input events, read-only Flutter focus probes, DOM mutation traces, accessibility snapshots, served script hashes, screenshots and original screencast frames.

1. Remove only the item's OrdinalSortKey. Source passes 24/24 per preference. Candidate fails 10/24 per preference, beginning with ArrowDown focus loss. This does not repair the recreated framework wrappers.
2. Replace ReorderableListView with a keyed Column and remove OrdinalSortKey. Source passes 24/24 per preference. Candidate passes 23/24 per preference. ArrowDown gives B/A/C with A focused; End gives B/C/A with A focused; Home gives A/B/C but focus becomes BODY; native Undo click restores B/C/A with B focused. Thus even stable parent/identity is insufficient for this sequence. The Column is diagnostic only: it removes drag machinery and framework reorder accessibility actions.

Exact driver sequence: initial native Tab setup until A, ArrowDown, End, Home, native pointer click on Undo. There is no intermediate Tab, .focus(), keyboard dispatch, DOM click, semantics-action injection or recorder recovery. The source owns its own useLayoutEffect focus request for Undo; that is component behavior. Each report retains the actual initial Tab events and all downstream failures. All eight reports passed trusted-input, page-error and decoded-frame-count checks. 409 original frames are retained. Summary is independently derived in summary-from-reports.json.

The Column Home trace records focused node flt-semantic-node-8 within ancestor flt-semantic-node-7 removed from and added back to the SAME parent flt-semantic-node-6. Active element is BODY. This is direct controlled evidence of a second failure mechanism beyond cross-parent reparenting. Both preferences produce the same result.

## Source and framework findings

Pinned TypeScript source uses stable item ids and one handle button per item. Its move handler publishes order; it does not perform deferred move refocus. Its Undo explicitly queues a target and focuses it after render. This distinction matters when comparing retention with recovery.

Current component keys its item scope and item semantics by id, but places them below ReorderableListView. In Flutter 3.47.1, material/reorderable_list.dart wraps items with _ReorderableListViewChildGlobalKey based on item key and state. widgets/reorderable_list.dart:1139-1202 then puts that child below _ReorderableItem and a custom-action Semantics container. Its _ReorderableItemGlobalKey equality and hash include index at lines 1737-1756. Moving an item therefore changes the outer key while the inner material GlobalKey can preserve and reparent its subtree. Component ValueKeys cannot stabilize an ancestor created by the framework.

SliverReorderableList exposes findChildIndexCallback, but the same private index-bearing key and semantics wrapper remain. A callback helps locate a child; it does not change key equality. ReorderableList uses this sliver too. Switching among these public list APIs is not an established fix.

The archived web engine SemanticsObject.updateChildren at semantics.dart:2011-2160 computes a longest increasing subsequence to minimize DOM moves. It does not pin the focused child. Its final loop uses append/insertBefore for children outside that subsequence. The Column experiment removes the wrapper problem, then Home still takes this focus-destroying same-parent path. The engine explicitly derives accessibility traversal from DOM order, so freezing semantic order to avoid mutation would violate the source order contract.

Changing container/explicitChildNodes or merging/excluding row semantics is not a proven repair. MergeSemantics across independently interactive row content can collapse separate actions and focus targets. ExcludeSemantics without equivalent accessible controls removes required accessibility. A static semantics mirror would need complete geometry, hit-testing, focus, arbitrary row-content action and traversal fidelity. It is a replacement component design, not the smallest defensible fix. A stable Stack paint order plus changing sort keys still asks the engine to reorder the accessibility DOM. Keeping those sort keys fixed makes reading order stale.

The current candidate accessibility snapshot also contains nested Reorder A buttons, whereas source has a single handle. That existing boundary must be reviewed in any replacement design; reducing the retention failure count does not establish accessibility parity.

## Exact external dependency and acceptance boundary

For the existing ReorderableListView topology, the unresolved dependency is Flutter's framework-generated item semantics ancestry plus web engine semantics DOM reconciliation, on framework 6655482ec0 / engine 5d53178869, engine hash 11d79658c444477b06513d32b52c8c4ccb7276b0. No supported component property inspected here controls preservation of the private wrapper identity or atomic DOM moves.

A narrowly owned engine implementation would belong inside EngineSemanticsOwner/SemanticsObject reconciliation, operating only on that owner's semantics nodes. For a stable connected parent, preserving the focused branch while moving other siblings is a candidate algorithm. It cannot by itself repair the current cross-parent path. Cross-parent preservation requires final connected ancestry and a state-preserving move supported by the browser, or an engine-owned semantics-update transaction with explicit focus arbitration. The current engine can populate new wrappers while disconnected, so replacing append with moveBefore mechanically is insufficient. Role replacement, permanent deletion and view disposal must remain separate operations.

These are implementation requirements, NOT a tested engine patch or a browser compatibility claim. No engine patch was built. No global Node/Element interception, extension of semantics_move_guard_web.dart, BODY heuristic, semantics toggling, or delayed refocus is proposed. The existing tooltip guard's owned same-parent sibling precondition does not cover Sortable rows or arbitrary app DOM.

Before any repair can be accepted it must pass uninterrupted ArrowDown/End/Home/Undo and source-equivalent focus/traversal order in both preferences, then native removal, disabled root/handle, competing owner focus, external browser focus, disposal, arbitrary interactive row content, and accessibility boundaries. Browser support and a tested fallback need explicit scope. Existing widget tests for removal/disabled/external owner precedence are useful but do not prove native DOM behavior. Those native boundary checks were not rerun for these rejected diagnostics, and screen-reader, Firefox, Safari, native60, visual parity, drag parity, CI and release readiness are not claimed.

## Artifacts and reproduction

- no-sort-key.diff and column-no-sort-key.diff are diagnostic component diffs against baseline.dart.
- no-sort-key-web and candidate/example/build/web preserve the respective served builds.
- candidate contains the isolated package and fixture inputs; source contains the archived source fixture.
- capture-original.mjs is the unchanged archived driver; capture.mjs changes only ports 18165/18166 to 18171/18172.
- attempt-1-no-sort-key and attempt-2-column contain complete reports, images and recordings, including failures.
- framework-*.dart preserve the inspected framework sources; input-hashes.json identifies old evidence read during research; manifest.json seals new artifacts.

Ports 18171 and 18172 were checked free before launch. Two isolated `flutter build web --release --no-web-resources-cdn --pwa-strategy=none` builds ran from candidate/example. Logs preserve the font warning. The archived repository capture workflow used Playwright's trusted native keyboard/pointer input and read-only observers. Run `node capture.mjs NEW_ATTEMPT` with source on 18171 and the intended preserved build on 18172 to reproduce. The Playwright runtime path in the driver is an external local dependency, /tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs. Chrome and ffmpeg/ffprobe are also required.

Both capture processes exited normally and wrote summaries. Owned server PIDs 47621 and 47653 were verified by command line and terminated after completion. Repository component hash still matches the starting hash.
