# Citations additive implementation

Status is implemented and behavior-checked, not parity acceptance. The changes remain uncommitted on `480eb6a338cedc821e0fa0df9b7069a9d0009ae0`.

The pinned source is `starc007/ui-components` revision `1ab921e62283e788a686bc4bafa1de5ff56104ea`, `components/agents/citations.tsx` and `components/previews/agents/citations.preview.tsx`. Its canonical checkout remains clean.

Before-state receipt: `/Users/codenameakshay/.t3/artifacts/beui-v3.1.0/agents/safe-unit-rest-480eb6a3`, manifest SHA-256 `f9b96f82bdae2d73ed03cff2945ccc6256c6c09ef1aa512e5d807a1f475210f5`.

## Change shape

```text
BeuiCitationItem.icon? -> stack and row -> decorative BeuiCitationFavicon.icon?
BeuiCitation.label? -> exact marker Semantics label and activation
```

Nullable icon additions preserve existing constructors and URL fallback when omitted. A supplied icon bypasses URL resolution and image acquisition, is kept decorative, and inherits source-sized muted icon defaults without overriding explicit child properties. Favicon failure state remains tied to URL changes; queued callbacks are ignored after source changes or disposal. Nullable marker labels replace the semantics label; null keeps the computed row index or existing orphan/index fallback and assertion.

The source mapping is limited to these additions.

| Pinned source | Flutter change | Observable check |
| --- | --- | --- |
| `CitationItem.icon`, stack and row forwarding | Optional `Widget? icon` on the item and favicon | Both compositions render custom icons without a favicon Image. |
| `useFavicon(icon ? undefined : url)` | Icon precedence before URL resolution | Custom icon makes zero HTTP requests; null with a valid URL requests its favicon. |
| `Citation.label ?? View citation {index}` | Optional `String? label` | Literal custom, derived-index, explicit-index, and orphan labels; number registry unchanged. |
| Marker anchor activation | Exact label with explicit semantic tap action | Semantic action, pointer, and keyboard each activate once; keyboard focus does not reflow. |
| PDF preview reference | Canonical fixture only | Exact prose, three markers, custom third label, PDF title/domain/icon, static PDF row, existing URL callback. |

The canonical demo now matches the pinned fixture's three markers and references, including its no-URL PDF icon. Its compact API specimen keeps the original React documentation item. Only URL-backed rows receive the demo callback, so the PDF stays static. Progressive timing remains 500ms plus 700ms per row, with reduced-motion completion and replay retained.

## Parent review and verification

One Luna owner implemented the draft. Two upstream `no active upstream websocket for response.interrupt` errors interrupted that owner. Saved files and processes were checked before each resume. No replacement worker or overlapping writer was started.

The parent read the complete diff against the pinned source. Review corrected pre-list marker indices, custom icon defaults, retained failed-URL state, and the PDF's no-op callback. The parent added same-URL late-error and keyed replacement tests. A semantic-action assertion caught a draft regression caused by excluding the painted numeral's semantics. The marker now owns its semantic tap action explicitly, and its GestureDetector excludes duplicate semantics. No registry, shared component, motion, font-weight, or existing geometry was changed.

The Model the Domain principle kept these additions on the existing typed item and marker. Test Behavior, Not Implementation added literal callback, label, request, focus, and disposal outcomes. Manual comment review retained public dartdoc and the narrow gallery-import lint suppression. No extra Comment Sicko worker was started under the one-worker clearance.

All final checks used `/Users/codenameakshay/fvm/versions/3.44.4/bin/flutter`, with dependencies already installed. The final test command was:

```sh
/Users/codenameakshay/fvm/versions/3.44.4/bin/flutter test --no-pub --concurrency=1 --reporter=expanded test/motion/citations_source_api_test.dart test/motion/citations_test.dart test/motion/streaming_response_test.dart test/motion/agents_source_defaults_test.dart
```

| Check | Result |
| --- | --- |
| New Citations API suite | 16 passed. |
| Existing Citations suite | 34 passed, one golden failed. |
| StreamingResponse suite | 22 passed. |
| Accepted source-default suite | 9 passed. |
| Combined command | 81 passed, one failed, exit 1. No skips. |
| Root `flutter analyze --no-pub` | No issues, exit 0. |
| Example `flutter analyze --no-pub` | No issues, exit 0. |
| Exact-SDK `dart format` on the three Dart files | Zero changes on final run. |
| `git diff --check` | Passed. |

The existing golden failed with `10px diff detected`. Its generated image SHA-256 is `fa441c732dafa7cc823d3f9d4b580eba1611e12d77acec2743fb48451a38b2d7`, byte-identical to the unchanged baseline failure image in root's `t3-2c65680f` worktree. Root's baseline log independently records the same 10-pixel failure. The golden was not regenerated. This is not an overall green test claim.

The late-error test forces a frame for the queued callback and includes a current-image failure positive control. Removing the generation guard makes it fail; restoring the guard passes. This synthetic negative control is not historical baseline evidence. Missing optional APIs were a static/compile gap, not an executed pre-change behavioral failure.

Reproducible local logs are under `/Users/codenameakshay/.t3/artifacts/beui-v3.1.0/agents/citations-api-review-480eb6a3/`, including `focused-tests.log`, `analyze-root.log`, `analyze-example.log`, and `generation-negative-control.log`. These contain no calibrated timing or performance results.

Public API behavior covered includes old-constructor compilation and execution, literal/custom/default/orphan marker semantics, index fallback, row and stack icon forwarding, no-acquisition versus valid-URL image acquisition, URL and icon switching, preserved URL failures, stale callbacks and disposal, icon defaults and explicit customization, pointer/keyboard activation, focus geometry, keyed child state, and the canonical PDF row.

## Remaining gates

This is bounded additive API/fixture work, not full source parity or release proof. Existing widget tests exercise closed, append, and reduced-motion states, but do not clear their remaining acquisition and visual obligations. Every progression state, matched source/before/after crops, browser reduced motion, touch/native surfaces, actual static/motion comparisons, and performance remain pending. The native gate is unresolved. Full-family tests, package dry-run, exact-head hosted CI, and integration remain pending. ThinkingShimmer and Activity remain separately gated.

No build, capture, install, server, native session, commit, push, or PR was performed for this unit. The original source/before media remains untouched. The earlier defaults web artifact still belongs to `480eb6a338cedc821e0fa0df9b7069a9d0009ae0`; its JS SHA-256 remains `194bdeef0806459b8d96c2661cf04a87269edac8512b70d940eb6fa864464581`. It does not include the current Citations edits.
