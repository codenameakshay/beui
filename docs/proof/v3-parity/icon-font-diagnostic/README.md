# Alert icon rendering diagnostic

The reported `functional-final/.../observed/01-success.png` visibly contains missing-glyph boxes. Its adjacent recorder config identifies implementation `2e2aa803` and JS `37b90f6d43ec0b4d2f5ef5235e036a6a8306f5938b49a726b550ce265132ddb2`. The observation itself has no embedded response hash, so the config is contextual provenance only. Copies are retained here without modifying the worker originals.

A fresh Chrome context against port 8110 renders the check-circle and close icons correctly in `success.png`, including after enabling semantics and selecting Success. `report.json` records the actual JS response `dff2693a8194213a63b552ce778f8429c8fe1c753a9f533b57272128a2e2705f`, all font response hashes and no browser errors. The Lucide response is 62,176 bytes, SHA-256 `48a6bf842b1c18318ebfb54a1391d666b4b75e7281bfc671efdeed6ecad12709`. Original screenshot pixels were visually inspected.

These are different builds. This run does not prove that the older failure was transient, fixed, or caused by font loading. Successful HTTP font responses alone do not establish CanvasKit font registration. A same-build reproduction with font response capture remains needed to attribute the historical failure. No engine, theme, icon package, or production changes were made for this diagnostic.

The T3 preview opened, but two snapshots failed with `Preview automation snapshot timed out after 15000ms.` The probe therefore uses the repository's existing Playwright runtime and Chrome executable. `probe.mjs` retains the exact diagnostic; it writes to `/tmp/beui-parent-icon-diagnostic` and requires the worker server on 8110. This is a still-image diagnostic, not parity certification.
