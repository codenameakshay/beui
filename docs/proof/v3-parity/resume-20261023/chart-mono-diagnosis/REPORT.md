# Candle and volume monospace diagnosis

Result: the historical substantial narrowing does not reproduce in the fresh current fixture or gallery. Its historical cause remains unresolved. Current actual paragraph advances agree with the named-font controls and with the gallery. Small DOM layout-width differences and a 0.26px baseline difference remain. No font replacement, alias change, tracking adjustment or offset is supported by this run. Exact raster parity fails.

## Scope and provenance

Read-only repository research on 2026-10-23. Observed checkout HEAD at input copy was `c8843c31a95e3ef1aea23967ddd6e91a30caad93`. Concurrent parent work means this is an observation, not a claim that every copied byte represents an atomic commit snapshot. `inputs.json` hashes the copied production and gallery Dart inputs and font assets. `final-inputs.json` hashes the final diagnostic fixture, dependency lockfile, served build, manifest and source bundle. Only new `/tmp` files were written. No git mutations, children, broad tests, goldens or existing evidence changes. Parent ports 18141, 18143 and 18144 were not used or stopped.

Read section 2 of the next-obligations note, round-four candle/volume README and fixture, fonts README, real-font typography test, and the archived Table raster diagnosis. The repaired NumberTicker width was not investigated or changed. The Table sans raster explanation was not used to explain mono advances.

Pinned source remains `a76e57c9bbc2837e96420b2610e9c82a3271bb05`. The reused round-four source bundle has actual served JS SHA-256 `91efa14dca91279a59255519b75086c5b8f37d16eff82f5aa2c425c21253f77e`. All 23 pinned-checkout input files in the archived source-input manifest match their current hashes, recorded in `pinned-source-validation.json`. Its wrapper and package lock remain in `source/`. This local fixture uses static TTFs, not the live site's variable WOFF2s; no live deployment identity is claimed.

Final diagnostic JS SHA-256 is `bd86693eba12b21a89a65872142c7551d55b08cb3d289bfe3c2238372f99f749`. This single fresh build runs the standalone charts, a small text matrix, and the actual `BeuiExplorerApp` gallery, selected by query parameters. The diagnostic fixture is a regular Dart file at `repo/example/lib/mono_fixture.dart`. Production files are unchanged copies. Instrumentation traverses actual `RenderParagraph`s and reports their widths, effective styles, scaling, top coordinates and alphabetic baselines. It also lays out the same span in `TextPainter` to obtain unconstrained advance and line metrics. In the sampled labels, actual paragraph width equals that advance.

Builds ran in the copied `/tmp` example directory with Flutter 3.47.1/Dart 3.13.1. Build logs are retained. The earlier builds are retained separately; the final capture uses `candidate-exact`. The only post-build HTML change sets the base href to `/candidate-exact/` for subdirectory serving. No parent build output changed.

Chrome is HeadlessChrome/156.0.0.0 using `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` and `/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs`. Fresh isolated contexts use 1280x1000 CSS pixels, DPR 1, light theme, reduced motion, text scale 1. The dedicated server uses only port 18148. Browser contexts are closed by each script.

## Font loading and selection

`source-measurements.json` records actual source DOM text ranges, computed styles, zero-size inline-marker baselines, CDP selected fonts, and response hashes. Screenshots precede insertion of baseline markers. Source candle labels select custom `GeistMono-Regular`; volume summary values select custom `GeistMono-Medium`. Styles are 12px, weight 400 or 500, 16px line height, normal tracking.

`candidate-measurements.json` records actual paragraphs after app initialization, network idle, `document.fonts.ready` and an additional 1500ms. Font responses are HTTP 200. Flutter CanvasKit does not register these fonts in browser FontFaceSet: the candidate's empty `document.fonts` list is therefore NOT evidence of CanvasKit font readiness by itself. Readiness/selection evidence comes from successful font responses, initialized actual paragraphs and their agreement with both explicit named-font and alias controls. CanvasKit's resolved native typeface object is not directly exposed by this diagnostic. Do not describe its configured family string alone as a direct native-typeface query.

Both source and candidate serve exactly the same bytes:

- Regular: 71,160 bytes, SHA-256 `7022da390e9b401ea35b722f8ed2376948e70add10954bc798839b4bfe17ef3f`.
- Medium: 71,212 bytes, SHA-256 `5c1b7b77c2d6132460f03b60c175adc80da1ebd0b418c785135b1aed27a28b30`.

Both are Geist Mono 1.701, 1000 units/em, zero advance 600 units, hhea 1005/-295/0. The final FontManifest hash is `94709ae500d3812d4e346edadad1c08c8e845b1f7d00dceef94f2bee2c322c1d`, also the historically reported manifest. `Geist Mono` and `monospace` point at identical regular/medium files. See `font-metadata.json`, final manifest and response records.

The exact-string matrix uses both names at weights 400 and 500, size 12, height 16/12, tracking 0 and tabular figures, under the same gallery theme as actual charts. `iiiiiiiiii` and `WWWWWWWWWW` both measure 72.00057983398438px for both names and both weights. Sans negative controls differ materially: regular narrow letters measure 27.120193481445312px and wide letters 112.32077026367188px. Actual chart labels match the mono controls, not those sans controls.

