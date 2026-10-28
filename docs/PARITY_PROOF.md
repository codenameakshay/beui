# Parity proof

`docs/proof/`, `example/proof/` and `.github/screenshots/charts/` are git-ignored
local output. A fresh clone does not have them. Flutter tests do not need them:
their source-derived fixtures live in `test/fixtures/`.

## Write a new run

Capture scripts in `tool/` and `test/charts/` create their output folder with a
non-recursive `mkdir`, so they refuse to overwrite an earlier run. Create the
parent folder first and pick a new leaf name:

```sh
mkdir -p docs/proof/v3-parity/charts/sankey
node test/charts/sankey_capture_configs.mjs <source-build> <candidate-build> docs/proof/v3-parity/charts/sankey/<new-run>
```

The `/tmp` reference builds, Playwright runtime, Chrome and `ffmpeg` that these
scripts import are separate prerequisites.

## Restore an old run

Every run up to `c0878f554` is in git history. Restore only the paths a reader
needs:

```sh
git archive c0878f554 docs/proof/v3-parity/audit | tar -x
```

| Reader | Needs from history |
| --- | --- |
| `tool/parity_audit.mjs check` | `docs/proof/v3-parity/audit` |
| `test/charts/configure_status_ownership_round3.mjs` | `docs/proof/v3-parity/charts/round3/configs-final-v10` |
| `test/charts/configure_touch_round3.mjs` | `docs/proof/v3-parity/charts/round3/configs-final-v4` and `configs-final-v9` |
| `test/charts/verify_round3_archive.mjs` | `docs/proof/v3-parity/charts/round3` (or `CHART_ARCHIVE_ROOT`) |
| `test/charts/verify_sankey_evidence.mjs` | `docs/proof/v3-parity/charts/sankey` |
| `test/charts/verify_sankey_gallery.mjs` | `docs/proof/v3-parity/charts/sankey/builds-release/provenance.json` |

A restored run is historical evidence for its own revision, not proof for the
current `HEAD`.
