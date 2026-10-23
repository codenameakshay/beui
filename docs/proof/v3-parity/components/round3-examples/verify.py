"""Verify committed originals and recompute the recorded pixel measurements."""

import argparse
import hashlib
import json
import subprocess
from pathlib import Path

from measure import compare


root = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument("--write-manifest", action="store_true")
parser.add_argument("--assert-parity", action="store_true")
parser.add_argument("--ffprobe", action="store_true")
args = parser.parse_args()
manifest = root / "assets.json"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


if args.write_manifest:
    files = {str(path.relative_to(root)): {"bytes": path.stat().st_size, "sha256": sha(path)}
             for path in sorted(root.rglob("*")) if path.is_file()
             and path != manifest and "__pycache__" not in path.parts}
    manifest.write_text(json.dumps({"algorithm": "sha256", "files": files}, indent=2) + "\n")
    print(json.dumps({"manifestFiles": len(files)}))
else:
    files = json.loads(manifest.read_text())["files"]
    for name, expected in files.items():
        path = root / name
        assert path.is_file(), f"Missing original {name}"
        assert path.stat().st_size == expected["bytes"], f"Changed size {name}"
        assert sha(path) == expected["sha256"], f"Changed bytes {name}"
    for build in json.loads((root / "build-provenance.json").read_text())["builds"]:
        assert sha(root / build["servedJs"]) == build["sha256"], build["label"]
    native_slider_flows = 0
    for batch in ["slider-guard-head-light", "slider-guard-head-dark", "slider-guard-head-reduce"]:
        for path in sorted((root / batch).glob("*/outcomes.json")):
            outcomes = json.loads(path.read_text())
            key = outcomes["example"]["key"]
            assert key in ["wave", "bubble"], str(path)
            assert all(check["pass"] for check in outcomes["checks"]), str(path)
            drag = next(check for check in outcomes["checks"] if check["name"] == "drag publishes value")
            assert drag["actual"] == (85 if key == "wave" else 89), str(path)
            assert json.loads((path.parent / "record-log.json").read_text())["code"] == 0, str(path)
            native_slider_flows += 1
    assert native_slider_flows == 12, "All source/candidate normal/dark/reduced Slider flows must exist"
    archived_scripts = {sha(path) for path in (root / "served-js").glob("*.js")}
    provenance_failures, unrecorded_configs, verified_configs = [], [], 0
    for path in sorted(root.rglob("record-config.json")):
        config = json.loads(path.read_text())
        expected = config["servedJs"]
        assert expected["sha256"] in archived_scripts, f"Unarchived served JS {path}"
        recording = path.parent / "recording"
        if not (recording / "environment.json").exists() or not (recording / "scripts.json").exists():
            unrecorded_configs.append(str(path.relative_to(root)))
            continue
        scripts = json.loads((recording / "scripts.json").read_text())
        environment = json.loads((recording / "environment.json").read_text())
        actual = next((script for script in scripts if script["url"] == expected["url"]), None)
        failures = []
        if actual is None or actual["sha256"] != expected["sha256"]:
            failures.append("actual served JavaScript differs from requested hash")
        reduced = config["reducedMotion"] == "reduce"
        if environment["reducedMotion"] != reduced:
            failures.append("effective browser motion differs from requested preference")
        flutter = environment.get("flutterCapture")
        if config.get("requireFlutterProbe") and (
            not flutter or flutter["disableAnimations"] != reduced or flutter["motionOverride"] is not None
        ):
            failures.append("effective Flutter motion differs or has an override")
        if failures:
            provenance_failures.append({"path": str(path.relative_to(root)), "failures": failures})
        verified_configs += 1
    recordings = 0
    for path in sorted(root.rglob("recording/timeline.json")):
        timeline = json.loads(path.read_text())
        for frame in timeline["frames"]:
            assert sha(path.parent / frame["file"]) == frame["sha256"], str(path)
        assert len(timeline["frames"]) == timeline["stats"]["frames"], str(path)
        if "video" not in timeline["stats"]:
            continue
        assert timeline["stats"]["video"]["decodedFrames"] == len(timeline["frames"]), str(path)
        recordings += 1
        if args.ffprobe:
            probe = subprocess.check_output(["ffprobe", "-v", "error", "-count_frames", "-show_streams", "-of", "json", str(path.parent / "capture.mp4")])
            assert int(json.loads(probe)["streams"][0]["nb_read_frames"]) == len(timeline["frames"]), str(path)
    count, failures = 0, 0
    for path in sorted(root.glob("pixels-*/measurements.json")):
        report = json.loads(path.read_text())
        for result in report["results"]:
            if "failure" in result:
                failures += 1
                continue
            for name, crop in [("viewport", None), ("rawStage", tuple(report["crop"]))]:
                actual, _ = compare(root / result["source"], root / result["candidate"], crop)
                expected = {key: value for key, value in result[name].items() if key != "rawDifference"}
                assert json.loads(json.dumps(actual)) == expected, f"Measurement changed {path}:{result['state']}:{name}"
            count += 1
            failures += not result["viewport"].get("exactZero", False)
    print(json.dumps({"verifiedFiles": len(files), "pixelComparisons": count,
                      "verifiedRecordingTimelines": recordings,
                      "verifiedNativeSliderFlows": native_slider_flows,
                      "verifiedServedJsAndMotionConfigs": verified_configs,
                      "unrecordedConfigs": unrecorded_configs,
                      "provenanceFailures": provenance_failures,
                      "exactPixelFailures": failures, "parityCertified": False}))
    if args.assert_parity and (failures or provenance_failures or unrecorded_configs):
        raise SystemExit(1)
