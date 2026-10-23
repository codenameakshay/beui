# Shared font authority and loaded-font proof

## Decision

Use Geist for sans and Geist Mono for mono. Do not change the gallery to Inter or JetBrains Mono.
The pinned source and the live rendered fonts agree. `docs/PORTING_SPEC.md` lines 184, 185, and 188 are stale.
That spec remains unchanged because this worker owns only shared font configuration and this proof directory.
The parent must reconcile those three lines with this evidence.

The correction changes `BeuiTextTheme` defaults to `Geist` and `Geist Mono`.
The gallery registers its existing mono files under `Geist Mono` as well as its existing `monospace` alias.
The test font loader registers the same added name. No font bytes, component styles, demos, capture tools, or existing baselines change.
The published package still bundles no fonts. Consumers still load their own files and can override both family names.

This is a shared contract correction, not a claim that every screenshot now matches.
The gallery already used Geist and Geist Mono before this correction. Its existing widget fonts therefore remain unchanged.

## Source authority

The source checkout is clean at `a76e57c9bbc2837e96420b2610e9c82a3271bb05` in `/tmp/beui-charts-reference-20261023`.
The Flutter base is `c8ef8a2cb0c40a1f7a59f9f5051fea528b43b9b0`.
[source-usage.json](source-usage.json) records file hashes and numbered font usages.

`app/layout.tsx` imports `Geist` and `Geist_Mono` from `next/font/google` at line 2.
Lines 22 through 29 bind `--font-geist-sans` and `--font-geist-mono`. Line 111 installs both variable classes on the document.
`app/globals.css` lines 115 and 116 map `--font-sans` and `--font-mono` to those variables.
Line 246 applies `--font-sans` to the body.

The source Code Block filename and preformatted text explicitly use `font-mono` at component lines 117 and 165.
Order Book applies `font-mono text-xs tabular-nums` to its root at line 132 and restores `font-sans` for a placeholder at line 308.
Command Palette does not select another family in its component file and inherits the global family.

## Live evidence

[live-run2/evidence.json](live-run2/evidence.json) is the canonical measurement.
It records Chrome 155.0.8059.86 on 2026-10-23 at a 1440 by 900 CSS viewport and DPR 1.
All three inspected pages returned HTTP 200.
They were `/components/blocks/command-palette`, `/components/agents/code-block`, and `/charts/order-book` on `https://beui.dev`.
The deployed source SHA is unknown. Agreement with the pinned font configuration does not prove deployment identity.

The script waits for network idle and `document.fonts.ready` before measuring.
It records computed styles, FontFaceSet statuses, font resource responses and hashes, and CDP `CSS.getPlatformFontsForNode` results.
It saves the response bodies and an unmodified screenshot of each page before adding measurement-only font aliases.
The `__font_proof` URLs serve local gallery bytes inside this isolated browser context. They are probes, not live-site resources.

The live sans resource is `/_next/static/media/caa3a2e1cccd8315-s.p.0wgildi0cnwt9.woff2`.
It returned 29,288 bytes with SHA-256 `9b6f5ff45b278c744b5f379a2c4ecbaf858a842b8eaf82ac8d21b699ca16c608`.
Its font metadata identifies Geist, version 1.800, with a weight axis of 100 through 900.

The live Latin mono resource is `/_next/static/media/797e433ab948586e-s.p.0r6juujl39pe6.woff2`.
It returned 23,108 bytes with SHA-256 `5f3d6ad60f29d6cb708414ec6887163d63bf197377ef5417d2483ff31ace6c3b`.
Its metadata identifies Geist Mono, version 1.701, with a weight axis of 100 through 900.
The Code Block page also loaded a 5,892-byte additional Unicode subset of the same mono version.
The saved CSS associates those URLs with the named families through `@font-face` rules.

CDP reports `isCustomFont: true` and PostScript name `Geist-Medium` for the Command Palette heading's 15 glyphs.
Its computed style is 30 px, weight 500, line height 36 px, and tracking -0.75 px. Its box is 239.9375 by 36 px.
The `Ctrl J` keycap renders six custom `GeistMono-Regular` glyphs at 12 px with 16 px line height and normal tracking.
Its 57.203125 by 22 px box includes keycap padding and borders.
The Code Block filename `summarize.ts` renders 12 custom mono glyphs in an 86.40625 by 16 px box.
The Order Book price `247.20` renders six custom mono glyphs in a 43.203125 by 16 px box.
These observations establish actual loaded font use, not merely a CSS fallback list.

The `⌘ J` keycap is an exception worth retaining. Chrome reports one Menlo glyph and two custom Geist Mono glyphs.
The shared family mapping does not establish equivalent platform fallback for symbols or other scripts in Flutter.

## Measured metrics and asset provenance

[font-files.json](font-files.json) records every existing gallery TTF and downloaded WOFF2, including hashes, names, versions, weights, and vertical metrics.
The gallery sans files are Geist 1.800 at weights 400, 500, 600, and 700.
Its mono files are Geist Mono 1.701 at weights 400 and 500.
All inspected files have 1,000 units per em, hhea ascent 1,005, descent -295, and line gap 0.
The gallery files are static TTFs. The live resources are subsetted variable WOFF2s. They are not identical files.
The existing license is `example/assets/fonts/OFL.txt`. No replacement font download is necessary for this correction.

