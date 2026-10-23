## 2026-10-24 Combobox independently accepted within scope

Final production `4d3d7dcccb86162b198182488cdaa022c8da61ef3d739d075f9eb1c377ca1fca` and tests `af6be0fe80755361e1dcc12438207f6e6fd6c38440f18d02725cce217a3db1fe` accepted. Independent 23 supplied + five new tests pass on 3.47.1 and actual minimum Flutter3.44.2/Dart3.12.2. Analysis clean. Parent archive verifier passed. Review retained in `../resume-20261024/combobox-review-r1/`.

Native evidence is archived, uncontrolled, and binds baseline opacity failure and final both-preference success. Widget tests do not reproduce native opacity failure. Known no-results differences and duplicate rejected-close callbacks remain outside repair. Scheduler P2 repair r3 remains active and excluded from Combobox delivery.

## 2026-10-24 Scheduler P2 blocks acceptance

Review r1 demonstrates focus escape after focused Apply becomes disabled. Pointer-removing final Tuesday selection moves focus to Friday background Remove time range; Enter emits unintended destructive week proposal. Both preferences. 24 supplied + five independent cases pass; archived native runs omit this transition. Review evidence retained in `../resume-20261024/scheduler-review-r1/`.

Repair task `v3-scheduler-disabled-focus-repair-20261024-r3` owns Scheduler code/tests and new `scheduler-disabled-focus` archive, preserving original evidence. No Scheduler commit/push. Combobox final independent review remains pending.

## 2026-10-24 Combobox opacity repair ready for review

Reduced-motion native reopen failure reproduced and traced to sampling overlay opacity inside the movement builder. Component-owned FadeTransition now listens to opacity. The defective read predates exit-query changes. Final production `4d3d7dcccb86162b198182488cdaa022c8da61ef3d739d075f9eb1c377ca1fca`: worker reports fresh native exact sequence passes both preferences, 23 focused tests and analyzer pass. Widget attempts did not reproduce native failure. Controlled ownership remains widget-only.

Evidence: `../resume-20261024/combobox-reopen/README.md`; original `combobox-exit` archive unchanged. Independent review task `v3-combobox-final-independent-review-20261024-r1` running. Parent verifier completed with exit 0; log: `/tmp/beui-combobox-reopen-parent-verify.log`. Independent review remains pending. Scheduler parent archive passes; independent review remains pending. No new commit/push.

## 2026-10-24 Scheduler recovery ready for review

Recovery r2 reports 24 focused tests and analysis passing, eight trusted native owner/motion runs, and 4,759 RGB-exact replay frames. Exact production `e988d873c612ef92f277ed05d0457d999c7cda46a7ff41745115bda9a4a9d6ae`; tests `59f859745bdc709dde7fe386a838e26f84474400093f90b5956e606d1a46c3b7`.

Independent task `v3-scheduler-copy-independent-review-20261024-r1` is running. Parent `verify-recovery.py` session 37540 completed with exit 0; log: `/tmp/beui-scheduler-copy-parent-verify.log`. Independent review remains pending. Evidence: `../resume-20261024/scheduler-copy/RECOVERY.md`. Two original stale log hashes and an accidental isolated golden failure remain disclosed. No Scheduler delivery before review acceptance. Combobox reduced-motion diagnosis r4 remains active.

## 2026-10-24 Combobox recovery exposes native reopen failure

Recovery r3 completed without Dart edits. Current production `b4b7b24c6fec2aa053676d08e2f1401f08bcf8c8abc78a8bb428f636b78566d7`: 21 focused tests/analyzer pass, but reduced-motion selection/no-results/Escape/ArrowDown/replacement typing leaves `apl` with no popup. Native acceptance remains false. `combobox-exit` archive preserves failures and portable integrity verification; saved candidate bundle was reused, not rebuilt.

Root-cause/repair task `v3-combobox-reduced-reopen-diagnosis-20261024-r4` now owns Combobox code/tests and new `combobox-reopen` evidence only. Original archive is immutable. Collapsible was pushed as `8fd89f601`; Scheduler recovery remains outstanding.

## 2026-10-24 Collapsible r2 accepted within scope

Original pending-owner-focus finding resolved at production `298d69810e2a002fc96518e62cc81fc33fa49c6f4df7cc7bcbc633e3df414f53`. Independent original 16/16 and final 32/32 pass; analysis and saved-native verification pass. Review retained at `../resume-20261024/collapsible-review-r2/`.

Distinct enclosing FocusScope reparenting during close can still lose Outside focus; plain Flutter control reproduces it. This is a documented composition limitation, not a proven introduced regression. Minimum SDK APIs source-checked only. Scheduler/Combobox recovery tasks remain active.

## 2026-10-24 resumed recovery checkpoint

Collapsible focus-precedence parent verifier completed with exit 0. Log: `/tmp/beui-collapsible-precedence-parent-verify.log`; 2,717 manifest files, 363 PNGs, eight videos, 267 RGB-exact replay frames, 27 checks per source/candidate motion run. Independent r2 review remains running; no acceptance inferred.

Fresh Combobox recovery r2 and Scheduler initial task ended with provider errors. Existing edits and evidence remain preserved. Recovery tasks now running, each with disjoint owned paths:
- `v3-combobox-exit-final-recovery-20261024-r3`
- `v3-scheduler-copy-recovery-20261024-r2`

Collapsible independent review task remains `v3-collapsible-focus-review-20261024-r2`. All use the existing delegated-task ID prefix. Disk had 2.6 GiB available at restart. No new commit/push or parity claim in this checkpoint.

## Collapsible review blocks acceptance on rebuild-time owner focus

Independent r1 review:16 existing tests pass, additional14 pass/2 fail. When owner requests outside focus during rebuild that closes focused content, didUpdateWidget trigger restoration overrides it. Both motion preferences reproduce; pre-pump pending-focus tests miss ordering. Reviewed productione4a3fbf525e2534ebff073919d07e367b3d3c6bbae0ed3a13d2a7d12150d1614. Repro/logs copied to resume-20261024/collapsible-review-r1.9677 saved hash entries verified independently, no video re-decode by reviewer.

Active `v3-collapsible-focus-precedence-repair-20261024-r3` owns original component/tests and NEW collapsible-focus-precedence evidence, ports18189-18190. Must preserve controlled close behavior and later owner intent using supported APIs; no shared focus patches. Scheduler and Combobox fresh recovery continue. No Collapsible acceptance/commit/push yet.

## Disk pressure relieved; Collapsible parent verifier passed

Parent documented verify-recovery.py completed exit0. Historical unfinished verify.py failure retained separately. Independent Collapsible review still active.

Disk had299MiB free. Removed only four parent-created tracked-only export copies after checking their delivery commits are ancestors of HEAD: sortable-staged-rhrqqbb6,filetree-staged-fih6r03c,multiselect-staged-d9o78u18,integrated-native-staged-v38cth7w. All contents remain committed canonical archives and prior verifier logs remain. These temporary export paths are now intentionally absent. No original captures, worker scratch or unrelated files removed. Available space now2.9GiB.

## Collapsible recovery complete; independent review underway

Productione4a3fbf525e2534ebff073919d07e367b3d3c6bbae0ed3a13d2a7d12150d1614 restores controlled-close focus only on effective owner acceptance.16 non-golden tests pass. Native both preferences plus separate supplemental disposal checks support bounded repair; recovery5 disposal failure remains recorded. Autonomous content growth/shrink/width/hidden reopening already work, no measurement fix. Archive2844 PNGs/43 videos/2546 RGB frames verified by recovery worker regular export. Timing120vs180ms/closed1vs0px differences remain.

Active `v3-collapsible-independent-review-20261024-r1`. Parent initially invoked historical unfinished verify.py, failed exit1; log retained /tmp/beui-collapsible-parent-verify.log. Correct documented verify-recovery.py now running /tmp/beui-collapsible-parent-recovery-verify.log. Do not mistake historical verifier failure for artifact loss. Recovery report discloses earlier ENOSPC; check available disk before additional full exports. Scheduler/Combobox workers remain separate. No acceptance/commit yet.

## Collapsible recovery moved to fresh worker

Same-thread Collapsible retry failed again at provider level. Fresh `v3-collapsible-fresh-recovery-20261024-r2` exclusively owns original component/test/evidence and will audit saved checkpoint before completing missing verification. All prior artifacts preserved; failed original task is not active. Combobox fresh recovery and Scheduler remain independent. No acceptance, commit or push of these partial repairs.

## Combobox recovery moved to fresh worker

Same-thread recovery also failed Provider turn failed. Parent inspected saved work:21 production lines/139 test lines, red/green/analyzer logs, native-1 four context frame counts323/69/261/49. No matching Combobox/server process found. Active fresh `v3-combobox-exit-fresh-recovery-20261024-r2` now exclusively owns original files/evidence, audits saved outputs and finishes missing portable verification; must preserve every prior artifact and avoid duplicate capture. Original failed worker is not active. No code acceptance inferred from partial logs.

## Collapsible provider failure recovery

