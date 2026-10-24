# Tooltip motion review

This review does not certify parity. The tight and wide sequences contain 32
paired native-size crops each. The shared extraction tool selected original
frames on a 100ms grid. It omitted the 2900, 3000, 3100, and 3200ms bins.
`selection.json` retains the selected source frames and timing uncertainty.

| Crop | Design Compare status | Score | Temporal correlation |
|---|---|---:|---:|
| Tight 160 by 112 | compared | 88.3 | 0.1478 |
| Wide 312 by 256 | static | null | 0.1625 |

The tight result detects both surfaces changing. Its score is not an exact
timing verdict. The wide result is inconclusive because the tool classifies
its motion energy as static. The native reference cadence is about 12 FPS and
the repaired cadence is about 29 FPS. A 100ms diagnostic grid cannot establish
the source's 180ms entry or 120ms exit trajectories.

The direct pixel comparison also fails. At the 1200ms selected bin, 14727 of
17920 pixels differ, or 82.18%. This includes the actual shared preview
background and the candidate's measured half-pixel placement offset. Neither
was masked or normalized. The component's trigger geometry is 80 by 40 on
both sides, but matching width does not establish matching pixels.

Decoded repaired frame 22 visibly contains the Top tooltip. Decoded reference
frame 16 in the retained earlier screenshot run visibly contains the Top
tooltip. This rejects a blank-canvas capture. It does not replace the pixel
and temporal comparisons.

The source and candidate crops align their measured trigger coordinates.
Reference crop origins are 520:488 for the tight crop and 444:484 for the wide
crop. Candidate origins are 692:303 and 616:299. No image was resized.

## Keyboard attempt

The separate four-video keyboard run records actual Top mouse clicks, Tab,
Tab, Shift+Tab, and Escape in light and dark themes. Source compositor footage
reaches roughly 57 FPS, but the repaired screenshot footage remains about
29 FPS. Neither is a native 60 FPS certificate.

Decoded light frames at 1.45 seconds reveal a real focus mismatch. Source Tab
has focused Left and displayed its tooltip. Candidate Tab has focused the
header logo instead. These recordings are retained as failed keyboard parity,
not labeled as successful focus navigation. Source uses a native button focus
position after a mouse click. The current gallery's button does not preserve
that position. The isolated Tooltip unit tests pass a focused child directly
and do not establish this gallery behavior.
