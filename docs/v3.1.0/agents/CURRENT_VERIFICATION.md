# Agents delivery checkpoint

This is a draft implementation checkpoint, not family or release acceptance.
Canonical source is `starc007/ui-components@1ab921e62283e788a686bc4bafa1de5ff56104ea`.
The unchanged Flutter baseline is `792ad82dca47cdf317fdd94f0bb9251724f562e2`.
The source catalog contains 18 Agents pages and 29 preview units. This delivery does not certify all units or variants.

## Delivery map

Source paths below are relative to `components/agents/` in the canonical checkout.
All local implementations are under `lib/src/motion/`.

| Source | Local implementation | Scope and current limit |
|---|---|---|
| `message.tsx` | `message.dart` | `animateIn` defaults to `false`, as in the source. Passing `true` keeps the mount-only entrance. |
| `message-bubble.tsx` | `message_bubble.dart` | `animateIn` defaults to `false`, as in the source. Passing `true` keeps the surface pop. |
| `tool-approval.tsx` | `tool_approval.dart` | Uncontrolled details start closed, as in the source. `defaultOpen: true` and controlled `open` are unchanged. |
| `citations.tsx` | `citations.dart` | Adds item icons for rows and stacks, plus an accessible marker `label`. Markers keep one focusable button node and drop stale numbers when the list empties. |
| `loading-states/thinking-shimmer.tsx` | `loading_states.dart` | Adds `BeuiThinkingShimmer.child` for rich content. It uses the shared `BeuiTextShimmer.child`. |

`text_shimmer.dart`, its child test, and its contract documents are byte-identical copies of the Components implementation.
They are not an independent Agents fork. The migration notes for the changed defaults are in `DEFAULTS_MIGRATION.md`.

```text
source defaults -> Message / MessageBubble / ToolApproval -> explicit legacy opt-ins
Citation item icon -> favicon slot (row, stack) ; marker label -> one semantics button
Components TextShimmer.child -> ThinkingShimmer.child
```

## Executed local gates

All Flutter gates use `/Users/codenameakshay/fvm/versions/3.44.4/bin/flutter` with the existing dependency resolution.
Behavior runs use `test --no-pub --concurrency=1 --reporter=json`.
Each run froze its local import closure and six configs before and after, and both snapshots match.
Counts below do not overlap.

| Run, head `24cf07190` | Result | Log SHA-256 |
|---|---|---|
| Root analysis, root2 | Exit 0, no issues, 577 files | `a1c59b669569b8770fe170b47129adced343364f54da94d5ec2abea2e010ee5c` |
| Example analysis, root2 | Exit 0, no issues, 577 files | `5b39c038040f49e167ac9b84e65e967425cff7f11de442695ff6dca73e31b6ec` |
| 23 relevant Agents suites, root2 | 532 passed, 6 golden errors, exit 1 | `5dbe1c221d2ff0ddef1d526f58e30a25c491ca67568d746bcfb4317147a4e8f5` |
| Source-default, Citations, Thinking and conversation suites, root2 | 46 passed, 2 golden errors, exit 1 | `bec3737663e60211daf13deb90bb11140d432d0db1b7d21c9363ee13fb8aa852` |
| Release-web build, root1 | Exit 0, 345 files | `45a03ab34604102e3b0d29eeae36ad74c0755997c89e16d011b640e484af323a` |

`dart format --set-exit-if-changed` on `lib`, `test`, `example/lib` and `tool` changed 0 of 558 files.

The eight golden errors are `agent_activity`, `approval_card`, `citations`, `todo_list`, `tool_approval`, `tool_result`, and both `message_bubble_variants` images.
All eight failed candidate PNGs are byte-identical to the candidates from the unchanged baseline run at `835f4396d`.
No golden was regenerated or skipped.

A cross-model review of `792ad82d..b998e85a1` found two defects. Both are fixed in `24cf07190` with regression tests:
an emptied `BeuiCitations` kept stale marker numbers, and the labelled marker did not expose its focus state.

Hosted CI on `ba3650e9e` ran the whole package suite and found two failures outside the relevant-suite list above.
`conversation_core_ux_test.dart` C12 still asserted the superseded `animateIn: true` default.
The C12 cases now assert the source default and opt in explicitly for the entrance and no-replay checks.
That file plus the source-default suite pass 63 cases, exit 0 (`conversation-ux-c12-20261106-root1`).
The relevant-suite list is not a full-suite gate. Hosted CI is the full-suite run.

Bulk receipts live under `/Users/codenameakshay/.t3/artifacts/beui-v3.1.0/agents/` on the verification machine.
Those local receipts are not accessible PR media.

## Open acceptance gates

- The full local test/golden gate is not green. The eight golden mismatches exist on the unchanged baseline too. Their lower-level cause is not established.
- The pilot media cover the preserved demo flows. The demo opts in to entrance motion and seeds ToolApproval open, so the media do not show the omitted defaults. The regression tests cover those defaults.
- Timing, performance, reduced-motion browser behavior, all-state coverage and native interaction are not accepted. Recorded frame gaps of about 183, 200 and 500 ms remain unexplained.
- `ShaderMask` colors all painted alpha, so `.child` shimmer over mixed non-text content differs from source CSS text clipping.
- Remaining source API gaps: AI Sidebar touch move commands and pointer drag-and-drop, Chat App source composition, Approval Card rich fields, Prompt Input rich labels, and Agent Activity rich items and status renderers.
- All 18 pages and 29 preview units still need final per-state and per-variant inventory acceptance.
- Hosted CI is a separate exact-head gate. Linux CI's existing golden-skip policy does not close the macOS golden hold.
