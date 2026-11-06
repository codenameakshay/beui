# Animated sidebar acquisition

Source is pinned to `starc007/ui-components` `1ab921e62283e788a686bc4bafa1de5ff56104ea`; the unchanged Flutter baseline is `792ad82dca47cdf317fdd94f0bb9251724f562e2`, resolved against `flutter_lucide` 1.63.0 and Flutter 3.44.4 / Dart 3.12.2. Original media remains under `/Users/codenameakshay/.t3/artifacts/beui-v3.1.0/components/{source,before}/sidebar-*`. The adjacent JSON manifest SHA-256 inventories all 52 original frames.

There are eight directories (desktop rest/collapse and mobile rest/open on source and before): 1 + 12 + 1 + 12 frames per side, 52 total. All recorded results say nonblank; the before captures report Flutter mounted. The source desktop-rest result JSON is missing, although its original PNG exists and is hash-listed. The parent visually inspected desktop rest/collapse and mobile-open source/before captures. This is acquisition evidence, not proof of parity.

The protocol intended dark theme and no-preference motion at 1280x900 desktop / 390x844 mobile. The MCP calls did not set or measure motion preference. The effective font and motion environments were not established as matched. Both desktop stages extend beyond the 900px viewport; source gallery has three columns while the Flutter local gallery has two. The MCP samples are not timing-grade motion captures. They do not establish the desktop shortcut behavior, reduced-motion states, mobile exit, focus entry/restore, or accessibility state. No parity verdict is made.

Remaining gates include comparable effective theme, font, and motion evidence; matched sidebar crops and gallery framing; a compositor-timestamped desktop collapse and mobile open/exit sequence; and keyboard, reduced-motion, focus, and semantics verification. The source desktop-rest return metadata is missing and cannot be reconstructed by a later capture. Any later acquisition must remain separate from these originals.

The owner independently rehashed all 52 sidebar frames and verified unchanged widget/demo bytes against the Flutter baseline. This clears only the approved additive provider implementation. It does not clear other sidebar motion, layout, or demo changes, nor any parity gate.
