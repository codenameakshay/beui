# Card motion review

The pinned source is the interaction specification. Generic motion simplification advice does not authorize a different source transition.

| Before | After | Why |
| --- | --- | --- |
| Privacy eye swapped instantly. | `_PrivacyIcon` retains both layers, uses the source quarter-scale and blur spring, and reverses from its current state. | The incoming and outgoing icons need continuity. The 60ms regression asserts literal expected opacity, scale, and blur values. |
| Privacy and optional action could press the whole folder. | `_FolderControl` owns its own press target. The folder input layer sits behind the sibling controls. | Independent controls must not move the whole card. Normal and reduced-motion tests assert the held state. |
| A 350ms privacy hold did not exercise Tooltip's mouse long-press threshold. | A 750ms regression fails before shared dependency `12155d8e` and passes after it. | The real browser also observes reveal after release and hide after Enter. The shared change is not duplicated here. |
| The captured eye trajectory has gaps and unknown exposure times. | Exact motion approval remains blocked. Existing samples are retained without interpolation. | A passing state assertion does not establish the 300ms trajectory or native 60 FPS. |
| Animated `ImageFiltered` blur has no performance profile in this round. | Retain the required source blur, but leave its runtime performance unapproved. | Removing blur changes the requested behavior. Sparse screenshots cannot certify its rendering cost. |

## Verdict

### Performance

Blur performance and native 60 FPS remain unverified. No claim of smoothness follows from the unit tests.

### Interruptibility and timing

The reversal regression verifies continuity at interruption. Source and candidate screenshot cadence does not establish exact enter and exit timing.

### Accessibility

The reduced-motion eye uses a 120ms opacity fade without scale or blur. The recorded Flutter probe verifies the effective preference.
The updated shared Tooltip dependency preserves mouse release beyond its touch long-press threshold.

Block exact-motion approval. The repaired behaviors pass, but zero-diff trajectory and performance evidence are missing.
