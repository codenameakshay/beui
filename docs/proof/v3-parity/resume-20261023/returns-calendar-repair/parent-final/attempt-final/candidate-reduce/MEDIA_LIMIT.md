# Timestamp encoding limitation

The original capture.mp4 has559 decoded frames for560 original PNGs. The original PNGs and timestamps are preserved. A subsequent timestamp-based FFV1 encode named frames-complete.mkv also decoded559, so its filename is not a completeness claim. Both are retained as incomplete timestamp videos. The exact encoding cause is not established.

frame-index-replay.mkv contains all560 original frames at25 fps in index order. Every decoded RGB frame was compared byte-for-byte with its source PNG. This supplemental replay is an inspection aid, not actual cadence or animation-duration evidence. No interpolation, duplicate frame or replacement capture was used.

The rejected worker-r2/attempt-2/source-no-preference video similarly decodes528 for529 original frames. Its originals are retained and its mismatch is explicit in the verifier. Behavioral assertions use recorded observations and PNGs; no native60 certification follows.