Original Collapsible r1 failed at provider level with no live child runs. Partial component/test changes and before/after/native capture artifacts are preserved in collapsible-lifecycle/. Resumed same worker via v3-collapsible-provider-recovery-20261024-r1, requiring audit of prior logs/processes before continuing without duplicate capture or lost evidence. Combobox recovery and Scheduler task remain separate. No acceptance or code-failure inference; latest delivered1c980497a.

## Combobox provider failure recovery

Original v3-combobox-exit-filter-repair-20261024-r1 failed at provider level, no live child runs. Partial component/test edits and red/green/analyzer/native-1 evidence exist in combobox-exit/ and /tmp/beui-combobox-exit-20261024. Resumed same worker conversation through idempotent v3-combobox-exit-provider-recovery-20261024-r1; must audit saved process/evidence state before continuing, preserve originals and avoid duplicate captures. No acceptance or code-failure conclusion from provider error. Scheduler and Collapsible remain active separately. Latest pushed1c980497a, integrated-gallery archive delivered and PR updated.

## Combined gallery archive verified for delivery

Parent and independent tracked-only export verifiers pass (exit0),1678 archive files. Export `/var/folders/nd/g6xnd2650d5444zpkr29ppgm0000gn/T/beui-integrated-native-staged-v38cth7w`, logs `/tmp/beui-components-native-parent-verify.log` and `/tmp/beui-integrated-native-staged-verify.log`. Evidence preserves known failures and gallery traversal limits, not exact parity. Ready for archive commit/push.

Active implementation tasks: Scheduler copy-menu keyboard r1, Collapsible lifecycle r1, and `v3-combobox-exit-filter-repair-20261024-r1` (new combobox-exit evidence, ports18187-18188). All own disjoint production/tests and must reproduce first. No broad rerun until changed inputs justify it. No merge authorized.

## Combined actual-gallery native evidence complete; archive verification underway

Fresh combined gallery build served JS11c8793e3b26481a2dc98940ba5d8ed3449b88d8ca41d959cab446ce7fa11f00, all six reviewed input hashes match. Actual MultiSelect/FileTree/Sortable routes tested under both motion preferences. No new production regression established. Known Sortable BODY focus after accepted move reproduced without recovery; pointer Undo works. MultiSelect browser-document exit/related-route traversal differs from supplemental fixture; no generic Tab parity claim. FileTree gallery lacks disabled rows; current-item semantics remain distinct from selectable-tree semantics.

Evidence components-integrated-native/ retains16 recordings/951 original frames, all failed assumptions and exact inputs. Parent verifier session66528 and tracked-only staged export verifier running; export path /tmp/beui-integrated-native-staged-path. Commit/push archive after exit0. Scheduler and Collapsible failing-first work continue separately; their test edits are unstaged and excluded. Last pushedc39e7e8bf.

## Next bounded work started after reviewed component delivery

Reconciliation copied to resume-20261024/next-obligations.md. Active independent implementation tasks:
- `v3-scheduler-copy-keyboard-repair-20261024-r1`: real copy-menu keyboard toggle/footer outcomes, owns copy_menu.dart + scheduler tests and new scheduler-copy evidence, ports18183-18184.
- `v3-collapsible-lifecycle-repair-20261024-r1`: reproduce controlled-close focus and stable-child growth before fixing, owns collapsible.dart/tests/new lifecycle evidence, ports18185-18186.

Both require failing-first and native exact-input verification, no shared edits or golden changes. Combobox exit-filter retention is next unassigned source-contract finding. Combined gallery native task remains active on prior immutable delivered snapshot. Latest remote deliveryc39e7e8bf; no new implementation accepted yet.

## Latest delivered head:8fdc8cb5f

Push confirmed successful through FileTree a4bbd37ee and MultiSelect8fdc8cb5f. Both reviewed repairs, all preserved evidence and integrated test logs are on PR26. Root2609 passes/56 unchanged golden failure identities; gallery66 passes. PR description updated with scoped acceptance and limits.

Active: `v3-components-integrated-native-20261024-r1` checks combined actual gallery build, and read-only `v3-next-obligations-after-components-20261024-r4` reconciles next work at /tmp/beui-next-after-components-20261024.md. No other production worker active. Sortable Flutter semantics-move focus blocker194550, FileTree tree-role/current-state mismatch, exact pixels/native60 and broader coverage remain unresolved. No hosted-CI/merge/deployment claim. Preserve .impeccable.

## FileTree and MultiSelect delivery

FileTree a4bbd37ee and MultiSelect8fdc8cb5f are committed, with all originals, review artifacts and integrated logs. All four MultiSelect portable verifiers exited0 from tracked-only export30436 evidence files; both FileTree verifiers exited0 from tracked-only export10292 evidence files. Push completed to akshay/v3-ship at8fdc8cb5f. FileTree a4bbd37ee and MultiSelect8fdc8cb5f are delivered.

Final scoped independent reviews accept both production hashes. Integrated root2609 passes/56 unchanged golden failures and gallery66 passes. Combined native task `v3-components-integrated-native-20261024-r1` remains active; no complete native integration or hosted-CI claim. Sortable engine move-focus blocker194550, FileTree roles/current-vs-selected limitations, exact pixels and native60 remain unresolved. PR body update prepared `/tmp/beui-pr26-components-final.md`; publish after push success. No merge authorized.

## Delivery queue and combined-gallery native task

FileTree commit a4bbd37ee is local, not yet pushed. MultiSelect staging holds30438 paths: code/tests plus30436 evidence/integration files, no file over100MB. Tracked-only export `/var/folders/nd/g6xnd2650d5444zpkr29ppgm0000gn/T/beui-multiselect-staged-d9o78u18`; four verifiers run in session54272, logs `/tmp/beui-multiselect-staged-multiselect-{native,repair,focus,tab}.log`. After all pass commit and push both deliveries, then update PR26.

Active `v3-components-integrated-native-20261024-r1` owns new components-integrated-native/ only, builds exact reviewed combined gallery snapshot and tests actual demo interactions. No production editor active. Preserves known Sortable native focus failure, no invented demo controls. Root2609 passes56 unchanged golden failures and gallery66 passes already complete; no repeat broad tests needed without new findings.

## Integrated suites complete; MultiSelect accepted and archive staged

Root2609 passes/56 golden failures; exact same56 failure identities as calendar baseline, zero new/removed. Gallery66 passes. All6 source/test input hashes unchanged. Logs/summary copied to components-integration-20261024/. No goldens updated. FileTree code and full evidence committed after both tracked-export verifiers passed.

Independent MultiSelect r3 accepts productionb58e5bfb3c254357da25ae3af77ff22a0b5526160d77e8c3ec2e7496e87c95bb:32 final tests,5 r2 controls,5 r1 controls,4 extra checks pass;804 archived native checks and3749 frames verified. Same-node/same-frame precedence remains widget-only. Review artifacts copied to multiselect-review-r3/. Staged only MultiSelect code/tests, all4 native archives,3 review directories and integration logs. Tracked-only export path recorded /tmp/beui-multiselect-staged-path;4 portable verifiers running. Wait all exits0 before commit/push.

Combined native gallery build remains separate unverified layer; native fixtures were isolated. Sortable engine focus blocker and FileTree role differences remain explicit. No merge authorized.

## FileTree review accepted; staged export verification underway

Independent FileTree review accepts bounded code,12 focused checks pass on current/minimum SDK; exact selectable-tree roles still unavailable and aria-current not equivalent to aria-selected. Review logs/probes copied to `filetree-review-r1/`. Staged only FileTree code/tests and filetree-native/semantics/review-r1 archives including ignored dependencies. Tracked-only export/verifiers running session78387, export path recorded `/tmp/beui-filetree-staged-path`. Wait for both verifier exits0 and integrated root outcomes before committing. MultiSelect remains unstaged awaiting final review.

Gallery integrated suite completed exit0. Root session50350 still running. MultiSelect Tab archive parent verifier completed exit0. No full-suite conclusion until root summary/failure identities compared.

## MultiSelect final implementation and integrated gates in progress

R3 productionb58e5bfb3c254357da25ae3af77ff22a0b5526160d77e8c3ec2e7496e87c95bb passes32 focused tests plus5 prior review controls, analysis and804 native checks across8 runs. Tab policy follows focus destinations, controlled query rejection remains effective; same-node owner focus is made observable before selection callback. New archive `multiselect-tab/` retains3749 frames. Active final independent review `v3-multiselect-final-review-20261024-r3`; parent archive verifier session76188 log `/tmp/beui-multiselect-tab-parent-verify.log`. No acceptance yet.

With both FileTree and MultiSelect implementations idle awaiting reviews, parent started fresh unsuppressed root and gallery suites. Logs `/tmp/beui-components-integration-{root,gallery}-20261024.jsonl` and `.stderr`; exact six source/test hashes recorded `/tmp/beui-components-integration-inputs-20261024.json`. Must compare failure identities against prior56 golden failures. No baselines changed. Review findings may require fresh targeted gates and invalidate parts of this run; do not infer exact final-head pass early.

