# Select pilot evidence (pre-implementation)

## Scope and provenance

This is a diagnostic of the preserved **default Select** baseline only. It is
not a parity verdict. The pinned source is `starc007/ui-components`
`1ab921e62283e788a686bc4bafa1de5ff56104ea`; the immutable Flutter widget
revision is `792ad82dca47cdf317fdd94f0bb9251724f562e2`, with dependency-only
prerequisite `835f4396d1cc397fc3a0f3360b242464138e171c`. The local prerequisite
head recorded by the pilot is `cb38aae5037749c4de656780f67d6596c9048e53`.
The baseline artifact directory is
`/Users/codenameakshay/.t3/artifacts/beui-v3.1.0/baseline-792ad82d-lucide1.67.0`;
the suffix is historical and misleading: the resolved `flutter_lucide` is
**1.63.0**. The capture protocol records verification of `provenance/BASELINE.md`,
all 68 checksums in `provenance/web-output.sha256`, and unchanged audited
`lib`, `test`, and `example/lib` bytes before baseline acquisition.

Canonical source preview: `components/previews/motion/select.preview.tsx:12-29`
in the pinned source. It is controlled with selected value `next`, a 224px
wrapper, placeholder “Pick a framework,” and options Next.js, Remix, Astro,
Vite. Capture viewport was 1280×800, dark theme, normal motion. The source T3
DOM reported Geist/Geist Mono loaded; the separate sampled-capture headless
font environment was not directly measured. The Flutter baseline used the
same selected value/options and matched viewport/theme; its font state is not
independently verified. Source and candidate full-page layouts differ, and
their widget crops retain different page backgrounds (source docs divider;
Flutter Morph heading/trigger behind the dropdown).

## Preserved capture and comparison records

The immutable sampled captures live outside git under
`/Users/codenameakshay/.t3/artifacts/beui-v3.1.0/components/`:

| State | Source acquisition | Flutter baseline acquisition |
|---|---|---|
| Closed/rest | `source/select-default-closed/frame_000.png`, crop `[460,400,280,240]`, SHA-256 `d05414aa391c8ba3b7490a22f098db7eb4203a4cd1aab5f65cc5858527a3c179` | `before/select-default-closed/frame_000.png`, crop `[632,352,280,240]`, SHA-256 `1101eacbf46263012a032a9db39bbdbc410e65513a1e040f2c516661ecad7ed6` |
| Open sampled sequence | `source/select-default-open/`, 24 frames, requested interval 30ms; first `frame_000.png` SHA-256 `aa2847d1dcbff1ce2cabb1db823c9a105347fd51a8a5b300f68136ef5085056b`, last `frame_023.png` SHA-256 `0f140bf533f916e014bd700663a3c58da3144907cb06182f5bd8b63707777260` | `before/select-default-open/`, 24 frames, requested interval 30ms; first `frame_000.png` SHA-256 `b7f28e5770203fc39d5cfa90eee1aa0240470c0fc40e947dafc053328267eea1`, last `frame_023.png` SHA-256 `78178654ec9caecc151d37fe621d5365f09fef5ea47a814068e0ac87d3576ff4` |

The closed comparison args are `docs/proof/v3.1.0/components/select-static-diagnostic-args.json`;
the corresponding diagnostic is
`docs/proof/v3.1.0/components/select-static-diagnostic.json`. It reports
overall **75.28**, comparison key
`b430d72b3be7e6581a335d9dd2a9e5f3c6e01841b1517b31c25084535ef354e9`, run key
`af3f50f366b4463f20e78810e8895964a1b1300f3c1e7e35ae80c4fa821720c9`, and
input RGB SHA-256 values `fb119a0f78ec0e7c5310719a1a183f27509a05c38dbf44bad2816ceffffae083`
(source) and `6c5e2c69e5b6dcc00eacdefd954487d28fa705a9474ea43ab5caf57805a6253e`
(candidate), both 280×240. This score is **confounded by crop background and
surrounding docs/gallery content**: the diagnostic sees 9 candidate text
regions versus 1 reference region, while the crop includes the distinct Morph
background locally and docs divider on source. The score is not a widget-only
fidelity measurement or acceptance threshold.

The motion args are `docs/proof/v3.1.0/components/select-motion-diagnostic-args.json`;
the diagnostic is `docs/proof/v3.1.0/components/select-motion-diagnostic.json`.
It reports 24 sampled frames per side, `motion_presence_mismatch` (reference
not moving, candidate moving), `motion_energy_score: 0`, inconclusive timing,
and `cadence_verified: false`. The source's first image partially reveals
rows, while its last image is settled. The tool's motion threshold labels that
sequence non-moving. The candidate's first image has no rows, and its last is
settled. These observations do not establish matched interaction phases or
prove when either animation elapsed. Both acquisitions
record only a **requested** 30ms interval; `capture_frames` supplies no
decoded/compositor timestamps. The interval is not evidence that a 30ms-timed
recording elapsed. These samples cannot prove duration, easing, cadence, or
temporal parity.

