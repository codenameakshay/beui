from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
import os
os.chdir('/tmp/returns-revision')
ThreadingHTTPServer(('127.0.0.1',18157),SimpleHTTPRequestHandler).serve_forever()