## FileTree semantics repair awaiting independent review

Production06da09b01f4636df4c14d35f8ad0ee3863d7ab9921bc0e028c2d4d7f7fcd6105 adds child button semantics carrying disabled/selected state while outer list item retains focus/expansion. Native mapping is aria-current, not source aria-selected; Flutter3.44.2 public roles lack tree/treeitem. Exact semantics parity remains unavailable.10 non-golden tests and analysis pass on current and minimum SDK.96 original native checkpoints plus disabled folder/content controls pass both preferences. Immediate-collapse focus unchanged.3385 original frames preserved, one intermediate MP4 count loss disclosed.

Active `v3-filetree-semantics-review-20261024-r1` independently checks semantics meaning, lifecycle and disabled focusability. Parent independently reran the semantics archive verifier successfully (exit 0), `/tmp/beui-filetree-semantics-parent-verify.log`. Recorded role/state differences remain explicit. No acceptance or commit yet. MultiSelect r3 continues with same-owner-focus finding included. Last pushed941bd9229.

## MultiSelect r2 review: same external owner focus still overridden

Independent immutable-input review found P2: already-focused external TextField explicitly retained by onChanged.requestFocus is overridden by deferred chip callback because focus equals previousFocus. Reproduced twice on dba8218b7d836f7a7d48994417a7573ca3682ef2daf5f62a27058aa49beafa12.29 supplied/prior tests plus4 extra controls pass; all374 archived candidate native checks independently verified. Same-node precedence is widget-proven, not native. Review/repro/log copied into `multiselect-review-r2/`.

Steered active `v3-multiselect-tab-repair-20261024-r3` to include this exact failing case before its final build and preserve normal chip focus behavior without owner override. No concurrent production editor added. Acceptance remains withheld. FileTree semantics task remains active. Latest pushed941bd9229.

## MultiSelect focus repair complete; review and Tab follow-up active

R2 production dba8218b7d836f7a7d48994417a7573ca3682ef2daf5f62a27058aa49beafa12 passes24 tests/analysis and374 candidate native checks. Guarded focus intent respects later external/owner decisions; chip tooltip absent from source caused ancestor DOM movement and was replaced by accessible label; typing reopens after Escape. Evidence `multiselect-focus/` retains5008 original frames and all failures, including one source chip-count discrepancy that passed exact-build rerun. Same-frame external click is widget-proven, not native timing-proven. Parent independently reran the focus archive verifier successfully (exit 0), `/tmp/beui-multiselect-focus-parent-verify.log`. This verifies archived outcomes; the disclosed Tab difference remains unresolved.

Active immutable-input review `v3-multiselect-focus-review-20261024-r2`. Active implementation `v3-multiselect-tab-repair-20261024-r3` addresses known remaining Tab close/clear and Shift+Tab reopen-empty difference, owns MultiSelect files and new `multiselect-tab/`. FileTree semantics work continues. Sortable archive941bd9229 pushed and PR26 description updated; native move-focus dependency remains open. No MultiSelect acceptance/commit yet.

## Sortable archive committed941bd9229

All three staged-export verifiers exited0: sortable-undo, sortable-focus, sortable-dependency. Commit941bd9229 archives12408 files preserving rejected captures, original PNGs/videos, exact inputs and upstream research. Push to akshay/v3-ship completed at941bd9229. No parity pass: native reorder focus blocker194550 remains. Production91819aa8e is already pushed; no merge.

MultiSelect/FileTree worker edits remain separate and uncommitted. State file itself pending consolidation.

## Sortable archive staged; tracked-only export verification running

Explicitly staged all files, including ignored dependencies, from sortable-undo, sortable-focus and sortable-dependency:12408 files total. Independent regular-file index export is `/var/folders/nd/g6xnd2650d5444zpkr29ppgm0000gn/T/beui-sortable-staged-rhrqqbb6`. Sequential portable verifiers running in session49547 with logs `/tmp/beui-sortable-staged-sortable-{undo,focus,dependency}.log`. Must confirm all exits0 before archive commit/push. Existing ownership evidence already delivered91819aa8e. Native focus remains failed; this is archival integrity only.

Other worker production edits are unstaged and excluded. Preserve .impeccable. Next after verification: archive commit, authorized push, record exact remote head. No new capture or encoding.

## FileTree native comparison complete; semantics repair active

`filetree-native/` preserves96 final checkpoints across both preferences and1663 original frames. Navigation, disabled activation blocking, callbacks and post-collapse Tab/selection match bounded source. Disabled rows are focusable in source; do not skip them. Immediate collapse focus differs (source BODY/candidate Parent) while tested continuation agrees. Candidate list/listitem markup lacks source tree/treeitem selected/disabled states; no accessible parity acceptance.

Active `v3-filetree-semantics-repair-20261024-r1` owns FileTree component/test and new `filetree-semantics/`. Requires minimum-SDK-supported roles/states, failing-first semantics tests, native exact-build markup plus keyboard controls, no shared edits or speculative collapse-focus change. Parent independently reran the baseline archive verifier successfully (exit 0), `/tmp/beui-filetree-parent-verify.log`. This confirms preserved evidence and bounded outcomes, not accessible-role parity. MultiSelect r2 remains running; Sortable archive preparation active. Last pushed head91819aa8e.

## Sortable archival consolidation active

`v3-sortable-archive-consolidation-20261024-r1` prepares new `sortable-dependency/` from preserved /tmp topology/upstream/reviewer evidence, exact originals and portable export verification. No staging/commit or old proof edits. Parent still needs to commit/push large existing sortable-undo and sortable-focus archives plus this new dependency archive after verification. Reviewed production91819aa8e is already pushed.

## Reviewed Sortable fixes committed91819aa8e

Independent ownership review r2 accepts exact production083f0b5b6a479d249c14050713186b23418ce449710d4e7f03f715a834994c98: original10 probes,36 focused tests,1 additional reactivation test pass; broken-input control29 pass/7 fail. Commit91819aa8e contains code/tests and ownership evidence/review logs. Push completed to akshay/v3-ship at91819aa8e. Raw logs/patches retain original trailing whitespace intentionally; production diff checks passed.

Upstream research found no supported fix in Flutter3.47.1–3.47.8 or main457d49bc600142ecb927f382cf20a728af186ea7. Issue flutter/flutter#194550 matches the semantics-move blur mechanism. Native move retention remains a runtime blocker. Report/raw sources106 hashes remain `/tmp/beui-sortable-upstream-20261024`; topology diagnostics remain `/tmp/beui-sortable-topology-20261024`. These and the large Sortable native archives still need durable archival delivery. No SDK upgrade, guard expansion or upstream posting performed.

MultiSelect r2 and FileTree native work continue. No complete parity, broad integrated gate or hosted-CI claim.

## Sortable handle ownership repair complete, independent recheck active

Production SHA083f0b5b6a479d249c14050713186b23418ce449710d4e7f03f715a834994c98 and test SHA1480670bd61883ef1a7deb14eb6add4050cf72b161767a4fe04ba06bae3666ad use per-mounted-handle nodes and identity-keyed registry.36 focused tests pass; identical tests have7 failures against broken input; analysis/diff checks clean. Evidence is `sortable-handle-ownership/`. Active `v3-sortable-handle-ownership-review-20261024-r2` independently rechecks original four probes and lifecycle transfer/cleanup/Undo controls.

Native reorder focus remains unresolved; upstream research active. MultiSelect r2 and FileTree native task remain active. No production acceptance, new commits or pushes yet.

## Sortable topology diagnostics rejected; upstream dependency research active

/tmp/beui-sortable-topology-20261024/REPORT.md records no safe fix: removing OrdinalSortKey still loses ArrowDown focus; diagnostic keyed Column preserves ArrowDown/End but loses Home focus on same-parent DOM move, and removes drag support. Do not land either diff.409 original frames/traces retained and hashed in that directory. Dependency includes index-dependent framework semantics wrappers plus engine DOM reconciliation; accessibility/removal/external-focus acceptance remains unproven.

Active `v3-sortable-upstream-dependency-20261024-r1` checks official released/main fixes read-only, no SDK changes. Sortable per-mounted-handle repair and MultiSelect r2 remain active. Independent next obligation `v3-filetree-native-states-20261024-r1` verifies nested traversal/collapse on isolated HEAD1254bfa63 in new `filetree-native/`, ports18173-18174; no production edits. Parent Sortable focus archive integrity verified5051 hashes, strict behavior still FAIL. No new commit/push.

## Sortable independent review: duplicate handle ownership regression

Review r1 demonstrated one introduced P2 with four probes: item-keyed shared FocusNode makes first handle activate second, disabled second suppresses first, and removing second breaks surviving focus. Candidate6 pass/4 fail versus baseline10 pass; existing22 pass. Repros/logs in `/tmp/sortable-independent-review-20261024`. These are widget proofs, separate from native move-focus loss.

