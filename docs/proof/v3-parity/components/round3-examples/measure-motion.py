"""Measure original post-release/key frames without synthesizing timing."""

import argparse
import json
from pathlib import Path

from measure import compare, digest


parser = argparse.ArgumentParser()
parser.add_argument("batch")
parser.add_argument("output")
args = parser.parse_args()
root = Path(__file__).resolve().parent
output = root / args.output
output.mkdir(exist_ok=False)
results = []
for source in sorted((root / args.batch).glob("source-*")):
    if source.name.endswith(("-data", "-editable", "-async", "-stateful")):
        continue
    candidate = source.with_name(source.name.replace("source-", "after-", 1))
    timelines = [json.loads((path / "recording/timeline.json").read_text()) for path in [source, candidate]]
    selected = [[event for event in timeline["events"] if event["type"] == "up"
                 or event.get("key") in ["Home", "End"]] for timeline in timelines]
    assert len(selected[0]) == len(selected[1]), source.name
    for index, events in enumerate(zip(*selected)):
        files, timing = [], []
        for path, timeline, event in zip([source, candidate], timelines, events):
            frame = next((frame for frame in timeline["frames"] if frame["requestedMs"] >= event["dispatchAfterMs"]), None)
            if frame is None:
                files.append(None)
                continue
            files.append(path / "recording" / frame["file"])
            timing.append({"event": event, "frame": frame,
                           "requestAfterDispatchMs": frame["requestedMs"] - event["dispatchAfterMs"],
                           "exposureUncertaintyMs": frame["receivedMs"] - frame["requestedMs"]})
        label = f"{index}-{events[0].get('key', 'release')}"
        record = {"example": source.name, "state": label, "timing": timing}
        if None in files:
            record["failure"] = "No unambiguous post-event original frame"
        else:
            record.update(source=str(files[0].relative_to(root)), candidate=str(files[1].relative_to(root)),
                          sourceSha256=digest(files[0]), candidateSha256=digest(files[1]))
            for name, crop in [("viewport", None), ("rawStage", (344, 0, 936, 478))]:
                result, delta = compare(*files, crop)
                record[name] = result
                if delta:
                    filename = f"{source.name}-{label}-{name}.png"
                    delta.save(output / filename)
                    record[name]["rawDifference"] = str((output / filename).relative_to(root))
        results.append(record)
report = {"method": "First original frame requested after event dispatch. Exact RGB subtraction; no masks or tolerance.",
          "statePairing": "Matching native release/Home/End event ordinal. Exposure intervals differ and remain explicit. No trajectory or native60 approval.",
          "crop": [344, 0, 936, 478], "results": results}
(output / "measurements.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"comparisons": len(results), "exactFailures": sum(not result.get('viewport', {}).get('exactZero', False) for result in results)}))
