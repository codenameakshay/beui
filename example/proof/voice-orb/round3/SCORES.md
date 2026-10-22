# Voice Orb design-compare (round 3)

Baseline: https://beui.dev/components/agents/voice-orb
Candidate: gallery `?section=agents&slug=voice-orb&theme=dark` primary orb, size 288.

## Rest (compare_designs widget / dark-ui)

| metric | score |
| --- | --- |
| overall | 89.05 |
| layout SSIM | 88.97 |
| color | 89.56 (mean ΔE 2.1) |
| content | 100 |
| spacing | 97.4 |
| typography | n/a (no text) |
| cv_findings | none |

Interior ridge vs cloudy cream is animation-phase, not a shader miss. Voice Orb has no hover on the source.

## Motion (compare_motion, 12 frames @ 130ms)

| metric | value |
| --- | --- |
| motion_status | compared |
| motion_score | 94.8 |
| energy_ratio | 0.948 |
| ref_moving | true |
| cand_moving | true |
| temporal_corr | -0.21 (unsynced living fields) |

Source WebGL captured via Puppeteer + SwiftShader (headless capture_frames cannot draw the source orb).

Parent revalidation (same committed crops): overall 89.05, layout 88.97, color 89.56 ΔE 2.1, content 100, spacing 97.4, typography n/a, cv_findings none. Motion 94.8, energy_ratio 0.948, both moving, temporal_corr −0.21.
