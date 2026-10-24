# Signup native input and accessibility follow-up

This slice repairs native accessibility exposed by source/candidate signup interaction checks. It does not certify visual or motion parity.

## Production

- `ea2024e3` scopes BeuiInput's accessible label and error hint to its editor, leaving suffix actions independent. Signup's reveal label and button action are merged together.
- `e81e9cc2` excludes the visible reveal tooltip from semantics, avoiding Chrome's duplicated “Show password” name.
- `25b395e7` merges the terms text and checkbox into one named actionable control.

The reveal and terms regressions fail before their repairs. The input's preserved golden passes unchanged. The affected input/signup/approval batch passes 70 tests with goldens disabled; the final signup/accessibility batch passes 14. Scoped analysis passes. All raw logs are under `gates/`.

## Browser evidence

`observe.mjs` uses real Chrome pointer and keyboard input against the live source and the integrated gallery. The documented recorder fallback applies after the earlier T3 preview failed twice with `Preview automation snapshot timed out after 15000ms.`

Final functional recordings are state screenshots and raw observed DOM records, not motion videos. The `terms-*25b395e7` directories cover light/dark and normal/reduced motion. Each source/candidate sequence checks invalid submission, native entry in all four fields, password reveal, submission, duplicate-email rejection, and successful retry. Busy-state records show all four fields disabled. Source is live beui.dev; its deployment revision is unknown. Pinned source correspondence is `a76e57c9`.

The final candidate is `25b395e7`, served on port 18118, with main.dart.js SHA256 `de6dbd3e185c96d8fd220091309dba3f01d4374c07578f0793aabce9b8f8515b`. Each run retains the actual response hash and effective Flutter probe. Viewport is 1280×1400, DPR1. Dummy data is local demo input; no account is created.

## Failed attempts retained

- `initial-a2942181`: source success locator matched three text spans; candidate initially had no native placeholder attribute.
- `measured-a2942181` and `native-entry-a2942181`: text was dispatched before the Flutter editing connection settled; values did not persist. This is not established as a product defect.
- `focus-wait-ea2024e3`: all values persisted, but Chrome exposed the reveal name twice.
- `single-name-e81e9cc2`: the reveal button was found; the immediate post-click type assertion ran before the UI update. Later runs wait for the observable type transition.

All screenshots and raw records remain unchanged. The source emitted a React hydration diagnostic in some runs; it did not prevent the successful workflows.

## Icon diagnostic and remaining work

Some fresh light screenshots show missing Lucide glyphs, and those runs did not record a Lucide font response. The same final JS renders correct icons in the standalone font probe and isolated candidate run. Later source/candidate dark runs also request the Lucide font successfully. The successful response is 62,176 bytes, SHA256 `48a6bf842b1c18318ebfb54a1391d666b4b75e7281bfc671efdeed6ecad12709`. No font, engine, or theme workaround was applied. The intermittent cause and the historical cause remain unresolved; deficient pixels are retained.

The demo's source Sign in button is still plain text in Flutter and needs a separate keyboard-accessibility correction. Exact geometry, palette, motion, and a labeled before/after video remain open. These functional checks do not waive those obligations.
