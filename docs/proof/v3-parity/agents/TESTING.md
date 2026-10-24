# Agent repair tests

Implementation commit `56f83f4fe5606a87999274508a9109c4419eeb81`.
Baseline commit `5ec78ac30e1274727ddd185a883346e4d908e6c8`.
The baseline checkout is `/tmp/beui-agents-baseline-audit`.
No golden images were regenerated.

## Completion regression

The exact regression name is `completion flush updates the ancestor live region after build` in `test/motion/transcript_announce_test.dart`.

The test renders `BeuiStreamingResponse` inside `BeuiMessageScroller`, changes streaming to complete, and checks the ancestor's actual live-region text. The unpunctuated tail forces the terminal flush. The baseline calls ancestor `setState` during a descendant build. The repair defers the flush until after that frame.

The repaired command passed one test. Its raw log is `completion-regression-green.txt`.

```sh
flutter test test/motion/transcript_announce_test.dart \
  --plain-name 'completion flush updates the ancestor live region after build' \
  --reporter expanded
```

The same composition failed on the exact baseline in `test/motion/completion_regression_repro_test.dart`. Only the new reproduction test was added to that detached checkout. Its library files remain unchanged. The raw log is `completion-regression-baseline-red.txt`.

```sh
cd /tmp/beui-agents-baseline-audit
git rev-parse HEAD
flutter test test/motion/completion_regression_repro_test.dart \
  --plain-name 'completion flush updates the ancestor live region after build' \
  --reporter expanded
```

The baseline error is `setState() or markNeedsBuild() called during build.` The affected ancestor is `BeuiTranscriptLiveRegion`. The minimal reproduction is preserved in `completion_regression_repro_test.dart.txt`. That fixture belongs under `test/motion/` with its `.txt` suffix removed when reproduced, because it imports `../support.dart`.

## Focused repairs

The following command passed 62 tests. The raw log is `final-focused-tests.txt`.

```sh
flutter test test/motion/agents_parity_demo_test.dart \
  test/motion/voice_orb_test.dart \
  test/motion/transcript_announce_test.dart \
  test/motion/streaming_response_test.dart --reporter expanded
```

The new demo regression names are listed below.

- `image preview follows the source cycle and replay`.
- `prompt preview starts without unsourced attachments`.
- `shared chat preview hides completion actions like source`.
- `reduced-motion chat delivers its full reply without a delay`.
- `chat prepares for 420ms then streams once into its answer`.
- `voice preview matches source at 390.0px`.
- `voice preview matches source at 639.0px`.
- `voice preview matches source at 640.0px`.
- `voice preview matches source at 1440.0px`.
- `orb failure stays stationary at full activity`.

`red-image-demo-tests.txt`, `red-agent-demo-tests.txt`, and `red-tests.txt` preserve the pre-repair failures. Tests do not establish browser pixel or motion parity.

The theme command passed 24 tests. Its raw log is `agent-theme-tests.txt`.

```sh
flutter test test/theme/beui_agent_theme_test.dart \
  test/motion/agent_theme_apply_test.dart --reporter expanded
```

`flutter analyze` passed with no issues. The raw log is `final-analyze.txt`. The release build passed. Its command and raw output are in `repaired-build.txt` and `provenance.json`.

## Nine baseline golden failures

The earlier broad agent run passed 436 tests and failed these nine goldens. A fresh baseline-only command reproduced all nine failures with the same pixel counts. The raw combined log is `baseline-nine-goldens.txt`. Earlier reproduction logs remain in `baseline-goldens.txt` and `baseline-tool-approval-golden.txt`.

| Test file | Full test name | Pixel delta |
|---|---|---:|
| `code_block_test.dart` | `settled golden (complete, line numbers, highlight)` | 6 |
| `tool_result_test.dart` | `BeuiToolResult golden — completed result with actions` | 135 |
| `todo_list_test.dart` | `golden — in-flight plan with all four row states` | 156 |
| `prompt_input_test.dart` | `rest-state golden` | 297 |
| `file_diff_test.dart` | `settled golden (complete, open, tinted rows)` | 8 |
| `approval_card_test.dart` | `BeuiApprovalCard theming golden — pending, expandable, and rejected` | 448 |
| `citations_test.dart` | `settled golden (open panel, static rows)` | 10 |
| `tool_approval_test.dart` | `BeuiToolApproval golden — pending, destructive, and approved tiers` | 1701 |
| `agent_activity_test.dart` | `golden — complete summary, open stream, and a failed card` | 210 |

The long dash characters in this table are verbatim test names.

The exact fresh baseline command is shown below. It returns exit code 1 with zero passes and nine failures.

```sh
cd /tmp/beui-agents-baseline-audit
git rev-parse HEAD
flutter test test/motion/code_block_test.dart \
  test/motion/tool_result_test.dart test/motion/todo_list_test.dart \
  test/motion/prompt_input_test.dart test/motion/file_diff_test.dart \
  test/motion/approval_card_test.dart test/motion/citations_test.dart \
  test/motion/tool_approval_test.dart test/motion/agent_activity_test.dart \
  --name golden --reporter expanded
```
