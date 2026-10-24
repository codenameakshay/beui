from math import ceil
from pathlib import Path

source = Path('/Users/codenameakshay/.t3/worktrees/beui/t3-df4b55e2/lib/src/motion/table/table_header.dart').read_text()
# Guard the copied arithmetic against a concurrent parent repair.
assert '((offset - _tableRuleWidth / 2) / rowHeight).ceil()' in source
assert 'rowHeight + i * rowHeight - offset,' in source
assert 'Rect.fromLTRB(0, rowHeight, size.width, size.height)' in source
h, rule, height, count = 52.0, 1.0, 220.0, 30
for offset in (0, 0.5, 0.75, 26, 52, 52.5, 52.75, 53, 104.75):
    first = max(0, ceil((offset - rule / 2) / h))
    last = min(count, ceil((offset + height - h) / h))
    drawn = set(range(first, last + 1))
    visible = {}
    for i in range(count + 1):
        top = h + i * h - offset
        overlap = min(height, top + rule) - max(h, top)
        if overlap > 0:
            visible[i] = overlap
    missing = {i: overlap for i, overlap in visible.items() if i not in drawn}
    print(f'offset={offset:6.2f} missing_visible_rules={missing}')
    if offset in (0.75, 52.75, 104.75):
        assert missing == {int(offset // h): 0.25}
    else:
        assert not missing
print('Confirmed: positive-area visible rules are omitted for fractional offsets.')
