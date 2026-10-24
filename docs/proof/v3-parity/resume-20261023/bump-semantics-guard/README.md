# Bump native focus repair

Flutter's semantics reconciliation moved the focused app ancestor around exiting tooltip siblings. Chromium detached native focus while Flutter retained its internal focused flag. The internal web adapter keeps that ancestor stationary and rotates only the intervening beUI tooltip siblings into the exact requested order. It never calls focus or schedules restoration.

The adapter intercepts connected, same-parent FLT-SEMANTICS moves inside a flutter-view. Ownership requires the tooltip instance marker, or a single-child wrapper with only id/style attributes leading to that marker. Application roles, labels, identifiers and other attributes reject interception. It supports insertBefore and single-node Element.append, including shadow-root focus. Other calls retain native behavior and errors. Installation is idempotent per realm and remains through portal disposal.

## Verified

- Production r5 Chromium contract passes 240 position combinations plus native API, ownership, shadow-root and focus controls. The independent second review passes 11 additional checks and finds no demonstrated new defect.
- Seven final Chromium Flutter runs pass 127 observed states. A separate WebKit Flutter run passes all 21 forward/reverse/dismissal states. Current Flutter runs exercise two actual ancestor reorder requests; Flutter 3.44.3 exercises one. Each preserves native focus and exact requested DOM order. Both motion preferences, reverse traversal, Escape/reopen and outside-click dismissal are covered. Zero-intervention runs are identified in their traces, not counted as causal proof.
- Fresh release builds pass with current Flutter 3.47.1 and oldest installed compatible Flutter 3.44.3. The declared 3.44.0 minimum itself was not installed or tested. The isolated older build resolves its own dependencies.
- 323 affected widget tests pass with golden comparisons disabled. Full root run has 2,460 passes and 56 preserved golden failures, with no non-golden failures. Scoped analysis passes. No golden was regenerated.

Exact input and served-JavaScript hashes are in inputs.json and each browser run's served.json. Native key logs retain trusted events and effective reduced-motion observations. PNGs and traces are original output; no video/timing or pixel-parity claim is made.

## Rejected attempts and review changes

Initial append returned null instead of JavaScript undefined; corrected before browser integration. Initial no-op focus assertions incorrectly demanded different behavior from native DOM; corrected to compare native behavior. First review found an app control wrapper could qualify as transparent, and the runner could pass without executing any browser. Both have regressions and are fixed. Shadow-root focus was also corrected.

The first reverse run expected the wrong previous Frame rank. Its failed output is retained; the corrected expectation uses the fixture's unchanged data. The older-SDK fixture initially failed because the isolated copy omitted shaders; the corrected complete copy builds. A first command was accidentally run from repository root and failed before finding its target. All logs remain separate.

## Limits

This adapter depends on Flutter's private semantics tags, identifier attribute and wrapper structure. It uses standard DOM APIs but is not a public Flutter extension. Later replacement of DOM methods can disable the installed wrapper. Separate application runtimes, actual screen-reader virtual-cursor retention and announcements remain unverified. DOM focus preservation does not establish those outcomes.

Chromium and WebKit each pass all 240 contract cases. The all-required-browser command correctly fails because Firefox cannot launch: macOS reports sandbox_extension_issue_file_to_process Operation not permitted, then launch times out. Its installation and launch attempts are retained. WebKit fixture evidence is one completed 21-state run with no observed ancestor reorder, so it does not establish a causal WebKit repair. Exact source parity, historical coverage and timing gates remain open in the parent ledger.

## Reproduction

See test/web/README.md for the compiled adapter contract. Build test/charts/bump_parity_fixture.dart from example with a fresh output directory. Serve it and run the archived beui-focus-production-reproduce.mjs with BUMP_URL pointing to that directory, side `after`, and a new run name. REVERSE=1 adds reverse traversal and outside dismissal; MOTION=reduce selects reduced motion. The reproducer observes the real adapter after installation without replacing its decision or injecting focus.
