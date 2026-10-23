# MultiSelect chip-removal repair

This component-owned repair changes only `lib/src/motion/multi_select.dart` and its focused test file. The shared overlay is unchanged. The isolated native candidate starts from the retained `1254bfa63a70298061c557616abeb9c6a67db372` library snapshot and replaces only MultiSelect. At capture time the only difference between this snapshot and the shared checkout's other library files was the concurrent Sortable work. No commit, push, children, broad suite, golden update, or old proof edit was performed.

## Source contract and cause

The exact source pin is `a76e57c9bbc2837e96420b2610e9c82a3271bb05`. `trigger.tsx:138-154` removes the chip and focuses the input. Input focus opens the popup at lines 244-247. `context.tsx:261-269` proposes a filtered value without clearing query. The source fixture confirms that closed and open chip clicks open/retain the popup, focus INPUT, propose removal once, and accept subsequent typing under both motion preferences and both selection owners. Source input bytes and hashes are retained in `source-inputs/` and `source-input-bindings.json`; they were checked against Git objects at that exact pin.

The candidate used BeuiOverlay's default full-screen opaque hit-test barrier and focus trap. The barrier intercepted open-popup chip clicks as dismissal. Supported `barrier: false` and `trapFocus: false` options remove that obstruction without modifying the overlay. A shared component tap-region group covers trigger, text field, and popup, preserving outside dismissal without dismissing inside clicks.

Native testing exposed a second issue after that repair: the immediate focus request briefly focused INPUT before native focus moved back to FLUTTER-VIEW or FLT-SEMANTICS. Subsequent `zz` typing did not edit the query, even though widget tests passed. Grouping the text field alone did not repair it. The final chip handler requests input focus after the rebuild in a guarded post-frame callback. Keyboard removal no longer makes the redundant immediate focus request. The chip handler proposes opening only when closed; controlled owners still decide the effective value, open state and query.

## Tests and attempts

`test-red.log` records eight failing-first cases against the original production implementation: initially open/closed, accepting/rejecting controlled values, and normal/reduced motion. `test-green-r3.log` records all 17 focused non-golden tests passing. The suite includes subsequent input, callback count/payload, rendered chips, focus, popup, Escape, outside dismissal, disabled options/component, and controlled open/query rejection. `analyze-r3.log` reports no issues for the two owned Dart files. Earlier green widget logs remain because they did not establish native correctness.

- Attempt 1 used revision 1 (`candidate-r1`). It demonstrates the remaining native focus/typing failure. Reloading reset its native event log, so its earlier closed-pointer screenshots and observations are retained but its event trace is incomplete.
- Attempt 2 used revision 2 (`candidate-r2`), adding the text-field tap group. It still demonstrates native focus/typing failure. Its recorder preserves both pre-reload and post-reload event histories. One run also recorded response-body errors for redirects; these are recorder resource-read failures, not asserted component exceptions.
- Attempt 3 uses the final `candidate`, deferred chip focus, and a recorder that reads bodies only from successful resource responses. All final behavioral checks must pass in the portable verifier. Every unsuccessful attempt, original PNG, checkpoint, timestamp video, and complete frame-index replay remains in this archive.

The source production bundle is the independently built and retained source fixture from the prior native archive, reused byte-for-byte. Each candidate revision has an isolated release build and retained production inputs and bundles. `exact-hashes.json`, `identity*.json`, `input-lock.json`, and served-response hashes identify exactly what ran. This is a supplemental fixture, not an unchanged gallery screenshot.

## Native coverage and limits

Attempt 3 runs source and candidate at 1000 by 800, DPR 1, light scheme, with installed Chrome and the documented Playwright runtime. It checks fresh closed-popup Alpha removal and subsequent `zz` typing, Escape and outside dismissal, then reloads to check empty-query Backspace, nonempty Backspace, open-popup Alpha removal and subsequent typing, disabled pointer selection, and Home/ArrowDown/Enter skipping Disabled. Accepting and rejecting controlled selection owners run under `no-preference` and `reduce`.

Observations include actual native input values and active elements, visible chips, popup accessibility, public callback payloads/counts, owner state, trusted browser events, browser version, and served bytes. There are no programmatic focus calls or dispatched behavioral events. The only synthetic click enables Flutter accessibility before behavior begins, explicitly retained and exempted in event verification. Programmatic fixture observations expose only fixture-owned state and public callbacks.

Controlled open/query rejection and a wholly disabled component are widget-tested; native fixtures exercise controlled selection rejection and disabled options. Escape closes the popup, but candidate native focus at the measured Escape checkpoint is BODY, while source retains INPUT. Disabled-option pointer focus also differs between frameworks. These are retained limitations. No exact parity, native60, pixel identity, timing certification, mobile-device, screen-reader, hosted CI, or release-readiness claim is made.

## Portable verification

Run `python3 verify.py` with Python, Pillow, ffmpeg and ffprobe installed. The verifier needs no checkout, dependency installation, browser, network, or original absolute paths. It checks regular-file hashes, source bindings, candidate identity, served production bundles, all PNG hashes, decoded timestamp-video counts, and exact RGB equality for every frame of every lossless frame-index replay. It independently checks the final callback/query/focus/popup and regression-control observations.

Timestamp videos can drop frames during encoding. Their decoded counts are disclosed per run in `verification-summary.json`; the separate 25 fps lossless frame-index replay preserves every original PNG but does not certify original timing. `archive-sha256.json` excludes itself and verification output logs. A separate regular-file export is verified at `/tmp/beui-multiselect-repair-export-20261023`.

## Bounded result

The final eight native runs pass all 548 checks. Across three attempts the archive retains 5,638 original PNG frames and 24 run records. `timestamp-count-differences.json` discloses every timestamp-video count mismatch. The first verifier run completed frame decoding but failed an incorrect recorder event-count expectation: accepting owners make seven pointer clicks, rejecting owners make eight because Alpha remains for the supplemental closed check. `verify-error-r1.log` preserves that failure; the verifier now checks the owner-specific count.

Only the matching task-owned server processes recorded in `servers.json` were stopped. `ports-before.txt` and `ports-after.txt` record free ports 18163 and 18164.
