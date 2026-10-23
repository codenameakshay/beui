# Sortable handle ownership

The input component SHA-256 was verified as `2ba3a4643a7fdeccc7521380a3749fb7ec9a4317f96ed2da3e2c24905a1068c4` before editing. Existing shared changes were retained. The two patches compare this task's input and output, rather than Git HEAD.

Each mounted handle now creates and disposes its own FocusNode. The root registry uses node identity keys and stores item IDs, allowing multiple nodes for one item. Unregistration checks the recorded item ID before removing that exact node. Deactivation unregisters before reparenting; dependency changes register with the current root and item. The registry only selects mounted, attached, focusable nodes. Undo still requests focus before publishing, allowing the owner's callback to choose external focus. Order-based eligibility and controlled publication are unchanged.

## Validation

- Reviewer baseline log: 10 passed; reviewer candidate log: 6 passed, 4 failed. Original probe and both logs are copied without edits.
- `red.log`: initial failing-first run before implementation; four reviewer failures reproduced.
- `red-final-tests.log`: final test input against preserved broken component in `/tmp/sortable-handle-ownership-red`; 29 passed, 7 failed.
- `green.log`: same final test input against repaired shared component; all 36 non-golden tests passed.
- `analysis.log`: targeted analysis of the component and test file, no issues.
- `git diff --check -- lib/src/motion/sortable_list.dart test/motion/sortable_list_test.dart`: passed.

Final test command, run in the workspace for green and the temporary package for red:

```sh
flutter test --no-pub test/motion/sortable_list_test.dart --name '^(?!rest-state golden)' --reporter expanded
flutter analyze --no-pub lib/src/motion/sortable_list.dart test/motion/sortable_list_test.dart
```

The isolated red invocation omitted `--no-pub` to resolve its new package. It used copied reviewer candidate supporting libraries and the preserved input component, with the exact final test file. The shared green invocation used workspace supporting libraries. Package files and Flutter version are preserved here; SHA256SUMS records evidence inputs and outputs.

The added cases cover the four reported failures, independent node identity, key remount, membership removal/reintroduction, disposal, global-key root reparenting, a global-key handle transferring between item IDs or roots, disabled/removed first-handle Undo fallback, and accepted/rejected controlled Undo with an already-focused external owner. Existing tests retain order-based Undo, disabled root, uncontrolled behavior, callback precedence, restored-item keyboard focus, pointer dragging, and reduced-motion coverage.

Intermediate test-authoring failures are retained separately: an unavailable ReorderableListView getter was replaced with visible row-position assertions; a disposed-node context assertion was corrected to check detachment and loss of focus. These are not final failures.

## Limits

Only the component, its test file, this new evidence directory, and temporary files were authored. No children, commits, pushes, broad suites, golden changes, native captures, builds, shared guard/overlay edits, SDK edits, or old evidence edits. Native move semantics remain for the parent's separate design work. This is focused widget-test evidence, not native-device or release qualification.
