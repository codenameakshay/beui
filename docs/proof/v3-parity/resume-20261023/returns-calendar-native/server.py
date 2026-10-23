from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
import os
os.chdir('/tmp/beui-returns-native-20261023')
ThreadingHTTPServer(('127.0.0.1',18155),SimpleHTTPRequestHandler).serve_forever()
