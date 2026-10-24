# Three-component gallery verification

Fresh release gallery build passed. Actual Collapsible, Combobox and Availability Scheduler routes were exercised with trusted browser pointer/key inputs in installed Chrome, under both no-preference and reduce. This is bounded gallery behavior evidence, not an unconditional behavioral pass. Combobox immediate Escape/type observations vary between attempts; details below.

## Identity

Accepted production commit: `ee5b755599cead69fabf30079af1be9634f80280`. Initial HEAD matched it. The parent then committed integration documentation, advancing HEAD to `594d607a196d7607997946facf6e7362ce250a02`. No production/test/example/package diff exists between those commits. All recorded committed inputs match accepted production; final-input-identity.json distinguishes ignored, locally resolved package locks and package_config from committed sources. These local resolved files are included and hashed. All recorded build inputs stayed unchanged.

Fresh command: `flutter build web --release --no-pub`, in the existing example/ checkout. Flutter 3.47.1 / Dart 3.13.1, with exact SDK output, command times, status and free capacity retained. Existing caches were reused. Missing Cupertino font-family warning retained in build.log. No source-comparison build was needed.

Served main.dart.js SHA-256: `27f85b5e40e2528bbc787be0e0a2af23fea6e081f4bdfe87c6c01e68a36a0aed`.

| File | SHA-256 |
| --- | --- |
| `lib/src/motion/collapsible.dart` | `298d69810e2a002fc96518e62cc81fc33fa49c6f4df7cc7bcbc633e3df414f53` |
| `test/motion/collapsible_test.dart` | `331ef5a58cd1fa86a5196bb0f0a3994afb4ad0dcd7bcf2984bef6dee5b3b91e4` |
| `lib/src/motion/combobox.dart` | `4d3d7dcccb86162b198182488cdaa022c8da61ef3d739d075f9eb1c377ca1fca` |
| `test/motion/combobox_test.dart` | `af6be0fe80755361e1dcc12438207f6e6fd6c38440f18d02725cce217a3db1fe` |
| `lib/src/motion/availability_scheduler/copy_menu.dart` | `b3a48de0ac3adf9f824ada52a8a142bcc671f3369e7a575c6dd9cfe23cde9047` |
| `test/motion/availability_scheduler_test.dart` | `4fcd24ee754298800c488b09f39e55f30989cb9daf7e6233744aa37e9ecf90c8` |

Input lock covers package/gallery Dart, web entrypoints, six affected production/test files, manifests, locks and package configuration. Supplemental shaders/font assets were recorded after build and verified against accepted Git blobs; they were not independently snapshotted before build. Resolved-build-dependencies.json records post-build hashes of files named by newly emitted dependency files, including external SDK/pub-cache paths. Those external caches are not copied or represented as a portable rebuild environment. Complete fresh web output is retained in gallery-web/ and build-manifest.json. served-build.json records HTTP SHA-256 for every output file; each browser context independently records the served executable scripts. Every context fetched the expected main.dart.js.

## Observed behavior

