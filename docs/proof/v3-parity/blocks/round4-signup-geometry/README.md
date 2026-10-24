# Signup source geometry and native workflow follow-up

The final candidate build is `c66a8825`, served JavaScript SHA256 `55ed90091a0f2213adc12a478b6013faa43cbf88aa60cfe38c4126dd84e19bcb`. It includes signup repairs through `1dca20f4`. The capture wrapper uses the existing `source-default-a76e57c9` palette; public themes remain unchanged. Source implementation is pinned to `a76e57c9`; the live deployment revision is unknown.

The earlier `native-af4522f8` sequence predates the final confirmation gap and presence fixes. It remains before/diagnostic evidence, not final proof.

## Verified behavior

Eight final source/candidate browser sequences cover light/dark and normal/reduced motion. Each observes rest, invalid submission, entered name, full values, revealed password, busy inputs, rejected email, successful correction, and keyboard access to Sign in. Native pointer/keyboard actions drive the workflow. DOM semantics are used to observe these sequences. All pass.

Four separate recordings use native coordinates and keyboard without enabling semantics. Original final frames were inspected: source and candidate both visibly reach Account created under normal and reduced motion. All original frames, exact timing, served response hashes, probes and video decode metadata are retained. These recordings demonstrate the paced success path; they do not establish exit-retarget behavior or exact motion parity.

| Preference | Source | Candidate |
|---|---|---|
| Normal | [Video](captures/source-light-no-preference/capture.mp4) | [Video](captures/candidate-light-no-preference/capture.mp4) |
| Reduced | [Video](captures/source-light-reduce/capture.mp4) | [Video](captures/candidate-light-reduce/capture.mp4) |

Native sequence: click Name; type Ada Lovelace; Tab and type email; Tab and type password; Tab/Space reveal; Tab and type confirmation; Tab/Space terms; Tab/Enter submit. Event dispatch timestamps are in each timeline. Dummy data stays within demo flows.

The four recordings contain 993 original PNGs. CSS viewport is 1280×1400 at DPR1; Chrome delivered 1280×1313 frames. Measured average cadence ranges from 14.05 to 41.43 frames/second. No interpolation or native-60fps claim. Fast-motion verification remains inconclusive.

## Repairs and remaining gaps

Typography, 96px field spacing, confirmation gap, and keyboard footer access have actual-Geist gallery tests. Input reserved errors retain their 22px line/gap allocation. Signup message presence retains exits, handles rapid retargeting, and preserves source opacity durations under actual platform reduced motion. Seven dedicated presence tests cover these policies.

Exact visual parity is not certified. Text rasterization, shared control appearance, focus styling, and fast-motion samples remain separate gates. Earlier intermittent missing glyphs remain historically unresolved; these four inspected final frames have visible icons. Successful later captures do not prove the cause of earlier deficient pixels.

`node docs/proof/v3-parity/blocks/round4-signup-geometry/verify.mjs` verifies the complete byte inventory, eight final observed sequences, all original frames, effective motion flags, served JavaScript and actual decoded frame counts. No goldens or earlier archives were changed.
