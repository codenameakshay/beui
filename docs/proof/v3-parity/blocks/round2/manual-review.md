# Manual frame review

These observations describe actual retained pixels. They do not certify exact parity or unseen motion between samples.
`frame-review-final.json` and `press-frame-review.json` give original paths, hashes and request-response intervals.

## Original state samples

| Selected state | Visible result |
| --- | --- |
| Card revealed, `flows-normal`, frame 24 | The full card number and CVV 123 are visible. The shared tooltip says Hide card details. |
| Card masked, `flows-normal`, frame 46 | Masked digits retain 0806. CVV is masked. The tooltip says Show card details. |
| Card opened, `flows-normal`, frame 65 | The front pocket is absent. Full card artwork and its bottom metadata are visible. |
| Card keyboard-closed, `flows-normal`, frame 92 | The front pocket returns with masked digits and metadata. The focus ring remains visible. |
| Shared tooltip hover, `after-final-card`, frame 25 | A dark shared tooltip appears over the eye control. This is not a Material tooltip. |
| Feedback rejected, `flows-final-feedback`, frame 174 | The error copy and separate Try again action are visible. |
| Feedback success, `flows-final-feedback`, frame 246 | Thanks and the received-message confirmation are visible. |
| Search Chips added, `flows-normal`, frame 59 | A dark mode chip appears next to onboarding. The input is empty and recent choices are visible. |
| Failed rates SVG, `after-secondary`, frame 30 | The rates header shows a tiny white dot rather than the full seal. This is the actual sizing defect. |
| Repaired rates SVG, `after-svg-final`, frame 31 | The full colored Federal Reserve seal fills the header artwork slot. |
| Secondary numbers, `after-secondary`, frame 44 | Card number, live active-users value and recurring revenue are all visible. This is not a matched count-up trajectory. |
| Secondary text, `after-secondary`, frame 44 | Scramble is mid-change. Chromatic, reveal, shimmer and cascade compositions are visible. Randomized glyph equality is not asserted. |

The seven decoded frames in `labeled-review` were inspected.
Their title bands identify round1 or round2 inputs and the changed wrapper or viewport where applicable.
The market and SVG-sizing frames show the repaired full seal.
The shared-tooltip frame is a transient digit-swap sample with overlapping outgoing digits. It is not an exact-motion pass.

## Held press

The original dark before candidate frame 59 shows the entire pocket inset with the shrinking card layer.
The source dark before frame 32 keeps the pocket full width while the card shrinks.
The after candidate dark frame 59 and light frame 58 keep the front pocket full width while the back/card layer shrinks.
The after source dark frame 28 shows that same layer relationship.
These observations agree with the independently measured privacy bounds in the assertion reports.

The reduced source frame 41 keeps both card and pocket at their rest size.
The reduced candidate frame 59 also keeps the geometry fixed, but its eye and shell icon glyphs are missing.
The separate candidate reduced assertion rest screenshot renders those glyphs.
The cause is not diagnosed here. Shared fonts and theme were not edited.
The failed recorded pixels remain unchanged and are not replaced by the successful assertion screenshot.

Both decoded `labeled-press-review` frames were inspected.
Their labels describe the same viewport, wrapper and event protocol before and after the layer fix.
The frames show an unchanged pocket with a shrunken card behind it.

## Motion review

| Before | After | Why |
| --- | --- | --- |
| One press transform scales the back, card, pocket and optional action. | A full-root transform scales only the back/card layer and its focus ring. | Source `card-folder.tsx` lines 152 through 190 put only these children inside the native pressed button. |
| The privacy control moves about 6.91px and shrinks to 38.4px during an upper-card hold. | Both themes retain its exact 40px bounds and zero displacement. | The privacy control belongs to the stationary front sibling. |
| Source icon scale/blur swaps are absent. | Still open. No claim of repair. | `card-folder.tsx` lines 248 through 278 define the separate eye-icon transition. |

The motion verdict is Block for exact parity.
Press-layer ownership is repaired, but icon transitions, disabled styling and optional-action footage remain incomplete.
Fast enter/exit timing and native 60fps remain unverified because sampled request-response intervals leave gaps.
No slowed or interpolated export supplies missing frames.

The UI review used the existing Flutter widgets, token colors and motion engine.
Typography was inspected but left to the parent's font investigation.
Borders, pocket spacing, chip artwork, gradient geometry and press ownership were inspected through source and retained pixels.
Exact icon styling remains open. Runtime frame-budget performance was not measured.
Scaling the entire root was rejected because it moves source siblings.
Applying separate local scales to the back and card was rejected because their independent centers differ from the source button's full-root center.
