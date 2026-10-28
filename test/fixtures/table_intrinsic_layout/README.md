# Intrinsic table sizing prototype

This is an isolated opt-in design experiment. Nothing in production imports it;
`BeuiTable` retains its existing width/flex behavior. The resolver, adapter, native
HTML fixtures and deterministic tests are all test-only. No full-table parity
claim is made.

## Source and derivation

Pinned beUI checkout `/tmp/beui-v3-parity-components-source` was verified at
`a76e57c9bbc2837e96420b2610e9c82a3271bb05`.

- `components/motion/table/index.tsx:164-207,266-284`: initial table has
  `table-layout:fixed`, **no explicit width**, and
  `min-width:max(100%, <floor>px)`. Only a nonempty current data-column list whose
  every key has a resize override gets `width:max-content` (`w-max`). Absolute
  declarations do not satisfy that condition. The table floor is the rounded
  sum of checkbox 48 plus each override, else absolute px/rem declaration,
  else 64 (or max(64,120) for input-only columns). Caller-supplied resize minimum
  and measured root font size replace the defaults. This floor is not a minimum
  on each rendered column.
- `use-column-resize.ts:30-62`: freeze each current data header's measured width
  with JS Math.round, retaining previous overrides; pointer delta changes the
  frozen preference, clamped by the resize minimum. Checkbox is not frozen.
- `utils.ts:3-4`: checkbox declared preference is 48px. Actual checkbox intrinsic
  contribution is a measurement input, not a constant 24 or an offset correction.
- The source `1.4fr`/`1.8fr` values are invalid native `<col>` CSS widths. Chrome
  drops them. They therefore enter the auto branch, not weighted flex.

Allocation follows CSS Tables 3
<https://www.w3.org/TR/css-tables-3/#width-distribution-algorithm> and these
**Chrome-version-pinned** implementation sources:

- <https://github.com/chromium/chromium/blob/155.0.8059.86/third_party/blink/renderer/core/layout/table/table_layout_algorithm_types.cc#L260>
  `Column::Encompass` derives a constrained column's maximum from its preference
  and cell minimum, rather than its wrappable max-content. This prototype accepts
  the already aggregated outer min/max contributions of unconstrained cells.
- <https://github.com/chromium/chromium/blob/155.0.8059.86/third_party/blink/renderer/core/layout/table/table_layout_utils.cc#L461>
  `DistributeInlineSizeToComputedInlineSizeAuto` supplies the allocation phases.
- <https://github.com/chromium/chromium/blob/155.0.8059.86/third_party/blink/renderer/platform/geometry/layout_unit.h#L602>
  `MulDiv` truncates integer units. The distribution code puts any remainder on
  the last eligible column. Inputs here must already be multiples of 1/64 px.

For this subset, each column has a minimum `m` and maximum `M`. For absolute
preferences `p`, `M=max(m,p)`; for auto, `M` is measured max-content. The source's
width:auto target is max(viewport, table floor, sum of minima). Width:max-content
also includes the sum of maxima in this maximum.

1. Start at minima; content can overflow the viewport.
2. Grow absolute columns proportionally to `M-m`, leaving auto columns at minima.
3. Once absolute preferences are satisfied, grow auto columns proportionally to
   their `M-m`, up to max-content.
4. Above max-content, distribute surplus to auto columns proportional to `M`.
   Empty auto columns receive no share when another auto's `M` is positive.
   When all auto maxima are zero, split surplus equally. Thus the empty filler
   gets all leftover space when it is the only auto column, but does not always
   own leftover space despite the source comment. Without auto columns, this
   constrained table target distributes surplus to absolute columns by `M`.

The native fixtures vary viewport, declared widths, intrinsic contributions,
number of auto/fixed columns, and table floor. They exercise interior points and
boundaries of every phase. `<i>` boxes with explicit widths and `<wbr>` break
opportunities provide intrinsic contributions independently of fonts and of the
resolver. Each case retains its complete HTML and CSS. This is native browser
layout, not mocked geometry or a reproduction of the original demo.

## Verification

