# Capture browser actions and motion preferences

The recorder combines the recovered `d9ff199` click, key, and text dispatcher
with validated reduced-motion config. The recovery was cherry-picked here as
`62d8ab9`. Do not apply both copies of the recovery commit.

Run the recorder from the repository root. Every output directory must be new.

```sh
export PARITY_PLAYWRIGHT=/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs
node tool/parity_capture.mjs /absolute/config.json /absolute/new-output
```

Set `reducedMotion` to `reduce` or `no-preference`. Omission retains the legacy
`no-preference` default. Other non-null values fail before output creation.
The recorder observes browser `matchMedia` and fails if it disagrees.

Use these event shapes inside `events`.

```json
[
  { "atMs": 400, "type": "move", "target": "search" },
  { "atMs": 600, "type": "click", "target": "search" },
  { "atMs": 900, "type": "text", "text": "Shared layout" },
  { "atMs": 1200, "type": "key", "key": "ControlOrMeta+A" },
  { "atMs": 1500, "type": "text", "text": "Replacement" },
  { "atMs": 1800, "type": "key", "key": "Enter" }
]
```

Move and click need a named target in `targets`. Key and text act on the focused
element. A missing event type still means move. Text inserts a literal string
with an input event. It does not synthesize character keydowns.

For a candidate build that publishes the shared Flutter probe, add
`captureProbe=1` to its URL and `requireFlutterProbe: true` to config.
`environment.json.flutterCapture.disableAnimations` records the actual
`MediaQuery` value at the demo. A mismatch fails before the first frame.
This option does not implement a Flutter preference override. Older builds
without the probe fail this check instead of being treated as observed proof.

Add `servedJs` with an exact script `url`, its expected `sha256`, and a
`revision` label. The recorder hashes response bytes from the actual page
load and rejects a missing or mismatched script before capture.
`scripts.json` retains all observed JavaScript response hashes. Use the actual
build revision, or label a dirty build with its base revision and input hashes.
Never assign the pinned source SHA to an unknown live deployment.

An optional `stageSelector` records matching DOM rectangles and backgrounds.
The browser viewport, DPR, and encoded video dimensions remain separate values.
Native 60fps remains unresolved. The recorder does not duplicate or interpolate
frames, and input dispatch does not prove a component's resulting state.

## Verify the combined recorder

```sh
node --test tool/parity_capture_config.test.mjs
PARITY_PLAYWRIGHT=/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs node tool/parity_capture_test.mjs
```

The first command checks validation, effective preference mismatches, and script
hash enforcement. The real Chrome fixture checks both motion preferences,
pointer entry, button click, input focus, text replacement, and Enter submission.
It asserts the fixture's observed DOM events, not just successful dispatch.
It also verifies event timestamps and retains each original capture in the
temporary directory printed by the test. The committed logs are
`config-tests.txt` and `recorder-events-tests.txt`.
