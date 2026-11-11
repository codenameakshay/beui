# Charts delivery checkpoint

This is a draft implementation checkpoint, not family or release acceptance.
Canonical source is `starc007/ui-components@1ab921e62283e788a686bc4bafa1de5ff56104ea`.
The unchanged Flutter baseline is `792ad82dca47cdf317fdd94f0bb9251724f562e2`.
The source catalog contains 17 Charts pages and 17 preview units. This delivery does not certify all units or variants.

## Delivery map

Source paths below are relative to `components/charts/` in the canonical checkout.
All local implementations are under `lib/src/charts/`.

| Source | Local implementation | Scope and current limit |
|---|---|---|
| `xy/`, `line-chart.tsx` | `_xy.dart`, `_xy_parts.dart`, `line_chart.dart` | New. Line and area series, snapping crosshair, tooltip, keyboard and screen-reader inspector. Per-coordinate springs through the motor facade. |
| `bar-chart.tsx` | `bar_chart.dart` | New. Grouped, stacked, vertical and horizontal bars on the shared XY parts. Stacked totals clamp to the largest finite `double`, and bar lengths cap just past the plot edge. |
| `sparkline.tsx` | `sparkline.dart` | New. Line and area variants, gaps, delta badge and optional inspector. Delta colors are the source's fixed Tailwind values, a documented exception to the `BeuiColors` rule. |
| `donut-chart.tsx` | `donut_chart.dart` | Ring geometry, legend, center content, hover and focus aligned with the source. |
| `price-target-fan.tsx` | `price_target_fan.dart` | Source 520px content-height host, responsive plot, header typography and 1.5px history stroke. Reduced motion keeps the source zero-duration target dim. |
| `returns-calendar.tsx` | `returns_calendar.dart` | Year typography, tint percentages, selection outlines and annual colors. Reduced motion mounts cells and rings at their targets, as the source does. |
| shared color and number helpers | `_shared.dart` | CSS color literals (including `#RRGGBBAA`) and source maximum-precision number output. Committed in `9fa84bddd`. |

`lib/src/motion/tooltip.dart` and its external-anchor test are byte-identical copies of the Components implementation.
They are not an independent Charts fork. `lib/beui.dart` only adds the three new chart exports.

```text
shared color/number contract -> every chart readout
XY domain + axis + inspector + point tracker -> Line / Bar / Sparkline
Components tooltip external anchor -> chart tooltips
```

## Executed local gates

All Flutter gates use `/Users/codenameakshay/fvm/versions/3.44.4/bin/flutter` with the existing dependency resolution.
Behavior runs use `test --no-pub --concurrency=1 --reporter=json`.
Each run froze its local import closure and six configs before and after, and both snapshots match.

| Run, head `220ddf134` | Result | Log SHA-256 |
|---|---|---|
| Root analysis, root3 | Exit 0, no issues, 592 files | `aba90032281dc9e0affe1e0382f988d3cae20fa516ec0cc6cb98947c76939a46` |
| Example analysis, root3 | Exit 0, no issues, 592 files | `b266aabd515f8d2f32a209047e3a4bc215bef027bc7fa2346a9a2228d25bed05` |
| Full package suite, all 202 test files, root1 | 2961 passed, 35 golden errors, exit 1 | `05736799f0718ac939d21cf598fc6b16d4a5689c2dfed5fcf0285559194b9926` |
| Full example suite, all 18 test files, root1 | 66 passed, exit 0 | `7ca0135dacb3a2f1cc7011befc06f9c5981f1cb92d85865d491a5659791915bb` |
| Release-web build, root2 | Exit 0, 353 files | `ce28805f2fe39556adfb11196ddc5559f8f4872119a225b04d1c236c4cad6b0f` |

After the three product decisions, on head `712c679d2`:

| Run | Result | Log SHA-256 |
|---|---|---|
| Root analysis, root4 | Exit 0, no issues | `53f5c4b36c9007a9e5158984d4b268006979ed1c39a5b752154a85025dd6e738` |
| Example analysis, root4 | Exit 0, no issues | `44cf9ab6c9826ddcf67859f115e29eecf618528e1c02d21df15f28d6bf646a5a` |
| Full package suite, all 202 test files, root2 | 2966 passed, 32 golden errors, exit 1 | `b37e23d17260f5104a2fdc00fa4398ce963388480dd03d15c8f6f744817ac2df` |

The follow-up review fix `bf6069327` then passed the seven affected suites, 135 cases, exit 0 (`1b5b1450794cd5325f07e8ead50030b77867b19c4504c21c0016809eb97beb74`).

`dart format --set-exit-if-changed` on `lib`, `test`, `example/lib` and `tool` changed 0 of 573 files.

All 35 errors are golden pixel mismatches. No golden was regenerated or skipped.
32 failed candidate PNGs are byte-identical to the candidates from the unchanged baseline run at `835f4396d`.
Four are new: Donut, Liquidity Heatmap, Price Target Fan and Returns Calendar. This branch changes those charts on purpose.
A cross-model review traced the Fan (5.45%) and Returns (5.09%) deltas to specific source-parity lines. The Heatmap delta follows the source number format (`100.00` becomes `100`). The Donut arc-edge delta (0.60%) has no established cause.

A cross-model review of the full Charts delta found and fixed overflow, readout, focus-ring and stale-touch defects in the XY family, with regression tests.
Root rejected three of its hunks. Two removed reduced-motion behavior that the pinned source has (`price-target-fan/series.tsx:80-82` with `context.ts:210`, and `returns-calendar/grid.tsx:113,145`).
The third moved the Returns wave to a motor tween, but it swapped the cell's parent widget and would remount its dim and tint transitions.

Bulk receipts live under `/Users/codenameakshay/.t3/artifacts/beui-v3.1.0/charts/` on the verification machine.
Those local receipts are not accessible PR media.

## Open acceptance gates

- The Heatmap, Fan and Returns goldens were regenerated on Flutter 3.44.4 for their intended source changes. The Donut golden still fails, and its arc-edge cause is not established. The other 31 failing tests write 32 candidate images, all byte-identical to the unchanged-baseline candidates.
- The Returns wave still uses a raw `AnimationController`. A motor version must keep the cell's tree shape stable.
- Matched source, unchanged-before and current-after media, timing, performance and native interaction are not accepted.
- All 17 pages and 17 preview units still need final per-state and per-variant inventory acceptance.
- Hosted CI is a separate exact-head gate. Linux CI's existing golden-skip policy does not close the macOS golden hold.
