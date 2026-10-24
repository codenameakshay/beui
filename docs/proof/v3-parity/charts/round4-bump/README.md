# Bump chart round-four evidence

The source rank/change legend and chart-owned native keyboard behavior are implemented. This is an owned implementation handoff, not exact parity certification. Every final static and interaction image comparison has a nonzero difference. The unchanged widget golden also fails.

[Open the labeled before/source/after proof](proof.html). [Read the measured results](measurements.json). The final implementation is `1214692666e297c5734bfdeb13a39e8b67554c49` on `t3/bump-chart-round4-parity`.

## Scope and source identity

The parent is [PR26](https://github.com/codenameakshay/beui/pull/26). The starting commit is `a2942181a755503a25571ca3150a16acc284d29b`. No push, PR edit, or merge occurs in this task.

The source checkout is `/tmp/beui-charts-reference-20261023` at `a76e57c9bbc2837e96420b2610e9c82a3271bb05`. Its worktree remains clean. A live beui.dev deployment has no verified deployment SHA. The pinned checkout and the live deployment are distinct inputs.

The audit entry is `charts/bump-chart` in `../../audit/inventory.json`. Its source entrypoint is `components/charts/bump-chart.tsx`, with `components/previews/charts/bump-chart.preview.tsx` as the preview. The round-three README names the rank/change legend and complete source keyboard behavior as unresolved bump work. This round addresses those named implementation differences.

Owned production files are `lib/src/charts/bump_chart.dart` and `example/lib/demos/bump_chart_demo.dart`. Dedicated tests and the consumer fixture are `test/charts/bump_chart_test.dart`, `bump_source_parity_test.dart`, and `bump_parity_fixture.dart`. All new proof is under this directory. No other chart, shared Tooltip, recorder, font, or theme implementation changes.

Only `127.0.0.1:18115` serves this task, after an availability check. `serve.mjs` maps separate before, source, and after directories. It changes only the generated HTML base href. JavaScript response bytes remain unchanged.

## Source correspondence

Paths in the source column are under `components/charts/bump-chart/`, except the preview path.

| Owned behavior | Source | Final implementation |
| --- | --- | --- |
| Legend layout | `legend.tsx` | Three columns at viewport widths of at least 640px. Two columns below 640px. Column gaps are 20px, row gaps are 4px, and each row is 36px. Each row has the swatch, name, final rank, and signed change. |
| Pin and highlight | `context.ts`, `legend.tsx`, `point.tsx` | Hover, focus, and pin have separate ownership. Legend opacity is 0.35 for other series. Plot opacity is 0.22. Selected legend fill is muted at 0.6. |
| Native traversal | `plot.tsx`, `point.tsx`, `legend.tsx` | One labeled plot Tab stop, then row-major existing dots, then legend buttons. Mouse click acquires the target's focus. Tab changes actual native focus without pinning. |
| Button keys | `point.tsx`, `legend.tsx` | Enter activates on key-down and repeats. Space activates on key-up. Escape clears pin, hover, focus highlight, and readout without moving native focus. Another arbitrary key does not reopen a dismissed readout. |
| Plot scrolling | `plot.tsx` | The plot scrolls with native keyboard commands and trusted touch pan. Dot or legend arrows, Home, and End do not invent series selection. |
| Readouts | `point.tsx` | Exact rank and previous-period values remain static. Content keeps its intrinsic width and the source minimum total width. Mouse click dismisses. Touch toggles the readout. Focus at a new dot reopens it. |
| Stable identities | `model.ts`, `context.ts`, `use-geometry.ts` | Duplicate IDs use the first row. Palette indexing follows deduplicated rows. Nonpositive and unsafe-integer ranks are missing. Unknown initial pins and removed uncontrolled pins do not revive later. |
| Plot geometry | `model.ts`, `plot.tsx`, `series.tsx` | Source minimum width, scaled dashed grid stroke, label placement, final-label hover, and primary-focus-only plot ring. |
| Effective dot border | `point.tsx` and actual Chromium computed style | Source CSS requests 1.5px. Chromium reports 1px at DPR 1, 1.25, and 2 in this environment. The final dot uses that measured 1px width. |
| Demo | `components/previews/charts/bump-chart.preview.tsx` | Matching header, subtitle, shuffle icon and label, rank data, accessible label, footer, wrapping header, and full-width chart layout. Shuffle keeps one product per rank in each period. Random draws are not claimed identical. |

The source Tooltip surface itself uses `font-medium`. The bump readout inherits that weight in both implementations. A screenshot's apparent weight is not evidence that the source uses regular weight.

The exact source HTML `aria-pressed` metadata is not reproduced by Flutter. The chart preserves button roles with Flutter selected semantics, which the engine exposes as `aria-current`. `Semantics.toggled` was rejected because it changed the native roles to switches. This remaining shared-adapter requirement is not hidden by normalizing selected state in the input checks.

## Matching examples

`source.tsx` imports the untouched pinned source components. `bump_parity_fixture.dart` calls the candidate public widgets with the same data. These are matching source consumer fixtures, not six separately published website examples.

| Variant | Matching source and candidate inputs |
| --- | --- |
| Default | Five preview series, April through September, a 592px host, default plot and legend. |
| Composed | The same inputs with explicit plot and legend children. Source default and explicit composition have identical final PNGs. |
| Narrow | A 320px host inside a 390px viewport. The plot retains its 560px minimum width. The legend uses two columns. |
| Empty | An empty series list. The empty plot and default composition spacing remain visible. |
| Missing | Five series with empty rank lists. The empty plot remains above the surviving rank/change legend. |
| Update | A native U key reverses each six-period rank list in both consumer fixtures. This deterministic replacement compares final geometry and legend values. It does not substitute for identical random shuffle output. |

All six variants have dark and light native PNGs in `static-source-v1/` and `static-after-v12/`. These final source static captures use the corrected, separately identified Geist font responses. `observations.json` retains script and font-response hashes, actual host rectangles, and effective motion preferences. Candidate static pages report no page errors.

Default and composed source host height is 349.703125px. Candidate height is 349.7142857142857px. Narrow height is 376px in both. Empty height is 168px in both. Missing height is 244px in both. The fractional wide-host geometry difference remains measurable.

## Actual served builds and fonts

| Build | Revision | Served script SHA-256 |
| --- | --- | --- |
| Before | `a2942181`, with the dedicated fixture | `1704dea5dea098fef3e857460f772910595ef6e2d9a50ad3ab5b29887315de4a` |
| Pinned source consumer fixture | `a76e57c9`, with the consumer wrapper | `bf1b0cfeebefd63c437afc0fed0346c8e0ea87faa06b5781036831b7383f7aab` |
| Final after, v12 | `1214692666e297c5734bfdeb13a39e8b67554c49` | `9060bcdad8840e849340956361c6acd047b4eaed968a0ee1baa7d12a919cdc3b` |

V12 compilation began with the border repair in the working tree. That exact component file was committed during compilation. No intervening component edits occurred. The final recordings verify the actual served response before their first frame. `build-inputs-v12.json` records the unchanged shared dependency hashes and candidate inputs. `source-inputs.json` contains every esbuild transitive source input hash. `source-package-lock.json` pins its runtime dependencies.

The source's Next font build output is not present as a pinned repository font artifact. `source-fonts/manifest.json` identifies the live Latin Geist and Geist Mono responses, their URLs, byte counts, and SHA-256 hashes. Their deployment SHA is unknown. Those font files and their license are archived here. The candidate retains the parent's existing font assets unchanged. No font equivalence claim follows from their family names.

## Native input and motion proof

The collaborative browser was attempted first. Two snapshot calls failed with the raw error `Preview automation snapshot timed out after 15000ms.` The documented `tool/parity_capture.mjs` fallback then recorded actual Chrome output. The shared recorder is unchanged.

`interactions-source-v3/` and `interactions-after-v12b/` each pass 38 native keyboard and trusted-touch states. `mouse-source-v1/` and `mouse-after-v12/` each pass 16 mouse/handoff states. `narrow-source-v1/` and `narrow-after-v12/` each pass four narrow keyboard/touch-pan checks. Both motion preferences run in these checks. Native screenshots and trusted event logs accompany the keyboard/touch states.

`repeat-source-v2/` and `repeat-after-v2/` each pass 28 additional native held-key states. Both dot and legend controls activate on initial Enter and repeated Enter, but not Enter key-up. Space activates only on key-up. Escape clears selection, and Home does not restore it. The event logs prove trusted Enter key-down events with `repeat=true` in both preferences. `repeat-summary.json` verifies the served source and candidate hashes. These 28 states bring the observed native input count to 86 per implementation.

The long 28-Tab traversal in the accepted interaction sequence uses a 60ms pause after each native key press in both source and candidate. `interactions-after-v12/` retains a real failure from the earlier unpaced burst. Browser focus reached the body instead of Highlight Studio. Earlier v8 and v11 burst runs passed. The cadence change does not repair or waive that intermittent mismatch. Its cause is not established as chart-only or engine-only. The parent needs a native semantics/focus synchronization investigation before certifying rapid key behavior.

Final matching native recordings are below. Each row includes both `no-preference` and `reduce` directories.

| Input | Pinned source | Final candidate |
| --- | --- | --- |
| Mouse click, pointer exit, Tab, Home, Enter, Space, Escape, rank replacement | `captures/source-*-v3/` | `captures/after-*-v12/` |
| Three trusted taps, select, clear, select | `captures/source-*-touch-v3/` | `captures/after-*-touch-v12/` |
| Earlier before implementation | `captures/before-no-preference-v2/`, `captures/before-reduce/` | Not a source reference. |

Every complete recording retains native `capture.mp4`, original PNG frames, frame hashes, actual `timeline.json`, `scripts.json`, `environment.json`, `config.json`, `ffprobe.json`, and action captions. Touch recordings also retain `observed-touch.json`, with trusted pointer-down/up/click events, `maxTouchPoints=1`, and no hover capability. There is no direct focus injection or programmatic semantics activation in the input sequence. The Flutter semantics placeholder is enabled before traversal.

The requested browser viewport is 800x600 at DPR 1. Native recorded output is 800x513. Static and interaction PNGs are 800x600, except the 390x600 narrow pages. No original is resized, interpolated, registered, or replaced. Display sizing in the HTML proof does not change those files.

Actual cadence is in each timeline and `measurements.json`. The final reduced-touch recording has only 18.45fps and a 367.58ms maximum interval. Native 60fps trajectories, short springs, and exact interruption timing remain inconclusive. Video existence, normalized state agreement, and a correct bundle hash do not certify motion parity.

## Exact pixel failures

`pixel-diff.mjs` decodes native PNGs to RGBA with ffmpeg. It compares matching dimensions without resizing, translation, or registration. The pass threshold is zero different pixels. The metrics also retain channel error and region counts. All comparisons below fail exact parity.

| Variant | Dark differing pixels | Light differing pixels |
| --- | --- | --- |
| Default | 9,706 | 10,676 |
| Composed | 9,706 | 10,676 |
| Narrow | 6,086 | 6,016 |
| Empty | 554 | 515 |
| Missing | 1,853 | 1,781 |
| Update | 9,429 | 10,722 |

Dark default before had 12,559 differing pixels. Its legend had 3,099. The final default has 9,706 total and 1,800 in the legend. Matching the effective source dot border reduced the preceding v11 result by 1,129 pixels. This is measured progress, not a pass.

The eight matched readout, pin, and touch PNGs have 13,237 to 15,155 different pixels. Exact values and absolute-difference PNGs are under `diff-interactions-v12b/`. Remaining visible differences include text rasterization, subpixel geometry, curve rasterization, and tooltip pixels. Their causes are not all assigned to a shared renderer.

## Exact local gates

| Gate | Result and evidence |
| --- | --- |
| Focused behavior | 21 pass. `tests-final-v12.log`. Command is `BEUI_SKIP_GOLDENS=1 flutter test test/charts/bump_chart_test.dart test/charts/bump_source_parity_test.dart --reporter expanded`. |
| Analyzer | No issues across the five owned Dart files. `analyze-final-v12.log`. |
| Release web build | Succeeds in 20.8 seconds. `build-after-v12.log`. Existing missing Cupertino icon-font warning remains. |
| Full focused suite with original golden enabled | 20 pass, one failure. `tests-full-golden-v12.log`. The unchanged bump golden differs at 169,220 pixels, 3.92%. |
| Effective source border | Three browser observations pass at DPR 1, 1.25, and 2. `source-border-metrics-v2.json`. |
| Native source and candidate inputs | 38 paced keyboard/touch, 16 mouse, and four narrow states per implementation. `report-v12.log`. Rapid burst failure remains separate. |
| Native repeated Enter and Space key-up | 28 additional states pass per implementation. `repeat-summary.json` and `final-checks.log`. |
| Source-matched static images | Twelve captures have the expected effective reduced motion and final served script hash. All twelve exact comparisons fail. |
| Original evidence | All 52 original artifacts match `../BEFORE.sha256`. `original52-final.log`. |
| Archive integrity | `node docs/proof/v3-parity/charts/round4-bump/archive.mjs` verifies the final seal, all original frame hashes, decoded frame counts, served hashes, and required effective motion values. Integrity does not mean behavioral or visual correctness. |

The analyzer command is `flutter analyze lib/src/charts/bump_chart.dart example/lib/demos/bump_chart_demo.dart test/charts/bump_chart_test.dart test/charts/bump_source_parity_test.dart test/charts/bump_parity_fixture.dart`.

The release command runs inside `example/` and is `flutter build web --release --target ../test/charts/bump_parity_fixture.dart --output /tmp/beui-bump-r4-after-20261023-v12`.

The original golden is never regenerated. No broader repository suite, hosted CI, pushed head, deployment, live-source identity, or physical-device certification is claimed.

## Append-only history and rejected runs

Every old capture and log remains in this directory. A successful byte seal does not promote rejected footage to accepted proof.

- The initial before base-href attempt failed and remains under `captures/before-no-preference/` with its logs.
- Early source footage used fallback sans fonts. Final v3 source videos supersede all earlier source videos. The accepted static source is `static-source-v1/`, which already uses the corrected Geist responses.
- Early after runs include captures begun before compilation finished. They are rejected blank-build evidence, not parity results.
- V4 input evidence exposed semantic text overflow that sent a Studio touch to Layers. V6b exposed focus on an unnamed wrapper. Later owned repairs and final native checks replace those claims.
- Earlier readouts expanded across the viewport. Earlier plot rings remained visible when a dot held focus. Final source/candidate PNGs show the repaired states.
- `interactions-after-v11b/` completed its 38 assertions but exited with browser-shutdown timeout code 2. It is not the accepted final run. Other slow browser shutdowns eventually completed. Proof scripts now persist observations before shutdown.
- `interactions-after-v12/` is the unresolved rapid-Tab failure. Its partial `diff-interactions-v12/` attempt failed because later PNGs did not exist. Neither is accepted final proof.
- `repeat-after-v1/` passed its first 14 behavior states, then failed the document-level key observer. Flutter intercepted key-down events before that observer. V2 uses an earlier window capture listener in both source and candidate. All 28 states and the trusted repeat-event assertions pass. The original observer failure remains intact.
- The first border hypothesis predicted DPR-dependent snapping. `source-border-metrics.json` and its failure log disprove that prediction. V2 records the actual 1px computed width at all three DPRs. `border-before.log` retains the failing-first component test.
- `ARCHIVE-pre-docs.json` is a preliminary byte seal created before final border work and documentation. It is preserved as historical evidence. Only `ARCHIVE.json` seals the complete final directory.

Output directories and generated JSON/HTML files use exclusive creation. Re-runs need a new run suffix. Existing originals are never replaced. The shared recorder and original baseline remain unchanged.

## Owned commits

These commits are linear above `a2942181`, in dependency order. The separate proof commit includes this directory.

```text
6ddcd9f1 fix(bump): match source legend and native keys
409ab30c fix(bump): retain button roles and align labels
f84dbce1 fix(bump): match repeated keys and reduced entrance
48058491 fix(bump): toggle from current chart ownership
673f7971 fix(bump): bound readouts and native hit targets
ca4125d2 fix(bump): validate source seeds and demo sizing
6c572c4a fix(bump): focus the labeled native controls
074dc3c3 fix(bump): align grid and focused plot visuals
888fa569 style(bump): brace label pointer guards
12146926 fix(bump): match computed rank border width
```

## Parent-owned requirements

The parent needs an adapter that preserves native button roles while exposing source-compatible pressed metadata. It also needs investigation of the intermittent rapid native Tab-burst focus loss. This worker does not change the Flutter engine, generic focus adapter, or shared Tooltip to conceal either gap.

Generic Tooltip owns surface geometry, arrow, collision bounds, pointer grace, and shared warm-delay behavior. Bump supplies its source initial 60ms hover delay locally. Exact shared timing is not certified. Shared font assets and typography configuration remain unchanged, with candidate and source hashes recorded separately.

The nonzero pixel comparisons and original golden failure remain real gates. A shared font or Tooltip repair requires fresh candidate builds, native input checks, videos, and raw image comparisons. The parent must not relabel this archive as exact parity.

Poteto Mode's Prove It Works principle required actual served hashes, effective motion probes, native inputs, and raw image measurements. Model the Domain kept stable pin/focus ownership inside the bump chart. Delegation is skipped because the user prohibits children. The unavailable `deslop` plugin is not claimed. Diffs and prose receive a manual check.
