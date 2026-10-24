import http.server,os,sys
os.chdir(sys.argv[2]);http.server.ThreadingHTTPServer(('127.0.0.1',int(sys.argv[1])),http.server.SimpleHTTPRequestHandler).serve_forever()
