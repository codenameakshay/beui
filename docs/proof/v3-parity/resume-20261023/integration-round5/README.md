# Latest integrated gates

Tested implementation is 410893339. Root tests pass 2,449 cases and retain 56 golden failures. All reported failures in this final run are golden comparisons. The earlier run retained two obsolete file-icon lookups; their geometry assertions now use the source-correct icon and pass. Golden images were not regenerated.

Chart and NumberTicker behavior passes 283 tests with golden comparisons disabled. Gallery passes 56 tests. Production/test analysis passes. Whole-tree analysis reports four informational lints in archived source fixtures; the archive bytes are unchanged. Release build passes. See build.json for the exact gallery script hash.

Native composition checks load that script in both motion preferences, hover the same measured plot location, and record actual period/value semantics and effective Flutter motion flags. Screenshots show the six percentage and value rows. They establish readable integrated behavior, not source pixel parity. Earlier and asserted runs are retained separately.

Composition/funnel archive verification also passes an independent tracked-only regular-file export: 13,719 files, 669,376,638 bytes, 102 recordings and 11,118 original frames. The dedicated Sankey lifecycle archive independently verifies 148 files and 12 source/candidate keyboard scenarios.

Native Tooltip dismissal and Bump focus loss remain open. Preserved golden differences, remaining coverage obligations and fast-motion limitations are not waived by these checks.
