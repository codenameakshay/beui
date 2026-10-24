# Agent parity evidence

Baseline commit `5ec78ac30e1274727ddd185a883346e4d908e6c8`.
Reference repository `https://github.com/starc007/ui-components`.
Reference revision `a76e57c9bbc2837e96420b2610e9c82a3271bb05`.
Live reference `https://beui.dev/components/agents/voice-orb`.

The reference revision is the checked-out repository revision. The live site's deployed revision is not exposed and is not assumed to match it.

## Capture prerequisites

The baseline was built before widget edits with `flutter build web -t lib/visual_harness.dart --base-href /agents-before/ --output build/agents-before --no-wasm-dry-run` in `example/`.
Port 8104 serves `example/build`.
The shared visual harness and its inputs are unchanged.
The baseline build is immutable for this run.

The shared stage-width README confirms that `previewWidth` applies only to the explorer. These builds use the unchanged `visual_harness.dart` entrypoint, which ignores that parameter. No shared-width commit or capture-only baseline wrapper was applied. Original recordings therefore do not establish matched preview-stage constraints. `source-geometry.json` gives supplemental live source measurements taken later at the same viewport, not measurements at original recording time.

T3 preview opened owned reference and candidate tabs. Reference evaluation confirmed a 1440 by 1000 viewport.
Two reference snapshots failed with the same raw error.

```text
Preview snapshot failed: Preview automation snapshot timed out after 15000ms.
```

Reference recording failed with this raw error.

```text
Preview automation client server-browser disconnected during recordingStart.
```

Candidate snapshot and recording attempts failed with those same errors. A subsequent reference evaluation failed with this raw error.

```text
No preview automation host is available for evaluate in environment e23d8eea-cfe5-4e10-8c25-ad814f8c088e. The server-owned browser may be starting or reconnecting. Retry preview_status, then call preview_open if no tab is available. If it remains unavailable, report the browser connection failure.
```

The alternate browser capture uses separate owned Chromium pages after the repeated T3 failures. No reference assets, baseline frames, or shared capture target are edited to reduce differences.

## Throughput checkpoint

First capture the source and frozen candidate for every agent catalog page. Then fix a single demonstrated mismatch, run its behavioral tests, and repeat the same capture inputs against the changed candidate. Static or unreliable Design Compare results remain inconclusive for motion.

## Ownership

The parent audit at `fe9213f` requires all 19 new-badged agent routes, including the local-only `agent-theme` composition. Voice Orb is the only newly added agent widget file in `origin/main...5ec78ac`, but that file census does not narrow the required evidence. There are 18 live-source routes. Shared shell, catalog, barrel, theme, and engine changes belong to the parent.

The how and architect workflows are performed locally without their usual delegated exploration because this task explicitly prohibits further subagents.
The unavailable `control-ui` and `deslop` skills cannot be invoked. T3 preview and focused local inspection cover the applicable checks.

## Result and artifact index

This family is not complete and does not have exact parity. No route has a passing visual-parity verdict.

- `TESTING.md` gives exact regression names, commands, results, and all nine baseline golden failures.
- `GAPS.md` separates observed mismatches from states that still need matched captures and review.
- `route-inventory.json` preserves every agent route, part, source example, source preview hash, and required state from the parent audit.
- `recordings.json` gives every preserved recording path, SHA-256, byte count, and unmodified FFprobe metadata.
- `provenance.json` pins the implementation commit and release-build digests.
- `CHANGE_MANIFEST.md` links labeled before/after derivatives and a video for every new-badged route. Its text distinguishes owned repairs from unchanged routes.
- `source-geometry.json` records per-route preview stages and immediate child bounds without changing source or candidate layout.

The implementation commit is `56f83f4fe5606a87999274508a9109c4419eeb81`. The final release gallery is `http://localhost:8104/agents-final/?slug=voice-orb&theme=dark`. Replace the slug for each route.

The `before/` and `reference/` directories contain the original 18-route recordings. They also contain the Voice Orb light, mobile, and reduced-motion captures. `final/` contains the repaired 18-route recordings. `after/`, `after-demo-defaults/`, and `after-orb-only/` preserve intermediate candidates. These directories are not interchangeable.

`voice-orb-before-after.mp4` and `new-widget-voice-orb.mp4` are captioned derivatives of the frozen baseline and first orb-only repair. Their orb code matches the final implementation. The original WebM recordings remain unchanged. These derivatives demonstrate a visible repair, not exact motion equivalence.

The orb motion diagnostic used `after-orb-only/`, not the later candidates. Its score is 63.6 with negative temporal correlation. Reduced motion returned `static` with a null score. Neither result proves exact parity. The initial comparison used wall-clock screenshot samples without synchronized event timing.

The fallback recordings have a native cadence of 25 FPS. They do not meet the parent's 60 FPS fast-motion gate. The raw output appears in `recordings.json`. No upsampling or frame interpolation is used.

`decoded-review/` contains decoded 4-second frames from each of the 18 source, pristine before, and final videos. The three contact sheets use route order from `route-inventory.json`, read across each row. Inspection confirms visible widget content in these sampled frames rather than a uniform blank Flutter canvas. This is one-frame content verification, not a full-video or motion-parity review. Generic Tab events also place focus rings on different candidate controls, so these frames cannot serve as matched-state comparisons.

`flows/final/agent-theme/recording.webm` is local-only functional evidence. It records hover, expansion, replacement text `Shared layout proof`, collapse, approval, rejection, and request changes. The three outcomes start from separate reloads. The successful event log records both text and actual accessibility-tree outcomes. Decoded video frames at 4, 5, 8, and 11 seconds visibly contain the editor and each decision outcome. Two rejected recorder attempts remain in `flows/final-theme-first/` and `flows/final-theme-second/`. The first hit the tooltip-expanded accessible name `Edit Edit`. The second used body text where Flutter exposed the proposal only through an accessibility label. Neither error establishes an application defect. No source route exists for this composition, so it cannot receive a source-parity verdict.

The recovered recorder is available in the sibling capture-recovery worktree and is integrated by the parent. Its screenshot backend avoids the blank CanvasKit compositor problem. Its pointer-only protocol does not perform agent submit or approval actions. This slice retains its real route-specific flow recordings and does not duplicate that recorder. Recovered recording does not make native 60 FPS proof available.

## Recording limitations

The existing `flows.cjs` recorder rejects prompt-input when the submitted text does not enter the body at 200 milliseconds. That check is invalid for this source preview. Prompt-input renders a completion notice at 900 milliseconds and never renders the submitted prompt as a transcript. `flows/after/prompt-input/events.json` preserves that error. This rejected attempt is not proof of an application defect.

The chat-app submission attempt was also rejected. Its input target and actual submission need a route-specific investigation. The message and message-scroller recordings exercised submission, completion, and stop during pending. Their event logs use wall-clock timestamps, not the required monotonic protocol. Their hover coordinates do not prove each semantic hover target.

The capture-recovery worker owns recording infrastructure recovery. This slice preserves the raw failures and original files. It does not certify fast transitions from the fallback recorder.

## Skill decisions

Model the Domain kept the existing typed status and activity models. Test Behavior, Not Implementation led to rendered bounds, visible text, and live-region assertions. Fix Root Causes moved terminal announcements after the current frame instead of suppressing the framework error. Prove It Works kept local tests separate from unresolved visual and motion proof.
