# v3 components review

## Scope and verification status

Review of the uncommitted diff against HEAD on `akshay/v3-components`, in `/Users/codenameakshay/.t3/worktrees/beui/akshay-v3-components`. The parent verified the results below centrally. This documentation worker did not run Flutter or change source or tests.

- GREEN: 20 affected test files, exit 0, `+212: All tests passed!`, `/tmp/beui-v3-review-final-tests.log`.
- GREEN: analysis of 48 touched Dart files, exit 0, `No issues found!`, `/tmp/beui-v3-review-final-analyze.log`.
- RED: current regression tests against the exact initial dirty versions of eleven repaired source/demo files, captured before review, produced 76 passes and 33 failures, `/tmp/beui-v3-review-red.log`. This baseline was not HEAD. All replaced files were restored exactly; no baseline-run mutations remain. The 33 failures are test failures, not a bug count, and include the old close-hover test failing because Alert was invisible.
- Supplemental Tooltip RED: strengthened final tests against the initial Tooltip source produced 12 passes and seven failures, `/tmp/beui-v3-tooltip-red.log`. All seven lifecycle/collision failures listed below were real.
- Supplemental Alert exit RED: the repeat-controlled-close regression against a broken intermediate repair produced zero passes and one failure, `/tmp/beui-v3-alert-exit-red.log`. The final independent delta audit found this issue only; it is now fixed and included in the final passing run.

These are local behavioral and touched-file analysis results, not full-suite, hosted-CI, release, or visual certification. No app or simulator was launched. No fresh visual goldens or device proof were produced; `BEUI_SKIP_GOLDENS=1` excluded goldens. Existing screenshots and [scores](SCORES.md) predate the repairs. No push, merge, or hosted checks ran.

## Standards and spec

[CLAUDE.md](../../../CLAUDE.md) requires the motion facade, shared overlay, theme tokens, controlled-state ownership, and accessible control names. [PORTING_SPEC.md](../../PORTING_SPEC.md), sections 1, 5, 6, 8, and 9, requires discrete reduced-motion geometry to reach its target, decorative movement to stop while opacity/color may continue, and keyboard/semantics state to match live controls.

