# Component change manifest

This is change text for the parent video's captions. It describes implemented
changes, not an exact-parity verdict. Baseline is `5ec78ac30e1274727ddd185a883346e4d908e6c8`.
Reference source is `a76e57c9bbc2837e96420b2610e9c82a3271bb05`.

| Route | Before | Repaired behavior or appearance | Remaining visual proof |
|---|---|---|---|
| Tooltip | Focus waited for the hover delay. Touch taps did not toggle. Mouse press could leave the label visible. Crossing the trigger-label gap closed it. Old enter used blur and travel. Arrow increased layout size. | Focus opens immediately. Touch preserves child activation and toggles the label. Mouse press suppresses until re-entry. A convex pointer corridor permits hovering the label. Current source scale 0.94 and fade use 180ms entry and 120ms exit. Arrow overlaps without increasing the body's 8px gap. Composed trigger/content and controlled visibility are supported. Body is 26px with a 16px text line. Demo gaps match current source. | All sides, alignment, collisions, reduced motion, live animated children, and full toolbar example recordings. Cross-provider exclusivity and external chart anchors remain missing. |
| Color selector | Label/list ran horizontally. Ring traveled in a straight line. Space did not activate the focused swatch. Disabled choices and a single group Tab stop were missing. | Label sits above the list. The ring follows the source's low upward arc, retargets from its rendered location, and settles at the selected swatch. Space/Enter activate. Disabled items dim, reject taps, and are skipped by arrows. Tab enters the selected choice and then leaves the group. Press uses the source spring and reduced motion keeps geometry still. | Quantitative source trajectory, selected-ring press scaling, focus outline extents, and interrupted reversals. |
| Arc picker | Selection brackets stayed at rest geometry during drag. | Drag and wheel activity expand the bracket gap by 6px and compress its height by 8%, driven by the source glide spring. Rest geometry is preserved. | All four orientations, inertia, wheel activity, interruption, and reduced-motion recordings. |
| Timeline | Demo used invented chart/photo/document tiles. | Demo ports the pinned preview's actual SVG/CSS recipes and chart data. It includes chart, grid, phone, sync, keyboard, and 2.0 tiles with theme-aware colors. | Matched event-card geometry, source imagery rendering, momentum, keyboard, and theme sequences. |
| Alert | Demo included an extra Default selector and used segment tabs. Root entered downward with scale. Initial open replayed an entry. Old variant icon disappeared immediately. | Demo exposes the source's four variants and pill tabs. Root enters and exits upward by 6px without scale. Initial open mounts settled. Variant replacement retains outgoing icons for the 100ms fade/slide/scale exit while the replacement enters over 180ms. | Exact source status text/background colors, color interpolation, layout-height trajectories, close/reopen, and focus restoration recordings. |
| Image viewer | Architecture photo was a different asset. Thumbnails were fixed at 120px. Hover invented lift, shadow, and brightness. Header omitted source copy. | Exact three source photo URLs are restored at 1600 by 2000. Gallery distributes equal responsive columns. Source press scale is 0.98. Hover does not alter image position or brightness. Header, photograph count, and instruction match source copy. | Photo-load confirmation, focus outline, zoom/pan/swipe, modal morph, navigation, Escape, and focus return against source. |
| Card | Muted card retained an outlined border. Press restarted its spring. Demo document text was not a full-card target. Studio card was an invented overlay image. | Muted rest border is transparent. Press retargets the existing spring. Text and card padding activate the owning checkbox once. Source title/description line heights, demo spacing, exact copy, and small button sizes are restored. Studio card ports the true image URL, media/header/footer layout, booking copy, price, and action. | Exact focus-visible outline, source/candidate pixel crops, radio composition, and hover/press/reduced-motion recordings. |
| Breadcrumb | Demo used a narrower width and an unrelated outlined button. Link minimum height shrank under compact Material density. | Source width cap, padding, divider, forward navigation row, icons, copy, and focus restoration are ported. Link uses a 32px minimum height and source text metrics. | Enter/exit item retention, ellipsis morph, hover focus outline, keyboard popover return, and matched motion crops. |
| Tabs | Indicator used the older 170/24/1.2 spring. | Component-local spring is 245/36/1.2 from the pinned source. No layout changes were made by this slice. | Blocks worker owns narrow overflow and wide-panel shrink fixes. Parent reconciles the shared file. |

No component motion helper, barrel, catalog, theme, or shared engine was edited
by this slice. The width wrapper is a separately owned cherry-pick.

The full-suite chart regression exposed a modality transition in Tooltip.
Mouse dismissal now yields to subsequent keyboard use even when a child chart
consumes the key. Commit `8ccb169` adds a global keyboard observer scoped by the
trigger's actual focus node. Chart-owned files remain unchanged.

## Named unresolved implementation gaps

- Adaptive stepper still lacks the source's `Liquid` filter and connected
  silhouette. The source passes blur 8, contrast 22, and a 600ms overshooting
  cubic transition. The existing outlined controls are not equivalent.
- Color picker still uses a translated/scaled popover instead of the source's
  trigger-to-area morph.
- Tooltip content can contain an animated widget. Updating plain `Text` does
  not itself animate glyphs. The chart worker must use an animated text child
  for animated chart readouts. No chart files were changed here.
- Tooltip's source toolbar install example needs gallery/example support and
  explicit accessible-label composition. The default cross demo alone does
  not cover `example/tooltip/toolbar`.
- All untouched required routes remain unverified, including collapsible,
  aspect-ratio, sortable-stack, date-range-picker, button's four examples,
  expandable-control, input, combobox, multi-select, shared-layout-bg,
  animated-sidebar, file-tree, dock, range-slider's six examples, and table's
  three examples. Existing tests do not certify their visual parity.