Active `v3-sortable-handle-ownership-repair-20261024-r3` owns Sortable production/test and new `sortable-handle-ownership/` evidence. Requires per-mounted-handle lifecycle ownership with item-ID registry for eligible Undo focus, identity-guarded cleanup/transfer, failing-first reviewer cases and controls. /tmp-only semantics design remains independent. MultiSelect r2 repair continues. No acceptance, commits or push.

## Sortable Undo focus repaired; uninterrupted keyboard movement still blocked

R2 component SHA2ba3a4643a7fdeccc7521380a3749fb7ec9a4317f96ed2da3e2c24905a1068c4 owns handle FocusNodes and focuses restored B before publishing Undo.22 focused tests/analysis pass. Native original sequence300/316 candidate vs316/316 source; both preferences pass Home-to-Undo focus. Accepted moves still reparent the focused semantics subtree, causing BODY focusout and Flutter root-scope focus. Uninterrupted subsequent End/Home fail. Archive `sortable-focus/` retains2062 original frames and all failures; strict parity exits1. Parent integrity verification running at `/tmp/beui-sortable-focus-parent-verify.log`.

Active independent tasks:
- `v3-sortable-owned-focus-review-20261024-r1`: read-only lifecycle/API review of the narrow Undo patch.
- `v3-sortable-semantics-design-20261024-r3`: /tmp-only design/proof, testing supported stable semantics topology before concluding an engine fix is required. No production/shared guard/SDK edits.

MultiSelect r2 repair remains active. No new commit/push or parity acceptance. Earlier archives remain unchanged.

## MultiSelect review found focus ownership and Escape continuation failures

Independent r1 review demonstrated two P2s. Deferred chip focus steals a later external field click before the next frame (baseline passes, patch fails widget repro). Native accepting normal-motion chip removal then typing, Escape and typing loses subsequent input on BODY. Three other owner/motion controls retain input. Direct-input Escape then typing also fails to reopen popup in baseline and patch, unlike source. Existing17 tests pass but do not cover these failures. Full review/repros retained in `/tmp/multiselect-independent-review`; review report copied to `multiselect-review-r1/`.

Active `v3-multiselect-focus-lifecycle-repair-20261024-r2` owns MultiSelect production/test and new `multiselect-focus/` evidence only. Requires failing-first lifecycle tests, root-cause repair preserving later external intent, native full typing continuation, exact hashes and complete originals. No shared overlay or old evidence edits. Parent repair archive integrity has passed, but production acceptance remains blocked. Sortable native focus task remains active. No new commit/push.

## MultiSelect pointer repair awaiting independent review

Worker repair is complete, uncommitted. Component SHA `5965a2e74edb3c9fd88f5bf80ee9463924b1c9a6064b0d04fde93bd178061cd9`: removes component barrier/focus trap, groups trigger/input/popup tap regions, defers chip input focus until after rebuild. Eight failing-first regressions;17 focused tests and analysis pass. Final eight native runs pass548 bounded checks for removal and subsequent typing. Archive `multiselect-repair/` retains24 runs,5638 original frames and480 checkpoints; two timestamp losses disclosed with complete RGB replays.

Escape still leaves candidate native focus on BODY while source retains INPUT. Acceptance remains open. Active independent `v3-multiselect-repair-review-20261024-r1` checks deferred-focus ownership/lifecycle, controlled state, outside dismissal and the Escape continuation gap. Parent independently reran the repair archive verifier successfully (exit 0), log `/tmp/beui-multiselect-repair-parent-verify.log`. This verifies preserved artifacts and bounded assertions, not Escape focus parity.

Parent Sortable r1 archive verifier completed successfully, including documented focus failures and media loss. Sortable r2 native-focus repair remains active. No new commit/push, exact parity or golden acceptance.

## Sortable Undo passes bounded order checks; native focus repair active

The r1 order-based `_canUndo` and action guard pass 15 targeted tests and analysis. Source/candidate native order, callbacks, Undo, reset, membership and disabled checks pass both motion preferences. Native acceptance remains blocked by 20 candidate focus failures: accepted moves lose DOM focus and Home then Undo focuses A where source focuses B. Evidence is immutable in `sortable-undo/`; one 11/12 timestamp video has a verified complete RGB replay. Parent integrity verification started at `/tmp/beui-sortable-parent-verify.log`.

Active `v3-sortable-native-focus-repair-20261023-r2` owns only Sortable production/test and new `sortable-focus/` evidence. Must diagnose focus mechanism, preserve prior Undo patch, verify supported component-owned correction and native retention without recorder focus recovery. Shared DOM/overlay edits are excluded. MultiSelect repair continues independently. No acceptance, new commit or push yet.

## MultiSelect native findings and repair in progress

Native verification completed in `multiselect-native/`: open-popup chip X clicks dismiss without a removal callback for accepting/rejecting owners under both motion preferences. Closed-popup removal emits the callback but differs from source input focus/popup behavior. Subsequent typing needs verification. Backspace/query editing, controlled ownership and disabled exclusion passed within the recorded slice.

Active `v3-multiselect-pointer-repair-20261023-r1` owns only multi_select.dart, its widget test and new `multiselect-repair/` evidence. Requires failing-first regression, component-owned correction, native removal plus subsequent typing/outside/Escape controls, exact hashes and preserved originals. No shared overlay edits authorized to worker. Baseline archive has 4,761 original frames and 340 checkpoints; one timestamp video omits a frame, complete replay preserved separately. Parent independently reran the archive verifier successfully (exit 0), log `/tmp/beui-multiselect-parent-verify.log`. This confirms archive integrity and recorded outcomes, including the failures; it does not establish repaired behavior.

Sortable repair task remains in progress. No new commits or pushes yet; latest delivered head remains1254bfa63. Parent review/integration remains required, no parity certification.

## Active follow-up: Sortable Undo and MultiSelect native states

Returns Calendar production and archive are pushed through `1254bfa63` to `akshay/v3-ship`. PR26 remains open; no merge or parity certification.

Two scoped asynchronous tasks are running:
- `v3-sortable-undo-repair-20261023-r1`: failing-first reproduction, order-based Undo repair, and source/candidate native verification. Owns Sortable production/test files and new `sortable-undo/` evidence only.
- `v3-multiselect-native-states-20261023-r1`: source/candidate native token removal and controlled rejection verification. Owns new `multiselect-native/` evidence only; no production edits.

Parent will review results, verify archives and integrate before pushing. Current baseline retains 56 golden failures; no baselines are to be regenerated. FileTree nested collapse/focus continuation remains next. Detailed acceptance is in `/tmp/beui-next-after-calendars-20261023.md`. Existing `.impeccable/` is unrelated and preserved.

# Continued parity run — 2026-10-23

Done means the scoped source behaviors, appearance and motion are implemented and verified with preserved source/candidate evidence, integrated gates, and pushed PR26 updates. No merge is authorized. Exact parity remains incomplete.

## Latest delivery: Returns Calendar accepted with media limits

- Production d8688c53f resolves R020-R025 within scoped independent r3 acceptance. Parent final native replay passes122 checkpoints; exact-source JS9bfd345c6eabe788cc9600937600d27aa322dac097cc479c568fd6ee08e5499a. Parent inspected January2030 replacement focus/readout. Focus DOM tags remain intentionally distinct from source BODY behavior.
- Fresh integrated root2,553 passes/56 golden failures. Failure identity set exactly matches earlier56; no new or removed failures. Full gallery66 passes. Logs and comparison under returns-calendar-repair/integration. No golden updates.
- Clean staged regular-file export /var/folders/nd/g6xnd2650d5444zpkr29ppgm0000gn/T/beui-returns-final-export-ocj4mk3v verifies12,551 hashes,22 decoded videos,10,312 recorded frames and final native assertions. Two timestamp-video count mismatches are explicitly retained: parent reduced559/560, rejected worker intermediate528/529. All original PNGs preserved. Supplemental560-frame index replay decodes byte-identically to original RGB, but25fps inspection playback is not native timing proof.
- Returns repair/review tasks are complete. Owned final server18158 stopped after verification. Active read-only `v3-next-obligations-after-calendars-20261023-r3` writes /tmp/beui-next-after-calendars-20261023.md, prioritizing remaining concrete scope from current evidence. No production edits delegated. Exact parity, screen-reader coverage, native60 and56 golden failures remain open.
- Archive and this state are queued for commit/push with PR26 update. Preserve all originals and .impeccable. No merge authorized.

## Returns Calendar final owner transfer verification

- Review r2 resolved previous three findings but found R025: retained cells moving between calendar owners keep registrations in the old map. Parent added guarded transfer in _ReturnsCellState.didUpdateWidget, plus all4 reviewer ownership/control cases. Red run had exactly2 failures; full parent charts now302 pass with goldens disabled, scoped analysis clean.
- Review r3 accepted the bounded correction;19 independent focused checks passed. No source commit yet. Exact-source isolated release build passes; native source/candidate capture runs in /tmp/beui-returns-parent-final/attempt-final, session71240, owned server18158 session4944. Served JS9bfd345c6eabe788cc9600937600d27aa322dac097cc479c568fd6ee08e5499a verified. Final manifests generated by manifest.py.
- Evidence remains unsealed under returns-calendar-repair with worker-r1, worker-r2 and three reviews. After capture run parent verify.py, inspect screenshots, copy manifest inputs and original media to parent-final, seal/archive/export verification, commit code/evidence and push. Broader integration full-root/gallery gates need refreshing after these calendar repairs; earlier56 golden failures are not waived.

