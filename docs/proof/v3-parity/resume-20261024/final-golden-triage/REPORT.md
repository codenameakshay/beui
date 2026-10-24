# Golden triage checkpoint

All 56 requested failure identities are mapped in [CLASSIFICATION.md](CLASSIFICATION.md) and [classification.json](classification.json). Recommendation: retain 21 environment/toolchain cases without regeneration; review 35 intentional changes individually, repairing five chart capture timings before any reference update. No demonstrated production rendering regression was found in these comparisons. This is a classification checkpoint, not a green release gate or proof that every component state is correct.

## Controls and result

The frozen current inputs are HEAD `313a9627e` plus the exact working files hashed in current-inputs.json. The parent's four formatting edits and analyzer change were present when copied. All execution used /tmp copies. The parent subsequently committed its changes; final observed HEAD is recorded separately in provenance.json. Results apply to the frozen hashes, not an assumed latest HEAD.

| Control | Result |
| --- | --- |
| Current snapshot, isolated Flutter 3.47.1 / Dart 3.13.1 | All 56 requested failures reproduced; all 56 rendered images are pixel-identical to the prior archived failures; one additional selected sibling golden passed |
| Same snapshot, isolated Flutter 3.44.4 / Dart 3.12.2 | 5 requested goldens passed; 51 requested goldens failed. Additional BeuiButton sibling golden fails, giving 52 failures / 5 passes across the 57 selected tests |
| October author commits, Flutter 3.47.1 | All 32 requested goldens pass exactly; one extra component sibling also passes |
| July/August author commits, Flutter 3.44.4 with compatible Lucide resolution | All 24 requested fixtures execute. Five references pass exactly; 19 have residual pixel differences. No compilation failures remain in the selected final author controls |
| Author-render vs current-render on 3.44.4 for the 21 environment cases | Pixel-identical in every case. Five equal the stored reference; sixteen retain 2–58 historical differing pixels |
| Five suspicious charts with 40 sequential 100 ms pumps | Missing paths, candles, arcs and bars appear. All five still differ from old references because source geometry/style intentionally changed |

The five reference passes on 3.44.4 are Checkbox, both ChatApp shells, PopoverMorph, and WheelPicker. A broad golden-name selector also selects BeuiButton, outside the original 56. Its additional 3.44.4 failure means downgrading the whole gate is not a complete repair. Do not hide it in the original failure counts.

## Authoring environment

There is no per-PNG authoring manifest that proves an exact original OS patch/build and SDK for every historical golden. That part of the requested provenance cannot be fully recovered from Git/docs; it must remain unknown rather than inferred as fact.

- `.fvmrc` says `stable`, not an exact release.
- CI is pinned to Flutter 3.44.4. Commit `4326ff4ff` records verification of all 1,024 package tests locally; `f9eb9c0fa` records all goldens passing on macOS and Linux-only mismatches. These support 3.44.4/macOS as the historical control for the older set, but do not prove each PNG was originally generated on that precise SDK.
- The declared current supported floor is Flutter 3.44.2 / Dart 3.12.2. We used exact supported stable 3.44.4 / Dart 3.12.2; provisioning the deleted 3.44.2 was unnecessary for the causal comparisons. Shared installations were not changed.
- The October references reproduce exactly at their author commits on Flutter 3.47.1 / Dart 3.13.1, macOS 27.0.1 build 26A434, arm64. This is a verified compatible environment, not a recovered author machine manifest.
- Root `test/flutter_test_config.dart` loads no fonts. Root goldens predominantly use Flutter's Ahem test face; some fixtures explicitly choose Ahem or request monospace without loading a production font. The gallery's real Geist setup is separate and was not imported. Ahem files in both isolated SDKs have identical SHA-256 `63d2abd0041c3e3b4b52ad8d382353b53c51c6785e76ce56ed9dacad2d2e31c4`. There is no evidence of an Ahem file replacement causing the SDK difference.
- Older source snapshots did not track pubspec.lock. Fresh offline resolution selected Lucide APIs incompatible with those snapshots. Failed first attempts are retained. Temporary `pubspec_overrides.yaml` pins flutter_lucide 1.11.0 for July/August 7 snapshots and 1.31.0 for August 18 snapshots. These satisfy their declared bounds and compile the historical icons. Locks for each run are retained. This establishes compatible controls, not exact original dependency lock reconstruction.

