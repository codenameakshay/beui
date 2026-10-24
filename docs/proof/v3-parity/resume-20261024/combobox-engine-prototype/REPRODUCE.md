# Reproduce the rejected candidate

Retained scratch is /tmp/beui-initial-edit-engine-r9. Run only the new boundary file or the existing semantics text-field file:

```sh
cd /tmp/beui-initial-edit-engine-r9/engine/src/flutter/lib/web_ui
export PUB_CACHE=/tmp/beui-initial-edit-engine-r9/pub-cache
export TMPDIR=/tmp/beui-initial-edit-engine-r9
export CHROME_EXECUTABLE='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
/tmp/beui-initial-edit-engine-r9/dart-sdk/bin/dart run dev/felt.dart test \
  --compile --run --browser=chrome --compiler=dart2js \
  test/engine/semantics/initial_edit_boundary_test.dart
```

Expected: exit 1, 16 passes and 6 failures. Substitute test/engine/semantics/text_field_test.dart for the existing narrow suite, expected exit 0 and 22 passes. Do not use plain dart test, which omits felt bootstrap/artifacts.

For a fresh disposable checkout, follow the adjacent combobox-engine-boundary/REPRODUCE.md pinned fresh-copy steps, placing all tools, caches and TMPDIR inside the new root. Apply r8-regression-and-trace.patch, then candidate.patch, both with patch -p1 from lib/web_ui. Replace test/engine/semantics/initial_edit_boundary_test.dart with this archive's source copy. Use the pinned lockfile and real packaged CanvasKit/flutter_js artifacts as documented there. Alternatively copy r8 to a NEW scratch path, rebase .dart_tool/package_config.json paths, apply candidate.patch and copy the final test. Never run setup in r8 or the shared SDK. No full SDK or dependency cache is bundled here.

For the baseline comparison, save the candidate semantics file and replace it with baseline/text_field.dart in the disposable engine only. Run the same final boundary test. Restore the candidate afterward, even on test failure. This baseline includes r8 trace instrumentation and no candidate behavior. Expected failures and counts are recorded in results.json. The final test has no dependency on candidate-only methods, so it runs unchanged on baseline.

Run python3 verify.py from this archive to verify artifact hashes, the six specific candidate failures, trace count/caps, and narrow suite success. This verifier checks archived evidence; it does not execute Chrome or establish native correctness.
