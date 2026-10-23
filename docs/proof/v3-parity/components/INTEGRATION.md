# Parent integration

The owned implementation commits are `11ee280` and `8ccb169`. The baseline
proof checkpoint is `44e7201`. The stage-width cherry-pick `685b076` is shared
work already integrated by the parent as `d64ad16`. It is not an owned patch
and must not be integrated twice.

## Shared-file reconciliation

The only Tabs edit is `_indicatorSpring` in `lib/src/motion/tabs.dart`.
It changes stiffness, damping, and mass from 170/24/1.2 to the pinned source's
245/36/1.2. The blocks worker owns narrow overflow and wide-panel shrink.
There are no owned Tabs demo or layout edits.

No component helper, engine, barrel, catalog, shell, or theme changed here.
Flutter's automatic `example/analysis_options.yaml` rewrite was reverted after
each release build. The final port 8102 server is a release build of `8ccb169`.

## Shared work still needed

- The shared preview background differs. A native Tooltip comparison crop
  has source background RGB 252/252/252 and candidate 249/249/249. The preview
  wrapper uses the candidate's card color at 40% opacity. Source uses its
  actual background. This difference remains in every comparison crop.
- Tooltip trigger placement is half a logical pixel offset in the candidate.
  The measured Top rectangle starts at 732.5/359.5 versus source 560/544 after
  independent page placement. Width and height are 80/40 on both sides.
  The crop comparison retains this offset. No resampling was used.
- The old shared chart adapter uses uncontrolled Tooltip behavior. Commit
  `8ccb169` keeps its keyboard inspection working after mouse dismissal by
  observing keyboard modality before a focused child consumes the key.
  This is broader than source Tooltip's focus-in-only reveal. The chart
  worker must move its adapter to controlled visibility and external anchors,
  then narrow the generic reopening behavior. The individual commit remains
  separable for this reconciliation. No chart-owned files changed here.
- The Tooltip keyboard video exposes a separate gallery focus gap. After a
  mouse click on Top, source Tab moves to Left and reveals its tooltip. The
  candidate's Tab starts at the header logo instead. The native gallery
  button does not retain the same mouse-to-keyboard focus position. The
  retained decoded 1.45s frames show the difference. This needs button/focus
  integration work. The isolated Tooltip focus tests do not cover it.
- Text-animation and number recordings cover their default routes only.
  The blocks worker owns text-scramble and digit-swap. This slice does not
  duplicate those implementations.

## Owned gaps still open

- Adaptive stepper needs the actual Liquid blur/contrast silhouette and its
  600ms overshooting geometry transition. Its existing outlined controls differ.
- Color picker still needs the source trigger-to-area morph.
- Tooltip still lacks cross-provider exclusivity, unscoped warm timing,
  external anchor composition, accessible-name composition, and the toolbar
  gallery example. Plain Text replacement does not animate glyphs.
- Color selector's selected ring does not share the swatch's press scale.
- Alert tone colors and layout-height trajectories remain unmatched.
- Breadcrumb item exit retention and ellipsis morph remain unmatched.
- Image viewer modal zoom, pan, swipe, morph timing, focus return, and narrow
  thumbnail gaps need full reference-state comparison.
- Combobox's default demo lacks the source Workspace label, 48px customized
  trigger, and true 28px icon marks. Its existing demo uses 10px color squares.
- Date-range-picker's trigger includes weekdays and omits the year. The live
  source trigger omits weekdays and includes the year for the same dates.
- The five failed golden comparisons remain unresolved. No golden was updated.
- The shared recorder currently hardcodes `reducedMotion: 'no-preference'`.
  A shared config extension is needed for actual reduced-motion video evidence.
  Widget tests exercise reduced motion, but those tests are not browser footage.
- Other required routes remain unverified. The all-route inventory records
  every state and example obligation instead of certifying them from a default
  demo recording.

The parent must not describe this handoff as exact one-to-one parity.
