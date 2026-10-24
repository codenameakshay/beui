# Reproduce

The retained disposable copy is `/tmp/beui-initial-edit-engine-r8`. To rerun the final instrumented case, use:

```sh
cd /tmp/beui-initial-edit-engine-r8/engine/src/flutter/lib/web_ui
export PUB_CACHE=/tmp/beui-initial-edit-engine-r8/pub-cache
export TMPDIR=/tmp/beui-initial-edit-engine-r8
export CHROME_EXECUTABLE='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
/tmp/beui-initial-edit-engine-r8/dart-sdk/bin/dart run dev/felt.dart test \
  --compile --run --browser=chrome --compiler=dart2js \
  test/engine/semantics/initial_edit_boundary_test.dart
```

Expected exit code is 1, with 5 passes and 4 retention failures. The ordinary `dart test` rerun suggestion printed by the test library omits felt's artifacts/bootstrap. Use the felt command above.

For a fresh disposable source copy, verify the SDK framework HEAD and engine.stamp against `inputs.json`. Copy its `engine/`, `bin/cache/dart-sdk/`, and `bin/cache/flutter_web_sdk/` into a new scratch root. Do not run the following setup in the shared installation. Set PUB_CACHE and TMPDIR inside the new root before running any tools. The source patch paths are relative to `engine/src/flutter/lib/web_ui`:

```sh
# In the disposable engine/src/flutter/lib/web_ui directory:
patch -p1 < /absolute/path/to/combobox-engine-boundary/regression-and-trace.patch
# Copy the retained pubspec.lock here before dependency resolution.
/path/to/scratch/dart-sdk/bin/dart pub get --enforce-lockfile
/path/to/scratch/dart-sdk/bin/dart run dev/felt.dart test --copy-artifacts \
  --browser=chrome --compiler=dart2js \
  test/engine/semantics/initial_edit_boundary_test.dart
```

The final command may fail at the documented missing fallback-font directory. Inspect its log; do not ignore another failure. The run here had already built `engine/src/out/web_tests/artifacts/host/host.dart.js` and copied primary fonts. Copy the pinned `flutter_web_sdk/flutter_js/` and `flutter_web_sdk/canvaskit/` directories into `engine/src/out/web_tests/artifacts/`, preserving those names. Then run the narrow `--compile --run` command using the new scratch paths. No fallback-font/image placeholder is needed for this test. A complete engine dependency checkout can instead use the stock artifact phase.

For the engine-instrumentation-free comparison, restore the two files in `baseline/lib/src/engine/` to their original relative locations in the disposable copy. Move the trace recorder declarations from the instrumented text_editing.dart into `test/engine/semantics/initial_edit_trace.dart`, and import that helper from the new test. Run the same felt command. `run_uninstrumented.py` automates this for the retained scratch paths, obtains original files from the pinned shared SDK read-only, and restores the instrumented copy. Its logs are overwritten on rerun, so preserve them first. The expected result is again 5 passes and 4 failures.

The test is synthetic engine ordering evidence. It does not use native typing, a gallery, or a production workaround.
