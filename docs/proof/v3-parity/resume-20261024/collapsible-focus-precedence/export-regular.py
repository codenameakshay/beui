#!/usr/bin/env python3
from pathlib import Path
import shutil, subprocess, sys
source = Path(__file__).resolve().parent
target = Path(sys.argv[1]).resolve()
assert not target.exists(), 'Use a new export directory'
target.mkdir(parents=True)
for item in source.rglob('*'):
    assert not item.is_symlink(), item
    dest = target / item.relative_to(source)
    if item.is_dir(): dest.mkdir(exist_ok=True)
    elif sys.platform == 'darwin': subprocess.run(['cp', '-c', str(item), str(dest)], check=True)
    else: shutil.copy2(item, dest)
print(target)