The acquisition protocol is preserved in
`docs/v3.1.0/components/select-pilot-protocol.json`. Preview snapshot timed out
twice at 15 seconds. T3 recording start timed out; stop hung and returned no
recording, with state unknown, so it was not restarted. The fallback capture
was the actual configured Design Compare MCP `capture_frames`; it is sampled
frame evidence only. No new browser, process, build, or capture was started for
this report.

## Gate matrix

| Gate | Evidence/status | Verdict |
|---|---|---|
| Pinned source and unchanged Flutter baseline identity | Revisions and baseline checksum record above; source preview state is identified | Provenance recorded, not parity |
| Closed/rest visual comparison | Static score 75.28 with crop/background/content confounds | Diagnostic only; no static pass |
| Open/rest visual comparison | First/last sampled images preserved; no matched open/rest score recorded | Pending |
| Open/close/reopen interruption behavior | Not covered in sampled captures | Pending |
| ArrowDown / Enter / Escape keyboard protocol | Not covered in sampled captures | Pending |
| Motion presence, duration, easing, cadence | Mismatched active phases; no compositor timestamps; cadence false | Inconclusive; no timing pass |
| Focus/semantics, controlled/default open, disabled/dynamic options | Audit may identify static source/API gaps; no runtime capture here | Pending behavioral verification |
| Reduced motion, touch, placement/RTL/responsive, native, performance | Not in this pilot's captures | Pending |

## Prepared timed-capture configurations

`select-timed-source.json` and `select-timed-before.json` are schema-shaped
inputs for the **existing, unchanged** `tool/parity_capture.mjs`. They prescribe
the same 1280×800 dark, `no-preference` session and an explicit sequence:
open/hold/close, reopen then interrupt by closing, reopen and send ArrowDown
/ Enter, reopen and send Escape, followed by a settled hold. Source uses the
default trigger coordinate `[600,455]` from the reviewed acquisition protocol.
An accessible-name-only locator would also match the separate Morph trigger.
The baseline uses the trigger coordinate `[772,406]` from the reviewed
preserved before-capture args. The Select unit remains the default preview;
Morph is out of scope.

The baseline config carries its independent `main.dart.js` URL/hash and
baseline revision from the verified passive template. The source config
intentionally omits `servedJs`: the preserved Select acquisition has no exact
served-response JavaScript manifest/hash, and the passive button template's
hash cannot be asserted as Select's without observing the response. Therefore
the source config is **provisional**; before using it as accepted evidence,
pin `servedJs` to the exact Select response URL/SHA-256 and source revision
from a verified acquisition manifest. The recorder's `scripts.json` records
all served JavaScript hashes on an authorized capture. At preparation time
neither config had been executed. The acquisition below supersedes that
execution status without changing either original config.

## Timestamped acquisition on 2026-11-05

Both prepared configs ran through the unchanged `tool/parity_capture.mjs`
after the authorized preview failures. Source output is
`components/source/select-default-timed`; before output is
`components/before/select-default-timed` under the durable artifact root above.
Each directory preserves original frames, config, scripts, environment,
event dispatch bounds, compositor timestamps, and `capture.mp4`.

Source returned 183 decoded frames over 3433.24ms. Its largest compositor
gap was 283.32ms. Flutter before returned 189 decoded frames over 3320.42ms,
with an 83.33ms largest gap. Both recorder runs exited zero, reported no
errors, and passed their video checks. These are recording statistics, not
application-performance measurements. Fast-motion timing remains inconclusive.

The source config remains provisional and unchanged. Its captured
`scripts.json` records the motion preview chunk as HTTP200 with SHA-256
`0a18093eb2ee0cf3714482fd2513cfb2466ef839fd3a8509eafc4d2dd9b2bbe5`.
Supplemental provenance belongs in `select-timed-acquisition.json`, not in
rewritten originals. No after runtime has been captured or certified.

Owner inspection of Flutter's first recorded frame found readable Lucide
glyphs in this Select run. This does not resolve the separate Message-run
tofu report. CanvasKit's empty `document.fonts` collection and
`document.fonts.ready` do not establish engine-font readiness. Both recording
and source/before state outcomes still require per-event review. MCP static
and motion diagnostics remain separate gates.
