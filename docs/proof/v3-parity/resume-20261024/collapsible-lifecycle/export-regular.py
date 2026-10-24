"""Export this archive without symlinks; macOS clones save disk, other hosts copy."""
from pathlib import Path
import ctypes,shutil,sys
root=Path(__file__).resolve().parent
dest=Path(sys.argv[1]).resolve()
assert not dest.exists(), 'Destination must be new'
assert not dest.is_relative_to(root), 'Destination must be outside archive'
libc=ctypes.CDLL(None)
clone=getattr(libc,'clonefile',None)
for p in root.rglob('*'):
 assert not p.is_symlink(),str(p)
 out=dest/p.relative_to(root)
 if p.is_dir():out.mkdir(parents=True,exist_ok=True)
 elif p.is_file():
  out.parent.mkdir(parents=True,exist_ok=True)
  if clone is None or clone(str(p).encode(),str(out).encode(),0)!=0:shutil.copyfile(p,out)
print(dest)
