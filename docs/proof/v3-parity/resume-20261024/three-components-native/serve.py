import http.server,socketserver,pathlib,json,os
p=pathlib.Path(__file__).resolve().parent
os.chdir(p.parents[4]/'example/build/web')
class S(socketserver.TCPServer):allow_reuse_address=False
with S(('127.0.0.1',0),http.server.SimpleHTTPRequestHandler) as s:
 (p/'server.json').write_text(json.dumps({'pid':os.getpid(),'port':s.server_address[1],'root':os.getcwd()}));s.serve_forever()
