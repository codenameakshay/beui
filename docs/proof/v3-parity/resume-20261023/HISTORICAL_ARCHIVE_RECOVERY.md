# Historical component originals recovered

The coverage ledger identified 264 missing files from the 300-entry `components/before-sha256.json` manifest. All 264 remained in the original `t3-48d38279` worktree and matched their saved byte counts and SHA-256 hashes.

The parent copied those exact files into their original relative paths and staged them despite the historical exclusion rules. The recovered payload is 63,750,876 bytes. All 300 manifest entries now exist in the parent checkout and pass the original size and hash checks. `historical-original-recovery.json` records each recovered path and its unchanged expected hash.

No recording was recreated, renamed, transcoded, or promoted to passing evidence. Failed and exploratory capture limitations remain unchanged. The coverage ledger retains its original `a2942181` snapshot; this recovery resolves that snapshot's missing-file finding without rewriting it.

The separate omitted Sankey finding is confirmed in the pinned source registry and now has an implementation owner. Its route and state inventory will be added explicitly; the old 76-route and 601-state counts are not silently expanded or called complete.
