# beUI v3.1.0 PR media

Static source, before and after captures for PRs #33-#36. They are review aids, not fidelity or motion proof.

- Source: pinned `starc007/ui-components@1ab921e62283e788a686bc4bafa1de5ff56104ea`, served by `next dev` on 127.0.0.1:8300. Each image crops the page's preview panel.
- Before: `example/lib/visual_harness.dart` built from `835f4396d` (release base). Its `lib/` and `example/` bytes equal the unchanged baseline `792ad82d`.
- After: the same harness built from each PR head (#33 `4eee81fb9`, #34 `4d01226ad`, #35 `f55dfc105`, #36 `ba1839870`).
- All three: Chrome, 1280x900 viewport, DPR 1, dark color scheme, `prefers-reduced-motion: reduce`. Flutter uses `?theme=dark&previewWidth=592` and a 6 s settle for fonts. Margins are trimmed, and panels are scaled to the same height.
- "Not in baseline" means the component did not exist at `792ad82d`.
