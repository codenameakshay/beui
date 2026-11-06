# Select and sidebar focused verification

The latest combined Flutter 3.44.4 run passes 91 tests and fails one unchanged
rest-state golden. This is behavioral evidence, not visual or motion parity.
No browser, native build, or device action ran during this verification.

## Commands and results

```sh
/Users/codenameakshay/fvm/versions/3.44.4/bin/flutter test --no-pub --concurrency=1 test/motion/animated_sidebar_provider_test.dart test/motion/animated_sidebar_test.dart test/motion/select_test.dart test/motion/select_source_parity_test.dart --reporter expanded
```

The log is retained in the durable task artifact directory at
`components/select-sidebar-root-findings-combined-20261105.log`.
The previous 84-pass receipt remains unchanged at
`components/focused-select-sidebar-placement-20261105.log`.
No tests or goldens were skipped. No goldens were regenerated.

Both root and example package configurations resolve Flutter and flutter_test
to `/Users/codenameakshay/fvm/versions/3.44.4`, with Dart generator 3.12.2.
An earlier worker attempt compiled against stale stable-SDK package paths and
failed before executing tests. Running the absolute CI SDK's `flutter pub get`
restored both package configurations without a tracked dependency-file change.
The cause of the prior configuration drift is unknown.

## Repairs independently verified

Select rows share the same source-derived reveal progress. Tests compare
same-frame row translation and opacity at literal 120ms entrance and 80ms exit
checkpoints. The long-list assertion now reads the first offset after proving
that every row offset is equal.

Tab and Shift+Tab close Select, restore the trigger as the traversal origin,
and focus the adjacent external field. Closing rows leave traversal immediately.
Reopening waits for the portal's focus gate to update before requesting the
active row. Tests cover ArrowUp after real Tab focus, endpoint selection,
typeahead expiry, active-value identity, rich labels, controlled ownership,
reduced-motion geometry, and disposal.

Root found that initially open panels never computed placement. Two regression
tests reproduced the failure for `defaultOpen: true` and controlled `open: true`.
At a trigger bottom of 584px, the panel bottom was 698px instead of 538px.
The default Select now recomputes placement after valid trigger and panel
measurement. Both ownership modes place the panel 8px above the trigger and
preserve the external field's primary focus. The failing run is retained as
`components/select-initial-placement-red.log`. Morph remains unchanged.

Reduced-motion panel opacity uses a 120ms overlay clock instead of a fade
embedded in a longer 200ms envelope. The test starts the deferred overlay clock
before advancing elapsed time, then checks intermediate entrance and exit
opacity while rows remain static.

Sidebar tests cover retained uncontrolled defaults after controlled handoff,
provider authority, nearest shortcut ownership, editable descendants, viewport
crossings, legacy constructors, and exit focus restoration. A real keyboard
test traverses the header action, Close button, and footer action. Tab wraps
forward and Shift+Tab wraps backward. Escape returns focus to the trigger and
the next Tab reaches the external action.

## Unchanged golden failure

`goldens/beui_select.png` differs by four pixels on this host. Its candidate
`beui_select_testImage.png` has SHA-256
`71d83a29c5c6bf0f84d1adce89af28486f56d27b696372dbfd30ddc2e43421df`.
That is byte-identical to root's unchanged-widget baseline capture, documented
in `coordination/golden-diagnosis/REPORT.md`. Root classifies this case as an
unresolved environment/toolchain mismatch. The lower-level cause is unknown.

## Remaining verification

Root and example `flutter analyze --no-pub` pass on the pinned SDK. Logs are
retained as `components/analyze-root-20261105.log` and
`components/analyze-example-20261105.log`.

The fresh Luna comment review proposed three comment-only removals. The parent
accepted all three. No public API documentation or pinned spring rationale was
removed. No comment was restored, no review rerun was required, and no
constraint encoding or architectural change was needed for these findings.

After-runtime visual and elapsed-time motion comparison is pending. The
sidebar's conflicting controlled-prop precedence still needs release-build
runtime proof. Native UI, calibrated performance, full-family tests, and
exact-head hosted checks remain pending.

