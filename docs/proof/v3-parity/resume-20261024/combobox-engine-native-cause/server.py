from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from pathlib import Path
import os,json,sys
s=Path('/tmp/beui-gallery-engine-causal-r10');os.chdir(s/'web'/sys.argv[1]);server=ThreadingHTTPServer(('127.0.0.1',0),SimpleHTTPRequestHandler);(s/'server.json').write_text(json.dumps({'port':server.server_port,'pid':os.getpid(),'build':sys.argv[1]}));server.serve_forever()
