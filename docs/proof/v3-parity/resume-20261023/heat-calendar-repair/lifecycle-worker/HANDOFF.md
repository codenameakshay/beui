# Heat Calendar continuation repair

Only lib/src/charts/heat_calendar.dart and test/charts/heat_calendar_native_regression_test.dart were edited in the shared checkout. Existing repair preserved. No commits, pushes, children, shared Tooltip/overlay changes, goldens, broad suites or existing proof edits. Port 18153 is still serving the isolated captures; no other server was stopped.

## Mechanism

A calendar FocusScope retains primary scope focus when an invalid focused cell is unfocused. It does not focus a legend or expose a day readout during input replacement. The next Tab continues from the final surviving grid cell through the existing traversal policy. The traversal origin is set synchronously on Tab; Flutter defers focus notifications, so forward traversal only exposes the following control. Shift+Tab focuses the final surviving day. Moving focus outside the calendar cancels continuation. The scope uses parentScope edge traversal, so a grid without a legend can exit to an external control. No hard-wired legend node is shared between compositions.

Invalid uncontrolled range endpoints clear the internal anchor and endpoint during input replacement. The pinned source inputs/433/context.ts lines 79-90 validates both endpoints and clears invalid internal selection. Controlled values are validated for rendering without changing the owner's value or emitting an update callback. Restoring valid inputs restores the owner's controlled selection. Clicking while that value is invalid requests a fresh anchor without taking ownership.

repair.diff is the incremental production change against before.dart, the uncommitted repair at start. The prototype was not copied wholesale.

## Focused test evidence

- red.log: before implementation, 7 new checks fail and the 10 prior regressions pass. This includes both reported failures, reverse traversal, no legend and an intervening control. The initial external-focus test used a touch tap that did not focus a TextButton; that test setup was corrected to explicitly focus it in the widget test. Native external focus proof uses a trusted mouse click.
- green-final.log: all 18 focused regressions pass. Includes invalid range cleanup with no revival after restoring inputs; controlled validation and ownership; no immediate readout/focus; forward/reverse continuation; custom grid without legend; intervening custom control; cancellation; and all prior repair checks.
- existing.log: all 8 affected heat_calendar_test.dart tests pass, selected by name. Golden test excluded.
- analyze-final2.log: only the two owned files analyzed; no issues.
- red.log and green1 through green6 logs are retained, including the unsupported FocusScope constructor parameter compile failure. No failed attempt is represented as passing evidence.

## Native Chromium evidence

native-final/{source,candidate}-{no-preference,reduce}/results.json, original-frames/, capture.mp4 and PNGs contain the final default-composition runs. native-checks.json independently checks the requested outcomes; capture.mjs's own pass field only checks sequence integrity. All four sessions pass:

- October 23 / Escape / endDate October 19 leaves BODY for source or FLUTTER-VIEW for candidate, with no day/legend focus or tooltip visible.
- Next forward Tab focuses legend 0, with no intermediate day focusin event. The screenshot shows its filter and outline, without a day readout.
- Reverse Tab focuses October 19, matching source.
- A trusted click on external fixture control date focuses it; Shift+Tab then reaches shrink, rather than calendar continuation.
- Lock September 28 through October 23, shorten to October 19, then click October 5. October 5 is a new anchor. Clicking October 6 next locks October 5-6 and displays "2 commits Oct 5 - Oct 6 2 days". Inspected screenshots verify this in both motion modes and against source.
- Input events are trusted except the original Flutter semantics bootstrap click. No browser programmatic focus is used. No page errors.

custom-native/results.json and its PNGs add four native reduced-motion sessions against the same production chart bytes. A custom grid with no legend continues forward to the external after button; a custom control between grid and legend receives forward Tab before the legend. Both compositions reverse to October 19. Removal leaves no focused day or control. Trusted inputs and no page errors pass. This fixture differs only in /tmp, uses a separate /custom/ build and does not modify the shared gallery.

The default final build is an isolated regular-file copy, with the final chart overlaid before build3.log. Build command: flutter build web --release --no-wasm-dry-run --base-href /candidate/example/build/web/. Source served files were copied from the parent's existing isolated source. The user explicitly authorized reuse of capture.mjs, so this uses its Playwright Chromium/native-input workflow.

## Exact inputs and preserved attempts

input-hashes.json records the final shared production file, final test, before.dart, build chart, fixture, capture script and served files. build-input-hashes.json records the regular-file package inputs. custom-input-hashes.json records the supplemental fixture and served build.

Final production chart SHA-256: 939a3ea71a36b7e50358cdc38576f2f2da2ba68f91c0acdddaae4286dab5e548
Final regression test SHA-256: c22a9714daac51caff137bda86eeb4d68976f8a27dbd2a700f6c4787ea94c121
Both default and custom built chart files match the final production hash exactly.

native-attempt1 uses the pre-controlled-validation chart and is retained, along with served-candidate-attempt1/. native-final is the final production input. build2.log is not final evidence: its preceding copy used a wrong relative path and failed. build3 used the absolute shared chart path and succeeded. The first custom build invocation failed before starting because the working directory did not exist; the next invocation created it and succeeded. These tool failures are retained in the conversation; nothing was overwritten to disguise them.

## Limits

The continuation policy is verified for the default composition and two ordinary custom compositions with one grid. Arbitrary nested custom FocusScopes, custom traversal policies, multiple grids and other browser engines are not claimed. Custom native sessions use reduced motion only; default sessions cover both modes. Native Flutter ARIA still omits the selected state and the tooltip readout, so selection proof combines widget semantics assertions with inspected native pixels and the subsequent locking behavior. Existing visual differences from source, including range dimming, remain outside this repair. No assistive-technology, mobile, full-gallery, hosted CI, merge or release claim.