## Returns Calendar independent findings and second repair

- First patch parent full chart run292 passes with goldens disabled, but review found three demonstrated lifecycle/API regressions; acceptance remains blocked. Preserve passing logs as narrow evidence, not general correctness.
- R022: disposing an old cell deletes a newer same-identity focus registration after custom grid remount. R023: GlobalKey reparenting drops retained focus because deactivate is treated as removal. R024: duplicate year values throw after new row keys, regressing the previously supported input.
- Active implementation `v3-returns-calendar-lifecycle-repair-20261023-r2` owns the same two code/test files and /tmp port18157. Must retain intended native year replacement/empty behavior while fixing registration ownership, distinguishing temporary deactivation and preserving duplicate-year compatibility. No production commit/push yet.
- Review repros and before/patched/guard logs retained in returns-calendar-repair/review-r1. Worker-r1 evidence remains unchanged. Next: focused red/green and final-input native replay, independent review, archive/export verification, then code/evidence commits and authorized push.

## Returns Calendar repair review underway

- Worker r1 patch remains uncommitted in returns_calendar.dart and returns_calendar_native_regression_test.dart. Year-keyed rows replace month identities; a skipTraversal grid focus anchor preserves next-Tab position after row replacement, while scope history is cleared on emptying. Source positional hover and controlled index selection remain intentional.
- Parent13 focused tests pass with goldens disabled; analyzer clean. Parent independently ran /tmp/returns-repair/verify-final.py against final manifests and all92 native checkpoints. Full chart suite running session56954, log /tmp/beui-returns-parent-charts.log; final PNG/frame hash plus ffprobe verification session25432.
- Independent review `v3-returns-calendar-independent-review-20261023-r1` active: teardown, focus-steal/stale-anchor, identity/reorder/custom composition and controlled selection. Do not accept until findings are handled.
- Pending evidence archive returns-calendar-repair/worker-r1 preserves worker originals, failed attempts and all final-input-hashes inputs. It is unsealed/uncommitted. Production SHA2245c5e829b4b0ec35907346d1e03908685c0bc22ab2d21f11e57fca0e890e80; native JSd3ddef897a2efa519bd4139e71ee8eb11bdc3d930444c011173ab114f8601f7e. Worker port18156 closed. Source BODY vs non-tabbable Flutter grid anchor is an explicit DOM distinction, not screen-reader certification.
- Next: consume review, fix demonstrated findings, verify final native inputs and behavior, seal/export archive, commit code/evidence separately and push PR26. Before evidence08c2133cf already pushed. Preserve .impeccable and originals.

## Latest continuation: Returns Calendar defects

- Heat Calendar repair/evidence pushed through aef70e819. Returns Calendar native worker completed and parent is accepting its before-repair archive. Final four sessions retain92 observations and1,373 original frames, with source/input/served hashes and rejected attempts.
- R020: year replacement retains candidate month element/focus by row position while source disconnects it. Next Tab reaches candidate April instead of source January. Restoring the year also differs. Both motion preferences reproduce this.
- R021: emptying all years restores candidate focus to a previously visited fixture control; source goes to body. Next Tab reaches replace versus source initial. Native focus history is under investigation.
- Missing-month truncation/reinsertion readouts and retained focus agree. Preserve these. Source stale Jan readout after restoration is explicitly recorded, not silently normalized into a generic cleanup rule.
- Active repair `v3-returns-calendar-repair-20261023-r1` owns returns_calendar.dart and a new focused regression file, plus /tmp port18156. Requires failing-first tests and exact-input native validation; no shared Tooltip/overlay changes or old-proof edits. No production fix accepted yet.

## Latest delivery: Heat Calendar accepted and archived

- Production d74fae552 accepted after independent review and final parent native checks. Archive clean staged regular-file export passes10,972 hashes,22 decoded videos,9,741 recorded frames,8 final default sessions and4 custom sessions. Export /var/folders/nd/g6xnd2650d5444zpkr29ppgm0000gn/T/beui-heat-final-export-rztazgt4. No original/golden edits.
- R016 legend filtering, R017 final-day Tab order, R018 stale readout/removal continuation and R019 invalid locked-range cleanup are resolved within the default and documented custom scopes. Parent chart287 pass with goldens disabled; no global pixel/timing/golden certification.
- Active task `v3-returns-calendar-native-states-20261023-r1` owns only returns-calendar-native proof paths and /tmp/port18155. Verifies deterministic missing-month/year replacement and focused identity lifecycle, no production changes assumed.
- Prior Heat Calendar repair/review tasks completed. Parent capture servers18152/18154 closed after archival. Worker18153 cleanup is checked against its actual process command. Older unrelated servers untouched. Pending action: commit archive/RUN_STATE, push authorized PR26 branch and update body.

## Heat Calendar accepted behavior repair

- Production d74fae552 resolves R016-R019 within the reviewed scope. Independent review r2 accepted both lifecycle fixes with no new demonstrated regression;18 regression tests plus5 independent lifecycle checks pass. New focus APIs exist in Flutter3.44.2.
- Parent chart gate287 passes with goldens disabled, analysis clean, exact final-source release build pass. Parent final default capture passes both motion preferences: no immediate day focus on removal; forward Tab legend0; reverse Tab final surviving day; external-focus cancellation; fresh October5-6 range after invalid endpoint removal. Parent inspected reduced-motion range screenshot. No pixel/native60 acceptance.
- Heat-calendar-repair archive includes worker rounds, intermediate parent failures, both reviews and final parent capture. Final source chart hash939a3ea71a36b7e50358cdc38576f2f2da2ba68f91c0acdddaae4286dab5e548. Final parent JS0aa5333d1ee7c631898cd1cf40f151f8342fd0c075fc279e2efdc601e3eef991. Archive verification and push pending below; no golden edits.

## Heat Calendar final validation running

- Lifecycle worker r2 completed both continuation and invalid-range fixes. Shared chart SHA939a3ea71a36b7e50358cdc38576f2f2da2ba68f91c0acdddaae4286dab5e548; test SHAc22a9714daac51caff137bda86eeb4d68976f8a27dbd2a700f6c4787ea94c121. Uncommitted patch remains owned by parent.
- Parent full chart gate:287 pass with BEUI_SKIP_GOLDENS=1, log /tmp/beui-heat-parent-charts-final.log. Scoped analyzer and final-source release build pass. Parent native capture /tmp/beui-heat-parent-lifecycle/native-final is running in session16287, owned server18154 session87824. Served JS0aa5333d1ee7c631898cd1cf40f151f8342fd0c075fc279e2efdc601e3eef991 verified before capture.
- Independent review `v3-heat-calendar-lifecycle-review-20261023-r2` is active. No final acceptance yet. Worker evidence /tmp/heat-calendar-continuation has exact built source identity, both-preference default sessions and reduced-motion custom/no-legend checks. Its server18153 remains running.
- Pending archive heat-calendar-repair includes both prior rounds, original failures, intermediate parent capture, review-r1 and lifecycle-worker. verify.py awaits lifecycle-parent capture and archive-sha256.json. After capture: run /tmp/beui-heat-parent-lifecycle/check-native.py; inspect screenshots; copy all final inputs/builds/frames; seal; verify regular-file staged export; consume independent review; commit code separately from evidence; push PR26. Keep old archives and .impeccable untouched.

## Heat Calendar lifecycle follow-up in progress

- Parent exact-source capture completed:84 observations / 1,354 original frames across source/candidate and both preferences. Checked native inputs, PNG hashes and decoded frame counts. Final-day Tab reaches legends0/1; removal clears stale readout. Post-removal Tab still restarts at initial instead of source legend0. All remains intermediate proof, not final acceptance.
- Independent review r1 confirms that continuation gap and demonstrates R019: a locked range with removed end survives; the next click clears the invalid range instead of anchoring the clicked day. It fails both original and first repair. Review artifacts /tmp/heat-calendar-review, copied under pending heat-calendar-repair/review-r1.
- Active implementation `v3-heat-calendar-lifecycle-repair-20261023-r2` owns the same two production/test files and /tmp port18153. Requires failing-first cleanup regressions plus native validation of delayed Tab continuation, external focus cancellation and invalid locked selection. Supported FocusScope prototype is only widget-proven and must not be accepted without native proof.
- Parent intermediate archive heat-calendar-repair is unsealed/uncommitted; preserve worker and parent failed attempts. Parent capture server18152 remains available. No production commit or push yet.

## Heat Calendar repair review in progress

