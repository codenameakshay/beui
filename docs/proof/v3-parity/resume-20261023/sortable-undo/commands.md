# Commands and provenance

Worktree base: `1254bfa63a70298061c557616abeb9c6a67db372`.
Pinned React source: `a76e57c9bbc2837e96420b2610e9c82a3271bb05`.

The source component, ease and utility files were copied verbatim and checked against `git show` at that pin. `source-pin` contains its original package metadata and Bun lock. The supplemental fixture uses its own recorded npm package-lock, including lucide-react 1.16.0. This is not a reproduction of the upstream site's complete build. `source-inputs.json` maps every esbuild input to a content-addressed archived copy; `source/metafile.json` preserves the build graph.

Candidate was copied into `/tmp/beui-sortable-undo/candidate` after the eligibility fix, with every library Dart file checked against the shared checkout. The fixture's example app uses that isolated path dependency. Full candidate library, assets, shaders, fixture entry point, package locks, web input and release web output are archived. No gallery or shared primitive was edited.

Commands executed:

- `flutter test test/motion/sortable_list_test.dart --plain-name controlled` on baseline with new tests: two failures.
- `flutter test test/motion/sortable_list_test.dart --plain-name 'external saved-order'` on baseline: failure.
- The same reset test in `/tmp/beui-sortable-red`, with the baseline production file and final tests, calls the retained action before checking disabled UI: expected one callback, observed two. See `red-action-guard-2.log`.
- `flutter test test/motion/sortable_list_test.dart --name '^(?!rest-state golden)'`: 15 passes. The rest-state golden was excluded by name. No golden was changed.
- `dart analyze lib/src/motion/sortable_list.dart test/motion/sortable_list_test.dart`: no issues.
- `node /tmp/beui-sortable-undo/build-source.mjs` builds the source bundle. The first missing-lucide failure is retained. `npm install --save-exact lucide-react@1.16.0` ran only in the isolated source fixture.
- In isolated `candidate/example`: `flutter build web --release --no-web-resources-cdn --pwa-strategy=none`.
- `lsof -nP -iTCP:18159 -iTCP:18160 -sTCP:LISTEN`: no listeners before use. Python static servers then reserved source 18159 and candidate 18160 on loopback.
- `node capture.mjs attempt-4` runs the corrected bounded sequence; `node capture-direct.mjs attempt-5-direct` runs direct native Tab to A then ArrowDown for rejected ownership.
- Captures use `/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs` and `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome` as requested. Driver inputs are Playwright keyboard and mouse events. No driver programmatic focus, synthetic key dispatch, Space pickup or Escape cancellation is used.
- `python3 verify.py` verifies the archive offline. It requires Python 3 and ffprobe. `python3 verify.py --require-parity` additionally fails on recorded native assertion failures. Neither command claims screen-reader certification, exact pixels or native60.

The capture scripts are task-local copies of the prior Returns Calendar workflow's CDP frame collection and encoding approach. Existing recorder files were not edited. Original timestamps are retained for completed captures. The interrupted first attempt has only original frames and an explicitly untimed 25 fps index replay because its metadata was not persisted before the redirect-read failure. No original PNG or video was discarded.
