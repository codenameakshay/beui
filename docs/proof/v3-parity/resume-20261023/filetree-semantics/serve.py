import http.server,functools,threading,json,os,time,socket
from pathlib import Path
ports=[18175,18176]
for port in ports:
 s=socket.socket();s.bind(('127.0.0.1',port));s.close()
servers=[]
for port,d in zip(ports,['source','candidate-build']):
 server=http.server.ThreadingHTTPServer(('127.0.0.1',port),functools.partial(http.server.SimpleHTTPRequestHandler,directory=str(Path(__file__).resolve().parent/d)));servers.append(server);threading.Thread(target=server.serve_forever,daemon=True).start()
Path('docs/proof/v3-parity/resume-20261023/filetree-semantics/server-lifecycle.json').write_text(json.dumps({'pid':os.getpid(),'ports':ports,'checkedFree':True,'started':time.time()}))
try:
 while True:time.sleep(1)
finally:
 for s in servers:s.shutdown()
