"""Disposable local prefix ingress: root traps production fallback with 418.

TLS uses a locally generated acceptance certificate. No public ingress changes.
"""
import argparse
import http.client
import ssl
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--upstream', required=True, help='isolated Laravel IP:port')
parser.add_argument('--runtime', type=Path, required=True)
args = parser.parse_args()


class Proxy(BaseHTTPRequestHandler):
    def do_request(self):
        if self.path.startswith('/staging/'):
            target, path = args.upstream, self.path[len('/staging'):]
        elif self.path.startswith('/tuf/'):
            if (args.runtime / 'worker-unavailable').exists():
                self.send_error(503)
                return
            target, path = '127.0.0.1:9116', self.path[len('/tuf'):]
        else:
            self.send_error(418, 'Root production fallback trapped')
            return
        if self.headers.get('transfer-encoding', '').lower() == 'chunked':
            chunks = []
            while True:
                size = int(self.rfile.readline().strip().split(b';', 1)[0], 16)
                if not size:
                    self.rfile.readline()
                    break
                chunks.append(self.rfile.read(size))
                self.rfile.read(2)
                if sum(map(len, chunks)) > 12 * 1024**2:
                    self.send_error(413)
                    return
            body = b''.join(chunks)
        else:
            body = self.rfile.read(int(self.headers.get('content-length', 0)))
        headers = {key: value for key, value in self.headers.items() if key.lower() not in {'connection', 'transfer-encoding', 'content-length', 'host'}}
        headers['Content-Length'] = str(len(body))
        headers['Host'] = self.headers.get('Host', '')
        # Record names only: never log capability/bearer/cookie values or signatures.
        if path.startswith('/uploads/'):
            with (args.runtime / 'upload-headers.txt').open('a') as log:
                log.write(','.join(sorted(key.lower() for key in headers)) + '\n')
        connection = http.client.HTTPConnection(target, timeout=30)
        try:
            connection.request(self.command, path, body=body, headers=headers)
            response = connection.getresponse()
            data = response.read()
            self.send_response(response.status)
            for key, value in response.getheaders():
                if key.lower() not in {'connection', 'transfer-encoding', 'content-length'}:
                    self.send_header(key, value)
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        finally:
            connection.close()

    do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = do_HEAD = do_OPTIONS = do_request

    def log_message(self, *args):
        pass


plain_server = ThreadingHTTPServer(('0.0.0.0', 9016), Proxy)
https = ThreadingHTTPServer(('0.0.0.0', 9446), Proxy)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(args.runtime / 'cert.pem', args.runtime / 'key.pem')
https.socket = context.wrap_socket(https.socket, server_side=True)
threading.Thread(target=https.serve_forever, daemon=True).start()
plain_server.serve_forever()
