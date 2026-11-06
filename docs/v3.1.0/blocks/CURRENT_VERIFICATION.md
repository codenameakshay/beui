# Blocks delivery checkpoint

This is a draft implementation checkpoint, not family or release acceptance.
Canonical source is `starc007/ui-components@1ab921e62283e788a686bc4bafa1de5ff56104ea`.
The unchanged Flutter baseline is `792ad82dca47cdf317fdd94f0bb9251724f562e2`.
The source catalog contains 26 Blocks pages and 34 preview units. This delivery does not certify all units or variants.

## Delivery map

Source paths below are relative to `components/motion/` in the canonical checkout.
All local implementations are under `lib/src/motion/`.

| Source | Local implementation | Scope and current limit |
|---|---|---|
| `file-upload.tsx` | `file_upload.dart` | Built-in selection, lazy file capability, controlled queue proposals, keyboard and cancellation. Actual platform pickers and drops remain open. |
| `attachment-upload.tsx` | `attachment_upload.dart` | Acquisition, metadata, EOF-gated bounded previews, cancellation and serialized reads. Browser reader and native resource behavior remain open. |
| `bloom-menu.tsx` | `bloom_menu.dart` | Roving keyboard navigation, focus restoration and retained controlled ownership. All-state visual and native interaction evidence remains open. |
| `notification-stack.tsx` | `notification_stack.dart` | Input ownership, outside dismissal, focus restoration and rich-content layout. Matched motion and platform proof remains open. |
| `infinite-masonry.tsx` | `infinite_masonry.dart` | Visible-window mounting, existing-scroll initialization and loading-tail behavior. Gallery uses the source image URLs. Network paint and performance remain open. |
| `morphing-search-chips.tsx` | `morphing_search_chips.dart` | Web localStorage recents and nonnegative spring geometry. Other platforms retain process-local recents. Reload behavior and golden review remain open. |
| `card-dealer.tsx` | `card_dealer.dart` | Deck, hand and discard composition with motion and supersession tests. Gallery route now exercises the actual catalog entry. Visual and native interaction remain open. |
| `mines.tsx` | `mines.dart`, `mines_round.dart` | Game state, payout, keyboard board, in-board results and source-timed presence. Audible playback is not implemented or accepted. |
| `plinko.tsx` | `plinko.dart`, `plinko_model.dart` | Board model, slots, animated paths, hit feedback and payout composition. Audible playback is not implemented or accepted. |

The gallery exports and routes include Card Dealer, Mines, and Plinko.
The copied Stepper and NumberTicker files match the separately owned Components implementation.
Their shared tests accompany the copies. They are not independent Blocks forks.

```text
platform picker/drop -> lazy upload capability -> queue/attachment lifecycle
source game helpers -> Mines/Plinko models -> widget composition
canonical shared Stepper/NumberTicker -> Mines value and payout display
public exports -> gallery routes -> example regressions
```

## Executed local gates

All Flutter gates use `/Users/codenameakshay/fvm/versions/3.44.4/bin/flutter` with the existing dependency resolution.
Behavior runs use `test --no-pub --concurrency=1 --reporter=json`.
Root and example analysis use `analyze --no-pub`.
Counts below overlap and must not be added.

| Run | Result | Log SHA-256 |
|---|---|---|
| Root analysis, root5 | Exit 0, no issues | `69e90bb5084e7778b1a2c6e5d0c1605102ef3b87e1f809107a513a8e8fad46cc` |
| Example analysis, root5 | Exit 0, no issues | `893a078b6156eb47bbd4ab8181f344daf2b4746270bcfbbe63aad3b945210fd9` |
| Shared Stepper/ticker plus Mines/Plinko, root4 | 100 passed, exit 0 | `58a7ccd4d9c824a7720b289b7b8b7ed42a885de6047ca16da50a4a6a3ec6949a` |
| Six upload suites, root3 | 97 passed, exit 0 | `6ce8ccb8fb6462193314a67f6f89412d20c5355819ada3fa167d43ebf2fc91d9` |
| Chips and recents storage, root1 | 12 passed, exit 0 | `dc9a0192fb75503a8e498c9d414aaa315d8b65c3d0168e2fb54f04eee2d10a2e` |
| Full example after Card Dealer catalog correction, root2 | 67 passed, exit 0 | `8f4f0a95d8b4fec203931fcf44a345051a2a5d5ce8d0818153034617be408a2c` |
| Earlier 39-suite relevant run, root1 | 531 passed, 10 golden errors, exit 1 | `6c1cfab048eef7abf4c6fd8249850bec61c5d9460368018e6c767b47d192726a` |
| Current 38-suite relevant run, root2 | 503 passed, 10 golden errors, exit 1 | `84d7c483c12b19cd781b0623c14b624114f854985c1445d0f2cc13e3767b64bd` |
| Release-web build, root4 | Exit 0; font warning retained | `18495ed53ce8971b1a5861e4229b03314ac3f6b3bd6c96f00a721f1b33a3c457` |
| Arm64 simulator build, root4 | Exit 0, BUILD SUCCEEDED | `514989096d47416b4633696de65d5078b3ef294b030b2127dbcf5789fc6fdb9b` |

The native command uses `xcodebuild`, the existing Runner workspace, `ARCHS=arm64`, and `IPHONEOS_DEPLOYMENT_TARGET=15.0`.
That command-line override does not change the project's compatibility floor.
The existing Rust toolchain directory is on PATH for the native drag-and-drop dependency.
No Blocks app launch or native interaction follows from this compile result.

The Card Dealer catalog regression first failed with `Bad state: No element`.
The gallery entry correction then passed the full example suite without changing the widget or demo.
The current relevant rerun omitted the older attachment suite because the command builder sliced one argument too far.
It is not a fresh 39-suite result. The earlier six-suite upload run includes that suite and passed 97 cases.
Historical reds, capture originals, JSON event streams, and frozen import/config manifests remain preserved outside git.
Each reviewed runtime manifest checks both conditional import branches and unchanged configs before release.
Bulk receipts live under `/Users/codenameakshay/.t3/artifacts/beui-v3.1.0/blocks/` on the verification machine.
Those local receipts are not accessible PR media.

## Open acceptance gates

- The full local test/golden gate is not green. Existing golden mismatches remain unskipped and unregenerated. Their causes are not interchangeable.
- All ten failed candidate PNGs in the current relevant run are byte-identical to the preserved unchanged-baseline candidates. This rules out new raster drift in those captures, not the existing mismatch or its unresolved cause.
- Matched source, unchanged-before, and current-after media is incomplete. No visual or motion score certifies the family.
- Real browser picker cancellation, drop behavior, durable-recents reload, web-reader backpressure, and native delayed reads require platform verification.
- Native changed-widget interactions, six-platform acquisition, and performance evidence remain open.
- Sound preference callbacks do not establish audio playback. Shared audio integration remains separate.
- All 26 pages and 34 preview units still need final per-state and per-variant inventory acceptance. Existing audit history is not current acceptance.
- Hosted CI is a separate exact-head gate. Linux CI's existing golden-skip policy does not close the macOS golden hold.

No family PR merge, publishing, tag, deployment, or final release approval is part of this checkpoint.
