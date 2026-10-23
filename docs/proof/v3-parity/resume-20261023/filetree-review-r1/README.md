# Independent FileTree semantics review

Scoped acceptance for production06da09b01f4636df4c14d35f8ad0ee3863d7ab9921bc0e028c2d4d7f7fcd6105 and tests6e3ad0c62dff701dbfcba22faf45e9d80de275079e2646761ed7ec96fddbc112.10 non-golden tests plus2 independent probes pass on Flutter3.47.1 and3.44.2. The new action assertion fails against the original. Archive verifier passes20 retained runs/3385 frames; no fresh browser run.

Current-item semantics are not equivalent to selectable-tree semantics. The focusable list item lacks disabled state; its child button exposes it. List roles, textual hierarchy, duplicate current state and nested buttons remain limitations. Assistive-technology interoperability and source-equivalent immediate collapse focus are not established. No screen-reader claim.

Original review logs, SDK/package metadata, baseline/final component and relevant probes are retained unchanged. Supporting library inputs are available in sibling filetree-semantics archive; these files alone are not a standalone package.
