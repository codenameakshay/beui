from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
import os
os.chdir('/tmp/beui-order-book-deterministic-20261023')
ThreadingHTTPServer(('127.0.0.1',18146),SimpleHTTPRequestHandler).serve_forever()
