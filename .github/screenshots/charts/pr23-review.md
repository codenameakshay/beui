# PR 23 chart review

Review of the uncommitted chart parity changes on `akshay/v3-charts`.
The review preserves the coordinator's visual changes and uses one worker per file.
No sibling-family implementation, package version, dependency, or toolchain changes are included.

## Verified repairs

Each behavioral repair has a regression demonstrated failing before its fix.

| Area | Finding | Regression coverage |
| --- | --- | --- |
| Shared tooltip | A ticker headline hid the accessible tooltip title. | `chart_ticker_test.dart` checks the AAPL accessible title with a custom ticker. |
| Volume profile | Top-row taps selected the lowest price. Uneven prices and clamped rows also selected the wrong visible bin. | `volume_profile_test.dart` checks the top row and tap/hover of the visible price-12 bar among prices 10, 11, 12, 100. |
| Volume profile | Hover survived an empty-data update and appeared again after replacement. | `volume_profile_test.dart` empties and restores the data without a new pointer event. |
| Bump | Hover replaced the persistent selection and could survive removal of its series. | `bump_chart_test.dart` checks hover, pinned selection restoration, and removal/replacement. |
| Returns | Short numeric year 99 rendered only an apostrophe. | `returns_calendar_test.dart` checks `'99`. |
| Price fan | Shared mutable State made old and new painter delegates compare the same widget, leaving cached layers stale. | `price_target_fan_test.dart` observes actual boundary repainting for axes, history, current guide, and targets after input updates. |
| Price fan | Invalid current prices reached the ticker instead of chart validation. | `price_target_fan_test.dart` checks `ArgumentError` for zero, negative, NaN, and infinity. |
| Composition/status | Earlier keyboard tests could pass from the tap result while arrow keys did nothing. Autofocus also failed after another control took focus. | Matching tests tap the first period, advance twice, and check entry from another focused control and Tab. |
| Donut | The outgoing caption jumped upward and then slid back down into the center. | `donut_chart_test.dart` checks rendered caption positions before, during, and after the transition. |
| Bump | Node focus overwrote a pin, Enter toggled that accidental pin off, and blur cleared selection. | `bump_chart_test.dart` checks callback payloads across Tab, Enter, and blur. |
| Returns | Tooltip titles reused the single-letter grid headers, making January, June, and July indistinguishable. | `returns_calendar_test.dart` checks full month names for all three while headers stay compact. |
| Candlestick | A first live price animated from zero, placing its badge far outside the price plot. | `candlestick_chart_test.dart` checks the first live badge position and animation on subsequent updates. |
| Price fan | Target/history hover and history blur retained stale inspection instead of returning to the Mean header. | `price_target_fan_test.dart` checks pointer exits and keyboard focus blur. |
| Price fan | Theme changes on an identical chart widget did not invalidate cached painter layers. | `price_target_fan_test.dart` checks boundary repainting across a theme change; delegates retain resolved palette snapshots. |
| Price fan | Showing the history tooltip changed the centered chart's height, moved the hovered point, and could trigger an endless enter/exit loop. | The history-exit regression reproduced a `pumpAndSettle` timeout before the tooltip stopped affecting layout. |
| Price fan | History-point hit targets intercepted drags that previously reached the background inspector. | `price_target_fan_test.dart` drags from the actual first point to the last and checks the literal last date. |
| Composition | Values and shares were available only on hover, not through keyboard inspection or screen-reader period actions. | `composition_chart_test.dart` checks Tab/Right, Organic 40 and 40.0%, and performs an accessible increase action. |
| Status | Pointer exit cleared the inspected selection and emitted null callbacks across gaps. | `status_bar_test.dart` checks that exit hides the tooltip while retaining the period and callback payload. |
| Status | The transparent range disappeared from accessibility semantics. | `status_bar_test.dart` checks its spoken value and performs an accessible increase action. |
| Composition | A stationary pointer kept the hovered period ahead of keyboard selection. | `composition_chart_test.dart` performs mouse hover/click then Right, checks Feb and Organic 40/40.0%, and checks that the resting card is absent. |

## Remaining findings

### Composition keyboard inspection after pointer exit

After hover and click focus the plot, pointer exit closes the tooltip. Right still changes the selected period, but the card stays closed.
The shared `BeuiTooltip` hides unconditionally on pointer exit and has no controlled-open API. Its focus callback does not run again while focus remains.
The worker reproduced this with a focused keyboard probe; inspection of the shared implementation confirms the lifecycle constraint.
No sibling tooltip code changed. The alternatives are a chart-local controlled overlay, or an authorized shared-tooltip lifecycle/API change.
Neither alternative is included in this review. Existing period semantics still expose the values and shares.

### Volume-profile tooltip placement

`BeuiVolumeProfileTooltip.side` is accepted but no longer read. Its content now renders inline below the plot.
Restoring the earlier tiny invisible trigger would hide the new pointer readout, so that is not a valid compatibility repair.
The two product options are floating side-aware inspection anchored to the plot, or inline inspection with the unused unreleased parameter removed.
This review does not choose between those placements or invent a follow-cursor API.

## Visual evidence limits

Live preview snapshots failed twice with `Preview automation snapshot timed out after 15000ms.`
The fallback computer-use browser reported `No browser is available`.
Registry source was readable, but these checks do not certify live browser or simulator parity.

The existing golden comparisons differed for treemap 3.15%, donut 10.23%, composition 4.01%,
price fan 7.57%, order book 0.13%, liquidity 3.58%, heat 5.15%, returns 4.83%, and bump 0.39%.
Those were intermediate working-tree runs, not final-head pixel measurements. Baselines remain unchanged.
The requested final test command skips golden comparisons.

`BeuiTooltip` has no `followCursor`. DigitSwap remains outside this review's write scope.
The donut center retains `BeuiChartTicker`.

## Caller and comment audit

The chart barrel export includes `BeuiChartTicker`; chart demos, the README table, and catalog callers match the current APIs.
Custom `BeuiPriceTargetSvg(children:)` callers need the explicit history-points layer for point interaction.
The default plot retains its Center-wrapped 520 by 236 cap and the IgnorePointer targets painter.

The independent Comment Sicko audit found no added inline narration comments to remove.
Keyboard tests encode the hidden-slider behavior instead of adding preservation comments.
False universal ticker timing and formatted-digit documentation are corrected. No runtime test was added for those documentation-only edits.

Test Behavior, Not Implementation changed the keyboard checks to advance from a known first period after another control held focus.
The motion regressions inspect rendered positions rather than only ticker-widget presence.

## Final local gates

The final working tree passed these commands on 2026-10-22:

```text
fvm flutter analyze lib/src/charts/ test/charts/ lib/beui.dart example/lib/demos/donut_chart_demo.dart example/lib/demos/heat_calendar_demo.dart example/lib/demos/price_target_fan_demo.dart example/lib/demos/treemap_demo.dart
No issues found! (ran in 7.4s)

BEUI_SKIP_GOLDENS=1 fvm flutter test test/charts/
00:03 +117: All tests passed!

git diff --check
Passed
```

These are local analyzer and behavioral-test results, not hosted CI or visual parity approval.
The two remaining findings above prevent a complete parity verdict.
Pre-existing source/Flutter capture directories remain untouched and are not part of this review commit.
