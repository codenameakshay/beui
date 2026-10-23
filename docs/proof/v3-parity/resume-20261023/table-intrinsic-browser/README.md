# Intrinsic Table native geometry

The DATA gallery now uses measured intrinsic sizing. Passive samples include
actual text, padding, badge content and header controls. No observed column
widths are embedded in production. The default flex mode remains unchanged.

Two source-owned header wrappers explain the remaining initial offset after
allocator integration: the checkbox label reserves 24px around its 20px control,
and the reorder grip reserves 24px around its 14px icon. Intrinsic mode now
matches those wrappers. The sort icon remains 14px. The earlier diagnosis that
attributed two pixels to the sort icon was rejected by source inspection.

The final native comparison checks five horizontal resize-handle positions in
three phases under both motion preferences: initial layout, pointer-down freeze,
and a trusted 50px mouse drag. All 30 source/candidate x coordinates match exactly.
The expected source Name column is112.453125px at rest and freeze, despite its
rounded112px override. It becomes162px after dragging. The checkbox column grows
from24 to48px at freeze. Pointer sensitivity was not changed.

Captures use the pinned source fixture, Blue palette, light theme,1280x1000 CSS
viewport and DPR1. Served JavaScript hashes and effective motion probes are
retained. See metadata.json for the exact final build and FOOTAGE.md for videos.
The original recordings are browser WebM videos; their cadence does not prove
native60. No frame interpolation or golden regeneration was used.

## Retained attempts

- r1 preserves screenshots and raw observations. Its candidate DOM extraction
  incorrectly searched aria-label attributes; role lookup could operate the
  controls but that extraction returned empty geometry. It is not geometry proof.
- r2 fixes extraction using role-derived bounding boxes. It retains the initial
  intrinsic implementation before the two header wrapper corrections.
- r3 proves corrected header geometry at4e4065cd0. It predates the separate
  fractional source-window sampling repair.
- r4 is the replacement capture after the sampling repair. Earlier artifacts
  retain their original labels and bytes.

## Sampling limits

Measurement samples use the full source-equivalent viewport and fractional
scroll offset, with ten overscan rows on each side. The range updates when
either endpoint changes. Tests include48 to48.5px and568 to568.5px transitions,
a wider trailing sample entering/leaving, sorting at a retained scroll offset,
short and empty lists, and row-height updates. The source dependency is locked
@tanstack/virtual-core3.17.7.

Flutter's actual mounted/cache interval still differs from the source window;
measurement sampling is deliberately independent. Runtime row-height changes
recalculate in Flutter, while the pinned source retains cached estimates until
remeasured. Dynamic-height parity is not claimed. Vertical row alignment,
font rasterization, colors and full-pixel equivalence remain separate open
checks. Matching horizontal boundaries does not certify overall parity.

Run `python3 verify.py`. It verifies retained file hashes, actual decoded video
counts, trusted pointer logs, served JS hashes, effective motion probes and the
30 final horizontal comparisons. ffprobe must be available.

## Final code gates

At production `3e1c3f4bb`, the full root suite has 2,517 passes and the same
56 preserved golden failures as the retained baseline. No new failure identity
appears. The full gallery passes 62 tests. The focused Table gate passes 73
tests with goldens disabled; scoped analysis and the release fixture build pass.
The final served JavaScript is
`c5b13dd0985cf017542a352778d5cce72c2472ca6daede83fcaecaa342dff62a`.

The archive retains 16 original WebM videos, including intermediates, and all
original screenshots. The verifier checks 30 exact final horizontal boundary
comparisons. These are local/browser results, not hosted CI or deployment proof.
