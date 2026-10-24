# Held pointer capture

The shared recorder accepts `down` and `up` actions for held presses and mouse pans.
These are the exact action names. `press`, `pointerdown`, and `pointerup` are not config aliases.
Chrome receives real mouse input and emits trusted DOM pointer events.
This recorder support is not component parity certification.

## Action protocol

`down` and `up` accept an optional `target` and an optional `button`.
An omitted target uses the current pointer position.
A named target moves the pointer to that target before the button transition.
That move and transition share one action's dispatch interval in `timeline.json`.
An omitted button means `left`, including on `up`.
The supported buttons are `left`, `middle`, and `right`.
A non-left press therefore needs the same explicit button on its release.

Only one button can be held at a time.
The recorder rejects unmatched releases, repeated presses, button chords, clicks during a hold, and unreleased presses.
It rejects unsupported buttons and button fields on `move`, `key`, or `text`.
These checks run before output creation, Playwright import, or browser launch.
Existing target and payload checks also run during this preflight.

Existing `move`, `click`, `key`, and `text` actions retain their behavior.
An omitted action type still means `move`.
Clicks default to `left` and accept the same supported button names.
The recorder preserves the supplied config in `config.json` and records effective button defaults in the timeline.

This sequence holds the pointer at `start`, pans through two named positions, and releases at `end`.
Each explicit move has its own requested time and dispatch interval.

```json
[
	{ "atMs": 200, "type": "move", "target": "start" },
	{ "atMs": 400, "type": "down", "button": "left" },
	{ "atMs": 900, "type": "move", "target": "middle" },
	{ "atMs": 1100, "type": "move", "target": "end" },
	{ "atMs": 1300, "type": "up", "button": "left" }
]
```

Targets use the existing named coordinate or accessible-role format.
No movement steps or intermediate frames are synthesized.
The existing `atMs` scheduler, screenshot backend, compositor backend, and video encoding remain unchanged.
Original PNG frames and their hashes remain in each new capture directory.
Reduced-motion checks and actual Flutter and served-JavaScript probes remain unchanged.

After a dispatch error, the recorder attempts to release the held button before closing Chrome.
An already closed or disconnected page cannot receive a release.
The browser still closes if that cleanup attempt fails.

## Verification

The repeatable checks use these commands from the repository root.

```sh
node --test tool/parity_capture_config.test.mjs
PARITY_PLAYWRIGHT=/tmp/beui-parity-capture-runtime/node_modules/playwright-core/index.mjs node tool/parity_capture_test.mjs
```

The fixture starts only its own temporary HTTP server, not a gallery server.
Both motion preferences retain the existing hover, click, text replacement, and Enter checks.
Chrome must observe a trusted left-button press, two moves with `buttons=1`, a release, and a move with `buttons=0`.
The first held move must occur at least 100ms after the press in Chrome's event timestamps.
A separate capture checks right and middle button masks, target-free presses, and a targeted release.
An invalid key during a balanced planned sequence must produce a trusted release during error cleanup.
Malformed pointer configs must fail without creating their output directories, even with an invalid Chrome path.

The test checks requested and actual dispatch times, PNG hashes, and decoded frame counts.
It prints each retained temporary capture path.
Each capture also retains `observed.json` with the fixture's actual DOM events.
Original frames are not replaced, duplicated, or interpolated for the test.
Native 60fps and component interaction parity remain unproven by these checks.

## Local result on 2026-10-23

All six config tests passed. The real Chrome fixture exited successfully.
Both motion preferences passed the exact held-pointer sequence and legacy input assertions.
The explicit right and middle button checks passed.
All three malformed configs failed before output creation. Error cleanup emitted a trusted `pointerup` with `buttons=0`.
The normal, reduced-motion, and alternate-button videos contained 94, 94, and 37 frames respectively.
The normal and reduced-motion runs passed every original PNG hash and decoded-frame-count assertion.

The retained local output root is
`/var/folders/nd/g6xnd2650d5444zpkr29ppgm0000gn/T/beui-capture-events-1uq47g`.
Its capture directories are `capture-no-preference`, `capture-reduce`, `capture-buttons`, and `capture-cleanup`.
The last directory retains the expected key error and the observed cleanup release, not a successful video.
These temporary artifacts can expire. The test commands reproduce the checks without a gallery server.
