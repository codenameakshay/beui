# Opt-in Table integration verification

Intrinsic sizing is implemented behind `BeuiTableSizing.intrinsic`. Existing
flex consumers remain on the default path. The gallery has not opted in yet;
this is library integration evidence, not native geometry acceptance.

The final focused gate passes 88 tests. Scoped analysis is clean. Before the
last scroll-cache correction, the full root suite had 2,512 passes and 56
failures, exactly matching the 56 failure identities in the retained Bump guard
baseline. `baseline-comparison.json` records both log hashes and the failure
comparison. The final small correction is covered by the focused gate; the full
root result must not be presented as a run of that final change.

Review and regression sequence:

- Six boundary tests fail before production corrections and pass afterward.
  They cover selection leakage, root/vertical/cross-axis constraint hazards and
  numeric bounds. The original prototype remains unchanged in fixtures.
- Actual asynchronous FontLoader changes expose a separate intrinsic text
  cache: fresh text measured 72px while the retained probe still measured120px.
  Recreating only passive probes on the font notification fixes this.
- First production review reproduces three failures: nested horizontal flex,
  fractional declared widths, and changed-row-height sampling. All pass after
  structural validation, width normalization and current-offset calculation.
- Second review confirms live editor state, focus and draft preservation through
  actual font loads, caller revision, probe count changes and disposal. Its
  additional row-height-then-jump regression failed before synchronizing the
  scroll cache and passes afterward.

Raw red, diagnostic, green, analysis and full-suite outputs are retained. No
baseline image or historical capture was changed. Browser raster equivalence,
gallery adoption and integrated native geometry checks remain outstanding.

Production integration commit: `654f5a218`.