- Worker repair remains uncommitted in heat_calendar.dart and heat_calendar_native_regression_test.dart. Parent focused run passes19 tests with BEUI_SKIP_GOLDENS=1; scoped analyzer clean. Original worker regression run had8 failures/2 passes; patched10 pass.
- Independent review `v3-heat-calendar-repair-review-20261023-r1` is active. It also investigates the remaining next-Tab-after-removal difference. Do not accept that continuation as repaired yet.
- Parent exact-source isolated build in /tmp/beui-heat-parent-final succeeds. Production input hash is retained there. JS1eeb3bef7b0f0be9084470c89dc5c54d34c8b49b8c96f4d38b813051e367a9d9 matches worker behavior build despite final comment/import-only differences. Parent capture attempt2 runs on owned18152, server session76106, capture session19507. Attempt1 rejected after18151 bind conflict; existing listener left untouched.
- Parent before archive is already pushed as038257b6b. Do not edit it. Await review, inspect final captures, fix demonstrated findings, then archive/commit/push the accepted repair and evidence. Worker evidence /tmp/heat-calendar-repair remains intact.

## Latest continuation: Heat Calendar defects

- Native source/candidate sessions reproduce three behavioral differences under both motion preferences. These are failures, not missing-certification labels. Original heat-calendar-native evidence retains 84 final observations and 1,374 original frames plus earlier failed attempts.
- R016: legend hover does not filter and click/exit retains filtering. Candidate legend has only an onTap GestureDetector; source has pointer and focus handlers. Repair and regression pending.
- R017: Tab from focused October 23 reaches candidate October 3 then October 4 instead of source legend levels 0 and 1. Row-major semantics/native traversal is under investigation; cause not yet established.
- R018: removing focused October 23 by changing endDate to October 19 exposes stale October 4 readout. Parent visually inspected the retained screenshot. Focus/hover identity synchronization is under investigation; cause not yet established.
- Active child `v3-heat-calendar-repair-20261023-r1` owns heat_calendar.dart and a new focused regression file, with isolated /tmp native diagnostics on18150. No shared Tooltip/overlay edits, golden changes or broad suites. Before archive remains immutable; passing integrity verifies the recorded failures, not parity.

## Latest continuation: chart mono measurements

- The current candle/volume narrowing did not reproduce in a fresh fixture or actual gallery. Actual advances exactly match the named Geist Mono and registered monospace controls. Source DOM and candidate advances differ by less than 0.019px across six labels; source Canvas2D advances differ by less than 0.00055px. Baselines differ by 0.26px. No typography change is supported.
- Parent verified the chart-mono-diagnosis archive from an independent staged regular-file export: 623 hashes, six recomputed label comparisons, and untouched crop comparisons. Exact raster differences remain nonzero. The historical narrowing cause remains unresolved.
- Original input manifest contains an initial diagnostic fixture hash superseded by final-inputs.json. Final fixture bytes are retained; initial fixture bytes were not recovered. All other initial hashes match. This limitation is explicit in ARCHIVE.md and verifier.
- Mono diagnosis task is completed. Active child `v3-heat-calendar-native-states-20261023-r1` owns only new heat-calendar-native proof paths and /tmp, port18149. It checks blank/filter/refresh and focused identity with trusted native input under both motion preferences. No production repair or parity claim is assumed.

## Current delivery and next diagnosis

- Pushed Order Book evidence `41a4f7bb0` and SDK/raster evidence with effective minimum correction `7a17c6621` to PR26. No merge.
- Parent clean regular-file export verified all 880 SDK hashes and 256 raster diagnosis hashes, then independently checked all 14 SDK sessions / 294 native states. Actual ancestor reorders remain zero in this SDK run.
- Active child `v3-chart-mono-runtime-diagnosis-20261023-r1` measures actual candle/volume monospace paragraph advances and loaded-font selection. Owns only new /tmp artifacts and port18148; no production edits, broad suites, or original evidence changes. Task ID suffix matches that client request under the current T3 parent.
- Earlier SDK, Order Book and badge raster tasks are completed and integrated. Their historical active entries below are superseded. Remaining acceptance still includes nonzero pixels, 56 preserved root golden failures, native60, screen-reader coverage, full-demo timer correspondence and later route-state obligations. No parity gate is waived.

## Latest continuation: deterministic Order Book

- Parent independently exported the staged Git tree to regular files and ran the exported verifier. All 6,285 checks passed with no failures. Four final sessions retain 136 observations and 1,576 original frames, with source/candidate build identities and trusted events.
- Accepted scope: deterministic cumulative readouts, selection, exit, keyboard traversal, reorder, Step, empty state and focused-side replacement under both motion preferences. No production change. Full-demo timer equivalence, pixels and native60 remain open.
- SDK follow-up completed: Flutter 3.44.2 / Dart 3.12.2 passed fresh resolution, adapter compilation, 240 Chromium contract cases, release Bump build and 294 native states. Zero actual ancestor reorder events occurred; causal repair evidence remains established only from 3.44.3 upward. Evidence is retained in minimum-sdk-3442/REPORT.md. The Flutter declaration now states >=3.44.2, retaining Dart ^3.12.2.
- Typography diagnosis reproduced the badge ink difference with identical font bytes and explicit baselines in DOM and CanvasKit. No component offset or font change is supported. Historical chart mono advances remain unmeasured. Evidence is retained in table-raster-diagnosis/REPORT.md.

## Latest continuation: Table grid and badge

- Grid production `450699dec` and self-contained archive `de25e67b9` are pushed to PR26. Intrinsic header content remains52px and advances52.5px; body content uses full52px rows. Shared rules scroll beneath fixed header content. Default flex is unchanged. Fractional visible-rule omission was independently found, reproduced with raster assertions, fixed and re-reviewed.
- Exact grid library run:2520 root passes with the same56 golden failure identities; gallery63; scoped analysis and release pass. Final native30 horizontal comparisons and16 light/dark/preference/scroll pixel-column pairs pass. Original/rejected recordings remain in table-vertical-grid. Independent regular-file export verifies246 hashes and36 videos.
- Badge production `aa373177c` and archive `05d797156` are pushed to PR26. It uses the parent line baseline and respects cell width. Actual-Geist1x/2x tests and direct ambient-tracking regression pass. Final gallery66 passes with zero overflow messages; analysis/release pass. Root library files match the grid full-suite run, but that run is not relabeled exact-aa373177c proof.
- Badge archive table-badge-baseline passes independent regular-file export:113 hashes,16 decoded original videos,30 horizontal and16 grid comparisons. Ordinary fixture JS6467520a61c2b2750a3b3c7ab58678cf28d163d84590cada26af6029b9eb0ee0. Separate diagnostic JS2dfe2fbddaf70e2c6de237648de5d6553d50ab7635d8b2e23985d0e47a6984ca reports actual CanvasKit baselines124.48 normal and124.47 badge versus source124.5. Red ink bounds still differ by one pixel; no screenshot-fitted offset or exact badge raster claim.
- A gallery gate limitation was observed: its existing Multiple exceptions filter swallowed intermediate Row overflow messages. The direct regression caught it, the badge was constrained, and the final full-gallery log has no overflow messages. The intermediate falsely clean result remains in the archive.
- Minimum SDK task r1 confirmed Flutter3.44.0 bundles Dart3.12.0 and fails fresh resolution against ^3.12.2. Official source identifies Flutter3.44.2 / Dart3.12.2 as the earliest stable constraint-compatible pair; it is not yet behaviorally verified. Evidence /tmp/beui-pr26-min-sdk-20261023-evidence/REPORT.md. No constraints changed.
- Active child `v3-minimum-sdk-verify-20261023-r2`: isolated3.44.2 resolution, adapter contract, native Bump reorder; owns /tmp only, suggested18147. Active child `v3-order-book-native-states-20261023-r1`: deterministic fixed-snapshot native state proof, owns only order-book-deterministic proof directory and /tmp, suggested18146. No shared production edits delegated.
- Active child `v3-font-baseline-raster-diagnosis-20261023-r1` owns a read-only /tmp typography diagnosis; it uses retained ordinary18143 and diagnostic18144 endpoints. Next parent work: consume the SDK, Order Book and typography tasks. Badge archive and consolidated PR report are pushed. Read-only prioritization is /tmp/beui-pr26-next-obligations-20261023.md. No merge authorized. Superseded parent servers18138/18139/18140/18142 are stopped; final grid18141, badge18143 and diagnostic18144 remain owned for follow-up. Preserve .impeccable/. Historical sections below are superseded where newer evidence exists.

## Historical initial state

- Parent head before this document: `678812d36`; last confirmed pushed head `25b395e7`.
- Signup capture build: `c66a8825`, port 18121, JS `55ed90091a0f2213adc12a478b6013faa43cbf88aa60cfe38c4126dd84e19bcb`.
- Final light source/candidate workflow: both pass nine observed states. Dark/reduced source/candidate workflow also passes nine states each. Motion videos and sealing remain open.
- Sankey archive correction `4679320c` integrated as `678812d36`; parent verification passes 2,186 files / 16 recordings. Independent parent regular-file export passes the same 2,186 files / 16 recordings.
- Existing owners: candle/volume (18114), bump (18115), composition/funnel (18116), agent pixels (18117), component examples (18120). Do not duplicate their scopes.
- Coverage ledger remains the historical a2942181 snapshot; Sankey supplement is additive. Historical 264 missing originals were recovered in 73e0d768.
- Combined tests, release/browser verification, consolidated PR report, and push of subsequent commits remain pending. Preserve golden failures and failed captures.