- Collapsible: both preferences pass initial hidden content, pointer open, Enter close, Enter reopen and rapid pointer close/reopen. The text returns intact. Actual content is static text only. Focusable descendant, dynamic child replacement, stateful-child retention, external controlled-state rejection and fixture lifecycle cases are inaccessible in this gallery composition and are not certified.
- Combobox run-1: both preferences filter Product to Product team, Escape closes the panel and restores Design studio, retyping Play then ArrowDown/Enter selects Playground, and zzzz displays No workspaces found. Trusted events and states are retained. The final immediate Escape then Pro sequence ended with an empty field and closed panel in both contexts; it had no explicit assertion in that first capture script. This observed limitation is not converted into a pass by its empty failure list.
- Combobox follow-up: immediate Escape/ArrowDown reopened the options in both preferences. Later Escape/type Pro retained Pro and showed options, but the retained snapshots include all options, so the weak Product-presence assertion does not establish correct filtering. The reduced-motion initial Pro entry was empty by its snapshot. These variable results leave reliable rapid Escape/type/filter behavior unresolved. Ordinary settled Product filtering and keyboard selection above are independently observed. No source, timing or pixel conclusion follows.
- Scheduler: scheduler-3 and scheduler-4 complete under both preferences. Native Tabs reach Every day; Enter copies Monday to all days, enabling Saturday/Sunday. Escape closes the copy panel. Native Tabs reach enabled Apply after choosing Tuesday. Pointer unchecking Tuesday disables Apply and moves browser focus to that checkbox; Enter leaves the entire recorded accessibility tree unchanged, including unrelated background state. This is not the fixture-only external update that disables Apply while preserving focus on it. No focus() or synthetic activation was used to manufacture that state.
- Scheduler-4 adds Monday's second 6:00 PM–7:00 PM range through the actual Add time button. Choosing Saturday, tabbing to Apply and pressing Enter copies both ranges to Saturday, while Sunday remains at one. Choosing Sunday and clicking outside cancels without copying the second range. There is no explicit Cancel button in this demo; cancellation is outside-click/Escape. Checkboxes have empty accessible names; their observed order is Tuesday through Sunday, and the corrected runner uses these actual ordered controls. Initial Tab after opening reached the related Project Folder button before entering the menu; keyboard traversal is observed, not certified as a trapped dialog.

## Attempts and limitations

All 14 contexts are retained. run-1 Scheduler timed out on an incomplete accessible name; actual names include the Copy times tooltip prefix. scheduler-2 reached Every day/Escape but timed out expecting a named Tuesday checkbox. scheduler-3 corrects the unnamed checkbox locator. scheduler-4 adds a changed-range Apply/cancel test. No failed capture was deleted. build-attempt-1 preserves the pre-build assertion rejected when the parent advanced HEAD; the accepted production comparison was then used. Other read/identity command errors are in reconnaissance-errors.txt.

Viewport 1440x1100, device scale 1, light theme. Routes use `?slug=collapsible`, `?slug=combobox`, `?slug=availability-scheduler`, with theme=light&captureProbe=1. They are the real gallery compositions. MatchMedia, gallery disableAnimations and platformDisableAnimations agree in every retained state, with null motionOverride. The only synthetic activation is the documented FLT-SEMANTICS-PLACEHOLDER bootstrap click. All subsequent captured pointer/key/input events are trusted; no DOM focus restoration or substituted fixture is used.

Visual samples inspected: reduced Collapsible reopen, normal Combobox Product filter, Scheduler initial state and normal Scheduler changed-range Apply. Content and schedule values agree with semantics and are legible. This is sampled visual inspection only. No source parity, native60/frame-rate, motion timing, pixel parity, screen-reader, hosted CI, minimum-SDK or release-readiness claim is made. Existing root 2668 pass / 56 unchanged golden failure identities and gallery 66 pass were read from components-integration/REPORT.md, not rerun.

## Archive verification

Run `python3 verify.py` from this directory in a regular-file export, with Python Pillow, ffmpeg and ffprobe installed. It uses no browser/network/cache dependencies. It checks archive/input/build/served identities, all screenshots and original frames, effective preferences, trusted inputs with the bootstrap exception, video decoded counts, exact RGB reconstruction from frame-index FFV1 videos, and the retained failed-assertion set. Independent checks cover Collapsible visibility, Scheduler focus transition, unchanged disabled-Enter tree, copied Saturday ranges and cancelled Sunday range. Integrity success does not certify every observed behavior or every capture assertion.

Capture scripts depend on the documented /tmp/beui-parity-capture-runtime Playwright installation and installed Google Chrome; package locks are retained. Original PNG frames, metadata, screenshots, trusted input records, timestamp MP4s and lossless frame-index videos are preserved. No native60 cadence is inferred from CDP screencast frequency. archive-sha256.json excludes itself and verifier output logs, avoiding self-reference.

Only an OS-allocated loopback port bound by this task was used, recorded in server.json. That owned server was stopped, with server-stopped.json retained. Initial free capacity was about 1 GiB; the build reused existing output/cache paths. No original or unowned evidence was removed. Only the authorized new proof directory, /tmp scratch and normal example build output were written. No production/test/shared edits, children, Git mutations, commits or broad suites were performed.
