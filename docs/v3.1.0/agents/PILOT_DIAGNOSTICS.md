# Message Bubble offline diagnostics

These are source-before diagnostics, not source-after acceptance. The actual
configured Design Compare MCP processed the preserved Message Bubble recordings.
No live browser or new recording ran for these checks.

The exact calls were:

```sh
node /Users/codenameakshay/.t3/artifacts/beui-v3.1.0/coordination/mcp-call.mjs compare_designs @/Users/codenameakshay/.t3/artifacts/beui-v3.1.0/agents/pilot-message-defaults-2026-11-05/static-diagnostic-args.json
node /Users/codenameakshay/.t3/artifacts/beui-v3.1.0/coordination/mcp-call.mjs compare_motion @/Users/codenameakshay/.t3/artifacts/beui-v3.1.0/agents/pilot-message-defaults-2026-11-05/motion-diagnostic-args.json
```

## Inputs and provenance

The bulk root is the directory in `PILOT_MANIFEST.json`. It contains the exact
`static-diagnostic-args.json`, `motion-diagnostic-args.json`, their complete result
logs, and the derived `message-bubble-source-before-roi` directory.

The unchanged `tool/parity_capture_roi.mjs` selected 30 paired samples against
actual compositor timestamps. Crops are source `312:365:576:440` and Flutter
`485:317:576:440`. Flutter's measured origin has a half-pixel component, so the
integer crop introduces alignment uncertainty. Originals remain untouched.
The 100ms sample grid omits `-300,-200,500,2900,3100,3200` milliseconds.

The exact selection manifest SHA-256 is
`0c8ecb9ca582be8702188a56aaa57a46b4fc2dfe5cdbdf505bbed4fcbf3cc225`.
Static comparison uses its first pre-input pair, widget mode, dark-ui preset,
no ignored region, and that manifest hash as the caller-declared protocol key.
Motion comparison consumes all 30 paired crops. MCP's motion tool receives
images without timestamps. The external selection manifest retains timestamps
but does not remove the original cadence gaps.

## Actual static result

MCP returned `isError:false`, `stub:false`, diagnostics status `ok`, nonuniform
inputs, and full comparison scope. Its heuristic overall is 94.33. This is not
pixel equality, a percentage of parity, or a design acceptance threshold.
Widget mode applies no alignment correction.

The comparison key is
`2d975c51206060bb12a58a6a26aefba3d2505b592e4047f8acdcf197708ccaf8`.
The candidate-specific run key is
`77e7ad194c0a022007c4de39625492e4bfebdaf78b8fe8ef827c9c9095247a8c`.
The full log SHA-256 is
`54b765016dddb9ad83f256d16d59600598b0669955e726d239bdc1999ef2894c`.

The returned side-by-side was independently inspected. The Flutter assistant
bubble is wider and its text is centered, while the source bubble wraps its
content with left-aligned text. The source send control is blue and circular;
the Flutter control is gray and rounded-square. MCP separately reported a coarse
left-margin difference and missing reference color mass. Its color proxy does
not identify the affected pixels or prove a specific token mismatch. These
observations remain outside the approved defaults-only change.

## Actual sampled-motion result

MCP returned `motion_status:compared` for 30 frames per sequence. Its energy
similarity is 68.5 and frame-index correlation is approximately 0.920. These
describe sampled pixel change only. They do not measure trajectory, rhythm,
spring equivalence, elapsed duration, or performance.

Its explicit timing result is `inconclusive`, reason `cadence_unknown`, score
`null`, and `cadence_verified:false`. The external recorder also reports cadence
gaps. No timing or performance acceptance follows from this call.
The full log SHA-256 is
`b0b025da6eacdb1a666fc1da41e1b00cf79eb2c8133bba4326a6e0cfc74ab513`.

## Remaining acceptance

Source-after comparisons, defaults-specific app insertion proof, complete states,
reduced-motion captures, native behavior, stable font rendering, and performance
under controlled host load remain open. This pilot validates the acquisition and
diagnostic workflow while retaining demonstrated design differences.
