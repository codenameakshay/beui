# Blocks change manifest

These changes improve specific behaviors. They do not establish exact visual or motion parity.

The [round2 report](round2/README.md) adds source CSS gradient geometry, shared Card Folder privacy tooltip, pointer-to-keyboard focus, source-layer held press, actual zero-glyph metrics, native SVG decoding and sizing, independent feedback retry semantics and the Search Chips backdrop.
The remaining-gap section below describes the round1 endpoint. Round2 fixes do not establish exact parity.

| Change | User-visible effect | Owned files |
| --- | --- | --- |
| Card Folder | Source contour spacing and layer-relative opening transforms. No initial purse-opening animation. Enter and Space activate the card. Privacy changes also animate CVV digits. | `lib/src/motion/card_folder.dart`, `example/lib/demos/card_folder_demo.dart`, `test/motion/card_folder_test.dart` |
| Morphing Tabs | Equal 154px tabs with 16px gaps in the 528px composition. Content controls root height. Shared content fills the panel. Narrow icon contents clip without overflow. | `lib/src/motion/morphing_tabs.dart`, `example/lib/demos/morphing_tabs_demo.dart`, `test/motion/morphing_tabs_test.dart` |
| Prediction Market Card | Source image URLs replace fake marks. Header, row, background inset, probability bars, sparkline color, and percent-to-action text follow the source more closely. The payout uses the shared tooltip. | `lib/src/motion/prediction_market_card.dart`, `example/lib/demos/prediction_market_card_demo.dart`, `test/motion/prediction_market_card_test.dart` |
| Market keyboard activation | One CTA tab stop replaces nested focus stops. Clicking an outcome moves keyboard activation to that outcome. Keyboard focus paints the source's 2px outline with a 2px gap. | Market card implementation and test above |
| Digit Swap | Outgoing digits roll opposite incoming digits. Pending stagger timers cancel on replacement. Same-value style changes refresh. | `lib/src/motion/digit_swap.dart`, `test/motion/digit_swap_test.dart` |
| Text Scramble | Ticker elapsed time no longer restarts through a zero sentinel. Nonpositive durations finish immediately. | `lib/src/motion/text_scramble.dart`, `test/motion/text_scramble_test.dart` |

## Callback contract and compatibility

At pinned source revision `a76e57c9bbc2837e96420b2610e9c82a3271bb05`, `components/motion/prediction-market-card.tsx` lines 161 through 166 pass `positive={index % 2 === 0}` and always call `onOutcomeClick?.({ outcomeId: outcome.id, side: "yes" })`. Lines 290 through 306 display `No` for an odd outcome. The styling and displayed action are independent of the callback side in upstream.

The Flutter callback now follows that source contract. Clicking Lakers reports `('lakers', BeuiPredictionMarketCardSide.yes)`, even though its rose action displays `No`. The public types and signature remain unchanged. The odd-row callback value is a behavioral breaking change from the previous port. Consumers that interpreted the old `no` value must update. The changed literal test expectation is intentional source alignment, not backward compatibility.

## Focus regression checks

`focus-before.log` reproduces the inert outer focus stop. `pointer-focus-repro.log` reproduces the stale keyboard target after a pointer click. The fixed test asserts two Lakers selections after clicking Lakers and pressing Enter. Tab traversal checks each payout and CTA once and observes Yes and No on keyboard focus.

Upstream line 291 also requires `focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring`. The late review found this outline missing. `focus-ring-before.log` shows the paint-level failure. `focus-ring-final.log` passes 30 market and tab behavioral tests after the fix. `focus-ring-after.log` and `focus-ring-reviewed.log` retain failed matcher-development attempts. Those failures are not final implementation failures.

## Narrow tabs

The smallest certified root width is 128 logical pixels for three tabs with close controls. Tests also measure 170, 280, and 528 logical pixels. They assert the actual root dimensions and no overflow exception. The 528px composition asserts three 154px slots and a 170px start-to-start interval. Widths below 128px are not certified. This is not a claim that a 128px browser viewport can contain the complete gallery.

## Videos

`change-videos/` contains labeled before-then-after clips for all five changed demonstrations. `change-videos-focus-ring/prediction-market-card.mp4` adds the final keyboard-outline fix. Their manifests name every input and verify that output frame count equals the sum of input frame counts. These are viewing edits, not aligned comparisons.

Original pixels are not resized. A black title band and bottom padding accommodate the 900px baseline and 813px screenshot capture. Original baseline clips retain page loading. The first frames can therefore be blank. There is no frame interpolation. Every source video remains separate and unchanged.

The local FFmpeg attempt failed with `[AVFilterGraph @ 0x7837403f80] No such filter: 'drawtext'` and `Error : Filter not found`. The final edit uses native AppKit-rendered title PNGs with FFmpeg overlay and VFR passthrough.

## Round1 remaining implementation gaps

Card Folder's radial glow, typography, and Material privacy tooltip differ from the source. The reference live site reports Geist and Geist Mono fonts, while the porting spec describes Inter and JetBrains Mono. This slice does not change shared fonts. Native Flutter cannot decode the remote source SVGs through the same web HTML image strategy. Market tooltip and text timing depend on shared widgets owned elsewhere. The full required block catalog has not received a zero-diff layout or motion verdict.
