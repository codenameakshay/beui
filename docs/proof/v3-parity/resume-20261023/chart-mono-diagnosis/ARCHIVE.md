# Parent archive acceptance

The original report, measurements, scripts, failed captures and all three served candidate builds are retained without edits. Copied production inputs and final diagnostic inputs are preserved; generated build caches are omitted.

`inputs.json` records an earlier diagnostic fixture hash. That single fixture changed during the worker investigation and its retained final bytes match `final-inputs.json`. The earlier fixture bytes are not recovered here. All other initial input hashes match. This exception is explicit in the verifier; it is not a production-input mismatch.

Run `python3 verify.py` with Pillow installed. It checks sealed bytes and original manifests, recomputes six label comparisons from raw measurements, checks the intentionally unmatched live gallery percentage, and verifies raw crop pixels and their nonzero differences. The original reproduction scripts retain their historical absolute /tmp paths; copy and adjust those paths to rerun into a fresh directory.

Current narrowing did not reproduce. Historical attribution, exact pixels and timing remain open. Archive integrity does not establish parity.
