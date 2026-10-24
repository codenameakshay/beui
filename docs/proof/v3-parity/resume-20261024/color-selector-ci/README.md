# ColorSelector CI lifecycle repair

CI run 40075386691 on ad9adb944 failed three reduced-motion teardown tests on Flutter 3.44.4. The isolated baseline reproduces those exact failures: 18 pass, 3 fail.

The selection ring lazily created its animation controller during dispose when reduced motion bypassed the animated builder. Ticker creation then read a deactivated ancestor. Initialize the controller in initState instead. Rendering and animation parameters remain unchanged.

All 21 existing ColorSelector tests pass on Flutter 3.44.4 and 3.47.1 with BEUI_SKIP_GOLDENS=1. The separate 3.47.1 rest-state golden passes with comparison enabled. Whole-tree analysis and package formatting pass. Existing tests provide failing-first coverage; no redundant regression was added.

The initial attempt used mismatched SDK package configuration and failed compilation. The successful reproduction used fresh dependency resolution in /tmp/beui-color-selector-ci. No shared SDK changed.