## Numbered continuation bug ledger

These IDs cover the resumed parent work; earlier detailed defects remain in their route proof reports.

| ID | Symptom | Root cause | Fix | Test and verified layer | Status |
|---|---|---|---|---|---|
| R001 | Signup reveal inaccessible independently | Outer merged input semantics | ea2024e3 / e81e9cc2 | Input accessibility tests and native signup workflows | Behavior verified |
| R002 | Terms checkbox unnamed | Label outside checkbox semantics | 25b395e7 | Semantics activation and native workflow | Behavior verified |
| R003 | Long checkbox label overflows | Unconstrained row label | ac90d0bc | Text-scale-2 layout regression | Widget verified |
| R004 | Reserved input error changes height | Missing source gap/line accounting | 8b9034e5 | Exact 22px reservation and unchanged input golden | Widget verified |
| R005 | Signup source typography/spacing/footer differ | Invented field wrappers and plain footer text | af4522f8 / 250a649c | Actual Geist gallery tests; final light workflow | Final visual/motion proof open |
| R006 | Signup messages vanish or duplicate during retarget | Missing retained presence and platform-shortened fade | 1dca20f4 | Seven presence tests incl platform reduced motion | Browser motion proof open |
| R007 | Sankey archive not self-contained | Git ignored 43 sealed logs | 678812d36 | Parent verifier: 2,186 files, 16 recordings | Archive verified |
| R008 | Intermittent Lucide tofu | Unknown; successful same-JS font response exists | No speculative font change | Historical deficient frames preserved; request tracing enabled | Transient watched |

## Historical initial next actions

Finish final signup combinations and inspected native recordings, independently export Sankey proof, integrate existing owner results, run combined gates, push authorized branch updates, and continue unassigned coverage obligations. Do not treat archive integrity or passing behavior tests as pixel or motion certification.

## Integration continuation

- Pushed `2fb8348fc` to PR26. Subsequent candle/volume, bump, and agent repairs/archives are integrated through `a2b87643e` and awaiting the next push.
- Their parent archive checks pass (candle/volume 9,077 frames; bump 2,754 frames; agents 14,628 PNGs / 68 videos). Clean-export checks remain pending for these three new archives.
- Combined chart behavior excluding golden-named cases: 58 pass. The first run's volume rest-state failure was a real 57px overflow, not merely a golden mismatch; this correction supersedes the initial progress interpretation.
- R009: default volume composition overflowed a 640x420 viewport because its plot retained full height beside a taller summary. Parent fix gives the plot a loose bounded flex allocation while retaining its 320px natural height. Dedicated geometry regression was red before, green after; affected batch 29 pass. No golden regenerated.
- R010: bump rapid native Tab-burst focus loss remains open in worker proof. Source pressed metadata and shared typography/Tooltip differences also remain open.
- Signup final source/candidate light normal and both reduced combinations pass. Candidate and source normal native recordings visibly reach Account created; reduced recordings require final frame inspection. Captures remain tied to c66a8825, not later unrelated chart commits.
- Existing composition/funnel and component-example workers remain active. Candle/volume, bump and agent workers have completed; their remaining obligations stay open here.

## Latest integration gates

- `f9a35c2fa` pushed. Signup proof independently exported and verified (1,151 sealed entries, 8 observed sequences, 993 original frames / 4 videos).
- At that implementation, full root run: 2,394 pass / 59 fail. 54 are preserved golden differences; five older chart checks refer to changed source composition. Parent compatibility updates preserve rank spring tracking, hover-only versus pinned ownership, range identity/tooltip values, and shuffle permutations using current public semantics/content. Updated 18-test batch passes. Exact endpoint text baseline alignment is still a visual gate, not asserted by the spring tracking test.
- Component example chain integrated as parent commits through `b43d67cb4`; focused 64-test root batch passes. Archive verification is running. Example gallery and fresh combined gates remain pending.
- Parent agent behavior batch: 227 pass. Candle/volume, bump, agents and signup archives all pass tracked-only independent exports. Disposable exports removed only after success; committed originals remain.
- Read-only Bump focus diagnosis delegated under task suffix `v3-bump-native-race-diagnosis-20261023`, isolated checkout, owned port 18122. No other worker owns Bump now. Composition/funnel remains active.

## Integrated continuation at 410893339

- Pushed through `410893339` to origin/akshay/v3-ship for PR26. No merge.
- Sankey independent defects fixed in `383931bbb`; compact traversal fixed in `e61ff63be`. Fresh native lifecycle proof `d07eca954` passes all 12 source/candidate scenarios across motion preferences. Independent tracked-file export verifies 148 files. R3 pointer interception remains a separate open Tooltip concern; R4 uses actual Tab to leave the chart and does not waive it.
- NumberTicker measured geometry repair `f23e8af49` and source file icon `072647a92` integrated. Matching geometry test lookup corrected in `410893339` without changing assertions. Composition percentage width now grows beyond its source 48px minimum when measured text needs it (`8eed11643`).
- Composition/funnel chain integrated through `bb41eecc7`, evidence `70660748b`. Independent tracked-file export passes 13,719 files / 669,376,638 bytes, 102 recordings / 11,118 original frames. All source and superseded evidence retained.
- Latest combined chart+ticker behavior: 283 pass with goldens disabled. Full root at 410893339: 2,449 pass / 56 preserved golden failures, no non-golden failures. Gallery: 56 pass. Production/test scoped analysis passes; whole-tree analysis has four informational lints in archived evidence fixtures, retained unchanged. Release succeeds.
- Latest gallery JS `6dde1f24097e8562b2ddf8bf093b0d2b8b640feac3e531aa6f9f3e3963a709bc`. Fresh composition hover screenshots show readable measured values and percentages; actual served hash and motion probes retained under integration-round5. This is not pixel parity.
- R011: Sankey cursor revival, pre-entry keyboard exclusion, horizontal offscreen focus: repaired and widget/native verified.
- R012: Sankey compact hit-target overlap skips chart in reading-order traversal: repaired with chart traversal group; red/green widget and native checks retained.
- R013: Native Tooltip mouse-click and second-tap dismissal fail in funnel under both motion preferences. Read-only diagnosis active: `node:delegated-task:command%3Amcp%3A88ccf142-fc2c-4907-a265-6141941bf107%3Adelegate-task%3Av3-tooltip-native-dismiss-diagnosis-20261023`; owns only /tmp and port18125. No production edits delegated.
- Bump focus race remains open. Rejected sort-key experiment was reverted and archived as d6a2e5c27. Do not reapply or report as fixed.
- Existing composition/funnel worker is completed. Remaining table, typography, coverage, pixel and fast-motion obligations remain open. No parity certification.

## Tooltip native repair at f59e909b2

- R013 repaired: nonmodal overlay wrapper no longer acquires focus or exposes a full-viewport focus target. Scoped semantic tap observation preserves the child callback and handles semantic-only activation. Mouse dismisses/cancels pending hover; touch toggles; keyboard focus-in remains intact. c89fcbcd7 adds nonmodal descendant focus/Enter/Escape verification.
- Final served gallery JS `0ecc85d34b1f1665818065ea54bd6d8d580a725f73bde77299d9c5de41de6f9e`. Four native dismissal contexts pass, including repeated touch, repeated mouse click, Tab and Escape. Sankey's original pointer variant now passes all 12 source/candidate contexts. Exact hashes and effective motion probes are in tooltip-native-dismissal.
- Root f59e909b2: 2,454 pass / 56 golden failures. No non-golden failures. Gallery 56 pass; lib/test analysis clean; release passes. Focused Tooltip/overlay/charts 317 pass with goldens disabled; additional overlay descendant suite eight pass. Golden baselines unchanged.
- Bump retest: burst1 and reduced1 pass 16 states; burst2 and burst3 again lose native focus at legend-tab. The dismissal repair does not fix the engine ancestor-reordering race. Original failures retained.
- Read-only design active: `node:delegated-task:command%3Amcp%3A88ccf142-fc2c-4907-a265-6141941bf107%3Adelegate-task%3Av3-bump-semantics-boundary-repair-design-20261023`. Owns /tmp and optional18129; parent retains18127 fixture server for it.
- Independent read-only review active: `node:delegated-task:command%3Amcp%3A88ccf142-fc2c-4907-a265-6141941bf107%3Adelegate-task%3Av3-tooltip-semantic-independent-review-20261023`. No repo writes delegated.
- No parity or timing certification. Remaining coverage/table/font/pixel obligations unchanged.

## Independent Tooltip review follow-up