[Named parity gaps](../../V3_COMPONENTS_GAP.md#remaining-gaps-named-not-blocking-this-pr) remain unchanged. Tooltip Provider, `followCursor`, and collision handling exist; Trigger/Content remain identity wrappers. No product decision is required.

## Fixed findings and regression coverage

All test names below refer to final source and are included in the 212-test GREEN run. The full initial-dirty RED run covers review repairs; supplemental RED runs distinguish strengthened Tooltip coverage and the repair-induced Alert exit regression.

### Alert visibility, initial state, icon movement, and exit

`NoMotion` kept the height builder at zero, hiding an open alert. An initially closed alert could flash its body, and variant icons still translated/scaled under reduced motion. [Alert](../../../lib/src/motion/alert.dart) now renders target height directly for `NoMotion`, starts closed opacity/geometry at zero, and omits reduced-motion icon transforms while keeping the fade.

An intermediate repair keyed the surface by open state, remounting motion builders and removing the body on the first close pump. Preserving builder identity restores collapse/fade on repeated controlled closes. This regression failed against that intermediate snapshot, not the initial-dirty baseline.

[Tests](../../../test/motion/alert_test.dart): `initially closed alert has no visible body before opening`; `reduced motion snaps height on initial open and reopen`; `reduced motion variant icon fades without a transform`; `controlled close fades and collapses before unmounting on repeat`. These cover initial closed/open, close, reopen, and repeated controlled exit. `open surface uses motor motion without AnimatedSwitcher` guards the engine choice. Remaining gap: no fresh visual proof; the existing variant-icon parity gap remains documented.

### Color Picker geometry and panel bounds

The area thumb froze under `NoMotion`. An expanding `Align` made the floating panel's painted `Material` fill the overlay, and its reduced-motion entrance retained translation/scale. [Color Picker](../../../lib/src/motion/color_picker.dart) bypasses geometry builders at their targets and shrinkwraps the panel while retaining opacity.

[Tests](../../../test/motion/color_picker_test.dart): `reduced motion snaps the controlled area thumb to its color`; `floating Material fits the picker body and dismisses outside`; `empty floating content still shrinkwraps its Material`; `reduced motion panel keeps final geometry while fading`. These cover controlled geometry, outside dismissal, empty content, and intermediate fade geometry. Remaining gap: no fresh visual proof or trigger-to-area morph, as already documented.

### Color Picker stale gesture release

Area, Hue, and Alpha release callbacks read the inherited color captured before the latest gesture update. Controlled rejection or an uncontrolled release could therefore commit stale color. The picker now retains the requested gesture color locally and commits it on release without taking controlled ownership.

[Tests](../../../test/motion/color_picker_test.dart): `uncontrolled area tap retains and commits the requested color`; `stale controlled area commits requested color on retry`; `uncontrolled hue release retains requested color`; `uncontrolled alpha release retains requested color`; `stale controlled hue commits requested color on retry`; `stale controlled alpha commits requested color on retry`. These assert final commits, repeated requests, and unchanged controlled geometry when the owner rejects a change. No additional behavioral gap identified in these reviewed cases.

### Arc Picker bracket

The bracket width froze at its previous label width under reduced motion. [Arc Picker](../../../lib/src/motion/arc_picker.dart) now renders target geometry directly for `NoMotion`.

[Tests](../../../test/motion/arc_picker_test.dart): `reduced motion snaps bracket geometry for controlled labels`; `empty options render the empty state under reduced motion`; `controlled selection reports without taking ownership`. Remaining gap: the existing simplified bracket morph; no fresh visual proof.

### File Tree chevron

The folder chevron received `NoMotion` and stayed at its old angle after expansion. [File Tree](../../../lib/src/motion/file_tree.dart) now renders target rotation directly in that branch.

[Tests](../../../test/motion/file_tree_test.dart): `reduced motion snaps the folder chevron to expanded`; `controlled selection and expansion report changes only`. These check geometry and owner authority. Remaining gap: no fresh visual proof.

### Timeline and Image Viewer hover movement

Hover transforms lifted cards and thumbnails under reduced motion. [Timeline](../../../lib/src/motion/timeline.dart) and [Image Viewer](../../../lib/src/motion/image_viewer.dart) gate movement separately from retained hover highlight/brightness.

[Timeline test](../../../test/motion/timeline_test.dart): `reduced motion keeps hover highlight without card movement`. [Image Viewer test](../../../test/motion/image_viewer_test.dart): `reduced motion thumbnail hover keeps brightness without movement`. These assert geometry and retained non-movement feedback. Remaining gap: no fresh visual proof; Timeline's placeholder imagery remains documented.

### Tooltip lifecycle and collision cache

Cancelled pending shows incorrectly warmed the provider. Disabling did not reliably close/cancel work, including when re-enabled before the old deadline. Turning collision handling off retained a cached flip/shift. [Tooltip](../../../lib/src/motion/tooltip.dart) distinguishes cancellation from a completed show, releases disabled ownership without warming, cancels delayed work, and clears stale collision geometry.

[Tests](../../../test/motion/tooltip_test.dart), the seven supplemental RED failures:

- `disabling an open tooltip closes it and permits reentry`
- `disabling a pending tooltip cancels its timer`
- `disabling collision handling clears a prior flip and shift`
- `aborted hover does not warm a sibling tooltip`
- `aborted hover retries the same trigger with a cold delay`
- `a pending hover does not warm a focused sibling`
- `same pending trigger focus retries with a cold delay`

The original four cold-delay tests misleadingly passed the initial source because `BeuiOverlay` mounts content post-frame. Final tests flush pointer/focus lifecycle and deferred mounts, assert absence at 700 and 799ms, and presence at exactly 800ms. `provider skips delay when moving to a sibling tooltip` guards valid warm handoff. Remaining gap: Trigger/Content remain identity wrappers; no fresh visual proof.

### Color Selector null, live registrations, and stale ring color

Null selection could reach a non-null assertion while an old ring target survived. Removed/reordered children and changed item values left stale registrations, keyboard order, or ring aliases. Selected color changes without geometry changes left stale ring color. [Color Selector](../../../lib/src/motion/color_selector.dart) guards null measurement, removes dead registrations, follows live child order/value identity, and compares selected color when notifying dependents.

[Tests](../../../test/motion/color_selector_test.dart): `controlled selection can transition to null`; `controlled selection can clear while children become empty`; `empty choices can repopulate and select again`; `controlled rejection keeps checked state and permits retry`; `removing the selected child removes its ring`; `keyboard navigation uses only live children in child order`; `reordering retained const children updates keyboard order`; `changing a selected item value drops its stale ring`; `changing selected swatch color updates ring without moving it`. Remaining gap: the existing spring path differs from the source arc path; no fresh visual proof.

### Card gallery accessible control names

Adjacent text did not name custom checkboxes/switches. The [Card demo](../../../example/lib/demos/card_demo.dart) adds labels with `MergeSemantics` and `Semantics`.

[Demo tests](../../../test/motion/v3_components_demo_test.dart): `card demo labels and activates Signed contract`; `card demo labels and activates Invoice`; `card demo labels and activates Mentions and replies`; `card demo labels and activates Weekly digest`. Each checks name, state, semantics tap, and two toggles. Remaining gap: no device screen-reader session.

### Number gallery narrow layout

The card-number glyph row overflowed by 19px at 280px. The first layout rewrite did not fix it and was removed. The [Number demo](../../../example/lib/demos/number_demo.dart) now uses `FittedBox` with `BoxFit.scaleDown` around the digits, preserving the original outer layout, centered maximum-320px band, and compact literal `Animate` button below it.

[Demo tests](../../../test/motion/v3_components_demo_test.dart): `number demo fits its band and keeps Animate compact at 280.0px`; `number demo fits its band and keeps Animate compact at 800.0px`. They check overflow, centered band bounds, button size/placement, and reveal/mask retry. Remaining gap: no fresh visual proof.

### Image Viewer custom-child caller and controlled morph source

The [Image Viewer demo](../../../example/lib/demos/image_viewer_demo.dart) supplied custom children but omitted `BeuiImageViewerContent`, so thumbnail selection did not open a viewer. It now includes that content. [Caller test](../../../test/motion/image_viewer_demo_test.dart): `photo demo opens, navigates, closes, and reopens the viewer` exercises the real caller.

A rejected controlled thumbnail request could overwrite the source rectangle used by a later accepted selection. [Image Viewer](../../../lib/src/motion/image_viewer.dart) separates pending request geometry from accepted geometry, adopts it only for a matching owner selection, discards mismatches, and preserves the accepted source through close.

[Tests](../../../test/motion/image_viewer_test.dart): `rejected controlled request cannot supply a later morph source`; `accepted controlled thumbnail source survives the close morph`; `controlled null stays closed until its owner changes value`; `empty gallery can receive images and retry opening`. Remaining gap: no fresh visual proof; the existing cross-route shared-layout parity gap remains documented.

## Exact risk checks and test repairs

Final passing tests check the Color Selector's 44px swatch, 52px ring, `Positioned` geometry, and swatch-colored ring at alpha `0.65`; Adaptive Stepper's transparent outlined rest actions with foreground alpha `0.18`, muted hover, and transparent hidden state; and Number's centered 320px band with compact `Animate`. Tooltip Provider, `followCursor`, and collision support exist. Alert uses motor without `AnimatedSwitcher`; demo width caps retain `Center`/`Align`.

The parent verified analysis options, dependencies, versions, and `example/lib/explorer/shell.dart` unchanged against HEAD. Numeric epsilon, motor settling, 8-bit color quantization, a valid PNG fixture, and semantics disposal in `finally` corrected test assumptions/resources; they are not independent product findings.

## Central commands

The parent ran these serially. Their exact file lists define the local verification scope.

```sh
BEUI_SKIP_GOLDENS=1 fvm flutter test --no-pub \
  test/motion/adaptive_stepper_test.dart test/motion/alert_test.dart \
  test/motion/arc_picker_test.dart test/motion/breadcrumb_test.dart \
  test/motion/card_test.dart test/motion/collapsible_test.dart \
  test/motion/color_picker_test.dart test/motion/color_selector_test.dart \
  test/motion/combobox_test.dart test/motion/date_range_picker_test.dart \
  test/motion/expandable_control_test.dart test/motion/file_tree_test.dart \
  test/motion/image_viewer_test.dart test/motion/multi_select_test.dart \
  test/motion/sortable_list_test.dart test/motion/tabs_test.dart \
  test/motion/timeline_test.dart test/motion/tooltip_test.dart \
  test/motion/v3_components_demo_test.dart test/motion/image_viewer_demo_test.dart \
  --reporter expanded

BEUI_SKIP_GOLDENS=1 fvm flutter analyze --no-pub \
  example/lib/demos/breadcrumb_demo.dart example/lib/demos/card_demo.dart \
  example/lib/demos/combobox_demo.dart example/lib/demos/file_tree_demo.dart \
  example/lib/demos/image_viewer_demo.dart example/lib/demos/number_demo.dart \
  example/lib/demos/tabs_demo.dart example/lib/demos/timeline_demo.dart \
  example/lib/demos/tooltip_demo.dart lib/beui.dart \
  lib/src/motion/adaptive_stepper.dart lib/src/motion/alert.dart \
  lib/src/motion/arc_picker.dart lib/src/motion/breadcrumb.dart \
  lib/src/motion/card.dart lib/src/motion/collapsible.dart \
  lib/src/motion/color_picker.dart lib/src/motion/color_selector.dart \
  lib/src/motion/combobox.dart lib/src/motion/date_range_picker.dart \
  lib/src/motion/expandable_control.dart lib/src/motion/file_tree.dart \
  lib/src/motion/image_viewer.dart lib/src/motion/multi_select.dart \
  lib/src/motion/sortable_list.dart lib/src/motion/tabs.dart \
  lib/src/motion/timeline.dart lib/src/motion/tooltip.dart \
  test/motion/adaptive_stepper_test.dart test/motion/alert_test.dart \
  test/motion/arc_picker_test.dart test/motion/breadcrumb_test.dart \
  test/motion/card_test.dart test/motion/collapsible_test.dart \
  test/motion/color_picker_test.dart test/motion/color_selector_test.dart \
  test/motion/combobox_test.dart test/motion/date_range_picker_test.dart \
  test/motion/expandable_control_test.dart test/motion/file_tree_test.dart \
  test/motion/image_viewer_test.dart test/motion/multi_select_test.dart \
  test/motion/sortable_list_test.dart test/motion/tabs_test.dart \
  test/motion/timeline_test.dart test/motion/tooltip_test.dart \
  test/motion/v3_components_demo_test.dart test/motion/image_viewer_demo_test.dart
```

## Changed-file manifest

Complete `git status --short --untracked-files=all` snapshot, excluding `.impeccable/`. This includes pre-existing work and proof assets, not only review repairs. `M` means tracked modification; `??` means untracked.

```text
 M CHANGELOG.md
 M README.md
 M docs/V3_COMPONENTS_GAP.md
 M docs/proof/v3-components/cand-card.png
 M example/lib/demos/breadcrumb_demo.dart
 M example/lib/demos/card_demo.dart
 M example/lib/demos/combobox_demo.dart
 M example/lib/demos/file_tree_demo.dart
 M example/lib/demos/image_viewer_demo.dart
 M example/lib/demos/number_demo.dart
 M example/lib/demos/tabs_demo.dart
 M example/lib/demos/timeline_demo.dart
 M example/lib/demos/tooltip_demo.dart
 M lib/beui.dart
 M lib/src/motion/adaptive_stepper.dart
 M lib/src/motion/alert.dart
 M lib/src/motion/arc_picker.dart
 M lib/src/motion/breadcrumb.dart
 M lib/src/motion/card.dart
 M lib/src/motion/collapsible.dart
 M lib/src/motion/color_picker.dart
 M lib/src/motion/color_selector.dart
 M lib/src/motion/combobox.dart
 M lib/src/motion/date_range_picker.dart
 M lib/src/motion/expandable_control.dart
 M lib/src/motion/file_tree.dart
 M lib/src/motion/image_viewer.dart
 M lib/src/motion/multi_select.dart
 M lib/src/motion/sortable_list.dart
 M lib/src/motion/tabs.dart
 M lib/src/motion/timeline.dart
 M lib/src/motion/tooltip.dart
 M test/motion/adaptive_stepper_test.dart
 M test/motion/alert_test.dart
 M test/motion/arc_picker_test.dart
 M test/motion/breadcrumb_test.dart
 M test/motion/card_test.dart
 M test/motion/collapsible_test.dart
 M test/motion/color_picker_test.dart
 M test/motion/color_selector_test.dart
 M test/motion/combobox_test.dart
 M test/motion/date_range_picker_test.dart
 M test/motion/expandable_control_test.dart
 M test/motion/file_tree_test.dart
 M test/motion/image_viewer_test.dart
 M test/motion/multi_select_test.dart
 M test/motion/sortable_list_test.dart
 M test/motion/tabs_test.dart
 M test/motion/timeline_test.dart
 M test/motion/tooltip_test.dart
?? docs/proof/v3-components/REVIEW.md
?? docs/proof/v3-components/SCORES.md
?? docs/proof/v3-components/cand-adaptive-stepper.png
?? docs/proof/v3-components/cand-breadcrumb.png
?? docs/proof/v3-components/cand-color-selector.png
?? docs/proof/v3-components/cand-file-tree-hover.png
?? docs/proof/v3-components/cand-file-tree.png
?? docs/proof/v3-components/cand-number.png
?? docs/proof/v3-components/ref-adaptive-stepper.png
?? docs/proof/v3-components/ref-color-selector.png
?? test/motion/image_viewer_demo_test.dart
?? test/motion/v3_components_demo_test.dart
```
