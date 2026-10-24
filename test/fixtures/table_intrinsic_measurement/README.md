# Test-only intrinsic measurement experiment

`IntrinsicMeasurement` takes column keys and a bounded list of passive header,
mounted-row and overscan-cell copies. The caller selects the sample; this widget
never walks a data source. The default budget is 96 cells, including headers.
Over-budget input rejects the entire sample before mounting it.

During layout the parent queries each probe's real RenderBox min/max intrinsic
width at infinite height, lays out the probes to clear dirtiness, aggregates the
outer widths by column, and rounds upward to 1/64 px for the existing resolver.
The final content builder receives those metrics before its first real layout.
The tests feed them to `resolveSourceTable` and a real Flutter `Table`.

A stock LayoutBuilder is insufficient for render-only metric invalidation at
unchanged constraints. This experiment uses AbstractLayoutBuilder with
(constraints, result identity) layout information. The parent invalidates its
content child inside invokeLayoutCallback, Flutter's permitted layout mutation
scope. It uses no setState, post-frame callback, or guessed first-frame widths.

Only exact Text (plain string), Padding, SizedBox, DecoratedBox, Row, Column,
Flex, Flexible and Expanded widget types are accepted recursively. Build badges
from those primitives. Unknown widgets, custom subclasses, rich spans,
LayoutBuilder, scroll viewports, controls, and GlobalKeys reject before mounting.
An editor uses CellSample.explicit with caller-owned outer min/max widths; its
actual editable widget is built only in content. Explicit values must be finite,
nonnegative, and ordered. Missing columns also reject. A failed result has no
columns; the content builder must inspect supported/error before resolving.

Only the final content child paints, participates in hit tests, and contributes
semantics. Probe copies have focus excluded and cannot contain active controls.
They still occupy elements/render objects and are laid out, so their cost is
bounded by the supplied sample and widget-tree complexity, not the total row
count. Intrinsic flex computations can be costly within a single sample.

Content/style/text-scale/environment rebuilds remeasure; changing the sample
removes old contributions. RenderParagraph metric invalidation also propagates
without rebuilding the parent widget. Callers can change revision when external
font loading or an explicit width contract changes. The tests simulate a render
metric change directly; they do not load an actual font asset asynchronously.

Limits for parent review:

- Sampling is not a proof of the widest unseen row. Widths may shrink or grow as
  mounted/overscan rows change. Retention policy belongs to the parent.
- This does not infer padding, icons, or decoration from unsupported controls.
  Explicit contracts must include their outer contributions and be invalidated
  by their owner.
- Flutter intrinsic widths are not browser typography parity. Quantization is a
  conservative adapter, not a claim about Chromium glyph measurement.
- The viewport must have bounded width. This wrapper does not implement intrinsic
  or dry measurement for an ancestor asking to size the entire prototype.
- The allowlist is intentionally narrow. No arbitrary builder is executed to
  discover whether it is safe. Passing malformed flex parent data remains a
  caller error under Flutter's normal widget contracts.
- Instrumentation counts top-level intrinsic queries, not recursive calls. The
  mutable trace is test-only and retains event history.

Run only:

```
flutter test --no-pub test/motion/table_intrinsic_measurement_test.dart
dart analyze test/fixtures/table_intrinsic_measurement/prototype.dart test/motion/table_intrinsic_measurement_test.dart
```

## Promotion review

This file and prototype.dart preserve the original experiment. Independent
review demonstrated selection leakage, malformed flex acceptance and oversized
numeric conversion failures in that prototype. It is not the shipping path.
Production corrections are in lib/src/motion/table/intrinsic_measurement.dart;
the current measurement tests import that implementation. The production path
excludes SelectionContainer, validates flex parent structure and probe
constraints, bounds width conversion, and contains no retained tracing history.
See lib/src/motion/table/INTRINSIC_SIZING.md for the supported opt-in contract.
