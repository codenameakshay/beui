from pathlib import Path
import shutil
s=Path('/tmp/beui-gallery-engine-causal-r10');o=Path.cwd()/'docs/proof/v3-parity/resume-20261024/combobox-engine-native-cause'
for p in (o/'baseline').rglob('*'):
 if p.is_file():
  dst=s/p.relative_to(o/'baseline'); archive=o/'instrumented'/p.relative_to(o/'baseline');shutil.copy2(dst,archive);shutil.copy2(p,dst)
# Restore the installed unmodified platform artifact, not the instrumented compiled one.
shutil.copy2('/Users/codenameakshay/fvm/default/bin/cache/flutter_web_sdk/kernel/dart2js_platform.dill',s/'sdk/bin/cache/flutter_web_sdk/kernel/dart2js_platform.dill')