The shared-unit baseline review is recorded in
[shared baseline evidence](SHARED_BASELINE_EVIDENCE.md). NumberTicker's narrow
formatting repair has a separate [focused receipt](NUMBER_TICKER_VERIFICATION.md).
Tooltip remains untouched. TextShimmer's child-only constructor is approved;
its worker diff awaits independent verification.

## Root whole-diff findings and direct corrections

The parent reproduced root's missing semantic activation findings through
rendered semantics nodes and `SemanticsOwner.performAction(tap)`. The default
trigger and enabled rows exposed no tap action. Both now supply explicit
semantic handlers while decorative child semantics remain excluded. Disabled
triggers and rows expose no tap action and ignore forced semantic activation.
Tests assert one literal selection value and one close callback.

The pinned source renders each SelectItem as a native button. Its listbox hook
excludes Space from typeahead. The local default row had no Space action.
The new test first failed with an empty selection list after genuine keydown
and keyup on the primary-focused Alpha option. A nullable pressed-option value
now tracks the Space press locally. Release selects only the same active,
focused option. Repeats do not commit early, the trigger's opening Space release
does not select, and an all-disabled panel remains open without selection.
No shared Actions framework or Morph keyboard path changed.

The source `select.tsx` removes its reveal clip at clamped progress one.
The default Flutter panel retained an exact-bounds clip and cut its shadow.
Only the outer reveal clip now becomes `Clip.none` at full reveal. The rounded
child clip, shadow constants, opening clip, and exit clip remain unchanged.
The raster regression enables real blur and samples 8px below the settled
panel. The unchanged local black-alpha-26 shadow with blur sigma 14.36 predicts
RGB about 239 over white at that position, with a two-level raster tolerance.
Restoring the old outer clip reproduces RGB 255, failing that same assertion.
The corrected panel passes. This is a widget-raster check, not browser parity.

Original red evidence is retained in
`components/select-root-review-red-20261105.log`. That run also reports a
secondary semantics-handle cleanup failure after the first failed assertion.
The tests now dispose handles in `finally`. The first corrected run passed the
activation checks but failed the debug-shadow restoration invariant. Restoration
also moved to `finally`; that log remains
`components/select-root-review-green-20261105.log`. The corrected source suite
passes 27 tests in `components/select-root-review-green-corrected-20261105.log`.
The independently isolated shadow red check is retained in
`components/select-shadow-blur-red-20261105.log`.

The final combined four-file run passes 91 tests and fails only the same
unskipped rest-state golden. Its candidate PNG still has SHA-256
`71d83a29c5c6bf0f84d1adce89af28486f56d27b696372dbfd30ddc2e43421df`.
No golden was regenerated. This parent receipt does not grant safecommit,
root acceptance, visual parity, or release readiness.

Root and example analysis pass again after these corrections. Logs are
`components/select-review-analyze-root-20261105.log` and
`components/select-review-analyze-example-20261105.log`. `git diff --check`
also passes. No build, capture, device UI, or calibrated performance run occurred.

## Code hashes for the focused receipt

The parent re-read the two initial-open placement regressions and the
default-Select-only measurement override after the run. The override computes
placement only after nonzero trigger and panel measurements. It requests no
focus and rebuilds only when the placement side changes. This is static review,
not a second test run or safecommit approval.

| File | SHA256 |
|---|---|
| `lib/src/motion/select.dart` | `e7be9931122eb6a2b9e5b58e0c7fd6aa4d0451680b11e3827c29eebead8ac597` |
| `lib/src/motion/animated_sidebar.dart` | `201c24d9e5c3bfafee87952a34f2a26be52ee3b43372e593bcbb994220955988` |
| `lib/beui.dart` | `9838785dbfc25e9e00be71bdbf888f088e30d0453ec6ef8f994a19da84c6d6ea` |
| `test/motion/select_test.dart` | `40eaa9d7ef57ef485e1d2fe8bc1556c6b5f4ab7a5b1dcc9c631df9027d1bd8f0` |
| `test/motion/select_source_parity_test.dart` | `79c06078da945e4a43ed23699c5613b43d81ed72200e2c1287f532f909942684` |
| `test/motion/animated_sidebar_provider_test.dart` | `a2e3365fc330dc06c2fb0d3c5f6eec957bd0c1d9f23b9976aad1828b9fcca1ec` |