Browser oracle: installed Google Chrome **155.0.8059.86**, headless, viewport
1280x1000, device scale factor 1. `oracle.json` contains 22 measured cases,
computed table styles, accepted col styles, inputs, and exact outputs. `oracle.mjs`
uses the existing documented Playwright workflow from
[`beui-table-research.mjs`](https://github.com/codenameakshay/beui/blob/c0878f554a9b44799ad4b727f626980df941cd05/docs/proof/v3-parity/resume-20261023/table-followup/beui-table-research.mjs).
It requires `/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs`
and `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`.

```sh
node test/fixtures/table_intrinsic_layout/oracle.mjs
flutter test --no-pub test/motion/table_intrinsic_layout_prototype_test.dart
dart analyze test/motion/table_intrinsic_layout_prototype_test.dart test/fixtures/table_intrinsic_layout/resolver.dart
```

Local result: **29 tests passed**; targeted analysis of the two Dart files found
**no issues**. No broad suite was run.

Tests compare the allocator exactly to stored native results, not within a broad
pixel tolerance. Additional tests cover the source floor, freeze versus minimum,
all-current-column override lifecycle, source adapter, unsupported inputs and
unchanged historical observations. Re-running the oracle overwrites only these
new fixture artifacts. Review changes when testing a different Chrome version.

## Original observations retained separately

The two `original-*.json` files are byte-for-byte copies of existing evidence in
[`table-followup/`](https://github.com/codenameakshay/beui/tree/c0878f554a9b44799ad4b727f626980df941cd05/docs/proof/v3-parity/resume-20261023/table-followup):

- `beui-table-research.json`, SHA256
  `6e7a6231c6bb6c3c1cc8c402b4e1ce22aef0d009f046a50178783add65857d4d`.
- `resize-phases.json`, SHA256
  `bc87a06f757e8e9911dea0d64dc202867fb46518f29a99a99125a425c622a331`.

Original rest widths are checkbox 24, name 112.453125, email 177.5625,
role 103.40625, status 111.265625, mrr 105.25. Pointer down rounds the data
preferences, while actual name remains 112.453125 above override 112, checkbox
becomes 48, and email becomes 178. A +50 pointer delta makes name 162. The
original handle coordinates remain 491.453125, 515.453125, and 565.

Those rendered rest widths are **not** established min/max-content measurements
for all original columns. The generic allocator never imports these captures.
The fractional freeze unit test is a supplied-minimum example backed by a native
fixture, not a claim that all original table contributions have been extracted.

## Supported boundary and remaining work

Supported: non-spanning, visible columns with cells; horizontal native table
layout; positive absolute px/rem preferences or auto (including the two invalid
fr declarations); no cell width declarations; zero horizontal border spacing;
finite measured outer contributions already quantized to Chromium LayoutUnit.
The source adapter supplies an empty filler and accepts checkbox measurements.
It filters stale overrides and reserves internal checkbox/filler keys.

Unsupported: percentages, calc, other units, zero/negative preferences, captions,
colspan/rowspan constraint derivation, collapsed/mergeable columns, explicit
fixed table widths, separate border spacing, vertical writing, CSS cell width
constraints, and intrinsic measurement of text, flex headers, icons, inputs,
custom widgets or virtualized row samples. The API does not pretend to accept
these structures. Unsupported CSS strings, invalid contributions and missing
freeze measurements throw; callers must not manufacture guessed widths.

The source freeze hook falls back to minColumnWidth when measurement is absent.
This prototype intentionally rejects that case so it cannot pass with invented
measurements. The adapter models sizing, not drag pointer capture or min-clamping
of pointer movement. Production integration still needs a measurement contract,
cache invalidation for fonts/content/columns, and behavioral/browser/device proof.

## Real source content oracle added by parent

`beui-table-content-metrics-final.json` additionally measures the unmodified pinned data preview's currently mounted 20 rows, preserving its inherited font. Separate single-column clones determine min/max-content independently of the allocator. Actual native source rest, pointer-down freeze and +50 drag rectangles are recorded afterward, with the served source.js hash. All three phases match the generic resolver exactly in the new test. The complete suite now has 30 passing tests.

This fresh preview starts with its default MRR sort, unlike the older research capture after Name sorting. Its mounted Email content is wider. Its initial table width is 651.234375, freeze width 675.375, and dragged width 724.921875. This is a different labeled observation, not a correction to the old pixels.

The first clone probe omitted inherited table typography and overmeasured some columns. Its original script, log and JSON remain separately named. The corrected probe preserves the table font and letter spacing. This demonstrates why the upcoming Flutter measurement layer must preserve inherited typography and mounted-row selection. It does not prove that Flutter measurements equal browser glyph geometry.