Environment drift here includes residual OS/engine/dependency effects. The experiment does not isolate the 2–58 historical pixels to a particular macOS or engine patch. It does show that those pixels are unchanged by current source for the 21 classified cases. The remaining older cases, ApprovalCard, CodeBlock and FileDiff, also contain intentional changes and are classified in that bucket with environmental residuals disclosed.

## Proposed implementation boundary

No production edits or golden regeneration were made. No original reference, prior failed image or prior log was changed. All 56 reference hashes match the starting snapshot, as recorded in provenance.json.

1. Assign only the five chart fixture files for a timing repair: `test/charts/{bump_chart,candlestick_chart,donut_chart,order_book,volume_profile}_test.dart`. Preserve the fixture's original motion preference; reduced motion intentionally retains opacity fades. A single two-second pump is insufficient for chained timer/animation starts. The diagnostic control uses forty 100 ms frames. The implementation should use a bounded settle appropriate to each fixture, with a paint/content assertion before capture. This is a stale test-contract issue following intentional animation changes, not evidence that production paint is missing after settling.
2. Review the 35 per-golden reasons and reference changes on the chosen supported gate environment. The current first-frame chart images must not become the new rest-state references. SignupForm's capture bounds also need explicit review. All other proposed updates are limited to the listed deliberate changes, not permission for blanket regeneration.
3. Keep the 21 environment cases intact. Choose and document an exact environment policy separately. The historical OS build is unavailable, and a global tolerance or pass-through comparator would conceal changes. This checkpoint does not propose either.
4. After assigned fixture/reference work, run focused changed goldens, then the required full root and example validation once on the accepted exact SDK. Full suites were not redundantly rerun while all 56 known comparisons still failed and no implementation had changed. Existing full-suite evidence remains in ../components-integration/. This new work proves focused classification only.

## Reproduction and retained evidence

`run.py` runs current controls. `author-controls.py`, `author-pinned.py`, and `author-lucide131.py` reconstruct exact author source with `git archive` into /tmp, resolve dependencies there, and run only relevant golden tests. `history.py` maps each original identity to its PNG's latest authoring commit. `compare-controls.py` compares decoded RGBA pixels, including transparent RGB. `chart-control.py` retains the insufficient single-pump experiment; `chart-frames.py` records the sequential-frame control. `report.py` builds the final map and provenance. Absolute execution paths, full argv, exits and elapsed times are in each *.command.json. `BEUI_SKIP_GOLDENS` was removed for every test; no `--update-goldens` command was used.

SDKs were APFS-cloned from installed 3.44.4 and stable 3.47.1 into `/tmp/beui-final-golden-triage/sdk-*` using `cp -cR`, without touching shared installations. The first attempted release-index URL returned HTTP 404; installed exact stable SDK clones made downloading unnecessary. Dependency resolution modifies only temporary locks. Original shared pubspec files/locks were untouched.

Each final author run has raw logs, stderr, commands, resolved lock and failure images. The first incompatible dependency attempts remain alongside them. Current controls also retain all failure PNGs. `component-history.txt` records relevant commits; classification.json names causal changes. Seven visual sheets were inspected for all 56 pairs. Full-size Card images and enlarged CodeBlock/FileTree crops were inspected; the five chart frame controls were inspected separately. These contact sheets aid review and do not replace original-resolution PNG evidence. The earlier original failure archive is preserved in ../components-integration/golden-failure-feedback/.

No commits, pushes, merges, child agents, production edits, shared SDK edits, or unrelated file changes were performed by this task. Work remains at the requested checkpoint pending parent path assignment.
