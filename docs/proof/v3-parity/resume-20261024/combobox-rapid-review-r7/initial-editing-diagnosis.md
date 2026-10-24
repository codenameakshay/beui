# Initial Combobox input loss: independent read-only diagnosis

The initial loss is consistent with Flutter's semantics editor activation gap. The archive proves browser input without a matching component controller update; it does not directly prove listener absence or identify the exact DOM overwrite call. The component's opening rebuild does write empty text and can supply the stale state that overwrites browser-only input. Source inspection finds no normal connection teardown caused by that controller write or rebuild. Do not call this a completed engine root-cause proof, or claim the component callback can recover input never delivered to it.

## Evidence inspected

Workspace proof root: docs/proof/v3-parity/resume-20261024/combobox-rapid-input/.

- Read REPORT.md, identity.json, archived SDK semantics source, buffered and final failing results.json, current component and installed framework/engine source. Current component SHA-256 matches ef7c79680a7208f9c593287a50fc30949b78e359b640a97aa78f9f7e4d316d97. Installed cached semantics file matches archive SHA-256 560248596a0ea39f197bd327dce65940f705abe166f5301634f8f15d6f46699b.
- Installed version metadata says Flutter 3.47.1, framework 6655482ec06e547f90abf8ae7590466f4415978d, engine 5d531788691ec3404cac0cee66ead4007b177363, Dart 3.13.1. No Flutter command or build was run.
- Buffered captures/buffer-sequence-2/combobox-reduce/results.json: node 4 receives trusted focusin at 1817.7 ms and trusted input P at 1823.9 ms, value P. At P keyup 1856.3 ms it is empty, still connected; no intervening node-4 blur. Dart trace records localKey P with controller Design studio, then inputBuild desired empty and controller empty in frame 5, then controller/onChanged r in frame 7. No controller/onChanged P is recorded. Selection-only controller changes before P do not establish that browser editing listeners were active; framework selection logic also writes controllers. Browser and Dart clocks are different, so do not subtract their timestamps as one clock.
- Final captures/final2-retry-initial-product-1/combobox-reduce/results.json: node 4 receives P/Pr/Pro at 1879.1/1879.8/1880.2 ms; o keyup at 1909 ms reads empty; subsequent d/u/c/t survive. Retained-query assertion fails with duct. This production capture has no engine/Dart instrumentation. REPORT's bounded final initial score is 5/6, not universal success.

## Exact SDK ordering and ownership

Paths below are relative to /Users/codenameakshay/fvm/default/.

1. bin/cache/flutter_web_sdk/lib/_engine/engine/semantics/text_field.dart:248-305 creates the editable DOM node and attaches focus/click/blur listeners. Native focus invokes SemanticsAction.focus at 282-293; it does not install the input listener. Click calls focusWithoutScroll. Blur calls deactivate.
2. packages/flutter/lib/src/widgets/editable_text.dart:4940 calls _openOrCloseInputConnectionIfNeeded on framework focus change. At 4150 it opens when focused and consuming the keyboard token. _openInputConnection at 4105 attaches a TextInput client, sends style and current editing value, then show.
3. Cached engine text_editing/text_editing.dart:2579 chooses the semantics strategy when semantics is enabled. _startEditing at 2593 calls strategy.enable with callbacks that forward through TextInputClient.updateEditingState or its delta variant. SemanticsTextEditingStrategy.enable at semantics/text_field.dart:49-57 only stores config/callbacks. It neither sets isEnabled nor registers input listeners.
4. SemanticTextField.update at 310-326 sees semanticsObject.hasFocus and calls activate. This depends on a focused semantics update, distinct from browser focus. activate at 64-82 attaches the DOM node and calls super.enable. Repeated activation of the same active field returns immediately. A different active field is disabled first.
5. DefaultTextEditingStrategy.enable at text_editing.dart:1738-1754 initializes, installs handlers, then replays lastEditingState through setEditingState, then refocuses. Semantics initializeTextEditing at 138-146 sets isEnabled and config; addEventHandlers at 119-134 installs input, keydown and document selectionchange handlers. There is no replay of prior input events. The synchronous listener-install/replay sequence does not itself require an intervening event; the exposure window precedes activation.
6. setEditingState at text_editing.dart:1579-1585 stores state even while disabled; when enabled and valid it applies that state to the DOM. Thus a pre-activation framework empty value can be replayed over P when activation finally runs. handleChange at 1596-1617 reads DOM editing state and forwards only a changed value. Missing controller delivery alone cannot distinguish missing handler, skipped equal state, wrong client, or a later channel/framework rejection.

Component boundary: lib/src/motion/combobox.dart:107-108 owns stable final FocusNode/TextEditingController objects; :149-152 disposes them only with component State. The trigger stays in the same keyed child structure. BeuiComboboxInput.build at :632-641 changes controller.value from the selected label to empty when open/query changes. TextField at :647-655 reuses those objects and remains enabled. EditableText._didChangeTextEditingValue at :4918-4936 sends remote editing state and schedules rebuild; it does not detach. didUpdateWidget at :3435 and :3492-3518 does not restart the connection merely for changed text or an onChanged closure. Connection close is tied to focus loss, disposal, or connection eligibility/config changes. No such transition is demonstrated here.

