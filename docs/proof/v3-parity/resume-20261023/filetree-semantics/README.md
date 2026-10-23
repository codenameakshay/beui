# FileTree semantics repair

This component-owned repair separates the focusable list item from its row action. The action now explicitly carries button, selected and enabled semantics. The list item keeps focus, selection, expansion and hierarchy hints. The key handlers, collapse behavior, gesture callbacks, shared semantics and overlay code are unchanged. Independent controls in a custom icon remain separate actions.

## Supported API and remaining difference

The exact Flutter 3.44.2 SDK is recorded in `minimum-sdk-version.json`. Its public SemanticsRole enum has list/listItem but no tree/treeitem. Its web Selectable behavior emits aria-current for these roles; aria-selected is supported for row and tab. Changing a hierarchical file explorer to a table or tabs would misrepresent the component. The list-item implementation does not emit aria-disabled. The explicit child button does.

The repaired DOM therefore remains list/listitem, with aria-current on the item and action, aria-expanded on folders, and aria-disabled=true on the disabled child action. Source remains tree/treeitem with aria-selected and aria-disabled on each row. This is a bounded accessibility improvement, not exact role/state parity. Screen-reader speech, virtual-cursor behavior and announcements were not tested.

Flutter 3.44.2 also refuses DOM focus for semantics nodes with enabled=false. The focusable list item therefore has no enabled flag; its child action carries disabled state. The disabled row stays accessible and keyboard-focusable. Nothing excludes its semantics or inserts programmatic browser focus.

## Identity

Source pin is `a76e57c9bbc2837e96420b2610e9c82a3271bb05`. Its FileTree SHA256 is `119f58c07143b515b979da8fdb478dec489febf457e8af80aa36bb7895733aaa`.

Candidate starts from archived snapshot `1254bfa63a70298061c557616abeb9c6a67db372`, with only `lib/src/motion/file_tree.dart` replaced. Every archived baseline file was compared against the isolated build directory. `identity.json` records the replacement and test hashes. The supplemental entry points are additional fixture files, not replacements for component internals. Concurrent MultiSelect/Sortable work is excluded.

All bundled source inputs, locks, minimum-SDK API evidence, baseline tar, replacement component, test, supplemental fixtures, compiled builds and actually served JS/CSS/WASM are retained. `build-identities.json`, input bindings and per-run scripts bind the builds to the captures. Browser runs use the archived Playwright workflow, installed Chrome and trusted pointer/key input only. No driver calls focus or synthetic DOM activation.

## Verification

Ten focused non-golden widget tests pass on the current SDK and Flutter 3.44.2. Scoped analysis passes on both. The new assertions fail against the original component before repair. They cover selected action state, disabled action state/no tap action, retained keyboard focus, blocked Enter/Space/Right activation, and two independent content actions. The misleading existing tree-role test title now describes its actual list-role assertions. No golden files were changed.

`attempt-2` repeats the original bounded 24-checkpoint native sequence for source and candidate under both motion preferences, 96 checkpoints. `analyze.py` verifies all visible rows, expanded IDs, complete callback histories, selected owner values, motion preferences and actual DOM focus. It also verifies candidate aria-current and disabled action markup. The external collapse still leaves source focus on BODY and candidate focus on Parent; both next Tab to After and Enter leaves tree callbacks unchanged. No speculative immediate-collapse focus change was made.

`attempt-controls3` adds a disabled folder and two custom-icon controls. It checks native disabled focus and blocked Enter/Space/Right selection/expansion, then trusted pointer activation of Inspect and Pin. Source hides icon content under aria-hidden; its buttons are clicked by DOM selector and are not claimed accessible. Candidate controls are found by accessible button name. This is supplemental composition evidence, not the unchanged gallery preview or pixel parity.

## Retained failures

The first widget assertion fails against baseline. An intermediate test used the wrong root semantics owner and another disposed its semantics handle too late. The first content-action test used a non-hit-testing empty box; its corrected fixture explicitly uses opaque hit testing. All logs remain.

`attempt-1` retains a rejected component build. Internal widget focus passed, but actual DOM focus stayed on Leaf at all three Disabled checkpoints in both motion modes. `attempt1-rejection.json` records that discrepancy. The repair removes the enabled flag only from the outer focusable item, keeping the disabled action exposed.

`attempt-controls` retains source role-lookup timeouts caused by aria-hidden icon content. Both it and `attempt-controls2` retain candidate control-lookup timeouts: Flutter's default base href loaded the original root fixture instead of the controls entry point. The served hashes demonstrate this setup failure. The controls build now uses `--base-href /controls/`. The original controls build and source fixture/bundle remain archived. Two mistaken build commands ran from the repository root and failed before compiling; their logs also remain.

## Media and portable verifier

All 3,385 screencast PNG originals across 20 runs remain, with per-frame hashes and capture metadata. Every run retains its timestamp MP4 and 25 fps FFV1 frame-index replay. `timestamp-audit.json` records original/decoded counts and maximum relative timestamp error for each run. `verification-summary.json` records decoded counts and exact RGB comparison of every FFV1 frame to the original PNG. FFV1 replay timing is intentionally unrelated to capture timing. MP4 YUV RGB equality and absolute capture epoch preservation are not claimed. One retained intermediate MP4, attempt-controls2/source-reduce-accept, decodes 89 frames from 90 originals. Other MP4 counts match. Among runs with equal counts, the largest relative timestamp error is 0.016667 seconds; no index-based timing comparison is claimed for the mismatched run. These captures do not establish 60 fps or animation-quality parity.

Run `python3 verify.py` from any directory with Python, Pillow, ffmpeg and ffprobe installed. It validates hashes, original media, actual served builds, expected failures, trusted input, behavioral assertions, decoded counts and every FFV1 RGB frame. The regular-file export is `/tmp/beui-filetree-semantics-export-20261024`. It requires no Git object store, mutable checkout, symlinks or browser servers. Build reproduction still requires the recorded SDK/dependencies; the verifier is portable, not a hermetic installer.

Only owned servers on checked-free ports 18175 and 18176 were used. No children, commits, pushes, broad tests, shared edits or old proof mutations were performed.
