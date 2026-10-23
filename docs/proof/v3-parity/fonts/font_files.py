import hashlib
import json
import sys
from pathlib import Path

from fontTools.ttLib import TTFont

paths = sorted(Path('example/assets/fonts').glob('*.ttf'))
paths += sorted(Path(sys.argv[1]).glob('*.woff2'))
records = []
for path in paths:
    font = TTFont(path)
    records.append({
        'path': str(path),
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'family': font['name'].getDebugName(1),
        'subfamily': font['name'].getDebugName(2),
        'version': font['name'].getDebugName(5),
        'postscript': font['name'].getDebugName(6),
        'weight': font['OS/2'].usWeightClass,
        'unitsPerEm': font['head'].unitsPerEm,
        'ascent': font['hhea'].ascent,
        'descent': font['hhea'].descent,
        'lineGap': font['hhea'].lineGap,
        'axes': [
            {'tag': axis.axisTag, 'min': axis.minValue, 'default': axis.defaultValue, 'max': axis.maxValue}
            for axis in font['fvar'].axes
        ] if 'fvar' in font else [],
    })
print(json.dumps(records, indent=2))
