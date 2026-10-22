# v3-components design-compare (widget / dark-ui)

Captured 2026-10-22 against beui.dev crops and the visual harness at `http://127.0.0.1:8098/?slug=<slug>&theme=dark`.

| Slug | overall | layout | color | notes |
| --- | --- | --- | --- | --- |
| adaptive-stepper | 86.47 | 93.80 | 73.17 | Rest +/- are outlined 48px circles. Flutter has no SVG Liquid gooey filter. Hover fills muted (widget test). |
| color-selector | 85.15 | 86.70 | 91.28 | Crop aspect mismatch; ring hugs blue swatch in swatch color. Accent sits beside the row. |
| tooltip (prior) | 94.57 | 95.15 | — | Cropped rest. Source iframe hover often misses the widget. |

Hover proved in the gallery / tests: file-tree (pill on `globals.css`), expandable chip, tabs, combobox, card Invoice, stepper (muted fill), tooltip (animated label).
