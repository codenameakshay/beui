# Table typography residual diagnosis

2026-10-23. Read-only research. Recommendation: retain the repaired Table layout and existing typography. The remaining sampled badge row difference is reproducible as renderer-level raster positioning with identical font bytes and identical explicit baselines. No source-style or package implementation defect is demonstrated by this residual. Exact pixel parity remains open.

## Provenance and boundaries

Requested parent HEAD was 05d797156. A read-only HEAD query during this run returned 4b06a056b58087f50ce379ac910fe60f9c92701d, consistent with concurrent parent work. This report identifies the served builds by hash rather than labeling them as that working-tree HEAD. Source checkout remains a76e57c9bbc2837e96420b2610e9c82a3271bb05.

Read the requested table-badge-baseline README, metadata, Dart probe and archived measurements; shared font diagnosis REPORT; and fonts README. Used the documented direct Chrome/Playwright workflow permitted in the brief. Chrome reported HeadlessChrome/156.0.0.0 on macOS, DPR 1. All browser contexts were newly created and closed. No existing user tab was driven. Only /tmp/beui-table-raster-research-20261023 was written. No repository, production, golden or original evidence edits, tests/builds, children, or server shutdowns.

Fresh inspection used source port 18143 and diagnostic candidate port 18144. Only the diagnostic candidate was queried with __readTableBaselines(). No production global was assigned. Standalone documents were served by Playwright routes in fresh owned pages, with separate font-provider instances and globals. These isolated font-byte comparisons did not substitute application fonts.

inspection.json records actual response hashes, CDP rendered-font results and computed styles. Source JS SHA-256 is c31b6542667d935f84871670d76b84013a0214c409e7ce8eed44e67afebbe7d4. Diagnostic JS is 2dfe2fbddaf70e2c6de237648de5d6553d50ab7635d8b2e23985d0e47a6984ca. These match the supplied metadata. Ordinary release JS was not re-captured; its supplied metadata hash remains 6467520a61c2b2750a3b3c7ab58678cf28d163d84590cada26af6029b9eb0ee0.

## Actual layout and source style

Fresh diagnostic output confirms visible first-row normal text baseline 124.47999954223633, badge baseline 124.47000026702881, badge y 112.21000003814697, height 16 and width 63.26448059082031. The callback also enumerates hidden measurement paragraphs; their y=41/43 records are not visible row measurements.

Archived source marker measurements give 124.5 for both normal text and badge. Badge Range y=112.5, height=16, width=63.265625. These are measured baselines, never inferred from screenshot ink. The source Range is a browser inline text rectangle; it is not interchangeable with a Flutter RenderParagraph line box.

Fresh source badge computed style is Geist, 12px, weight 500, line-height 16px, normal tracking, font-feature-settings normal, font-variation-settings normal, font-kerning auto, text-rendering optimizelegibility, -webkit-font-smoothing antialiased, transform none. Its lowercase DOM text is capitalized by CSS. CDP reports nine custom Geist-Medium glyphs. All four static @font-face registrations have explicit matching 400/500/600/700 CSS weights. This rules out a demonstrated source regular/medium registration mismatch for this badge.

Pinned app/globals.css:248-249 supplies antialiased and optimizeLegibility. In isolated DOM probes, changing text-rendering to auto left these bounds unchanged. Changing font smoothing to auto altered some horizontal coverage but not the vertical residual. These settings are not supported as a package fix.

## Exact fixture fonts differ in hinting, but that does not explain the row residual

The Table fixture serves STATIC WOFF2s. They are not the live variable WOFF2s in the earlier report. Fresh source medium SHA-256 is b0a0867cda44efef4529a4b13ce37fd9fd6e1597708615287542a51bc7452ab4. It identifies Geist Medium / Geist-Medium, weight class 500, Version 1.800; ttfautohint v1.8.4.16-eb64. It has fpgm, cvt and glyph instructions. Candidate medium TTF SHA-256 is a8eefb873ba9c9020665f8a98302697ce1f3b79ab2deef6ee508c0ca6a82e876, Version 1.800, same names/weight class, without those glyph programs. Both have hhea 1005/-295/0. See font-metadata.json.

The badge glyph advances match in both files. Glyph instruction lengths are recorded in badge-outlines.json. That file's raw coordinate-index differences are NOT valid geometric displacement measurements: contours may start at different points. Do not interpret its maximum raw index deltas as shape-size errors. This run does not claim identical outlines. Font-byte swaps produce small coverage differences, recorded in font-pixel-comparison.json, so matching bounds must not be relabeled pixel identity.

Crucially, both source WOFF2 and candidate TTF reproduce the same vertical row residual when passed through each renderer. CanvasKit disableHinting=false versus true also gives the same measured vertical bounds in this matrix. Hint-program presence is therefore real provenance information, but no causal font-replacement fix is demonstrated.

