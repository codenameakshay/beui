# Commands

- Before launch: `lsof -nP -iTCP:18165 -iTCP:18166 -sTCP:LISTEN` found no listeners.
- Source server: `python3 -m http.server 18165 --bind 127.0.0.1 --directory /tmp/beui-sortable-focus/source`.
- Candidate server: `python3 -m http.server 18166 --bind 127.0.0.1 --directory /tmp/beui-sortable-focus/candidate/example/build/web`.
- Initial red: `flutter test test/motion/sortable_list_test.dart --plain-name 'Undo transfers keyboard ownership'`.
- Exact-input red replay: same command in `/tmp/beui-sortable-focus-red`, with final archived tests and original component.
- Final green: `flutter test test/motion/sortable_list_test.dart --name '^(?!rest-state golden)'`.
- Analysis: `dart analyze lib/src/motion/sortable_list.dart test/motion/sortable_list_test.dart`.
- Web builds in `/tmp/beui-sortable-focus/candidate/example`: `flutter build web --release --no-web-resources-cdn --pwa-strategy=none`.
- Captures: `node capture.mjs attempt-1-baseline`, then `node capture.mjs attempt-2-focus-nodes`; baseline driver preserved as `capture-baseline.mjs`. `node capture-uninterrupted.mjs attempt-3-uninterrupted` ran the sequence with no recovery.
- `python3 replay-mismatches.py` found no timestamp frame losses in the new captures.
- `python3 seal.py` checked source pin and final owned-file hashes; `python3 archive.py` exported inputs, builds and all media.
- `python3 verify.py` passed offline integrity; `python3 verify.py --require-parity` exited 1 for native focus failures.
- Owned server PIDs 35954 and 35958 were verified and terminated after capture. No other server was stopped. Driver PID 39900 cleanup is separately documented.

Flutter commands and all native runs are supplemental local evidence, not hosted CI or deployment proof. No file was staged by this task. Logs/build files may be ignored by repository rules and require explicit inclusion when the parent archives this work.
