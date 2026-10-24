from pathlib import Path
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
import tarfile,tempfile,os
root=Path(__file__).resolve().parent
with tempfile.TemporaryDirectory(prefix='heat-replay-') as tmp:
 with tarfile.open(root/'served-builds.tar.gz') as t:t.extractall(tmp,filter='data')
 os.chdir(tmp)
 print('Serving archived regular files on http://127.0.0.1:18149; Ctrl+C closes the port.',flush=True)
 ThreadingHTTPServer(('127.0.0.1',18149),SimpleHTTPRequestHandler).serve_forever()
