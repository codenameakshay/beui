# Shared chart helper repair

## Source-derived contracts

`components/charts/donut-chart/model.ts` describes a segment color as any CSS
color. The shared parser now handles CSS `#RGB`, `#RGBA`, `#RRGGBB`, and
`#RRGGBBAA`; legacy bare 3/6-digit hex; legacy bare 8-digit Flutter ARGB;
comma and space/slash `rgb[a]`; `hsl[a]` with degree, turn, grad, and radian
hues; the 148 CSS named colors; `transparent`; `currentColor`; and the chart's
existing ten `var(--token)` aliases. CSS-prefixed 8-digit hex is RGBA, while
bare 8-digit hex remains ARGB for compatibility with the original helper.
`currentColor` resolves to the chart foreground because this API has no DOM
inheritance context.

This pure Dart parser is not a browser CSS engine. It does not resolve arbitrary
`var()` fallback chains, `color()`/`color-mix()`, relative colors, OKLCH, or
other browser-context-dependent expressions; unsupported inputs use the
existing explicit fallback, then the primary theme color. The 148-name table
count was checked directly. No broader CSS-expression support is claimed.

Number formatting follows the explicit source options rather than treating a
maximum as a fixed precision. `maximumFractionDigits: 2` trims trailing zeroes;
`minimumFractionDigits: 2, maximumFractionDigits: 2` preserves fixed two-place
prices in Order Book. Decimal rounding uses the number's decimal/exponent text
and integer arithmetic, including carry, large/small exponents, and
negative-zero display. Compact
formatting preserves the helper's existing default of one fractional digit,
trims a zero fraction, promotes after rounding (`999.95` → `1K`, `999950` →
`1M`), and supports the source's trillion (`T`) suffix. Compact notation does
not use the helper's zero-valued non-compact default to erase its legacy
fractional digit.

## Literal source checks

An independent Node `Intl.NumberFormat('en-US', ...)` check established these
outputs before changing the tests:

| Options | Input | Output |
| --- | ---: | --- |
| maximum fraction digits 2 | `-0.004` | `-0` |
| compact, maximum fraction digits 1 | `999.9` | `999.9` |
| compact, maximum fraction digits 1 | `999.95` | `1K` |
| compact, maximum fraction digits 1 | `1,200` | `1.2K` |
| compact, maximum fraction digits 1 | `999,950` | `1M` |
| compact, maximum fraction digits 1 | `1,000,000,000,000` | `1T` |
| maximum fraction digits 2 | `1e21` | `1,000,000,000,000,000,000,000` |
| maximum fraction digits 2 | `-1e-8` | `-0` |
| compact, maximum fraction digits 1 | `1e21` | `1,000,000,000T` |

The shared contract test asserts these outcomes, the legacy hex semantics, CSS
alpha literals, aliases, fallbacks, fixed-vs-maximum fraction behavior, and
non-finite en-US outputs. Order Book's source formatter remains explicitly
fixed at two places; its existing sorted-table behavior is checked separately.

## Owner review and caller migration

The owner read the helper diff and source formatter defaults independently.
The repaired maximum precision already strips fractional zeroes. Four old
`replaceFirst(RegExp(r'\.?0+$'), '')` calls would then corrupt integer values,
including `100` becoming `1` and `120` becoming `12`.
Root explicitly approved removing only these four obsolete post-trims under
the cleared helper unit.

| Existing caller | Exact change |
| --- | --- |
| Sankey default value formatter | Remove one obsolete post-trim. |
| Candlestick default price formatter | Remove one obsolete post-trim. |
| Volume Profile default price formatter | Remove one obsolete post-trim. |
| Volume Profile default volume formatter | Remove one obsolete post-trim. |

Custom formatter branches, visual/state/motion code and other existing widget
behavior remain unchanged. Order Book is the separate approved minimum2
preservation. `_candleVolume` uses `r'\.0$'`, which requires a decimal point and
cannot remove bare integer zeroes; that call is unchanged.
Consumer-context regressions are in `formatter_consumers_test.dart`.
The seven tests assert real model/legend/slider/Order Book outcomes, including
`100`, `120`, `2`, `98.4`, grouping and negative zero. All seven passed on the
restored production code. The tests were written after the migration, so this
is not presented as a historical fail-first run.
The owner temporarily restored the four rejected post-trims for a labeled
mutation check. Five consumer tests failed and two passed. Removing the
mutation restored all seven passes. Pre/post file hashes match for all three
files; immutable source and before artifacts were never changed.
Receipts are `owner-obsolete-posttrim-mutation.log` and
`owner-consumers-restored-green.log` in the helper proof directory.

