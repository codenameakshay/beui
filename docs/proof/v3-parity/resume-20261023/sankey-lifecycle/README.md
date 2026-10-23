# Sankey independent lifecycle review

Independent review reproduced three defects at integrated head f674fd35: focused nodes remained horizontally offscreen, offscreen charts were removed from keyboard traversal before entrance, and removed cursors revived on reinsertion. The reviewer tests are preserved verbatim here. The portable test copy changes imports and fixture path and applies dart format; assertions are unchanged.

The parent reproduced all three failures. Repairs keep keyboard focus enabled independently of pointer entrance gating, scroll a newly focused target into view only when outside each viewport edge, and clear invalid cursor identity when layout changes. The parent batch passes all 18 tests: 11 existing and seven reviewer cases, including 100 generated graph comparisons. This is widget/source proof; fresh browser proof remains pending.

Pinned source: a76e57c9bbc2837e96420b2610e9c82a3271bb05. Original source pin/archive stays unchanged. The reviewer's deterministic graph generator is retained; its external paths describe the generation environment, while tests consume the committed JSON fixture.

## Fresh native lifecycle checks

The compact browser fixture exposed a fourth defect: expanded node hit targets overlapped the preceding control vertically, so reading-order traversal skipped the chart. Commit e61ff63be groups chart traversal without shrinking hit targets. The failing compact-layout regression and 19 passing Sankey tests are retained.

`native-r4/results.json` passes all 12 pinned-source/candidate scenarios across normal and reduced motion. Native Tab enters the chart, End/Home scroll into view, offscreen entry scrolls into view, and removing/reinserting B retains A as the tab stop. Restore moves outside using native Tab and asserts the actual focused control. This is behavioral proof, not raster or motion certification.

Earlier attempts remain unchanged. R1/R2 reproduce skipped entry. R3 passes entry and scrolling, but its Outside pointer click is intercepted by a tooltip semantics subtree; that pointer issue remains open. R4 tests keyboard restoration independently and does not certify pointer dismissal. Source build inputs/lock and actual response hashes are retained. `build-identity.json` identifies the candidate fixture.
