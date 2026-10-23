# Combined branch verification

These checks ran against `a2942181a755503a25571ca3150a16acc284d29b`, the head pushed to PR26 before the resumed repairs. Later documentation and gallery-copy edits are not part of this build.

| Command | Observed result |
| --- | --- |
| `flutter test --reporter json` | 2,321 visible passing tests and 54 failing tests. All 54 failure outputs contain golden-comparison failures. No other failure was observed. |
| `cd example && flutter test --reporter json` | All 50 tests pass. |
| `flutter analyze` | No issues found. |
| `cd example && flutter build web --release` | Build succeeds. Existing Cupertino font metadata warning remains in the log. |

No golden baseline was regenerated. The root suite was run without `BEUI_SKIP_GOLDENS`. Raw JSON events, stderr, the exact failure names and messages, analyzer output, and build output are retained in `gates/`. Counts exclude hidden suite-loader tests.

The release JavaScript SHA-256 is `17b12e0d099f0d80edc1ba1bfdd529b2f156ac8de0ac469c1f85ae0b5e6b4998`. The parent serves that build on port 18118 for combined-build checks. A worker's earlier build is not substituted for this artifact.

## Integrated Tabs native input

All 24 native pointer-release to End/ArrowLeft checkpoints pass across pill, segment, and underline variants, light and dark themes, and both motion preferences. Each check validates the loaded JavaScript response and effective Flutter motion flag. Input and screenshots precede semantics activation; semantics is enabled only afterward to read the resulting selected label. The exact control coordinates are measured in a separate discovery context. Results and original screenshots are in `integrated-tabs-measured-a2942181/`.

The first attempt reused coordinates from a differently positioned worker gallery and missed the control. It failed with an empty observed row. Its script, result, and screenshot remain in `integrated-tabs-a2942181/`; it is not a widget regression or passing proof. The corrected run uses freshly measured coordinates without changing the built application. `parent-gate-manifest.json` records artifact hashes.

These native checks prove the listed focus and selection outcomes, not exact source pixels or animation trajectories.

These results do not establish exact source parity. Golden failures and the source implementation/state gaps remain work to complete. The coverage ledger is being reconciled against the archived evidence rather than treating the original empty audit as current coverage.
