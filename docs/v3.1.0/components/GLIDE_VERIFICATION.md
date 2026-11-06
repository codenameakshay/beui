# Glide token focused verification

The approved additive `beuiSpringGlide` constant matches pinned source
`lib/ease.ts` SPRING_GLIDE at revision
`1ab921e62283e788a686bc4bafa1de5ff56104ea`. Stiffness is 700, damping is 50,
and mass is 0.5. Existing token values, the resolver, public barrel, and all
widget consumers remain unchanged. No existing widget physics were retuned.

The parent read the full two-file worker diff against the exact source token.
The token uses the existing SpringMotion and SpringDescription representation.
Its documentation does not repeat the source's mathematically inaccurate
critically-damped description. No trajectory or frame-performance claim follows
from these parameter checks.

## Commands and results

```sh
/Users/codenameakshay/fvm/versions/3.44.4/bin/flutter test --no-pub --concurrency=1 test/tokens/motion_test.dart --reporter expanded
/Users/codenameakshay/fvm/versions/3.44.4/bin/dart analyze lib/src/tokens/motion.dart test/tokens/motion_test.dart
git diff --check
```

The token suite passes 15 tests, including the new public-import parameter
check and normal/reduced movement resolution checks. Normal motion returns the
same glide token; reduced movement resolves to NoMotion. Scoped analysis reports
no issues, and whitespace checks pass. Logs remain in the durable task artifact
directory as `components/glide-focused-20261105.log` and
`components/glide-analyze-20261105.log`.

The existing immutable whole-widget baseline predates this unused token
addition. No visual consumer was changed, so the tests do not establish a new
widget's trajectory, visual fidelity, native behavior, or source parity.
No build, capture, browser, device, dependency, or performance action ran.
Root review and local commit clearance remain pending.

## Reviewed bytes

| File | SHA-256 |
| --- | --- |
| `lib/src/tokens/motion.dart` | `fcd72e395815c09e08f9d465185105dfecb529dec7c551fe950a76f649199e8a` |
| `test/tokens/motion_test.dart` | `7f275c6ca40ae961015fa1b91a05a802bddeee95dca40374ec01212da08f03d3` |
