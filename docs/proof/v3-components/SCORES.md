# v3-components design-compare (widget / dark-ui)

Captured 2026-10-22 against beui.dev crops and the visual harness at `http://127.0.0.1:8098/?slug=<slug>&theme=dark` after `6f97bc3`.

| Slug | overall | layout | color | notes |
| --- | --- | --- | --- | --- |
| adaptive-stepper | 86.47 | 93.80 | 73.17 | Rest +/- are outlined 48px circles. Flutter has no SVG Liquid gooey filter. Hover fills muted (widget test). |
| color-selector | 85.15 | 86.70 | 91.28 | Crop aspect mismatch; ring hugs blue swatch in swatch color. Accent sits beside the row. |
| tooltip (cropped rest, prior) | 94.57 | 95.15 | — | Cropped rest. Source iframe hover often misses the widget. |

Full-viewport uncropped card/tabs vs site chrome score ~63–71 (aspect 25% + sidebar). Those are not widget scores.

Hover / enter proved in this harness pass:

- tooltip Left: rest → `More context` with arrow (`cand-tooltip.png` → `cand-tooltip-hover.png`; enter pair `cand-tooltip-enter-0.png` / `cand-tooltip-enter-1.png`)
- file-tree: selected `file-tree.tsx` plus hover pill on `public`
- image-viewer: thumbnail click opens lightbox `1/3` caption `01 / Form and light`
- card: 2-col, labels left / switches right, selected ring on Signed contract
- tabs: overflow chevrons both sides; Activity hover lightens the label
- number: compact `Animate` under 320-wide digit-swap

`compare_motion` on the full 1440×900 tooltip sequence reports `motion_status: static` (tiny ROI vs viewport). The enter stills show the surface appearing.

Named gaps stay in `docs/V3_COMPONENTS_GAP.md`.
