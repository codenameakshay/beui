# Intrinsic Table collapsed vertical grid

Production commit: `450699deca010bfd1d885f93dcd6e13d611d4ade`.
Pinned source: `a76e57c9bbc2837e96420b2610e9c82a3271bb05`.
Final capture hashes and viewport are in `metadata.json`.

The source header has 52px content and advances 52.5px because of its shared
collapsed border. Body rows advance 52px and center content in that full height.
The original candidate inset its rules, moving body content 1px upward. The
repair preserves full content height and paints the shared grid once over row
backgrounds. Rules scroll with the table while header content stays fixed.
Default flex sizing retains its prior behavior.

## Verified

- Layout regression failed before the repair and passes afterward. Legacy flex
  geometry is covered separately.
- Fractional-scroll review found a rule-range omission at 52.75px. An actual
  raster assertion failed before correction and passes afterward. Follow-up
  arithmetic review checked 1,515,840 cases without an omitted visible rule.
- Final root suite: 2,520 passes and the same 56 baseline golden failures.
  `baseline-comparison.json` records the exact unchanged identities. No golden
  was regenerated. Gallery: 63 passes. Scoped analysis and release build pass.
- Final r4 native source/candidate captures retain all 30 exact horizontal handle
  comparisons: five handles, three resize phases, two motion preferences.
- Final r4 scroll captures use trusted wheel input at offsets 0, 26, 52 and 104
  in light/dark and both motion preferences. All 16 paired pixel columns match
  at x700, y91 through458. This checks blank-space grid painting, not entire
  screenshots or all content.
- Loaded-Geist widget geometry measures the first normal text baseline at
  83.48005px below header top versus the source's measured83.5px. This small
  metric residual is retained. Checkbox centers and row advances match the
  source geometry.

Run `python3 verify.py`. Requires Python Pillow and ffprobe. Verification checks
all sealed file hashes, decoded video counts, trusted events, served JavaScript,
effective motion preferences, final horizontal boundaries and grid pixel probes.

## Preserved attempts

`diagnosis` retains the original read-only source/candidate measurements and
border-isolation experiments. `r1-split-rules` is rejected: two half-rules
rasterized lighter than one shared rule. `r2-rest`, `r2-horizontal` and `r2-scroll`
retain the static-header-rule attempt; scrolling disproved it. `r3-horizontal`
and `r3-scroll` match the observed integer-offset grid but precede the reviewed
fractional-range correction. Only r4 is the final build. No earlier recording
has been relabeled as final proof.

All original screenshots and 36 original WebM recordings are retained, including
superseded runs. `FOOTAGE.md` maps recordings to their context. Scripts retain
original ports and output paths; change these explicitly for a new run rather
than overwriting old evidence. Browser capture follows the documented local
Chrome/Playwright workflow used by the earlier Table archive.

## Limits

The status badge still has a separate inline-baseline mismatch at this commit.
These checks do not certify full-image parity, native60, every theme/palette/DPR,
all loading states, arbitrary custom cells, or a live deployed source revision.
The sampled source is the pinned local build. Whole-project parity remains open.
