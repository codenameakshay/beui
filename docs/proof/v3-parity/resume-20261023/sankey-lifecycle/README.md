# Sankey independent lifecycle review

Independent review reproduced three defects at integrated head f674fd35: focused nodes remained horizontally offscreen, offscreen charts were removed from keyboard traversal before entrance, and removed cursors revived on reinsertion. The reviewer tests are preserved verbatim here. The portable test copy changes imports and fixture path and applies dart format; assertions are unchanged.

The parent reproduced all three failures. Repairs keep keyboard focus enabled independently of pointer entrance gating, scroll a newly focused target into view only when outside each viewport edge, and clear invalid cursor identity when layout changes. The parent batch passes all 18 tests: 11 existing and seven reviewer cases, including 100 generated graph comparisons. This is widget/source proof; fresh browser proof remains pending.

Pinned source: a76e57c9bbc2837e96420b2610e9c82a3271bb05. Original source pin/archive stays unchanged. The reviewer's deterministic graph generator is retained; its external paths describe the generation environment, while tests consume the committed JSON fixture.
