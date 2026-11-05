# TextShimmer child focused verification

The approved additive child constructor passes its new and existing focused
suites on Flutter 3.44.4. This verifies the shared composition contract, not
source visual parity, audible output, native UI, or release readiness.

## Implementation boundary

The owner independently read the worker's complete production diff. The
positional String constructor, its public String text field, and all existing
parameter types remain intact. The child constructor stores its widget
privately and sets the compatibility text value to the empty string.
DefaultTextStyle.merge supplies child-path style and alignment. Both paths
share the existing controller, shader, ShaderMask, and RepaintBoundary.
No duration policy, animation phase, physics, or reduced-motion policy changed.

```diff
 BeuiTextShimmer
   String constructor
+  child(Widget) constructor
   existing state/controller/shader
```

The pinned source TextShimmer accepts ReactNode children and defaults to 2.5s.
ThinkingShimmer composes it with arbitrary children, font-medium, and a 1.8s
default. Agents can use the exact [approved contract](TEXT_SHIMMER_CONTRACT.md)
with its own 1800ms default and no forked controller or mask.

The all-alpha mask also colors non-text child paint, unlike CSS text clipping.
The source reduced-motion highlight differs from the local centered phase.
Both limitations remain in [shared baseline evidence](SHARED_BASELINE_EVIDENCE.md).
The additive child change does not repair or certify either difference.

## Commands and observed results

```sh
/Users/codenameakshay/fvm/versions/3.44.4/bin/flutter test --no-pub --concurrency=1 test/motion/text_shimmer_child_test.dart test/motion/text_shimmer_test.dart --reporter expanded
```

The corrected run passes 15 tests. Its complete log is retained at
`components/text-shimmer-child-corrected-20261105.log` in the durable task
artifact directory. No tests or goldens were skipped or regenerated.

Coverage includes the positional public API, empty child compatibility text,
rich textual content, inherited and explicit styles, alignment, a literal
90px layout constraint, and the child's actual merged semantic label.
A real Tab acquires the child button's primary focus. Enter and pointer tap
produce callback counts one and two. Keyed replacement and transitions between
the string and widget constructors render only the intended content.
Reduced-motion updates stop scheduling frames, and disposal releases the
running ticker. Duration updates retain one live child path; exact period
changes during an existing sweep are not certified by that assertion.

The shader comparison mounts each constructor into fresh state, starts the
frame clock, then samples both at 625ms and identical 200 by 24 bounds.
Their complete 200-pixel red-channel rows match. Independent literal samples
at x=0,40,80,100 are approximately 253,133,13,0, with small raster tolerances
on the nonzero samples. These values follow the unchanged repeated gradient's
20-degree projection and 30%,50%,70% stops. This is local shader evidence, not
a browser source comparison or real elapsed-time recording.

The first authored child-suite run passes nine tests and fails two fixture
checks. Its semantics finder assumed the wrapper label excluded child text,
but Flutter merges both labels. Its shader helper reused one controller while
claiming matched elapsed time. The parent corrected the lookup to the rendered
keyed node and asserted the literal merged label. The helper now unmounts
between samples. The original log remains at
`components/text-shimmer-child-focused-20261105.log`. No production repair was
needed for either fixture failure.

Root and example `flutter analyze --no-pub` pass on the pinned SDK. Their logs
are `components/text-shimmer-analyze-root-20261105.log` and
`components/text-shimmer-analyze-example-20261105.log`. `git diff --check`
passes. No build, browser, device, or performance action ran.

## Reviewed bytes and remaining gates

| File | SHA-256 |
| --- | --- |
| `lib/src/motion/text_shimmer.dart` | `a6a9158929e97598fe2a6f72af45f701ad7734842151ab5ab426760a045708ae` |
| `test/motion/text_shimmer_child_test.dart` | `5e188cc5e459eb601ae8c74761cd7462aa291f71f778edeb22cf70dd7d046358` |

The source and unchanged-before normal and reduced acquisitions predate this
implementation and remain immutable. After-runtime composition, visual and
elapsed-time motion evidence, native UI, full-family tests, exact-head hosted
checks, and root acceptance remain open. The files remain outside the approved
Select/sidebar local commit. No TextShimmer commit or push is claimed.