- Reviewer found R014: mouse modality survived exit/removal and suppressed a later accessibility semantic tap. Fixed in 2b1a8ae52 by clearing pointer kind on trigger exit. Original five reviewer tests pass unchanged; portable repository assertions also unchanged. Focused Tooltip/overlay/chart batch 323 pass, scoped analysis clean, release succeeds.
- Fresh mouse/touch native contexts pass both motion preferences including repeated activation, Tab and Escape. Proof: tooltip-accessibility-followup. Real screen-reader transition remains unverified; semantic-action widget evidence is explicitly distinct.
- Latest full-root count remains the f59e909b2 run, not a rerun after this one-line repair. Bump repair-design task remains active; no remaining defect waived.

## R015 Bump semantics ancestor focus repair

- Implemented a conditional internal web adapter that rotates owned tooltip siblings while keeping the focused semantics ancestor stationary. Native insertBefore/append order and return/error contracts retained; no focus restoration, SDK patch or chart timing change.
- Independent review round one found wrapper ownership and zero-browser test acceptance gaps; both fixed. Round two found no demonstrated new bug, confirmed shadow-root fix and 11 additional checks.
- Seven r5 Flutter browser runs pass 127 states. Two current-SDK and one Flutter3.44.3 reorder events actually exercise the repair, preserving focus and exact order. Full root: 2,460 pass / 56 preserved golden failures; 323 focused behavior tests pass; analysis clean; both release builds pass.
- Evidence under bump-semantics-guard. Original failures and failed test/copy attempts retained. WebKit additionally passes 240 contract cases and 21 real Flutter states. Firefox launch is unavailable after macOS sandbox extension errors/timeouts; actual screen-reader checks remain open. Private Flutter DOM integration remains version-sensitive. Other parity obligations are not waived.

- Next read-only diagnosis running: `v3-table-outcomes-followup-20261023-r1`, Table resize and Editable deletion/recovery. No shared production edits delegated.

## Table outcome diagnosis and supplemental recovery

- Resize proof corrected: source handle moves24px on pointer-down as checkbox width changes24to48, then49.546875px during50px drag. Name ends162px after rounded-width freeze. Historical total-handle50px assertion is invalid; original sealed evidence unchanged. Source intrinsic widths versus Flutter flex remains unresolved, with read-only design task `v3-table-intrinsic-layout-design-20261023-r1` active.
- 5749bdc20 adds separately labeled editable-recovery composition with240px floor/header allowance. Original editable/default heights unchanged. Native source supplemental240px composition and candidate recovery pass24 observed states across both motion prefs, including last-row deletion and empty restoration. Actual hit-tests and focused candidate field values checked. No original-preview or pixel parity claim.
- Six gallery tests, scoped analysis and release pass. table-followup archives original diagnosis, rejected locators, successful observations and served hashes. No shared Table/golden changes.

## Intrinsic Table sizing implementation phase

- Design task completed. Chosen boundary is an opt-in intrinsic sizing mode; existing flex consumers keep their behavior. Declared preferences, measured geometry and resize overrides must remain distinct. A shared layout result must drive selection, header, body, skeleton and reorder geometry.
- Source switches to maximum-content width only when every current data column has an override. Its table-level floor is separate from rendered per-column minima. The Name override rounds to 112 at freeze but still renders 112.453125 until dragged. No captured offsets become production constants.
- Active isolated prototype task: `v3-table-intrinsic-resolver-prototype-20261023-r1`. Owns only new test/motion/table_intrinsic_layout_prototype_test.dart and test/fixtures/table_intrinsic_layout/. It will derive the absolute/auto allocation subset against deterministic and native browser oracle cases before parent production integration. No existing production or sealed evidence edits delegated.

## Intrinsic resolver prototype verified

- Isolated test-only allocator matches 22 native Chrome155.0.8059.86 fixtures exactly. Parent added independently cloned real source content measurements preserving font inheritance; rest, freeze and +50drag all match exactly. All30 prototype tests pass and targeted analysis is clean. Production flex behavior remains unchanged.
- Retained the incorrect first clone measurement without inherited typography, corrected observations, actual served-source hash and all old measurements. Default MRR-sorted preview differs from earlier Name-sorted observations because mounted Email content is wider; neither record replaces the other.
- Active measurement prototype: `v3-table-intrinsic-measurement-prototype-20261023-r1`, restricted to test/fixtures/table_intrinsic_measurement/ and test/motion/table_intrinsic_measurement_test.dart. It must measure content synchronously before child layout, preserve inherited styles, avoid duplicate focus/semantics and reject unsupported widgets. Production opt-in API/integration is pending this boundary.

## Intrinsic Table integration in progress

- Measurement review completed with three demonstrated defects: hidden selection leakage, malformed flex acceptance, and finite overflow during quantization. Six production regression cases failed before repair and pass after. Original test-only prototype retained unchanged with its limits documented.
- Opt-in production integration is now present but uncommitted. Default flex stays unchanged. One resolved layout drives selection/header/body/skeleton/reorder widths; bounded sorted viewport/overscan samples feed the same-frame allocator. Current focused gate: 82 tests pass with preserved goldens disabled.
- Independent read-only production review active: `v3-table-intrinsic-production-review-20261023-r1`. No repository writes delegated. Reviewer owns only /tmp repros.
- Gallery opt-in, integrated native geometry, full-suite run and push of this unit remain pending. No source-parity acceptance is inferred from resolver/measurement/widget gates.
- Round-one production review found nested flex constraints, fractional declared-width conversion and row-height sample invalidation bugs. All three repros were red, then green after correction. Raw outputs retained in table-intrinsic-integration.
- Actual asynchronous FontLoader test exposed RenderParagraph's separate stale intrinsic cache: loaded font measured72px in a fresh painter while existing probe retained120px. System-font changes now recreate only keyed passive probes; actual font-load regression passes. No live content subtree reset is intended.
- Second read-only review active: `v3-table-intrinsic-production-review-20261023-r2`, including font-load/editor preservation. Full root suite retains exactly the same56 failure identities as prior guard baseline; baseline-comparison.json records hashes and identity comparison. Scoped analysis clean. Push and gallery/native follow-up remain pending review completion.
- Round-two review confirms actual font load preserves live editor state/focus/draft and cleans up listeners. Its additional stale cached-row-index finding reproduced red; synchronizing the cache during layout fixes the rowHeight-change then jump-back sequence. Final focused88/88 and analysis clean. Full root2512pass/56baseline failures predates only this final cache correction; do not call it exact-final-head full-suite proof.

## Current continuation after intrinsic integration push

- Pushed production654f5a218 and evidencec130fe979 to origin/akshay/v3-ship for PR26. No merge. Default gallery still uses flex.
- Active final read-only review: `v3-table-intrinsic-production-review-20261023-r3`, checking the final scroll-cache correction against the full prior findings. Shared production files remain stable.
- Active gallery worker: `v3-table-intrinsic-gallery-integration-20261023-r1`, owns only example/lib/demos/table_demo.dart and new example/test/table_intrinsic_demo_test.dart. No commits, library edits, builds or browser servers delegated. It will use honest passive candidate samples for the data example and preserve editable/recovery behavior. Known checkbox20px versus source24px remains explicit; no fabricated sample widths.
- Parent next: consume reviews, finish gallery integration, release-build and record native source/candidate rest/freeze/drag geometry, then update PR report and push. No pixel or motion certification yet.
- Final scoped review r3 completed with no findings at654f5a218. Independent10/10 checks and the original two-test reproduction pass; offset1200 now samples40..66 after the row-height change. No full-suite or browser claim added. Gallery worker remains active; do not modify its owned files before handoff.

## Intrinsic DATA native geometry verified

- Gallery worker completed and integrated.4e4065cd0 opts DATA into passive intrinsic samples and corrects Table-owned header wrappers:24px checkbox label around20px control,24px grip around14px icon. Existing flex remains default. Source inspection rejected an initial sort-icon-size diagnosis; both icons are14px. Actual-Geist column tests match all five source widths within0.05px.
-3e1c3f4bb fixes source sampling using full rounded viewport height plus fractional offset, invalidating either endpoint. Two red source-range/wider-cell tests turned green; sort/short/empty coverage added. Independent research confirmed TanStack3.17.7 formulas. Runtime rowHeight updates intentionally remeasure while source retains stale estimates; this limit is documented.
- Exact code-head full root2517pass/56identical baseline golden failures, gallery62/62, focused Table73/73 with goldens disabled, scoped analysis and release pass. Final fixture JS c5b13dd0985cf017542a352778d5cce72c2472ca6daede83fcaecaa342dff62a. Actual Chrome finalr4 passes30 exact horizontal comparisons across rest/freeze/50px trusted drag and both motion preferences.
- table-intrinsic-browser preserves r1 incomplete DOM extraction, r2 pre-wrapper captures, r3 wrapper repair and r4 sampling repair; all original screenshots and16WebMs retained. Verifier checks hashes/decoded frames/trusted inputs/served hashes/effective preferences. No pixel/native60 certification.
- Active next diagnosis: `v3-table-vertical-geometry-diagnosis-20261023-r1`, read-only source/candidate vertical row/baseline correspondence. Owns /tmp and browser page only. Parent server18137 retained for this task; source18134 is unchanged. Earlier parent-owned18135/18136 remain frozen, no unrelated servers stopped.