The measured string is `Build something great. 0123456789 Wiil`, 38 characters.
At 14 px and weight 400, Chrome measures 253.959716796875 px for both live Geist and the gallery sans TTF.
For mono, Chrome measures 319.19512939453125 px live and 319.19976806640625 px for the gallery TTF, a 0.004638671875 px difference.
At that size, ten narrow and ten wide mono letters both measure 83.99871826171875 px live and 83.99993896484375 px in the gallery TTF.

The script also measures 95 printable ASCII glyphs, four weights, and sizes 12, 14, and 16 px.
Across that matrix, the largest sample-string width difference is 0.02520751953125 px for sans and 0.00518798828125 px for mono.
The largest individual-glyph advance difference is 0.00665283203125 px for sans and 0.0001373291015625 px for mono.
Mono weights 600 and 700 use browser synthesis for the gallery probe because only 400 and 500 exist in the gallery.
These nonzero deltas remain evidence. They do not certify pixel equality or identical outlines, kerning, or rasterization.

Flutter's actual rendered sans paragraph measures 253.96006774902344 px at 14 px regular.
Its named mono and generic mono alias both measure 83.99993896484375 px for ten narrow or wide letters.
The default agent mono role measures 71.99996948242188 px for ten narrow letters at its native 12 px size.
The real-font tests check the effective `RenderParagraph` family and metrics, not just the contract's strings.
They also check that the generated asset manifest maps both mono names to the same font entries.

## Affected callers and boundaries

`BeuiTextTheme` is a family-name value object. It does not install a theme or load files.
No production widget in `lib/` or `example/lib/` constructs it to choose its family. The constructor and `copyWith` are the only non-documentation construction sites there.
The corrected defaults affect consumers who use the public names to configure their theme and code text.
Explicit custom-family overrides remain available and unchanged.

`beuiGalleryTheme` still sets `ThemeData(fontFamily: 'Geist')` and normalizes Material tracking for both brightnesses.
The voice-orb preview also names Geist explicitly.
`BeuiAgentTypography` leaves sans families inherited and explicitly names `monospace` for its mono role.
Existing code surfaces and chart labels retain that alias, including Code Block, File Diff, loaders, Card Folder, Candlestick, Funnel, Treemap, Bump, and Price Target Fan.
[callers.txt](callers.txt) retains the exact grep census, including demo and explorer callers.
None of those widgets or demos was edited. The existing alias must remain registered.

`example/pubspec.yaml` and `example/test/flutter_test_config.dart` are the only shared asset configuration files touched.
No package-level asset declaration, capture script, port, gallery server, or baseline was changed.

## Verification and limits

Flutter 3.47.1 and Dart 3.13.1 ran three real-font tests, two gallery boot and routing tests, and the demo-width test.
[gallery-tests.txt](gallery-tests.txt) retains six passing tests and the printed rendered widths.
That run also logs remote-image HTTP 400 errors. It is not evidence that those external images load.
[package-tests.txt](package-tests.txt) retains ten passing text-theme and agent-theme tests.
The scoped analyzer logs report no issues. JavaScript syntax checks and `git diff --check` pass.

There is no repaired Flutter browser screenshot pair or zero-diff verdict in this report.
The existing gallery already loads the correct family assets. This correction does not claim to remove unrelated layout, timing, symbol-fallback, or raster differences.
Full screenshot and motion parity remain the parent's gates.

T3 was attempted first. `preview_status` reported no browser, then `preview_open` created an owned tab at `https://beui.dev/blocks`.
Two explicit snapshot attempts on that tab each returned `Preview automation snapshot timed out after 15000ms.`
The documented direct-Chrome recovery path then supplied this evidence. This work did not repair T3 transport.

`live-run1` remains untouched as an earlier run. Its quoted generic-family probes resolved differently from CSS generic keywords.
`live-run2` corrects that instrumentation and adds per-ASCII metrics. Only run2 is canonical for comparisons against generic fallback faces.

Prove It Works required rendered-font CDP evidence and real Flutter layout, rather than CSS names alone.
Test Behavior, Not Implementation required paragraph metrics that fail when a real family falls back to the test font.
Model the Domain kept network files, font faces, rendered nodes, and metric probes as separate records.
The user prohibited children, so how, architecture, and comment review ran locally without their delegation steps.
The poteto-mode `deslop` dependency is unavailable. A local scoped diff and prose review replaced it.

## Reproduce the evidence

Run the browser probe from the repository root with the existing external runtime and a new output directory.
The script rejects an existing output directory before launching Chrome.

```sh
PARITY_PLAYWRIGHT=/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs node docs/proof/v3-parity/fonts/inspect.mjs /tmp/beui-font-proof-new
python3 docs/proof/v3-parity/fonts/font_files.py /tmp/beui-font-proof-new
node docs/proof/v3-parity/fonts/source_usage.mjs
flutter test test/theme/beui_text_theme_test.dart test/theme/beui_agent_theme_test.dart
cd example
flutter test test/typography_fonts_test.dart test/widget_test.dart test/demo_width_cap_test.dart
```

The font metadata script requires the existing `fontTools` 4.63.0 installation.
No server is needed for the live-font probe or Flutter widget tests.
