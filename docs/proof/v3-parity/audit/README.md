# v3 parity audit

## Verdict

NOT_CERTIFIED. No widget has a complete matching source, task-baseline before, repaired-head after, interaction timeline, cropped comparison, and text-of-changes record in this audit.

This is an evidence audit, not an implementation review or a new visual approval. Existing tests and scores do not change this verdict.

The audit owns only `docs/proof/v3-parity/audit/` and `tool/parity*`. It does not change implementations, goldens, existing proof, package metadata, or dependencies. No agents were spawned. No push or PR creation occurred.

## Revisions and scope

- The released comparison is `a4d493aba5ed70fdf5baba3e4844649971ce7234`.
- The immutable task baseline is `5ec78ac30e1274727ddd185a883346e4d908e6c8`.
- The upstream code reference is `starc007/ui-components` at `a76e57c9bbc2837e96420b2610e9c82a3271bb05`.
- Upstream HEAD and the clean components, charts, and agents reference clones all resolved to that SHA on 2026-10-23.
- PR [#26](https://github.com/codenameakshay/beui/pull/26) was open against `main`, with head `5ec78ac30e1274727ddd185a883346e4d908e6c8` when inspected. This is not a hosted-CI verdict.

`CLAUDE.md` and all of `docs/PORTING_SPEC.md` were read. The spec's 72-page, three-family catalog predates the live four-family registry. Its requirements for parts, variants, controlled state, keyboard, semantics, reduced motion, and canonical preview data still apply. Its tolerance-based spring tests do not satisfy the user's additional exact-UI and video requirements.

`reference-health.json` records current registry responses for Tooltip, Treemap, Voice Orb, and Card Folder. Their primary source files match the pinned clone after removal of the registry's injected `// beui.dev/...` attribution line. Their included component dependencies match too. This is a four-component code sample, not proof of the production deployment SHA or all live previews.

## Inventory

`inventory.json` contains every route, its new badge, changed-demo flag, source files and hashes, source example install targets, public widget parts, and demo hash. `widget-index.md` provides the readable index.

The baseline catalog contains 111 routes. There are 54 components, 25 blocks, 19 agents, and 13 charts. The committed `docs/proof/v3-ship/show-me.html` claims 109 and 23 blocks. Those counts are stale.

Evidence is required for 76 routes. There are 28 components, 16 blocks, 19 agents, and 13 charts. This includes new-badged routes even when their implementation predates this release. Agent Theme is an additive local composition with no source registry page.

The diff contains 49 changed library files and 185 public widget classes in those files. Of these, 181 names are added and four existing names occur in changed files. The existing names are `BeuiInput`, `BeuiSharedLayoutBackground`, `BeuiTabs`, and `BeuiTooltip`. A changed-file flag does not assert that every method of that class changed.

The 17 new component pages do not include every new widget. Metallic Button, Digit Swap, Text Scramble, and Inline Slider are new targets under existing pages. Composable parts are individual widgets. Source examples and all 185 changed widget names are indexed separately. Shared chart widget parts belong to every chart route, not an invented gallery route.

`states.json` defines explicit scenarios for all 111 routes. Every required route also owes rest, hover-exit, keyboard, and reduced-motion evidence. Each named source example is an additional obligation. Each public part must occur in a passing composition record. This matrix is a capture floor, not a claim that every source union or prop has already been behaviorally certified.

## Observed gaps

1. There is no source/before/after evidence record with matching data, dimensions, state transitions, and repaired-head provenance. `evidence.json` deliberately starts empty. Existing artifacts remain available in `existing-assets.json` with original Git blob IDs.
2. `docs/V3_COMPONENTS_GAP.md` explicitly excludes agents, blocks, and charts. It admits Timeline placeholder imagery, simplified Arc Picker geometry, missing Color Picker trigger morph, missing Stepper liquid connection, linear Color Selector travel, incomplete Tooltip composable wrappers, and an Image Viewer cross-route gap. Under the user's exact-parity requirement, these are unresolved gaps, even where that document calls them nonblocking.
3. `docs/proof/v3-components/REVIEW.md` says the visual proof predates repairs and goldens were skipped. `SCORES.md` says iframe hover often missed its target. Its full-viewport tooltip motion result was `static`. Neither is a visual approval of the task baseline or future repairs.
4. `.github/screenshots/charts/pr23-review.md` names wrong or incomplete demo data and controls. Examples include one status series instead of two, an extra funnel stage, an always-visible bump legend, different order-book framing, and missing source simulation chrome. It also records composition keyboard inspection after pointer exit and volume tooltip placement gaps. Some comments about shared Tooltip APIs are stale relative to the consolidated baseline. Every claim needs recapture, not automatic acceptance or rejection from that old review.
5. The charts MP4 has five frames over 5.64 seconds at `125/141` FPS. It cannot show all 13 charts' point-to-point transitions. The blocks MP4 has 64 frames over eight seconds at eight FPS. The component text MP4 has 16 frames over two seconds at eight FPS. The orb MP4 has 12 frames over 1.56 seconds at `100/13` FPS. None supplies the required baseline-before and repaired-head-after pair for every widget.
6. A fresh comparison of committed treemap hover directories returns `motion_status: static`, `motion_score: null`, reference energy `0`, and candidate energy `0.00002`. There is no captured source point transition to judge. Raw output is in `treemap-motion-probe.json`.
7. The committed orb directories reproduce motion score `94.8`, energy ratio `0.948`, and temporal correlation `-0.20631311692169196`. Similar energy is not matched trajectory, timing, interaction, or renderer behavior. Its unaligned living fields require a seeded or scripted comparison protocol.

## Actual comparison capabilities

Design Compare `ping` returned `pong: true`, protocol `1`, version `0.11.0`. Only `ping` and `compare_motion` are exposed in this session. There is no callable `compare_designs`, URL capture, ROI argument, static-image diff, or video comparison endpoint in the discovered catalog. Old reports that mention `compare_designs` do not make that endpoint available now.

`compare_motion` accepts frame directories or frame-path arrays, loads at most 240 frames by default, and can return signature visuals. Videos require extraction first. It does not accept event timestamps, semantic point identities, or a crop. Matching cadence, cropping, and event alignment are the caller's responsibility.

Actual probes in `tool-probes.json` show these limits:

- Three identical decoded frames return `static` and null score, even when energy ratio is one.
- Passing the same pathname twice is not two frames. It returns `ValueError: need at least 2 frames, got 1`.
- The tooltip enter pair at 1440 by 900 returns energy `0.00022` and `static`.
- The same pair cropped to `x=460, y=370, width=220, height=100` returns energy `0.01308` and `compared`.
- The crop self-comparison score is 100 because both inputs are the same pair. It is a sensitivity probe, not source parity evidence. Two frames cannot establish a trajectory.

FFmpeg and FFprobe are available. A cropped tooltip-frame SSIM probe returned `0.928492`. This compares two different moments of the same candidate, not source against candidate. The reusable crop script runs successfully at the native eight FPS and rejects a requested 60 FPS. Duplicated frames cannot create missing timing evidence.

## Recording blockers

T3 `preview_status` initially returned `available: false`. `preview_open` created an agent-owned beui.dev tab and subsequent status reported available. Recording and screenshots still failed.

The first recording error was `Preview automation recordingStart timed out after 15000ms.` The retry returned `Preview automation client server-browser disconnected during recordingStart.`

Two snapshot attempts returned `No preview automation host is available for snapshot in environment e23d8eea-cfe5-4e10-8c25-ad814f8c088e.` The fallback `cua.createBrowserTab("iab", ...)` returned `Browser is not available: iab`. No successful T3 recording or screenshot was produced. No recording-stop transfer was claimed.

The exposed T3 recording API supports selecting a tab, starting recording, and stopping with a transferred environment-local evidence path. The stop tool documents a 50 MiB transfer limit. There is no exposed recording FPS, codec, ROI, event marker, or reduced-motion setting. `preview_resize` controls CSS dimensions, not device pixel ratio. `preview_set_appearance` controls light or dark, not reduced motion. These capabilities are catalog facts, not successful runtime proof in this environment.

The baseline gallery was started with `flutter run -d web-server --web-port 8105 --web-hostname 0.0.0.0` in this worktree's `example/`. An HTTP GET returned 200. This is only server-liveness proof. No claim of rendered gallery health follows from it. Flutter automatically changed `example/analysis_options.yaml` at startup. That generated edit was removed and is not part of the audit.

## Audit checks

- `node --check tool/parity_audit.mjs` passed.
- `node tool/parity_audit.mjs self-test` passed. It rejects empty proof, missing provenance, static motion, unreliable capture, and null motion scores.
- `sh -n tool/parity_roi.sh` passed.
- The crop script extracted 16 native-cadence frames from the existing two-second video, without scaling.
- The crop script rejected a 60 FPS request against that eight FPS input with exit code 2.
- `node tool/parity_audit.mjs check` returns exit code 1 and `NOT_CERTIFIED`. `coverage-result.json` records every missing obligation and widget-part capture.
- The check records 601 state and source-example obligations plus 185 missing widget-part captures. No obligation has a complete passing record.
- Regenerated inventory matches `inventory.json` exactly. All 111 routes have explicit scenario rows.
- All 476 original proof artifacts retain their task-baseline Git blob IDs.
- `git diff --check` passed before commit.

No full Flutter analyzer, widget test suite, golden regeneration, hosted CI, mobile device check, or production visual approval was attempted by this audit. Those are separate gates.

Poteto-mode's Visual Parity playbook kept the baseline immutable. Prove It Works required actual tool probes and a failing completeness check. Model the Domain produced route, state, and capture records instead of one score per family. Build the Lever produced the rerunnable index and crop tools. Technical Writing and Unslop kept the report separate from the capture procedure.

The skill's delegation and per-component PR steps were skipped because the user prohibits agents and requires one consolidated PR. The referenced `deslop` plugin is not installed. The available Unslop pass was used instead. No skill installation or memory update occurred.
