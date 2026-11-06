# Internal size observer verification

The standalone internal `BeuiMeasureSize` passes 10 focused widget tests on
Flutter 3.44.4. No consumer has migrated. This receipt does not establish a
consumer's layout, animation, visual parity, performance, or native behavior.
Root review and local commit approval remain open.

## Exact scope

```text
lib/src/layout/measure_size.dart        internal widget and render-local state
test/layout/measure_size_test.dart      notification and render behavior
```

There is no barrel export, dependency change, global registry, hidden child,
consumer edit, audio implementation, build, browser capture, or device action.
One Luna worker wrote the two files. The owner read both files and corrected
the test fixtures and the private-type analyzer finding described below.

The contract is `SHARED_INFRA_CONTRACT.md`, measurement section. Root approved
that section in durable `coordination/shared-infra-root-review.md`. The helper
uses one `RenderProxyBox`. Its state is local to that render object.

```text
layout
  keep the latest size that differs from the last delivered size
  queue one post-frame delivery for the attachment generation
post-frame
  reject a detached or stale generation
  deliver through the latest callback
detach
  invalidate pending work and preserve the last delivered size
reattach
  observe valid layout again without replaying an unchanged size
```

The callback observes constrained local `Size`, not a global rectangle,
transformed bounds, clipping, visibility, or scroll position. A callback that
sets widget state changes the next frame's layout, not the completed frame.

## Final commands and results

All paths below are relative to this worktree unless stated otherwise. The
Flutter executable is `/Users/codenameakshay/fvm/versions/3.44.4/bin/flutter`.
The Dart executable is
`/Users/codenameakshay/fvm/versions/3.44.4/bin/cache/dart-sdk/bin/dart`. Existing
dependency resolution points to that exact SDK and flutter_lucide 1.63.0.
No dependency command ran for this unit.

| Command | Result |
| --- | --- |
| `flutter test --no-pub --concurrency=1 --reporter expanded test/layout/measure_size_test.dart` | 10 pass, exit 0 |
| `dart analyze lib/src/layout/measure_size.dart test/layout/measure_size_test.dart` | No issues, exit 0 |
| `flutter analyze --no-pub` in the root | No issues, exit 0 |
| `flutter analyze --no-pub` in `example` | No issues, exit 0 |
| `dart format lib/src/layout/measure_size.dart test/layout/measure_size_test.dart` | Completed |
| `git diff --check` | Clean |

Final durable logs are under
`/Users/codenameakshay/.t3/artifacts/beui-v3.1.0/components/`.

- `measure-size-final-frame-tests.log`.
- `measure-size-clean-scoped-analyze.log`.
- `measure-size-clean-root-analyze.log`.
- `measure-size-clean-example-analyze.log`.

## Tested outcomes

| Test | Literal observable outcomes |
| --- | --- |
| First and changed sizes | `30x20`, then `50x35`, only after layout in `postFrameCallbacks` |
| Child-only relayout | `20x12`, then `44x28`, without another parent build |
| Coalescing and changeback | `10x8`, then only `35x24`; return to last delivered size cancels; a later same-frame target delivers `22x17` |
| Callback replacement | Initial `16x9` goes to the old callback; pending `25x14` goes only to the replacement; unchanged size does not replay |
| Callback-driven state | `18x11`, then `32x19` on the following frame |
| Keyed reparenting | Same-size reattach does not replay `24x16`; changed-size reattach of the same render instance delivers `41x27` once |
| Stale attachment generation | Canceled first `19x13` never delivers or clears the newer pending `31x23` |
| Disposal | Delivered `21x15` remains the only callback after disposal cancels pending `32x26` |
| Local bounds | Tight `25x15` wins over preferred `80x60`; translation and scale do not emit another size or schedule idle frames |
| Render neutrality | Wrapped and unwrapped results both have `40x28` layout, dry layout, and child size, loose `800x600` constraints, intrinsic widths 40, intrinsic heights 28, and actual and dry baselines 18 |

Render neutrality also checks every RGBA pixel against `0x12,0x34,0x56,0xff`,
one paint in each variant, pointer taps, and rendered semantic tap actions.
Both pointer and assistive actions reach the child's callback. The semantics
handle and image resources are disposed. No golden was created or regenerated.

## Review corrections and failed attempts

The original worker suite failed to compile. It lacked the scheduler import
and marked non-const `BoxConstraints` constructors const. The owner fixed only
those compile issues and reran it. That run produced 5 passes and 4 failures.
Two fixtures inherited tight `800x600` root constraints while expecting their
preferred child sizes. The changeback test returned to the initial size, not
the last delivered size. A test also called the protected actual-baseline
method outside the framework's required parent layout call.

The owner corrected those fixtures and strengthened callback replacement to
use distinct direct callbacks, rather than closures over a mutable variable.
The owner added a parent render probe for a lawful actual-baseline query,
literal layout and raster expectations, genuine changed-size reattachment,
distinct stale-generation sizes, disposal after a positive delivery, and the
local-size boundary test. A raster attempt waited under fake async and was
interrupted. The owner moved image encoding inside `tester.runAsync`.

Analysis found a private render type in the public override signature and
deprecated test use of `pipelineOwner`. The owner changed only the override
parameter to `RenderObject` with the framework-boundary cast. The notification
algorithm did not change. Test layout flushes now use `rootPipelineOwner`, and
semantic activation uses the rendered object's actual owner.

Two intermediate runs exposed test-only standalone pipeline setup mistakes.
Attaching loose test render objects to the binding's root owner created dirty
semantic nodes without that owner's root node. An isolated `PipelineOwner`
avoided that shared-state mistake but did not schedule a frame by itself.
The final fixture owns and disposes that isolated owner and explicitly
schedules the test frame before pumping its post-frame callbacks. The helper
does not request an extra frame or poll continuously.

The original compile log, the 5-pass/4-failure log, the interrupted raster log,
the two 8-pass/2-failure setup logs, and earlier passing logs remain unchanged
in the durable artifact directory. They are not hidden by the final pass.
The owner's failed initial format attempt and wrong-working-directory hash
command made no source change and were corrected before the final checks.

## Reviewed code hashes

```text
1a0a52e37ce0d88cfda1eaa83d19a525c0971c1d8320591fb79fc78ccccd4037  lib/src/layout/measure_size.dart
b3e1a4a5780636e40b93d34e793e1b8547cf4b39c8f1574d922019588d71923e  test/layout/measure_size_test.dart
```

Fresh Luna Comment Sicko review found zero findings. It retained the sole
widget dartdoc and found no comments in the tests. There were no deletions,
restorations, encodings, or reruns. Both code hashes remained unchanged.

Test Behavior changed the tests to assert literal callback sequences, actual
semantic activation, and raster output. Prove It Works kept all failed inputs
and limited the verdict to this standalone helper. Root independent review,
consumer migration, and full-family evidence remain separate gates. Nothing
in this receipt authorizes a commit, push, or PR.
