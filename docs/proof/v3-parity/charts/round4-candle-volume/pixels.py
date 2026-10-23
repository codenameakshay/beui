import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageStat

parser = argparse.ArgumentParser()
parser.add_argument('output')
parser.add_argument('--after', default='after-v3')
parser.add_argument('--after-volume')
parser.add_argument('--before', default='before')
parser.add_argument('--source', default='source')
parser.add_argument('--stills', action='store_true')
args = parser.parse_args()
root = Path(__file__).parent
output = root / args.output
output.mkdir()
rows = []

for chart in ['candle', 'volume']:
    for preference in ['dark-no-preference', 'light-reduce']:
        states = ['rest', 'pointer-a', 'pointer-b', 'home', 'end', 'escape', 'replaced', 'restored', 'reopened', 'empty', 'restored-empty', 'touch-tap', 'touch-move', 'touch-release'] if args.stills else ['rest']
        for state in states:
            final_after = args.after_volume if chart == 'volume' and args.after_volume else args.after
            for phase in [args.before, final_after]:
                def path_for(label):
                    if args.stills:
                        return root / f'stills-{label}-{chart}-{preference}' / f'{state}.png'
                    return root / f'{label}-{chart}-{preference}' / 'original-frames/frame_000000.png'

                reference_path = path_for(args.source)
                candidate_path = path_for(phase)
                if not reference_path.exists() or not candidate_path.exists():
                    raise FileNotFoundError(f'Missing required native state: {reference_path}, {candidate_path}')
                reference_full = Image.open(reference_path).convert('RGB')
                candidate_full = Image.open(candidate_path).convert('RGB')
                assert reference_full.size == candidate_full.size
                regions = {'chart': (348, 340, 932, 704) if chart == 'candle' else (348, 280, 932, 750)}
                if chart == 'candle' and state != 'empty':
                    regions.update(legend=(352, 348, 928, 364), plot=(352, 376, 928, 696))
                if chart == 'volume' and state != 'empty':
                    regions.update(plot=(352, 283, 928, 641), summary=(352, 656, 928, 738))
                for region, box in regions.items():
                    reference = reference_full.crop(box)
                    candidate = candidate_full.crop(box)
                    difference = ImageChops.difference(reference, candidate)
                    deltas = [max(pixel) for pixel in difference.getdata()]
                    changed = sum(delta > 0 for delta in deltas)
                    slug = f'{chart}-{preference}-{state}-{phase}-{region}'
                    row = {'chart': chart, 'preference': preference, 'state': state, 'phase': phase, 'region': region, 'reference': str(reference_path.relative_to(root)), 'candidate': str(candidate_path.relative_to(root)), 'box': box, 'pixels': len(deltas), 'differentPixels': changed, 'differentPercent': changed / len(deltas) * 100, 'pixelsAbove1': sum(delta > 1 for delta in deltas), 'pixelsAbove8': sum(delta > 8 for delta in deltas), 'meanAbsoluteChannelError': sum(ImageStat.Stat(difference).mean) / 3, 'verdict': 'pass' if changed == 0 else 'fail'}
                    if region == 'chart':
                        reference.save(output / f'{slug}-source.png')
                        candidate.save(output / f'{slug}-candidate.png')
                        difference.save(output / f'{slug}-absolute-diff.png')
                        mask = Image.new('RGB', reference.size)
                        mask.putdata([(255, 0, 255) if delta else (0, 0, 0) for delta in deltas])
                        mask.save(output / f'{slug}-changed-pixels.png')
                    rows.append(row)

(output / 'metrics.json').write_text(json.dumps({'method': 'Native RGB comparison at identical viewport coordinates. No alignment, scaling, recoloring, thresholding, or excluded pixels. Above1 and Above8 are supplementary counts only. Any nonzero exact difference fails.', 'rows': rows}, indent=2))
for row in rows:
    if row['region'] == 'chart':
        print(row['chart'], row['preference'], row['state'], row['phase'], row['differentPixels'], f"{row['differentPercent']:.3f}%", row['verdict'])