Owner verification on Flutter3.44.4 ran the30 shared-contract tests plus the6
Order Book tests with concurrency1. The result was35 passes and one unskipped
golden failure, not a green suite. The Order Book golden differs by357 pixels,
exactly the count in root's unchanged baseline run.
The actual generated PNG matches root's unchanged baseline PNG byte-for-byte
at SHA256 `c13506eca7d0644bd22256897125c9e71a6551ed595f4c5961d667635962098e`.
No golden was regenerated. The receipt is
`docs/proof/v3.1.0/charts/helper-tests/owner-shared-order-book.log`.
Owner scoped analysis of helpers and the four migrated widget files found no
issues. Its receipt is `owner-scoped-analyze.log` in the same directory.

The read-only Comment Sicko check reported zero comment findings, suppression
directives or dead paths. The owner accepted that result after reading the
comments and retained public API documentation and source-encoding rationale.
There were no comment deletions, restores, reruns, architecture changes or
constraint encodings. This does not certify UI fidelity or all CSS syntax.

## Numeric color boundary

Four independent public-parser tests reproduced huge decimal RGB, RGB-percent,
HSL-degree and HSL-turn inputs throwing `Infinity or NaN toInt` in `round` or
`floor`. The minimal fix rejects non-finite parsed components and converted
hues, and clamps RGB channels before integer conversion.
Malformed/non-finite components now retain the explicit fallback or theme
primary fallback. No CSS grammar was added.
The four failing originals are retained in `owner-color-boundaries-red.log`.
After the repair, all34 helper and seven consumer tests pass together in
`owner-boundary-consumers-green-r2.log`. The first expanded consumer run had
two test-only semantics-handle disposal failures; those logs are retained and
the handles are now disposed before each test ends.
One additional finite-overflow assertion covers a finite RGB percentage that
overflows during scaling and a finite hue that overflows during turn-to-degree
conversion. Its first combined run could not load the barrel while the active
Line worker was changing that new module. `owner-boundary-consumers-final.log`
retains that compile-time intermediate state. The stable-module rerun passed
all35 helper tests and seven consumer tests, including that extra assertion.
Its receipt is `owner-boundary-consumers-verified.log`.
The final limit-contract run adds unsupported browser-expression fallbacks and
passes36 helper tests plus seven consumer tests in
`owner-boundary-consumers-css-limit.log`. Seven-file scoped analysis reports
no issues in `owner-boundary-analyze-verified.log`.
Root independently read the finite guards, exact caller migrations and seven
consumer tests, then passed the same43 tests on Flutter3.44.4 with concurrency1.
Seven reviewed file hashes stayed unchanged across that run. The durable root
receipt is `coordination/charts-helper-root-review.log` with SHA256
`4fa548ccd2b9352d401011dd94813c158af855af36c464c2eecf91b576967da5`.
The reviewed `_shared.dart` SHA256 is
`bff6d6f11e95cb9cc0003daa7c1da69118f9386c1baacd3f2b0cc099874a9b56`.
This accepts the helper behavior only, not UI, native, performance or all CSS.

Arbitrary CSS expressions, relative OKLCH, `color()` and `color-mix()` remain
outside the shared parser's implemented subset. Existing Price Target and
Returns Calendar expressions require their chart-specific literal equivalents,
tracked separately in `expression-colors.md`. No any-CSS parity is claimed.
The public test pins both explicit and theme-primary fallbacks for OKLCH,
relative OKLCH, `color-mix()`, `color()` and `var()` fallback expressions.

## Verification record

Using Flutter/Dart 3.44.4/3.12.2 from `/Users/codenameakshay/fvm/versions/3.44.4/bin`:

- `dart format lib/src/charts/_shared.dart test/charts/shared_source_contract_test.dart` — clean after formatting.
- `flutter analyze lib/src/charts/_shared.dart test/charts/shared_source_contract_test.dart` — no issues.
- `flutter test --no-pub --concurrency 1 test/charts/shared_source_contract_test.dart --reporter expanded` — 30 tests passed.
- `flutter test --no-pub --concurrency 1 test/charts/order_book_test.dart --plain-name 'shows sorted order tables, midpoint spread and live depth summary' --reporter expanded` — passed; fixed `100.00` / `2.00` / `98.40` behavior remains intact.
- `flutter test --no-pub --concurrency 1 test/charts/finance_source_contract_test.dart --reporter expanded` — 8 tests reached, with the pre-existing Price Target default-label assertion failing at line 472 (`Price target · 12 months: mean $205.00, now $178.52` not found). That widget/test is outside this helper repair and remains unchanged.

Attempt logs are retained outside git under ignored
`docs/proof/v3.1.0/charts/helper-tests/` with unique timestamped names. These
focused checks do not certify other chart widgets, arbitrary browser CSS
expressions, motion fidelity, or visual parity.