## Fixed-baseline experiment

probe.mjs and probe.json test both exact font inputs, weights 400/500, sizes 12/14, explicit baselines 40/40.47/40.5, browser DOM, Canvas2D and the served CanvasKit software surface with hinting on/off. phase2.mjs tests the half-pixel neighborhood, CSS controls and CanvasKit MakeCanvasSurface as well as MakeSWCanvasSurface. These API paths return the same vertical bounds; this does not certify hardware GPU execution under headless Chrome.

The initial matrix uses default paragraph metrics. faithful.mjs repeats the comparison with Flutter's settings: applyRoundingHack=false, explicit line-height 16/12 or 20/14, halfLeading=true and letterSpacing=0. Engine text.dart:207 disables the rounding hack; its style mapping forwards heightMultiplier and maps even leading to halfLeading. The faithful 12px/500 probe exactly reproduces the actual diagnostic badge width 63.26448059082031, height 16 and internal baseline 12.260000228881836.

Every baseline is set from an inline zero-size baseline marker or CanvasKit getAlphabeticBaseline(), never from screenshot fitting. The source DOM marker reports an internal baseline of 12px at 12px text; CanvasKit's 16px line reports 12.26px. Shared global baselines therefore imply different fractional glyph drawing origins. The 0.29px source Range/paragraph-top difference is expected from those distinct metrics and the 0.03px global baseline difference; it is not a measured need for a one-pixel translation.

Bounds scripts examine black-on-white ink using four explicit coverage thresholds: 1, 16, 64 and 128 on a 0-255 scale. Bounds are inclusive. At threshold 64, faithful 12px/500 Suspended at explicit baseline 40.5 yields DOM rows 32..42 and CanvasKit rows 31..41. This holds with EITHER font input and with hinting enabled or disabled. Adding the fixed coordinate difference of 84 maps these rows to the archived source116..126/candidate115..125 observation. This is correspondence between measured bounds, not a proposed translation.

At the SAME baseline 40.5 and 14px/20px, faithful Suspended at weight 500 gives DOM and CanvasKit rows31..42 at threshold64. Thus an ordinary-size match and badge-size mismatch can coexist with correct baselines and font selection. This is not proof that every 14px string matches, nor a recapture of all body text.

phase2-bounds.json shows the DOM's vertical raster transition between measured baselines40.484375 and40.5. CanvasKit's corresponding transition is later in the sampled interval, between40.515625 and40.75. Both paths agree at41 for this string's threshold64 bounds. The experiment demonstrates different fractional vertical raster behavior; it does not identify the exact Skia/CoreText implementation branch or certify a universal snapping rule.

The exploratory body.json uses default paragraph metrics and a regular-weight Leo Marsh string, whereas the fixture name is medium. It is retained as an exploratory control, not promoted as a faithful application-body comparison. Use faithful-bounds.json for the line-height-aware conclusion.

## Smallest supported action and limits

No package code change is supported for this residual. Keep the baseline repair, source weight500, line-height16 and existing fonts. Do not add y translation, adjust global typography, switch fonts or downgrade weight. Keep the archived exact-raster failure distinct from the passing layout evidence. If exact DOM/CanvasKit glyph parity is a product requirement, this evidence supports a renderer-focused investigation with fixed fonts and baselines, not component compensation.

The original four light/dark and motion-preference bounds remain untouched. Fresh inspection was light at DPR1; isolated probes use black text on white at DPR1. No new dark/DPR2/mobile/live parity claim follows. The source-font instruction difference is specific to this fixture and must not be attributed to the live variable deployment. Browser and CanvasKit versions, color/coverage thresholds, glyph strings and line-height settings bound the result.

This does not resolve the historical candle/volume narrow-mono-width residual. This experiment concerns vertical sans raster placement and does not measure actual chart paragraph advances or selected mono faces. Earlier alias/provider success and matching font manifests remain insufficient to certify those actual labels. Their next discriminating measurement remains actual paragraph advances and resolved/load-complete font behavior for narrow/wide mono strings. No chart sweep ran, and no new chart defect or repair is claimed.

## Reproduction and retained failures

Run inspect.mjs with the existing ports, then probe.mjs, phase2.mjs and faithful.mjs with the installed /tmp/beui-parity-capture-runtime Playwright runtime and Chrome path embedded in the scripts. Bounds scripts consume their PNGs and JSON. Use a new output directory when rerunning to preserve this report's artifacts.

Initial inspection incorrectly searched capitalized DOM text; it failed before measuring because the source stores lowercase text with CSS capitalize. A subsequent inspection recorded no match before the selector was corrected. Initial standalone script assumed a global CanvasKitInit; this served build uses an ES-module default export, and that attempt failed before rendering. The successful saved scripts use the corrected selectors/import. None of these failed attempts is evidence of an application failure.
