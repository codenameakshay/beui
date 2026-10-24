import http.server,json,os,pathlib
os.chdir('/tmp/beui-rapid-input-20261024/candidate/example/build/web')
s=http.server.ThreadingHTTPServer(('127.0.0.1',0),http.server.SimpleHTTPRequestHandler)
pathlib.Path('/tmp/beui-rapid-input-20261024/server.json').write_text(json.dumps({'pid':os.getpid(),'port':s.server_port}))
s.serve_forever()
