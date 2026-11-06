# Number ticker formatting contract

This records the pinned `components/motion/number-ticker.tsx` formatting
behavior and the additive Flutter API approved for v3.1.0. The source formats
before splitting text into digit slots; prefix and suffix are outside that
formatted text, while left-padding is applied after formatting.

## Public formatter precedence

`BeuiNumberTicker` retains `String Function(int)? format` and adds
`int decimals = 0` plus `String Function(num roundedValue)? formatNumber`.
Resolution is:

1. `formatNumber` receives the source-rounded value and wins if both custom
   formatters are supplied.
2. Otherwise, legacy `format` receives the current Dart integer-round result;
   it retains its existing integer contract and ignores `decimals`.
3. Otherwise, built-in locale grouping or fixed-decimal formatting is used.

The chosen formatted string is then `padLeft(pad, '0')` when `pad` is set,
followed by the unchanged `prefix` and `suffix` in rendered/semantic text.

## Source rounding and precision

The new/default formatting path matches the source expression:

```text
places = max(0, floor(decimals))
factor = 10 ** places
rounded = Math.round(value * factor) / factor
```

Since the Dart API takes an integer, negative decimals clamp to zero; decimals
are not otherwise truncated. JavaScript `Math.round` ties toward positive
infinity, including negative ties. The source's fixed/default and locale APIs
accept fractional-digit precision through 100 and throw above 100. Do not clamp
or silently reduce precision. A custom `formatNumber` path does not invoke
either formatting API and can therefore be used above 100 (the rounding
formula itself still applies).

Literal reference outcomes from Node, using the source formula and default
fixed formatter:

| Input | Decimals | Rounded callback value | Default output |
|---:|---:|---:|---|
| `1.25` | `1` | `1.3` | `1.3` |
| `-1.25` | `1` | `-1.2` | `-1.2` |
| `2.5` | `0` | `3` | `3` |
| `-2.5` | `0` | `-2` | `-2` |
| `1.005` | `2` | `1` | `1.00` |
| `1` | `100` | `1` | `1.` followed by 100 zeroes |
| `NaN` | `0` | `NaN` | `NaN` |
| `Infinity` | `2` | `Infinity` | `Infinity` |
| `-Infinity` | `2` | `-Infinity` | `-Infinity` |

For `decimals: 101`, source `toFixed` throws `RangeError` and `toLocaleString`
throws `RangeError`; this is not an invitation to clamp. With a custom
formatter, the source still evaluates the rounding formula and invokes the
callback instead (for example, `value: 1.25`, `decimals: 101` supplies `1.25`).
Locale rendering of infinities is intentionally not pinned here: it is
runtime-locale-dependent (`∞` under the Node environment used for the reference
calculation), while the fixed path has the literal strings above.

The legacy formatter remains an integer-only compatibility path. Its existing
`int.round()` behavior is kept for all valid finite inputs, independent of
`decimals`; non-finite values have no valid Dart `int` representation and are
defined to throw `ArgumentError` on that legacy callback path.

## Test contract

`test/motion/number_ticker_source_parity_test.dart` is intentionally written
against the approved additive API and should compile only after its production
implementation lands. It asserts the literal strings/callback values above,
formatter precedence, affixes/padding, supported and unsupported precision,
non-finite defaults, reduced-motion snapping, and live value/decimal updates.
The original draft was contract-only. Source and unchanged-before normal and
reduced acquisitions now satisfy the baseline prerequisite for additive
formatting work. See [shared baseline evidence](SHARED_BASELINE_EVIDENCE.md).
This does not certify matching random data, after-runtime output, or motion.
