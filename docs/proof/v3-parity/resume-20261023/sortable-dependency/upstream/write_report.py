from pathlib import Path
import json,hashlib,datetime,shutil
P=Path('/tmp/beui-sortable-upstream-20261024');R=P/'raw'
S=json.loads((R/'stable-ref.json').read_text())['sha'];M=json.loads((R/'main-ref.json').read_text())['sha'];B=json.loads((R/'pinned-ref.json').read_text())['sha']
def link(sha,path,lines=''):return f'https://github.com/flutter/flutter/blob/{sha}/{path}'+lines
sem='engine/src/flutter/lib/web_ui/lib/src/engine/semantics/semantics.dart';focus='engine/src/flutter/lib/web_ui/lib/src/engine/platform_dispatcher/view_focus_binding.dart';key='packages/flutter/lib/src/widgets/reorderable_list.dart'
report=f'''# Flutter web Sortable upstream research

Research date: 2026-10-24. Read-only source and issue research; no SDK/repository changes, installation, build, browser replay, children, or upstream posting. All outputs are under this directory.

## Decision

No released supported fix for the observed semantics DOM move focus loss was found in the inspected scope. The official stable ref resolves to **Flutter 3.47.8**, framework `{S}`, pinned engine `cf636b1dfb818dd6a3ff16e390e93b1a036969c8`. Main resolves to `{M}`. Neither implements focus-preserving `updateChildren` moves. Do not recommend upgrading as a demonstrated Sortable repair.

The concrete upstream issue is [flutter/flutter#194550](https://github.com/flutter/flutter/issues/194550), open when fetched. It describes the same `updateChildren` → native blur to BODY → view unfocused → root-scope focus sequence, reproduced there on 3.47.4. Its reproduction is a tooltip/menu case, not proof of Sortable parity. Its only fetched comment asks for latest-stable reproduction and video. No fixing PR appeared in its fetched timeline or the bounded issue-number search. The proposed refocus workaround in the issue is a reporter proposal, not an accepted or released solution, and must not be copied into beUI's global guard.

## Exact release/source evidence

The [official 3.47 tag refs](https://api.github.com/repos/flutter/flutter/git/matching-refs/tags/3.47) bind 3.47.1 to `{B}` and 3.47.8 to the stable SHA above. [Stable ref](https://api.github.com/repos/flutter/flutter/commits/stable), [main ref](https://api.github.com/repos/flutter/flutter/commits/main), and fetched JSON are archived. The stable commit date is 2026-10-23; main is also 2026-10-23.

Inspected each tag 3.47.1 through 3.47.8 for `semantics.dart`, `view_focus_binding.dart`, and `widgets/reorderable_list.dart`. For each file, all eight releases have byte-identical fetched source. Also fetched the engine files directly at both `bin/internal/engine.version` pins, rather than assuming the framework checkout's engine directory represented the shipped engine; the relevant files match. Source hashes and every intermediate release SHA are in raw sources and `manifest.json`.

- Baseline [engine.version]({link(B,'bin/internal/engine.version')}) is `5d531788691ec3404cac0cee66ead4007b177363`.
- Latest stable [engine.version]({link(S,'bin/internal/engine.version')}) is `cf636b1dfb818dd6a3ff16e390e93b1a036969c8`.
- [Stable updateChildren]({link(S,sem,'#L2051-L2200')}) always renders traversal order as DOM order. The empty-container path appends children. The nonempty path computes an unconstrained longest increasing subsequence, then appends/inserts every nonstationary child. It neither anchors the focused subtree nor uses a state-preserving move.
- [Main updateChildren]({link(M,sem,'#L2110-L2259')}) retains these operations. `dom.dart` on stable and main has `insertBefore` and `append` bindings, but no `moveBefore` binding. This absence claim covers the inspected bindings/reconciler, not every file in Flutter.
- [Stable focusout]({link(S,focus,'#L60-L113')}) ignores some already-refocused cases, but otherwise passes the event's related target to view-focus resolution. Null target with BODY active leads to view-unfocused. [Framework handling]({link(S,'packages/flutter/lib/src/widgets/view.dart','#L261-L265')}) requests root-scope focus.
- [Main focusout]({link(M,focus,'#L85-L122')}) still immediately reports the Chrome semantics-button case. Its deferral requires `isIosSafari`, no related target, document focus, and the active text-editing element. A generic semantics reorder does not satisfy those requirements.
- [Stable outer key]({link(S,key,'#L1737-L1756')}) and [main outer key]({link(M,key,'#L1742-L1761')}) include `subKey`, `index`, and list `state` in equality and hashing. [The builder]({link(S,key,'#L1139-L1202')}) places the custom-action semantics wrapper inside this indexed `_ReorderableItem`. Material additionally wraps the user child in `_ReorderableListViewChildGlobalKey`, preserving a deeper subtree while the outer wrapper can change. The [Material source]({link(S,'packages/flutter/lib/src/material/reorderable_list.dart')}) is identical on inspected stable and main. A public `findChildIndexCallback` does not remove this private key's index dependency.

Archive limitation: the conventional Google Storage macOS and Linux release JSON URLs returned HTTP 404, so no binary download/release availability was independently verified. The official [SDK archive](https://docs.flutter.dev/install/archive) page was fetched, and version identity comes from the official Git tag/stable-ref match. GitHub Releases API returned old prereleases and was not used to establish latest stable. This report claims source-level absence within the tagged releases and current main inspected, not an exhaustive proof about all historical Flutter branches or unretrieved artifacts.

## Related changes checked by diff

1. [PR #192963](https://github.com/flutter/flutter/pull/192963), merged 2026-10-02 at `d6ffa40f14a27713e367678e57f40e3b93cf3f10`, changes `_updateRole`, not the `updateChildren` move loop. It connects the replacement role element before moving children and restores previous subtree focus or the replacement element. Its regression test changes an ancestor from generic to scrollable around a focused text field. This is relevant design precedent but not this fix. Main contains it; the inspected stable role code does not.
2. [PR #190942](https://github.com/flutter/flutter/pull/190942), merged 2026-09-18 at `634b0ed597124ca57830047cad4358371fd4e517`, adds the iOS text-editing deferral described above. The production diff and tests concern caret-drag transient blur. It cannot preserve a Chrome semantics handle moved by `append`.
3. [PR #177069](https://github.com/flutter/flutter/pull/177069), merged 2025-10-17 at `16ae36ce20bbbe0543e70b2be5564f2dd595f06d`, changes removal finalization so reattached descendants survive. Its test asserts tree structure and node membership. It does not test or preserve native DOM focus during reparenting.
4. [Issue #140235](https://github.com/flutter/flutter/issues/140235) remains open and explicitly identifies the index in `_ReorderableItemGlobalKey` as an item-state retention problem. It is corroborating ancestry evidence, not a released key fix. [Issue #193487](https://github.com/flutter/flutter/issues/193487), also open, describes a reparent-during-drag lifecycle failure; a key redesign must not ignore those drag state transitions.
5. [PR #189686](https://github.com/flutter/flutter/pull/189686), merge `03ebdcd6bd92a06081e2f24fff97f0ba6dbe731d`, fixes iOS `SemanticsObject.mm` parent cleanup and closes [#100946](https://github.com/flutter/flutter/issues/100946). Stable cherry-pick [#193420](https://github.com/flutter/flutter/pull/193420), merge `deb287481e3ce9468f3434937ced4240a70539ca`, also touches that native bridge and native tests. Neither modifies the web reconciler. Their closed/merged status establishes no web fix and no beUI native parity.

The raw PR metadata and file patches are archived. Search scope includes `moveBefore`, semantics/focus/reorder, `ReorderableItemGlobalKey`, focusout, semantics/insertBefore, and #194550 in flutter/flutter; 30 latest path commits for semantics and focus binding were inspected. Searches against the archived flutter/engine repository returned HTTP 422. The broad state-preserving search was noisy and bounded to its first page; it is not evidence of exhaustive absence.

## Smallest defensible upstream implementation path

There are two independently necessary cases in the supplied local evidence. Removing the ordinal sort key did not fix the framework ancestry change. A keyed Column removed that ancestry change but still lost focus on same-parent Home. Therefore changing only the framework key, or only choosing a better LIS for the existing ancestry, is insufficient for the existing component.

The smallest isolated first patch can target same-parent reorder in `SemanticsObject.updateChildren`: when a surviving direct child's subtree owns native focus, constrain the stationary sequence to include that child and move other siblings around it while producing the exact requested DOM order. This requires no global DOM interception and can work without `moveBefore`. It is a partial fix only. It must include arbitrary permutations, removal, insertion, traversal-order assertions, and a native-focus regression test.

The smallest complete scope for the existing ReorderableListView is the web engine's owned reconciliation transaction, covering both existing-parent reorder and cross-parent moves into newly created wrappers:

- Add a feature-detected `moveBefore` binding/helper in `engine/src/flutter/lib/web_ui/lib/src/engine/dom.dart`. Use it only for existing nodes with eligible source/destination ancestry. `moveBefore(node, null)` is the append equivalent. Ordinary insertion remains necessary for new nodes.
- Coordinate parent connection order in `EngineSemanticsOwner.updateSemantics` and `SemanticsObject.updateChildren`, including the empty-container path, so a focused subtree is not moved into a disconnected replacement wrapper first. Keep the old connected ancestry until the destination chain is connected and the move is eligible; retain finalization's distinction between reattachment and genuine deletion.
- If a supported browser cannot make that move atomically, use an explicitly owned semantics-update transaction with focus arbitration. Capture the owner, semantic identity, actual focused descendant and current focus intent before a known engine mutation. Do not convert a known transient mutation blur into a root-scope focus request before the transaction can resolve it. At completion, permit recovery only for a surviving eligible node with no competing focus intent, view disposal, or real browser/user exit. Hook this narrowly into `ViewFocusBinding`; do not suppress arbitrary null-target/BODY events or schedule general delayed refocus. Exact arbitration needs implementation and tests, not a heuristic inferred from BODY.
- Treat role replacement, disabling/blocking, permanent removal, and view disposal separately. Preserve DOM traversal order and z-index/hit-test behavior. Do not weaken semantics or merge independent row controls to avoid a move.

[WHATWG DOM move algorithm](https://dom.spec.whatwg.org/#concept-node-move) requires the same shadow-including root for the node and new parent; a connected old subtree and disconnected new wrapper fail that precondition. It also requires a valid reference child and prohibits ancestor cycles. The separate move operation skips ordinary insertion/removal steps. [Chrome's first-party API explanation](https://developer.chrome.com/blog/movebefore-api) explicitly lists preservation of input focus and Chrome 133 availability. These establish the API's purpose and constraints, not current Safari/Firefox support or Flutter acceptance. Feature detection and browser validation remain required. A mechanical append/insertBefore substitution is not a complete patch.

An alternative two-patch route is to stabilize framework wrapper identity by removing index from identity and repairing item registration/index updates, then add same-parent engine retention. That route needs framework drag, cancel/drop, overlay, membership and reparent tests. It is broader than a component property change and is not a safe one-line edit inferred from #140235.

## Validation and ownership boundary

Required upstream tests belong in `engine/src/flutter/lib/web_ui/test/engine/semantics/semantics_test.dart` and `test/engine/platform_dispatcher/view_focus_binding_test.dart`, plus framework reorderable tests if key identity changes. Assert actual focused DOM descendant, native focus event sequence, emitted view focus state, exact final DOM traversal, and retained keyboard behavior. Cover same-parent permutations, existing-parent reparent, a newly created disconnected destination, nested moved ancestors, moved focused descendants, role replacement, removal, disabled/blocked state, another owner requesting focus during update, Tab/Shift+Tab leaving the view, window blur, multiple views and disposal. Exercise atomic support and explicit fallback separately. Do not count a final refocus assertion alone as uninterrupted retention.

Then rerun beUI's preserved source/candidate sequence with trusted input: initial native Tab setup, ArrowDown, End, Home, native Undo click, with no intermediate recovery, under both motion preferences. Retain mutation/focus traces, exact SDK and served script hashes, order/callback assertions, accessibility snapshots and original recordings. Add browser coverage for the declared support scope and assistive-technology verification before accessibility claims. No new validation was run in this research task.

**Runtime dependency blocker:** Flutter-generated semantics ancestry plus focus-destructive web reconciliation still prevent demonstrated uninterrupted native browser focus retention. No supported released replacement was identified here.

**beUI work remaining:** keep the component-owned Undo focus-node repair and its owner-precedence/removal/disabled/disposal tests; resolve the existing nested Reorder-button accessibility boundary and arbitrary interactive row content; verify drag, reading order and visual behavior after the runtime fix. These are not automatically resolved by an engine patch. Do not land the diagnostic Column/no-sort-key changes as a parity repair, broaden `semantics_move_guard_web.dart`, freeze reading order, or add a global BODY-refocus listener. Native-platform parity, native60, screen-reader parity, hosted CI, and release readiness remain unclaimed.

Actionable next step: prepare an engine-owned regression and patch against pinned main `{M}` for #194550, with separate same-parent and new-wrapper cross-parent cases from the preserved trace. Submit or comment only under separate authorization. Require a merged revision and exact release containing the complete fix, followed by uninterrupted beUI replay, before changing the dependency or declaring this gate closed.
'''
(P/'REPORT.md').write_text(report)
inputs=[Path('/tmp/beui-sortable-topology-20261024/REPORT.md'),Path.cwd()/'docs/proof/v3-parity/resume-20261023/sortable-focus/README.md']
records=[]
for i,p in enumerate(inputs):
 out=R/('input-topology-report.md' if i==0 else 'input-sortable-focus-readme.md');shutil.copyfile(p,out);records.append({'source':str(p),'copy':str(out.relative_to(P)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(P/'input-hashes.json').write_text(json.dumps(records,indent=2)+'\n')
files={str(p.relative_to(P)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(P.rglob('*')) if p.is_file() and p.name!='manifest.json'}
(P/'manifest.json').write_text(json.dumps({'captured_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'sha256':files},indent=2)+'\n')
print('Wrote REPORT.md and manifest for',len(files),'files')
