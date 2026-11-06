# Message defaults pilot

The cleared implementation unit is the default values of `BeuiMessage`,
`BeuiMessageBubble`, and `BeuiToolApproval`. This does not clear their complete
visual, behavioral, or motion acceptance, or permit edits to other entries.

## Immutable acquisition

Bulk media stays outside git at
`/Users/codenameakshay/.t3/artifacts/beui-v3.1.0/agents/pilot-message-defaults-2026-11-05`.
The compact machine-readable review is `acquisition-review.json` there.
Its SHA-256 is
`d4f64e528d9b1ed60f36095b007db3bd16d7bbc3ec7b57e88c091e208fba3547`.
The repo's compact state and hash review is [PILOT_MANIFEST.json](PILOT_MANIFEST.json).
The input manifest SHA-256 is
`05706f53fe84fe863dc2a4e96155b94d8a497d93fe18987a7a9a1f45145cebae`.

`prepare-pilot.mjs` and `prepare-pilot-events.mjs` produce acquisition inputs.
They reject existing output protocols. `check-pilot.mjs` verifies all six
nonblank stills, six compositor recordings, every retained frame hash, actual
event dispatch timestamps, served-script manifests, effective motion preference,
viewport, and FFprobe frame counts. It rejects an existing acquisition review.
These tools orchestrate the existing recorder without changing it.

All source and before widget/demo hashes passed `check-inventory.mjs
--require-untouched` before implementation. Source is pinned to `1ab921e6`.
Flutter widgets are pinned to `792ad82d`, built with Flutter 3.44.4 and Lucide
1.63.0. The shared artifact's misleading `lucide1.67.0` folder suffix is not its
dependency version. Root's full provenance records the resolved version.

Two fresh T3 snapshots failed with the same message, `Preview automation snapshot
timed out after 15000ms.` The authorized actual MCP fallback acquired the stills.
The existing `tool/parity_capture.mjs` acquired variable-frame-rate videos with
compositor timestamps. No fixed-rate frame replay is presented as a recording.

## Independent state review

| Pair | Observed source and before final state |
| --- | --- |
| Message | Submitted `Pilot parity check`, appended an assistant response, and returned to the empty composer. |
| Message Bubble | Submitted the same prompt and rendered the full source preview reply. |
| Tool Approval | Allow once progressed to Completed and closed the parameter disclosure. |

All six rest frames and six final frames were independently inspected. Existing
gallery previews explicitly opt into some states, so these captures do not alone
prove the omitted constructor defaults. Source-derived widget tests establish
those outcomes separately.

The originals retain different docs chrome and different stage origins. Source
and Flutter widget design differs in alignment, typography, controls, and color.
The before-Message recording's final frame also shows missing icon glyphs despite
the corresponding MCP still rendering icons. Font/rendering stability is an open
gate. Do not erase that observation or replace originals with a later render.
Root's later independent inspection also found tofu glyphs in its first timed
frame, before any events. An empty `document.fonts` list and
`document.fonts.ready` do not establish Flutter engine font readiness. The
acquisition difference remains under investigation; no fix is claimed.

Cadence is inconclusive for fast motion. Timeline reports retain delivery
reordering and gaps, including a roughly 500ms gap in before-ToolApproval.
The host also ran baseline tests. No measured FPS is a performance result.
Actual static and sampled-motion MCP calls completed offline. Their inputs,
provenance, observations, and limitations are in
[PILOT_DIAGNOSTICS.md](PILOT_DIAGNOSTICS.md). Design differences remain. Timing is
explicitly inconclusive. After captures, reduced-motion capture, native proof,
and complete state acceptance remain open.

## Scoped repair

```diff
 BeuiMessage(...)
-  animateIn = true
+  animateIn = false
 BeuiMessageBubble(...)
-  animateIn = true
+  animateIn = false
 BeuiToolApproval(...)
-  initialOpen = defaultOpen ?? parameters.isNotEmpty
+  initialOpen = defaultOpen ?? false
```

Root approved these as source-default bug fixes. Keep all parameter names and
types. Explicit `animateIn: true` and `defaultOpen: true` retain the previous
opt-in behavior. No source-specific alternate constructor hides the correction.
The implementation diff was independently reviewed against the pinned source.
Only these defaults changed in production code. Nullable `defaultOpen`, controlled
ownership, names, types, and explicit opt-ins remain unchanged.

The reviewed nine-test regression changed from six passes and three expected
failures to nine passes. The four focused suites produced 61 passes and one
unskipped ToolApproval golden failure. Its eight-pixel difference also exists on
the unchanged baseline. Both generated test images have SHA-256
`de3c5c08486ef53afb2731355e387ca3c1117721f5abe81766bc98b0b1c157d7`.
The golden fixture now explicitly requests `defaultOpen: true` to preserve its
original open-evidence composition. No golden image or tolerance changed.

The exact command was:

```sh
/Users/codenameakshay/fvm/versions/3.44.4/bin/flutter test --concurrency=1 --reporter expanded test/motion/agents_source_defaults_test.dart test/motion/message_test.dart test/motion/message_bubble_test.dart test/motion/tool_approval_test.dart
```

The complete run log is `after-focused-tests.log` under the immutable acquisition
directory. The manifest records its hash. This is not an overall green test run.
Root and example analysis both report no issues with the exact SDK. The manifest
records each complete log's hash. Root also independently reviewed the production
diff against source and reran all nine regression tests successfully.

Rerun `node docs/v3.1.0/agents/verify-pilot.mjs` to verify the retained acquisition
and diagnostic receipts without rewriting them. Missing or changed artifacts fail
the command. Hash verification does not replace the manual state review above.
