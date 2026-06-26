// Motion tokens — the foundation every animated component depends on.
//
// To be implemented (next step): the five spring tokens as
// `motor.SpringMotion(SpringDescription(...))` constants and the three easings
// as `Cubic` constants, mirroring the source's `lib/ease.ts` verbatim, plus the
// reduced-motion resolver (`MediaQuery.disableAnimationsOf` -> `NoMotion`).
//
// This is the ONLY place `motor` types appear directly — components consume the
// `beui*` constants defined here. See docs/PORTING_SPEC.md §1.
