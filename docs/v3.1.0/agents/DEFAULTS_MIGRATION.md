# Agent defaults migration

This narrow repair aligns three constructor defaults with pinned beUI source
`1ab921e6`:

| Widget | Flutter default before | Source default | Migration opt-in |
| --- | --- | --- | --- |
| `BeuiMessage.animateIn` | `true` | `false` | `animateIn: true` |
| `BeuiMessageBubble.animateIn` | `true` | `false` | `animateIn: true` |
| `BeuiToolApproval.defaultOpen` | `parameters.isNotEmpty` when null | `false` | `defaultOpen: true` |

Source references:

- `components/agents/message.tsx:70` defaults `animateIn` to `false`.
- `components/agents/message-bubble.tsx:109` defaults `animateIn` to `false`.
- `components/agents/tool-approval.tsx:113` defaults `defaultOpen` to `false`.
- `components/agents/tool-approval.tsx:124` seeds uncontrolled open state from
  that default; parameter presence does not override it.

No public names, parameter types, requiredness, or constructor shapes changed.
Explicit entrance opt-ins remain mount-only. Tool approval keeps nullable
`bool? defaultOpen`: null and false both start closed, true starts open, and
non-null controlled `open` remains authoritative with `onOpenChange` requests
preserved.

The coordinated source-default regression tests cover default insertion without
movement, explicit entrance movement and non-replay after content updates,
reduced-motion entrances, tool evidence closed by default, explicit open/closed
defaults, and controlled owner decisions. The pre-implementation reviewed
baseline recorded the three expected source-default failures in
`docs/proof/v3.1.0/agents/before/source-default-regressions-reviewed.log`;
the reviewed post-fix run passed all nine regressions. The four focused suites
passed 61 tests and retained the baseline-identical eight-pixel ToolApproval
golden failure. Its fixture explicitly requests open evidence, preserving the
original golden composition without regenerating pixels. Root and example
analysis passed. `PILOT_MANIFEST.json` records the receipts. This change closes
only the selected defaults discrepancy. It does
not establish full agent-family parity, visual fidelity, motion/performance
fidelity, native behavior, hosted CI, or release readiness; the open evidence
gaps in `PILOT.md` remain open.