Consequently, the component contributes an authoritative value write, but there is no evidence it creates the activation gap by rebuilding its controller. Removing the build write could change the symptom, yet activation can still overwrite browser text with the original selected label. That is not a reliable repair. Same node/focus narrows lifecycle explanations but does not prove which client/listeners are active. DOM-value scraping, synthetic focus, printable-key reconstruction and globally delaying input are unjustified.

## Primary upstream evidence checked live

https://github.com/flutter/flutter/issues/194186 is OPEN, created 2026-10-11, titled "[web][a11y] Semantic text field erases input typed between browser focus and SemanticsTextEditingStrategy.activate()". Its author describes the same ordering and pre-activation overwrite. It uses a plain TextField and synthetic same-task input, so its report supports the mechanism independently of Combobox but is not a trusted-native reproduction of this archive.

https://github.com/flutter/flutter/issues/194186#issuecomment-6118111581 reports inability to reproduce on 3.47.7, framework abaf9c5237, Chrome 155 on macOS. This conflicting observation is material. It is neither a fix commit nor evidence that upgrading repairs the native timing case.

Read stable branch source through GitHub API; stable ref resolved to 737ba8f885dc774b53b442759999a312c9461e4e. Semantics enable/activate still defer handlers; pinned DefaultTextEditingStrategy.enable still registers handlers then replays lastEditingState:
https://github.com/flutter/flutter/blob/737ba8f885dc774b53b442759999a312c9461e4e/engine/src/flutter/lib/web_ui/lib/src/engine/semantics/text_field.dart
https://github.com/flutter/flutter/blob/737ba8f885dc774b53b442759999a312c9461e4e/engine/src/flutter/lib/web_ui/lib/src/engine/text_editing/text_editing.dart

Recent file history includes #192963 preserving DOM focus across role replacement and #192328 fixing iOS semantic input font sizing. Neither establishes a fix for this unchanged-node desktop input loss. Search for 194186 found related open reports #194548 and #194636, not a linked merged fix. No supported-version fix was verified. The bounded search does not prove no fix exists elsewhere.

## Next discriminating experiment, proposed only

Use a separately provisioned disposable engine checkout, never the shared installed SDK. Add one deterministic engine browser regression beside engine/src/flutter/lib/web_ui/test/engine/semantics/text_field_test.dart. Existing tests at :252 and :274 start with isFocused true; they do not insert an edit between native focus and the first focused semantics update.

Create an enabled, unfocused semantic text field with stable identity. Focus its existing DOM input. Hold the first focused semantics update. Supply config/show and a valid initial editing state through the text-input channel, inject a DOM input edit P while activation is withheld, then release the focused semantics update. Assert the editing callback/client receives P exactly once, DOM retains P with selection 1, and next r yields Pr. Run paired orderings with and without a framework empty-value update before activation; also pair an empty initial state with selected-label state. A test-created DOM input event is appropriate for deterministic engine ordering, but must not be called native capture evidence. Assert absence of callbacks and overwrite on the old engine as the failing-first result; no actual result is claimed here.

For the archive-specific diagnosis, add a bounded in-memory engine trace using one monotonic clock and stable node/client IDs. Record native focus/input entry, focus semantics action, text-input setClient/show/clearClient/setEditingState, strategy enable/activate/disable, listener add/cancel, handleChange entry and equality result, every DOM editing-state application with old/new text, and outgoing updateEditingState. Include framework receipt/client match and controller write reason. Export after the interaction rather than console logging during it.

Decisions from that trace:
- P precedes listener attachment, followed by activation's stale-state application: establishes the proposed engine activation boundary.
- Listener attached before P, but no handleChange: investigate event dispatch/propagation and listener identity.
- handleChange sends P but current framework client never accepts it: investigate client/channel routing.
- Controller accepts P and a later component write clears it: component-owned overwrite, a different diagnosis from the archived buffered trace.
- disable/re-enable appears during the opening rebuild: identify the exact caller before blaming rebuild; ordinary controller changes do not explain it.

Use a bare TextField with a persistent State-owned controller and no focus-time value rewrite as the control, then the same field with an explicit focus-time label-to-query write. This separates engine exposure from the component's clearing policy without invoking the parent-reviewed stale-open fix.

Safe options: retain the delivery blocker and file/share the existing native evidence with upstream only when messaging is authorized; evaluate a supported SDK upgrade in isolation as an experiment, without calling 3.47.7 a fix; or develop an engine-owned fix after the ordering regression is red. Any early-listener/pending-edit solution must bind edits to the correct client, preserve selection/composition, handle focus switching and explicit programmatic writes, and avoid replaying an edit twice. Simply calling activate from DOM focus is unsafe before configuration/client availability. No production workaround or accessibility removal is recommended on this evidence.

Only this /tmp report was written. No production/shared SDK/archive edit, build, capture, test run, Git mutation, child task or external message was performed.
