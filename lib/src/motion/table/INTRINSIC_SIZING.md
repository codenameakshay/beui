# Opt-in intrinsic sizing

`BeuiTableSizing.flex` remains the default. Its declared widths, flex weights,
selection width and resize behavior are unchanged.

`BeuiTableSizing.intrinsic` separates measured content contributions, declared
absolute preferences and resize overrides. Supply `intrinsicSamples` and leave
column flex weights at one. The callback receives the sorted source-equivalent index window plus
ten overscan rows on each side. Range endpoints use the full table viewport
height and fractional scroll offset. This differs from Flutter mounting, whose
body viewport excludes the sticky header. It must return passive outer-width samples for
every column, including headers. Selectable tables also need a selection sample.
The callback runs during layout and must not change ancestor state.

Samples must use matching inherited typography, text scale, padding and icons.
The library does not copy arbitrary cells or editors. Plain Text, Padding,
finite SizedBox, DecoratedBox and constrained passive Flex structures are
supported. Flexible/Expanded must be direct children of a horizontal Flex.
Horizontal cross-axis stretching is unsupported because probes have bounded
width and unbounded height. Unsupported controls and editors need explicit outer
minimum/maximum widths. A live editor is mounted only in the real table.

Probes do not paint, hit-test, expose semantics, receive focus or join text
selection. Intrinsic and font invalidation rebuild the real content within the
same layout pass, including unchanged parent constraints. Invalid, missing or
over-budget measurements fail explicitly. The default 256-root budget does not
bound subtree complexity or text length. Samples are not measurements of unseen
rows; scrolling can grow or shrink columns.

The allocator covers the absolute/auto subset verified against the archived
Chromium oracle. It uses a table-level floor, separately measured selection
width, an empty trailing column and maximum-content sizing only after all
current data columns have resize overrides. Resizing freezes rounded measured
data widths. Overrides and callback values remain distinct from rendered widths.
Header, body, skeleton and reorder geometry share the same resolved layout.

This mode does not implement arbitrary CSS table layout. It does not certify
Flutter/browser font raster correspondence, unsupported custom cells or exact
source virtualization. The gallery has not yet opted in; native integrated
geometry acceptance remains open.

For runtime row-height updates, this API recalculates estimates immediately.
The pinned TanStack source retains cached estimates until remeasurement; its
Table does not explicitly request that remeasurement. Dynamic-height parity is
therefore not claimed. Fixed-estimate range tests use the source dependency's
actual boundary behavior, including equality at a row end.
