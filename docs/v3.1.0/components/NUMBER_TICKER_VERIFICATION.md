# NumberTicker formatting verification

The approved additive formatter passes 28 focused widget tests and root and
example analysis on Flutter 3.44.4. This does not certify web, native, visual,
motion, performance, hosted checks, or the whole family. No commit is approved.

## Reviewed change

`BeuiNumberTicker` adds `decimals` and `formatNumber`. One internal pure helper
formats the readable text before the existing padding and digit splitting.
Legacy integer callbacks remain unchanged and ignore decimals. No chart,
DigitSwap, demo, controller, spring, timing, or in-view code changed.

```text
NumberTicker parameters
  pure formatter selects modern, legacy, or built-in contract
    existing padding
      unchanged glyph slots and readable semantics
```

The parent found and repaired three defects in the worker's first helper.
Fixed-decimal binary scaling used the wrong exponent sign. Integer-base
`math.pow` overflowed at large precisions. Whole-Uint64 extraction and shifts
were unsuitable for the web integer backend. Two Uint32 words now construct
the BigInt significand. This is a static portability repair, not executed web
proof. The locale formatter separately uses decimal formatting, signed zero,
grouping, and infinity symbols rather than applying toFixed's binary fraction.

A lightweight pure-Dart diagnostic compared outputs with independently
evaluated pinned-source expressions in Node. The initial 360-case probe found
190 mismatches. After repairs, 12,360 cases have zero mismatches. The expanded
set covers precision 0 through 100, unsupported precision, deterministic varied
values, near ties, signed zero, extremes, and non-finite numbers. This is a
diagnostic corpus, not an exhaustive proof or a web runtime test.

## Commands and receipts

```sh
/Users/codenameakshay/fvm/versions/3.44.4/bin/flutter test --no-pub --concurrency=1 test/motion/number_ticker_test.dart test/motion/number_ticker_source_parity_test.dart --reporter expanded
/Users/codenameakshay/fvm/versions/3.44.4/bin/flutter analyze --no-pub
```

The analysis command ran separately in the root and example directories.
Both package configurations resolve the pinned SDK. All tests ran with
concurrency 1. No existing goldens were skipped or regenerated.

The first focused run passed 27 tests and failed one newly added literal.
The expected grouping for value 1e21 at two decimals had omitted the source's
multiply-round-divide step. Node confirmed the rounded value is
999999999999999900000 and its locale output is
`999,999,999,999,999,900,000.00`. Correcting that test expectation required no
production change. The second run passed all 28 tests.

Durable artifact logs are in the task's `components` directory.

| Receipt | Result |
|---|---|
| `number-focused-20261105.log` | 27 pass, 1 new expectation failure. |
| `number-focused-corrected-20261105.log` | 28 pass. |
| `number-analyze-root-20261105.log` | No issues. |
| `number-analyze-example-20261105.log` | No issues. |
| `number-format-check.mjs` and `number-format-check.dart` | Retained source-reference diagnostic and runner. |

The public-widget tests assert negative tie rounding, binary boundary values,
fractional grouping, decimal-versus-binary high precision, formatter precedence,
legacy negative rounding, affixes and padding, precision 100, RangeError above
100, custom factor overflow, non-finite values, signed zero, and reduced-motion
target placement during live value and precision changes. Existing ticker
tests exercise normal motion and in-view behavior unchanged.

## Open gates

Actual web compilation and running-gallery verification remain required.
Native UI, exact-head before and after comparisons, full relevant tests, and
calibrated performance remain pending. The immutable original shared baseline
remains untouched. Source random demo values are still not matched data.

The reviewed file hashes for this receipt are:

| File | SHA256 |
|---|---|
| `lib/src/motion/number_ticker.dart` | `01f000ac107dd69a41804b2be185c04d0c44d450b934c11051018a99c7a906ff` |
| `lib/src/motion/_number_ticker_format.dart` | `cba2eae0a36b275908562368f60d89907311985686ba67c4b0cf34bedcaa29fc` |
| `test/motion/number_ticker_source_parity_test.dart` | `4008a37a66429dc9fa12b2bdddd7c3670a4fc2952cfcd13a9e8b9e3ad2aa5c4d` |
