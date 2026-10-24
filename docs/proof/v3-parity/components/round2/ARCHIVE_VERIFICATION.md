# Round2 archive verification

The archival follow-up adds 10,611 original PNGs from all 112 retained sequences.
Their exact total is 1,022,998,499 bytes. Failed and superseded runs are included.
All files match their original timeline SHA256 and the committed
`original-frames-archive.json` byte inventory. No PNG was changed or re-encoded.

The follow-up also adds 36 existing final before/after MP4 files, totaling
193,061,023 bytes. The earlier `*-after.mp4` intermediate exclusion also matched
those final filenames. They were absent from `3fa062f8` despite existing locally.
The isolated checkout caught this omission before the archival commit.
The final videos are now tracked unchanged. Presentation exclusion rules remain
unchanged; only the original-frame exclusion was removed.

Total newly tracked media is 10,647 files and 1,216,059,522 bytes. Documentation,
the archive inventory, and verifier scripts are separate from these media totals.

## Isolated checkout result

The staged round2 tree was exported with `git checkout-index` to
`/tmp/beui-round2-archive-check.HO5f2w`. The export contains regular files, not
symlinks to the implementation worktree. Both commands ran with that directory
as their working directory. They need no gallery server or capture runtime.

```sh
node docs/proof/v3-parity/components/round2/verify-original-frames.mjs
node docs/proof/v3-parity/components/round2/verify-round2.mjs
```

Both commands exited with status 0. Their exact result records were:

```json
{"sequences":112,"pngFiles":10611,"pngBytes":1022998499,"timelines":112,"matchedTimelineFrames":10611,"verdict":"Every retained original PNG matches its original timeline SHA256 and archive byte inventory."}
{"sequences":112,"pngFiles":10611,"pngBytes":1022998499,"timelines":112,"matchedTimelineFrames":10611,"verdict":"Every retained original PNG matches its original timeline SHA256 and archive byte inventory."}
{"presentations":36,"functionalSequences":27,"verdict":"All listed functional assertions and decoded-frame checks passed. Exact parity not claimed."}
```

The repeated PNG record is intentional. The full round2 verifier also invokes
the all-sequence archive verifier. These commands run from an integrated
checkout using only committed proof files, Node.js, and `ffprobe`.

There are no production changes or new captures in this follow-up. Historical
deficient glyph pixels and their capture revisions remain unchanged. Parent
diagnostic `c2ac3e1d` establishes correct fresh `dff2693a` rendering, not the
cause of the older `2e2aa803` footage's glyph deficiency.
