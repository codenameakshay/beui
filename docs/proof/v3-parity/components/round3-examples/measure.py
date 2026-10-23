"""Compare unmodified PNGs at their original coordinates and resolution."""

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def compare(left, right, crop=None):
    a, b = Image.open(left).convert("RGB"), Image.open(right).convert("RGB")
    if a.size != b.size:
        return {"failure": "raster dimensions differ", "left": a.size, "right": b.size}, None
    if crop:
        assert crop[2] <= a.width and crop[3] <= a.height
        a, b = a.crop(crop), b.crop(crop)
    delta = ImageChops.difference(a, b)
    red, green, blue = delta.split()
    maximum = ImageChops.lighter(ImageChops.lighter(red, green), blue)
    total = a.width * a.height
    changed = total - maximum.histogram()[0]
    histogram = delta.histogram()
    return {
        "width": a.width, "height": a.height,
        "differentPixels": changed, "totalPixels": total,
        "absoluteChannelSum": sum((index % 256) * count for index, count in enumerate(histogram)),
        "maximumChannelDelta": max(index % 256 for index, count in enumerate(histogram) if count),
        "differenceBounds": delta.getbbox(), "exactZero": changed == 0,
    }, delta


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source_batch")
    parser.add_argument("candidate_batch")
    parser.add_argument("output")
    parser.add_argument("--assert-zero", action="store_true")
    parser.add_argument("--candidate-prefix", default="after")
    parser.add_argument("--states", nargs="*")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    output = root / args.output
    output.mkdir(exist_ok=False)
    results = []
    for source in sorted((root / args.source_batch).glob("source-*")):
        candidate = root / args.candidate_batch / source.name.replace("source-", args.candidate_prefix + "-", 1)
        if not candidate.exists():
            results.append({"example": source.name, "failure": "candidate capture absent"})
            continue
        for left in sorted(source.glob("*.png")):
            if args.states and left.stem not in args.states:
                continue
            right = candidate / left.name
            if not right.exists():
                results.append({"example": source.name, "state": left.stem, "failure": "candidate state absent"})
                continue
            record = {"example": source.name, "state": left.stem,
                      "source": str(left.relative_to(root)), "candidate": str(right.relative_to(root)),
                      "sourceSha256": digest(left), "candidateSha256": digest(right)}
            for name, crop in [("viewport", None), ("rawStage", (344, 0, 936, 478))]:
                measurement, delta = compare(left, right, crop)
                record[name] = measurement
                if delta:
                    filename = f"{source.name}-{left.stem}-{name}.png"
                    delta.save(output / filename)
                    record[name]["rawDifference"] = str((output / filename).relative_to(root))
            results.append(record)
    report = {"method": "Exact RGB subtraction. No masks, resizing, registration, interpolation, or pixel tolerance.",
              "statePairing": "Same named interaction state, separate native runs. Not synchronized trajectory equivalence.",
              "crop": [344, 0, 936, 478], "results": results}
    (output / "measurements.json").write_text(json.dumps(report, indent=2) + "\n")
    failures = sum(not result.get("viewport", {}).get("exactZero", False) for result in results)
    print(json.dumps({"comparisons": len(results), "exactFailures": failures}))
    if args.assert_zero and failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
