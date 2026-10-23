# FileTree native keyboard evidence

Bounded supplemental composition, tested 2026-10-24. No production change is proposed by this archive. The source and candidate complete the requested keyboard sequence under both motion preferences, with a demonstrated immediate focus difference after external collapse and accessible markup differences. This is not a general parity or native60 claim.

## Identity and scope

Candidate snapshot: `1254bfa63a70298061c557616abeb9c6a67db372`, created with read-only `git archive`, never copied from the mutable checkout. FileTree SHA256 is `d0927cbf4c8c349c3726eb9a3365cdb246e7fc29ef63d5482a188190632b7882`. Snapshot bytes, commit bytes and shared FileTree bytes matched before the run. Concurrent Sortable/MultiSelect changes are excluded.

Source pin: `a76e57c9bbc2837e96420b2610e9c82a3271bb05` in `/tmp/beui-charts-reference-20261023`. FileTree SHA256 is `119f58c07143b515b979da8fdb478dec489febf457e8af80aa36bb7895733aaa`. All four bundled repository source inputs match that pin. `source-input-bindings.json` binds every bundled input to retained bytes; package locks, candidate baseline tar, resolved Flutter dependencies, source bundles, candidate builds and served JS/CSS/WASM hashes are retained.

The explicit tree is Parent > Folder > Leaf, Disabled, Sibling; Peer is another Parent child; Tail is a root file. Before/After buttons bound native Tab traversal. The accepting controlled owner records every selection and expansion proposal. A trusted `c` keypress clears expanded IDs externally while Leaf has focus. Fixtures do not replace FileTree internals. This is not the unchanged gallery preview. No typeahead requirement is imposed.

## Source contract and observed results

The unchanged source `file-tree.tsx` derives the tabbable row from the visible rows during render. It does not explicitly focus a replacement after removing a descendant. Its keyboard handler traverses disabled rows; `aria-disabled` blocks selection and expansion, not keyboard focus. Therefore disabled exclusion here means exclusion from activation, not skipping during traversal.

Both final motion modes on both implementations demonstrate:

- ArrowRight expands Parent, enters Folder, expands Folder, and enters Leaf. Expansion proposals occur only on expansion, not entry.
- Enter selects Leaf once. ArrowDown focuses Disabled. Enter and Space leave selection and callback counts unchanged. Another ArrowDown reaches Sibling.
- End reaches Tail and Home reaches Parent without selecting either.
- ArrowLeft collapses Folder, moves to Parent, then collapses Parent. Reopening returns to Leaf without stale selection callbacks.
- External collapse removes descendants and leaves expanded IDs empty, selection `leaf`, one selection callback and six expansion callbacks. The external owner update adds no component callback.
- The next native Tab reaches After; Enter produces no tree selection or expansion callback. There is no demonstrated post-collapse Tab/selection defect in this composition.

Immediate focus differs: source `document.activeElement` is BODY after removal; candidate is the Parent semantics button. Both have the same subsequent Tab/Enter outcome. Candidate focus conclusions use actual DOM focus and trusted keyboard continuation. The release-build `primaryFocus` debug-label probe is null and is not treated as focus evidence.

Accessible markup differs: source exposes tree/treeitem, `aria-selected`, and `aria-disabled`. Candidate exposes list/listitem and does not expose those selected/disabled attributes on the recorded rows. The selected Leaf is visibly highlighted and the owner selection is correct, but those facts do not establish accessible selection parity. Screen-reader speech was not tested. Fixture typography, button styles and background are not pixel-matched; screenshots are evidence of the interactions, not pixel acceptance.

`analyze.py` verifies 24 checkpoints per final run, 96 total, including visible rows, exact expanded IDs, complete callback histories, owner selection, motion preference propagation and native focus. Source selected/disabled attributes are checked separately; they are not silently assumed present in Flutter. `behavior-checks.json` contains the result. `motion-probes.json` records browser and fixture reduced-motion values. It does not certify animation quality or frame rate.

## Attempts and capture limits

Attempt 1 retains two complete source runs and two failed candidate setup runs. A trusted click did not enable Flutter accessibility semantics; finding Before timed out. All failure PNGs, three screencast frames per failed run, logs and videos remain. Attempt 2 changes only the supplemental Dart entry point to call `ensureSemantics()` at startup. The archived component bytes are unchanged. No driver call sets focus or synthesizes DOM activation. Inputs use the documented Playwright runtime and installed Chrome; all logged input events are trusted.

All 1,663 original screencast PNGs across eight runs are retained. Timestamp MP4 and index replay each decode to the original count for every run, so there is no decoded frame-count loss. There is timestamp loss: the first normal-motion source MP4 differs from recorded relative timestamps by up to 0.449983 seconds. The final four MP4 runs have maximum measured relative timestamp error below 0.000001 seconds. Original metadata remains in each results file. The MP4s do not preserve the absolute capture epoch and RGB equality is not claimed for their YUV encoding.

The separate 25 fps FFV1 index replays decode every original PNG in order with exact RGB equality. Their timing is intentionally unrelated to capture timing. Complete RGB replay is not timing proof. `timestamp-audit.json` and verifier decoded counts retain these distinctions.

## Verification and handoff

Run `python3 verify.py` from any location with Python, Pillow, ffmpeg and ffprobe installed. The verifier checks retained file hashes, original screenshots/frames, served bundle identity, trusted inputs, expected setup failures, final behavioral checks, decoded counts and every FFV1 RGB frame. It needs neither checkout nor browser servers.

The regular-file export is `/tmp/beui-filetree-native-export-20261024`; no symlink, Git object store or mutable original source is needed for verification. `verify-export.json` records its independent verification. Builds require the dependencies and paths recorded in the setup/build scripts; this is a portable evidence verifier, not a hermetic dependency installation service.

Only the owned Python servers on checked-free ports 18173 and 18174 were stopped. No children, broad suites, goldens, production/test/shared edits, commits or Git mutations were performed. PR 26 is linked to this thread; no hosted checks, merge or deployment claim is made.
