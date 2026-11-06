# ThinkingShimmer child API

## API mapping

The source `ThinkingShimmer` accepts optional React children, defaults its
message to `Thinking…`, applies medium text weight, and uses a 1.8-second
shimmer period. The additive Flutter constructor preserves the existing
unnamed string API and adds one widget child:

```dart
const BeuiThinkingShimmer(text: 'Thinking…');
const BeuiThinkingShimmer.child(Text('Thinking…'));
```

The string constructor retains its non-nullable `String text`, defaults,
ambient style selection, and forced `FontWeight.w500`. The child constructor
stores one private nullable `Widget`, sets the compatibility `text` value to
`''`, and delegates to `BeuiTextShimmer.child`. It fills an unspecified style
weight with medium. An explicit style weight and descendant text styles keep
normal Flutter precedence.

```text
BeuiThinkingShimmer (StatelessWidget)
├── string path → BeuiTextShimmer(String)
└── child path  → BeuiTextShimmer.child(Widget)
                   └── existing controller, shader, and repaint boundary
```

There is no Agents-owned ticker, mask, repaint boundary, layout wrapper,
semantics node, focus node, or interaction handler. The child retains
ownership of its layout, semantics, focus, and callbacks.

`ShaderMask` applies the gradient to all painted alpha. It colors non-text
paint too, so mixed-content children are not certified as equivalent to the
source's text-only CSS clipping. The source's reduced-motion behavior and the
existing Flutter centered-highlight behavior also remain different. This
change does not retune either behavior.

## Owner verification

`test/motion/thinking_shimmer_source_api_test.dart` uses the package's public
barrel. It covers:

- Const legacy and child constructor values, public `String` assignment,
  defaults, custom duration/style/key, and forced legacy medium weight.
- Child compatibility text, rich spans, inherited style/alignment, and
  explicit descendant style precedence.
- Narrow RTL text constraints, retained single semantics label, pointer
  activation, actual Tab focus followed by Enter, keyed replacement, and
  string-child-string updates.
- Duration forwarding, reduced-motion updates, unmount during an active sweep,
  and the delegated single mask/repaint boundary.
- Shared-engine raster comparison at identical 200×24 bounds and one-quarter
  phase. Each sample unmounts before the next mount. The test checks the
  literal grayscale samples `[253, 133, 13, 0]` as well as equality between
  the wrapper and direct `BeuiTextShimmer.child` samples.

The owner reviewed the complete production diff and all 18 new tests. The
corrected run passes all 56 tests across the new Thinking suite, the existing
23 loading-state tests, and the 15 shared TextShimmer tests. No tests or
goldens were skipped or regenerated. The child API's missing baseline
is a static compile gap only. No historical red test was run or inferred.
Duration forwarding does not prove a changed full-period timing measurement.
The local shader comparison is not source-browser fidelity evidence. The small
RTL and bounds check is not broad layout parity.

The first run passed 54 tests and failed two new fixture checks. One read
`RichText.textDirection`, which is null when direction is inherited. The
corrected assertion reads the resolved `RenderParagraph.textDirection` and
expects RTL. The other disposed a semantics handle in `addTearDown`, after
Flutter's end-of-test handle check. A test-body `try/finally` now disposes it.
The semantics action already reached the child's callback. Neither failure
required a production change. Both original and corrected logs are retained.

## Baseline and remaining proof

The accepted unchanged-before packet is
`/Users/codenameakshay/.t3/artifacts/beui-v3.1.0/agents/thinking-passive-before-20887a60`.
Its 550 original frames were receipt-checked. Three videos decode to 268, 269,
and 12 frames. The reduced-motion attempt retained one original frame and
failed with `No usable compositor timestamps`; it has no video.

The root review clears this isolated API addition only. It does not establish
source visual parity, matched crop or phase, effective font identity, reduced
motion temporal stability, touch behavior, performance, native behavior, or
all-state coverage. After-runtime acquisition and phase alignment remain open.

## Commands and retained evidence

The owner ran these commands serially on the pinned SDK after whole-diff review:

```sh
/Users/codenameakshay/fvm/versions/3.44.4/bin/flutter test --no-pub --concurrency=1 --reporter=expanded test/motion/thinking_shimmer_source_api_test.dart test/motion/loading_states_test.dart test/motion/text_shimmer_child_test.dart test/motion/text_shimmer_test.dart
/Users/codenameakshay/fvm/versions/3.44.4/bin/flutter analyze --no-pub
# The same analysis command ran from example/ after root analysis finished.
/Users/codenameakshay/fvm/versions/3.44.4/bin/dart format --output=none --set-exit-if-changed lib/src/motion/loading_states.dart test/motion/thinking_shimmer_source_api_test.dart
git diff --check
```

The pinned SDK is Flutter 3.44.4 with Dart 3.12.2. Dependencies were already
installed. Corrected tests, root analysis, example analysis, format checking,
and diff checking all exit 0. Both analyses report no issues.

Logs and the reproducible owner receipt are in
`/Users/codenameakshay/.t3/artifacts/beui-v3.1.0/agents/thinking-implementation-d7f828a4`:

- `focused-tests-initial.log` retains the 54-pass, two-fixture-failure run.
- `focused-tests-rerun.log` retains the 56-pass corrected run.
- `analyze-root.log` and `analyze-example.log` retain both clean analyses.
- `owner-review.json` pins the reviewed files, protected bytes, and log hashes.
- `check-owner-review.mjs` rechecks those pins without changing files.

The test slot was checked for other beUI test processes before the run.
Unrelated SplitFast stable-SDK tests were present and left untouched. No timing
or performance conclusion is drawn under that contention.

The dependency remains the exact four-file accepted TextShimmer cherry-pick at
`d7f828a4cb2700e63495b11948e0c8241f3419ee`. Only the Thinking class in
`loading_states.dart` changes. Imports, progress/reasoning code, and the
canonical demo remain byte-identical to HEAD. The 22 preexisting untracked
audit files remain unchanged. The new feature is uncommitted. No dependency
resolution, build, browser, device, capture, or performance work ran during
this verification. A feature commit, push, and PR remain unapproved.
