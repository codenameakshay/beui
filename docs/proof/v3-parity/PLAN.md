# v3 reference parity remediation

Baseline is `5ec78ac30e1274727ddd185a883346e4d908e6c8`. The v3 additions are measured against `a4d493a`. Delivery uses the existing PR https://github.com/codenameakshay/beui/pull/26. No merge is authorized.

## Acceptance

Every new or changed widget must have a reference mapping, matching data/theme/viewport, state inventory, real interaction evidence, and a verdict. Compare rest, hover enter/move/leave, focus, activation, intermediate animation, exit and repeat interactions where applicable. Chart tooltips must show correct values and matching motion while traversing points. Tooltip text transitions must be captured, not inferred from container visibility.

Preserve immutable reference and pre-change recordings. Attach labeled before/after videos for every changed widget, a text explanation of each change, and videos for all new widgets. A missing recording is an open gate. Static or inconclusive motion output cannot pass a motion gate. Report pixel differences honestly; aggregate similarity scores cannot establish exact parity.

## Workflow

1. Inventory the four widget families and inspect source and prior evidence.
2. Capture baseline and reference states before editing each component.
3. Repair isolated slices with GPT-6.1 Sol workers using Poteto Mode.
4. Independently judge coverage and evidence. Integrate only reviewed commits.
5. Rebuild the combined gallery, verify cross-widget behavior, run analysis and tests.
6. Publish one consolidated PR with a complete video and change index. Keep unresolved gates explicit.

## Ownership

| Slice | Work | Local port |
| --- | --- | --- |
| charts | Chart widgets, demos and tests | 8101 |
| components | Motion components, including tooltip | 8102 |
| blocks | Composed blocks and shared digit-swap/text-scramble | 8103 |
| agents | Agent/chat/voice widgets | 8104 |
| audit | Independent inventory and evidence tooling | 8105 |

Each worker uses a separate worktree. Shared theme, engine, barrel and gallery changes require integration by the coordinator. All children use codex/gpt-6.1-sol, high reasoning and priority service.

## Throughput checkpoint

The baseline v3 diff contains 668 changed files. Work is partitioned by family so captures and focused tests can run independently. The critical path is reliable reference/candidate recordings and independent verification, followed by integration. Existing scores and skipped goldens are not acceptance evidence. Exact widget/state count is pending the independent inventory.
