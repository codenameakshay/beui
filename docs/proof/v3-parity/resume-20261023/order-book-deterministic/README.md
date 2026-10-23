# Deterministic Order Book behavior supplement

The bounded source/candidate behavior slice passes. No production, demo, shared recorder, golden, historical ledger, or audit-index edits were made. Files remain uncommitted for parent review.

Candidate library inputs were copied from parent HEAD `aa373177c1d18227926384cc2465b432f883235c`. Source inputs match pinned commit `a76e57c9bbc2837e96420b2610e9c82a3271bb05`; `pinned-input-check.json` compares every bundled checkout input against that commit. The wrappers use unchanged actual chart implementations and their public composed parts. `snapshots.json` supplies identical explicit arrays to both wrappers. Initial bids are 99×2, 98×3, 97×5; asks are 101×4, 102×6. Initial state is paused with no timer. Step selects one explicit snapshot whose quantities are all incremented by one. It is not the gallery demo's timer or Pause/Step algorithm.

## Results

`attempt-2/summary.json` contains four passing Chrome sessions, 70 capture assertions each. Each session retains 34 settled observations, original PNGs, trusted event logs, and a lossless MP4 encoded from the original compositor PNGs. The final four sessions contain 1,576 original compositor frames. The offline verifier independently recomputes expected cumulative quantities and quotes from the snapshots, checks actual focus and selection callbacks, checks replacement states, validates original input/media/served-JavaScript hashes, and checks decoded video frame counts.

- Ask A at 101: quantity 4 BTC, quote 404.00 USD, average 101.00.
- Ask B at 102: quantity 10 BTC, quote 1,016.00 USD, average 101.60.
- Bid A at 99: quantity 2 BTC, quote 198.00 USD, average 99.00.
- Bid B at 98: quantity 5 BTC, quote 492.00 USD, average 98.40.

Each A/B price receives native mouse hover, click selection, and exit. Native Tab traverses ask 101, bid 99, and bid 98 after clicking ask 102. Shift+Tab reverses traversal; Enter invokes the actual selection callback. Home and ArrowRight leave the price-button inspection unchanged, consistent with source. Reordering the input arrays retains keyboard focus and the price identity. Step retains focused bid 99 and changes its readout to 3 BTC / 297.00 USD. Keyboard fixture controls then empty the focused book or remove the focused side; all clear the old readout. Separate native control clicks verify empty, bids-only, asks-only, restore, and exact one-sided readouts.

Browser reduced-motion and effective Flutter `MediaQuery.disableAnimations` agree in both preferences. These are light-theme desktop sessions at 1000×800 CSS pixels and DPR 1. Screenshots and compositor frames are native 1000×713 pixels; they are not rescaled to the CSS viewport. Flutter is 3.47.1 / Dart 3.13.1. Browser version is retained in each results file. No DOM focus mutation or `locator.focus()` is used. A synthetic zero-coordinate click on Flutter's semantics placeholder enables semantics before native testing; the verifier allows only that bootstrap shape as an untrusted input.

## Identity and originals

Actual served source.js SHA-256 is `2daefa6f3a5061b307944420b29b30341a487588376bcc0034e7bc695dc68a31`.

Actual served main.dart.js SHA-256 is `a74782b7e46804d511718d91d87c89dcb37f7fee3ddd1a4ae551644e85e06087`.

`served-js/` retains original response bodies, including other loaded scripts. `source-inputs.json`, `source-input-originals.tar.gz`, and `source-package-lock.json` retain the source bundle's transitive inputs. `candidate-effective-inputs.json` and `candidate-input-originals.tar.gz` retain the candidate library, shaders, fixture, fonts, web bootstrap inputs and resolved pubspec locks. The earlier `candidate-inputs.json` records the initial copy before adding the omitted shaders and wrapper. Use the effective manifest for the actual build. Capture runtime lock and SDK identity are retained separately.

Builds ran only in `/tmp/beui-order-book-deterministic-20261023/`. Source is under `source/`; candidate is under `candidate/example/build/web/`. A dedicated Python server used checked-free port 18146. The native capture script follows the repository's [Chrome/Playwright workflow](../../shared-capture/RECORDER.md) and the [round-four observer](../../charts/round4-candle-volume/stills.mjs), with CDP original compositor frames and FFmpeg passthrough timestamps. The shared recorder was not edited.

## Verification and replay

Run from any directory after retaining this directory intact:

```sh
python3 /absolute/path/to/order-book-deterministic/verify.py
```

The verifier uses Python's standard library and installed `ffprobe`; it does not need the checkout, temporary builds, browser, or network. `archive-sha256.json` seals originals, scripts, indexes, and logs. The seal excludes itself and `verify.log`, which is the final verification output. Integrity and behavioral checks do not establish screenshot pixel parity.

For a fresh native replay with the retained temporary builds, start `python3 server.py`, then run `node capture.mjs NEW-ATTEMPT-NAME` from this directory. It uses installed Chrome and the documented `/tmp/beui-parity-capture-runtime` Playwright installation. Do not reuse an output name. `setup-original.py` records the original copy operation, not an idempotent rebuild command. Build source with `node build_source.mjs /tmp/NEW-SOURCE-OUTPUT` from the repository root. Candidate build command was `flutter build web --release --no-wasm-dry-run --base-href /candidate/example/build/web/` inside the isolated candidate example. The build logs retain dependency resolution and the existing missing Cupertino font warning.

## Prior evidence and rejected work

[evidence-supplement.json](evidence-supplement.json) indexes 68 matched source/candidate state pairs for the six public Order Book parts and references the current accepted [round-three archive](../../charts/round3/ARCHIVE-v11.json). It supplements [the current ledger](../coverage-ledger.md) without rewriting it. Its behavior-only records intentionally do not claim the historical audit's before/static/temporal requirements or reduce the 601-obligation aggregate.

The first candidate build failed because the temporary copy omitted package shader assets. The unchanged shader directory was copied and build 2 passed. Both build logs remain. Attempt 1 passed its narrower 29-state sequence but blurred the price by clicking fixture controls before replacement. Attempt 2 adds replacement while the price remains focused; attempt 1 is retained as narrower evidence. No assertion was weakened. The first offline verification ran before the final capture wrote its results and failed with FileNotFoundError. Its empty stdout, failure note, and interim seal remain. `verify-initial-complete.log` is the first completed passing offline run; `verify.log` verifies the final sealed archive.

## Limits and remaining defects

No behavioral defect was reproduced within this slice. Reorder here means the same price/size levels supplied in reversed input order; it does not certify arbitrary live market evolution. One-sided replacement uses the original surviving side. This is a deterministic fixture result, not full-demo live tick equivalence or a test of the gallery's play/pause timer. Overflow, other browsers, assistive technologies, mobile input, task-baseline footage and minimum SDK remain outside this slice.

The screenshots visibly differ in typography, surrounding theme, geometry, and focus decoration. No exact-pixel or visual-focus-ring parity is claimed, and no cause is assigned here. Typography remains parent-owned. Native behavior can pass while these visual differences remain open.

The compositor only emits changed frames. Final recordings measure 9.83–36.31 delivered frames/second across the full sequence, with approximately 1.58-second gaps during paused holds. These are observed capture cadence values, not application render FPS. Native60 trajectories and flash/spring timing remain unverified. No interpolation, frame duplication, golden updates, broad tests, hosted CI, push, deployment, or merge claims are made.
