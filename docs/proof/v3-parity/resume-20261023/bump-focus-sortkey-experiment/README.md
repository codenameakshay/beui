# Rejected Tooltip semantics ordering experiment

The candidate patch added a named ordinal semantics container to the Tooltip overlay. It did not repair the native focus defect: repeated normal-motion burst tests still failed at legend-tab after initially passing. The failing trace retains active-ancestor-insertBefore, confirming the app ancestor can still move. The production patch was reverted and is not part of the library.

The successful reduced-motion run and 70 passing widget compatibility tests do not override the native failure. Scripts and original screenshots/traces remain here. No engine patch, focus injection, input pacing, golden update or parity claim. The failed build command and corrected build logs are retained separately. Source correspondence and the prior causal moveBefore intervention are in ../bump-focus-diagnosis.
