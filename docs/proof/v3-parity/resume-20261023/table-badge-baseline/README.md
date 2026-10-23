# Table badge inline baseline

Production commit `aa373177c1d18227926384cc2465b432f883235c` changes only the
gallery Table badge composition and its tests. The source inline padded span
shares its parent 14px/20px line's alphabetic baseline. The candidate previously
centered its 12px badge independently, placing its baseline about 0.72px higher.
The demo now uses a baseline row with a zero-width font strut. The strut is
excluded from semantics and selection. The badge respects the cell's available
width; passive width samples still measure only the badge's actual content.

## Verification

- The original baseline assertion failed before repair. Final actual-Geist
  checks pass at 1× and 2× scaling, within 1/64px per scale of regular cell text.
- A direct ambient-tracking regression exposed a 0.248px Row overflow. It failed
  before constraining the badge and passes afterward. The intermediate full
  gallery run reported success despite printing those overflows because its
  existing multiple-exception filter treated them as noise. That run is not
  accepted as a clean layout gate. The final full gallery run passes 66 tests
  with zero overflow messages. Focused DATA/recovery checks pass 10 tests.
- Scoped analysis and the final release build pass. The last full root run at
  the unchanged library code 450699dec passed 2,520 tests with 56 unchanged golden
  failures; it is not relabeled an exact-aa373177c root run.
- Final native captures preserve 30 exact horizontal handle comparisons and 16
  paired grid pixel columns across both motion preferences, light/dark and
  four scroll offsets. These are regression checks, not badge pixel acceptance.
- A separate diagnostic build adds only `baseline_probe.dart`. Its actual
  CanvasKit paragraphs report first-row normal text baseline 124.4799995 and
  badge 124.4700003. Pinned source baseline markers report 124.5 for both. The
  source marker is removed immediately and its cell geometry stays unchanged.
  Diagnostic and ordinary release JavaScript hashes are separate in metadata.

The red badge text still occupies source pixel rows 116..126 versus candidate
115..125 in the sampled first-row region, in all four theme/preference pairs.
`final-scroll/badge-ink-bounds.json` preserves that residual. It is an ink-bounds
measurement, not a measured 1px baseline discrepancy. No screenshot-fitted
translation, font asset replacement, or global typography change was made.
Exact badge raster parity remains open.

## Archive and reproduction

`final-horizontal` and `final-scroll` are the final ordinary release build.
`before-width-fix` preserves an intermediate native run before the width guard.
All 16 original WebMs and screenshots remain. `runtime-baselines` contains the
separate diagnostic screenshots, measurements and script. `logs` preserves
failed tests and the misleading intermediate gallery output alongside the final
results. A concurrent Chrome launch for the earlier scroll attempt failed before
any capture with SIGTRAP and “Target page, context or browser has been closed”;
the final run used a fresh sequential launch. No failed capture was promoted.

Run `python3 verify.py` with Pillow and ffprobe. It verifies every sealed hash,
actual decoded frame counts, native input trust, served hashes, effective motion,
horizontal comparisons, grid pixel columns and diagnostic baseline tolerances.
Scripts retain original local ports/output paths; use new paths when rerunning.
No overall parity, live deployment, screen-reader or native60 claim follows.
