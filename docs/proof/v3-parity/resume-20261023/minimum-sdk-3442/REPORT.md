# Flutter 3.44.2 minimum SDK verification

Flutter 3.44.2 / Dart 3.12.2 is the lowest version now verified for fresh dependency resolution under unchanged constraints, compilation of the actual adapter, the 240-case Chromium DOM contract, release compilation of the actual Bump fixture, and its native forward/reverse/dismissal assertions. The requested actual ancestor reorder was NOT observed. This task therefore does not certify causal focus-repair behavior on 3.44.2. The prior archive's lowest causal version remains 3.44.3, based on historical evidence, not a rerun here.

## SDK and inputs

Installed official GitHub Flutter tag 3.44.2 separately at flutter/. Commit c9a6c484230f8b5e408ec57be1ef71dee1e77020, engine 77e2e94772b6eb43759e34ed1ad7da4674e19cab, bundled Dart 3.12.2. See sdk-clone.log, sdk-commit.txt, sdk-remote.txt and sdk-version.log. Detached official tag reports channel [user-branch] and repositoryUrl unknown source; remote and commit establish its provenance.

Parent HEAD read as aa373177c1d18227926384cc2465b432f883235c. Copied 396 current regular files into package/, using the previous round's file inventory. Bytes were copied, with no parent symlinks, hardlinks, .git, lockfiles, .dart_tool or build output. Included lib, shaders, assets, actual test entrypoints and example. input-hashes.json indexes inputs; final input-recheck.json verifies every parent and copied source still matches. All package and example locks/configuration were freshly generated inside this archive. HOME and PUB_CACHE were isolated for SDK and pub/build commands. Existing default SDKs and configuration were not changed.

The previous /tmp/beui-pr26-min-sdk-20261023-evidence archive remains unchanged. Its boundary source evidence maps 3.44.0 to Dart 3.12.0 and 3.44.1 to Dart 3.12.1. Neither satisfies Dart ^3.12.2. Do not claim stock Flutter 3.44.0 supported or loosen Dart based on this run.

## Commands and raw results

run.py preserves exact command arguments and working directories in each *-result.json, with corresponding raw *.log files. All six phases exited 0: sdk-version, pub-get, adapter-compile, contract, example-pub-get, bump-build. Compilation used this SDK's dart compile js -O2 test/web/semantics_move_guard_entry.dart. Contract used REQUIRED_BROWSERS=chromium with the documented PLAYWRIGHT_MODULE and CHROMIUM_EXECUTABLE overrides. contract/results.json records 240 cases, zero errors, HeadlessChrome/156.0.0.0. Optional Firefox and WebKit were unavailable in the isolated HOME; neither was installed or claimed.

The actual fixture was built from package/example with flutter build web --release --target=../test/charts/bump_parity_fixture.dart and served on owned port 18147. Build passed, including its default Wasm dry run, which is not runtime Wasm verification. The raw build log retains a missing CupertinoIcons font-family warning; no font or source was changed to suppress it.

## Native assertions and causal limitation

The unchanged archived beui-focus-production-reproduce.mjs ran side after with REVERSE=1. native-no-preference and native-reduce each passed 21 states. Five repeat runs and four runs with the existing PACE option at 16, 30, 50 and 100 ms also passed 21 states each. Three additional runs used beui-focus-append-observer.mjs, which adds only an observer around Element.append because the original records only insertBefore. It delegates to the installed production adapter unchanged, computes expected child order, records native active focus, and throws on focus/order failure. Original reproducer is retained unchanged. No diagnostic rotation, injected focus or recovery was enabled.

All 14 runs passed, totaling 294 observed states. Exact expectations remain in the preserved reproducer: plot focus, Studio Apr rank 4 and May rank 3 focus/readouts; Home/End/ArrowDown/ArrowRight retention; Enter pin; Space down/up behavior; Escape close; Enter-after-Escape pin without reopening; Jun focus/readout; Studio and Canvas legend focus; legend Escape; reverse legend; Frame Sep rank 5 with previous rank 4 in Aug; reverse Escape; Frame Aug rank 4 with previous rank 5 in Jul; outside dismissal. Input assertions require trusted keydown/pointerdown events. Motion assertions check Flutter disableAnimations; validation additionally checks browser reduced motion and served-main hashes.

All traces recorded zero production-active-move requests. Retained-focus/order checks over that empty set are NOT causal evidence. The 240 synthetic DOM cases must not be substituted for a real Flutter ancestor reorder. native-summary.json, each run's states.json, trace.json, served.json, native event logs and PNGs preserve the result, including all zero-reorder runs. validate.py and validation.log cross-check 21 states per run, trusted input, effective browser motion preference, served JS and any observed move's retained/exactOrder values. The missing actual reorder remains the unresolved gate.

## Hashes and scope

key-hashes.json records source, fixture, contract, generated locks, adapter JS and fixture JS hashes. Fixture source: f54e06a427e510556a7dcd76701af71f8606ae417ffba6c8f4fe506db19ee526. Compiled adapter JS: 5888e6051a3a2d9dfbcabafdf4e90086113d05291352dc427f6e79ba41823bf5. Served main.dart.js: 5c48ef5eb38e294999d2b29a014718a209feafd1615a9e55314014d76927ae2c. Every native run's observed main.dart.js hash matches the build file. SHA256SUMS indexes evidence and source/build outputs, excluding bulk installed SDK/pub-cache/HOME and generated package caches.

No parent repository, git, production, configuration or dependency edits; no broad tests, unrelated builds, children, commits, pushes or PR operations. Port 18146 was not used. Screen-reader behavior, other browsers, timing/pixel parity and physical devices remain unverified. The local server was stopped after verification.
