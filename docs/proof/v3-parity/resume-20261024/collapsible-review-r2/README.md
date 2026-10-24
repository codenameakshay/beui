# Collapsible independent review r2

The original pending-owner-focus P2 is resolved. The unchanged reviewer suite passed 16/16 and final focused tests passed 32/32 on Flutter 3.47.1. Targeted analysis passed. Additional scope-history and pending-focus probes passed.

Reviewed production SHA-256: `298d69810e2a002fc96518e62cc81fc33fa49c6f4df7cc7bcbc633e3df414f53`. Tests: `331ef5a58cd1fa86a5196bb0f0a3994afb4ad0dcd7bcf2984bef6dee5b3b91e4`.

## Remaining composition limit

Closing while moving the keyed panel between distinct enclosing FocusScopes can lose a simultaneous owner request to Outside. Both motion preferences reproduce this. A plain Flutter FocusScope/ExcludeFocus control also reproduces it; this is not a demonstrated regression introduced by the repair. Moving while open preserves Outside. See the retained isolation repro and log.

## Evidence boundaries

Saved native verification passed 27 checks for each of four source/candidate motion combinations and 267 exact replay frames. No fresh native capture was performed by the reviewer. Callback-before-frame ordering remains widget evidence. Flutter 3.44.2 APIs were checked in source only, without minimum-SDK execution. Timing, closed-height, exact pixels and screen-reader parity remain unverified.

Logs and repros are copied unchanged from the independent review. Parent archive verification also exited 0. This review accepts the bounded repair and does not certify general parity.