The DOM control named `monospace` deliberately uses the CSS generic keyword. It is a negative control and is NOT equivalent to Flutter's registered asset alias. Source comparison uses explicit `Geist Mono`.

## Actual advances and baselines

All values are CSS/logical pixels. The final exact-string matrix, actual standalone charts and actual gallery are from the same served JavaScript.

| String | Source DOM range | Source Canvas2D advance | Actual Flutter paragraph | Actual gallery paragraph |
| --- | ---: | ---: | ---: | ---: |
| `15:55` | 36 | 35.9999847412 | 36.0002899170 | 36.0002899170 |
| `2,360.34` | 57.609375 | 57.5999755859 | 57.6004638672 | 57.6004638672 |
| `Vol` | 21.609375 | 21.5999908447 | 21.6001739502 | 21.6001739502 |
| `+0.34%` | 43.21875 | 43.1999816895 | 43.2003479004 | Different live demo value |
| `2,271 BTC` | 64.8125 | 64.7999725342 | 64.8005218506 | 64.8005218506 |
| `$65,050` | 50.40625 | 50.3999786377 | 50.4004058838 | 50.4004058838 |

Every listed Flutter value exactly equals the corresponding named `Geist Mono` and `monospace` matrix control at the same weight. `comparison.json` retains full precision. The largest source DOM minus candidate width in this selected set is 0.0184020996px. Source Canvas2D and Flutter advances differ by less than 0.00055px in this set. Thus the DOM box discrepancy is much larger than the advance discrepancy but still below 0.019px for these labels. The DOM control's `+0.34%` range is 43.203125px while the actual source component's range is 43.21875px. Do not collapse DOM ranges, individual text-run rounding and glyph advances into one measurement. The small differences are consistent with subpixel layout/run quantization; this experiment does not identify a universal browser rounding rule.

The gallery candle demo updates over time. Its last close, volume and percentage differed from the fixed fixture during final capture. Comparisons use unchanged exact strings such as open price and time; no value/whole-gallery state parity claim follows. The percentage row is explicitly not matched to a gallery value. Gallery volume summary strings do match.

For actual candle labels, source top is 348 and baseline is 360. Flutter top is 348 and baseline is 360.2600002289. For volume summary, source top is 694.5 and baseline is 706.5; Flutter top is 694.5 and baseline is 706.7600002289. Source internal baseline is 12px, Flutter is 12.2600002289px. These measurements come from layout APIs/markers, not fitting ink bounds. No offset correction is proposed.

## Untouched raster evidence

Full page PNGs are unmodified captures. `source-candle-raw-crop.png` and `candidate-candle-raw-crop.png` use identical integer rectangle [348,344,932,368]. Volume crops use [348,690,932,714]. They contain the original native RGB at those coordinates, without alignment, scale, recoloring, interpolation or exclusion masks.

The candle crop has 2079 differing RGB pixels out of 14016. The volume crop has 1256 out of 14016. See `crop-metrics.json`. These are nonzero exact-raster failures. Near-matching advances do not establish pixel equality, and this run does not assign every raster difference to the baseline measurement.

## Bounded conclusion and next discriminator

The current substantial narrow-label symptom is not reproduced. Actual chart paragraphs and gallery paragraphs resolve to the same measured mono behavior as named-font controls, using verified identical font bytes. No current alias/loading defect is demonstrated. Historical v13 still lacks actual paragraph metrics and resolved-font evidence from that historical execution, so this run cannot establish why it looked narrower than v6 or whether its captured execution loaded a different effective face. Identical manifests alone never answered that question.

The smallest additional historical investigation would instrument an isolated recreation of the exact v13 production/fixture inputs and record its actual paragraph advances plus load responses before comparing it to this current capture. That was not performed here. Do not change current fonts, typography or offsets based on the old screenshot. No exact-parity, broad-test, native60, CI, push, deployment or merge claim is made.

## Reproduction and retained failures

Start a new server on free port 18148 serving this directory, then use the retained scripts. To preserve evidence, copy the artifacts/scripts to a new output directory and change their explicit output prefix before rerunning.

```sh
python3 -m http.server 18148 --bind 127.0.0.1 --directory /tmp/beui-mono-research-20261023
node /tmp/beui-mono-research-20261023/inspect-exact.mjs source
node /tmp/beui-mono-research-20261023/inspect-exact.mjs candidate
node /tmp/beui-mono-research-20261023/controls.mjs
python3 /tmp/beui-mono-research-20261023/summarize.py
```

Rebuild from `repo/example` using `flutter build web --release --no-wasm-dry-run --target lib/mono_fixture.dart --output <new-output>`, with the correct base href for the serving path. Initial copy/setup is retained in `/tmp/beui-mono-setup-20261023.py`; the final regular-file fixture is the authoritative diagnostic input, including the later gallery branch and exact strings.

The first source capture served the original absolute font URLs under the wrong directory, causing HTTP 404 and Times fallback. `failed-font-path-*` preserves that invalid run. Root-level font copies corrected the isolated server layout without editing source CSS or production. Only the subsequent source capture with CDP-confirmed custom faces is used above. Earlier candidate captures used illustrative strings in two matrix rows; `pre-exact-*` retains them. Final `candidate-*` captures use the exact strings. The first summary script assumed the gallery percentage remained fixed and stopped on its changed value; the corrected script records that gallery comparison as null. None of these instrumentation errors is an application regression.
