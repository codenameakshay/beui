from pathlib import Path
import subprocess,shutil
r=Path.cwd();o=r/'docs/proof/v3-parity/resume-20261023/multiselect-native';o.mkdir(exist_ok=True);t=Path('/tmp/beui-multiselect-native-20261023');t.mkdir(exist_ok=True)
subprocess.run(['git','archive','1254bfa63','lib','assets','shaders','pubspec.yaml','example'],stdout=open(t/'candidate.tar','wb'),check=True)
(t/'candidate').mkdir();subprocess.run(['tar','-xf',str(t/'candidate.tar'),'-C',str(t/'candidate')],check=True)
old=o.parent/'returns-calendar-native'
(o/'build_source.mjs').write_text((old/'build_source.mjs').read_text().replace('returns-calendar-native','multiselect-native'))
(o/'source.css').write_text((old/'source.css').read_text().replace('components/charts/returns-calendar','components/motion/multi-select'))
(o/'base-head.txt').write_text('1254bfa63a70298061c557616abeb9c6a67db372\n')
