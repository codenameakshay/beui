"""Verify retained bytes and recompute the bounded mono measurement claims."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageChops

root = Path(__file__).resolve().parent


def read(name):
    return json.loads((root / name).read_text())


def digest(name):
    return hashlib.sha256((root / name).read_bytes()).hexdigest()


seal = read('archive-sha256.json')
for name, expected in seal.items():
    assert digest(name) == expected, name
for manifest in ['artifact-hashes.json', 'final-inputs.json']:
    for name, expected in read(manifest).items():
        assert digest(name) == expected, (manifest, name)
for name, expected in read('inputs.json')['files'].items():
    if name == 'repo/example/lib/mono_fixture.dart':
        expected = read('final-inputs.json')[name]
    assert digest(name) == expected, name

source = read('source-measurements.json')
candidate = read('candidate-measurements.json')
dom = read('dom-controls.json')
comparisons = read('comparison.json')
assert len(comparisons) == 6
for row in comparisons:
    chart, text = row['chart'], row['text']
    s = next(x for x in next(x for x in source if x['chart'] == chart)['data'] if x['text'] == text)
    c = next(x for x in next(x for x in candidate if x['chart'] == chart)['data'] if x['text'] == text)
    controls = next(x for x in candidate if x['chart'] == 'probe')['data']
    for family in ['Geist Mono', 'monospace']:
        control = next(x for x in controls if x['text'] == text and x['weight'] == c['weight'] and x['family'] == family)
        assert c['advance'] == control['advance']
    d = next(x for x in dom if x['text'] == text and x['weight'] == c['weight'] and x['family'] == 'Geist Mono')
    assert row['actualCandidateAdvance'] == c['advance']
    assert row['sourceDOMWidth'] == s['rect']['width']
    assert abs(d['canvasAdvance'] - c['advance']) < 0.00055
    assert abs(s['rect']['width'] - c['advance']) < 0.019
    assert abs(c['y'] + c['baseline'] - s['baseline'] - 0.26) < 0.000001
    gallery = next((x for x in next(x for x in candidate if x['chart'] == 'gallery-' + chart)['data'] if x['text'] == text), None)
    if gallery is None:
        assert text == '+0.34%' and row['actualGalleryAdvance'] is None
    else:
        assert gallery['advance'] == c['advance'] == row['actualGalleryAdvance']

for row in read('crop-metrics.json'):
    images = []
    for side in ['source', 'candidate']:
        crop = Image.open(root / f"{side}-{row['chart']}.png").convert('RGB').crop(row['cropXYXY'])
        saved = Image.open(root / f"{side}-{row['chart']}-raw-crop.png").convert('RGB')
        assert crop.size == saved.size and crop.tobytes() == saved.tobytes()
        images.append(crop)
    count = sum(any(pixel) for pixel in ImageChops.difference(*images).getdata())
    assert count == row['nonzeroRGBPixels'] and count > 0

print(json.dumps({'hashes': len(seal), 'labels': len(comparisons), 'result': 'PASS',
                  'limits': ['Historical narrowing unexplained', 'Exact raster comparisons fail',
                             'No native60 or full-gallery state equivalence']}))
