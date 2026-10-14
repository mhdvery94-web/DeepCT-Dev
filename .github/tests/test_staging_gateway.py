"""Local transport/boundary checks using Caddy and controlled HTTP upstreams.

CADDY_BIN=/path/to/caddy python -m unittest discover -s .github/tests -v
Upstreams are fixtures; this does not claim live-host auth/GPU/ingress readiness.
"""
from contextlib import ExitStack
import http.server
import json
import os
from pathlib import Path
import socket
import socketserver
import subprocess
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
CADDY = os.environ.get('CADDY_BIN')


class Upstream(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(json.dumps({'upstream': self.server.identity, 'path': urlsplit(self.path).path}).encode())

    def do_PUT(self):
        self.rfile.read(int(self.headers.get('Content-Length', 0)))
        try:
            self.do_GET()
        except (BrokenPipeError, ConnectionResetError):
            pass  # The gateway closes an upstream stream rejected by its body limit.

    def log_message(self, *args):
        pass


class UnixHTTP(socketserver.UnixStreamServer):
    identity = 'worker'


@unittest.skipUnless(CADDY, 'set CADDY_BIN for local Caddy integration')
class StagingGateway(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.resources = ExitStack()
        cls.addClassCleanup(cls.resources.close)
        cls.http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        cls.directory = cls.resources.enter_context(tempfile.TemporaryDirectory())
        cls.socket_path = str(Path(cls.directory) / 'worker.sock')
        worker = UnixHTTP(cls.socket_path, Upstream)
        legacy = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Upstream)
        legacy.identity = 'legacy'
        for server in (worker, legacy):
            threading.Thread(target=server.serve_forever, daemon=True).start()
            cls.resources.callback(server.server_close)
            cls.resources.callback(server.shutdown)
        cls.ports = []
        for _ in range(3):
            with socket.socket() as probe:
                probe.bind(('127.0.0.1', 0))
                cls.ports.append(probe.getsockname()[1])
        private, public, pi = cls.ports
        tuf = (ROOT / 'deepct-model-server/deploy/Caddyfile.staging').read_text()
        tuf = tuf.replace('100.85.210.125:8001', f'127.0.0.1:{private}')
        tuf = tuf.replace('bind 100.85.210.125', 'bind 127.0.0.1')
        tuf = tuf.replace('127.0.0.1:8003', f'127.0.0.1:{public}')
        tuf = tuf.replace('/home/jihyo-yue/deepct-model-staging/state/worker.sock', cls.socket_path)
        tuf = tuf.replace('127.0.0.1:8000', f'127.0.0.1:{legacy.server_port}')
        pi_config = (ROOT / 'be/deploy/staging/Caddyfile.staging').read_text()
        # Combine site blocks with one global block; staging Pi upstream is a fixture.
        pi_config = pi_config[pi_config.index('http://'):]
        pi_config = pi_config.replace('127.0.0.1:8003', f'127.0.0.1:{pi}')
        pi_config = pi_config.replace('100.85.94.74:8001', f'127.0.0.1:{private}')
        pi_config = pi_config.replace('127.0.0.1:8000', f'127.0.0.1:{legacy.server_port}')
        config = Path(cls.directory) / 'Caddyfile'
        config.write_text(tuf + '\n' + pi_config)
        cls.logs = cls.resources.enter_context(open(Path(cls.directory) / 'caddy.log', 'w+'))
        cls.process = subprocess.Popen([CADDY, 'run', '--config', str(config), '--adapter', 'caddyfile'],
                                       stdout=cls.logs, stderr=cls.logs)
        cls.resources.callback(cls.stop)
        for _ in range(100):
            try:
                cls.http.open(f'http://127.0.0.1:{private}/', timeout=0.2).close()
                return
            except (OSError, urllib.error.URLError):
                if cls.process.poll() is not None:
                    cls.logs.seek(0)
                    raise RuntimeError(cls.logs.read())
                time.sleep(0.05)
        raise RuntimeError('Caddy did not become ready')

    @classmethod
    def stop(cls):
        cls.process.terminate()
        cls.process.wait(timeout=10)

    @classmethod
    def tearDownClass(cls):
        cls.resources.close()

    def request(self, port, path, data=None):
        request = urllib.request.Request(f'http://127.0.0.1:{port}{path}', data=data,
                                         method='PUT' if data is not None else 'GET')
        try:
            with self.http.open(request, timeout=5) as response:
                return response.status, response.read()
        except urllib.error.HTTPError as response:
            return response.code, response.read()

    def test_private_gateway_reaches_unix_worker_and_public_upload_strips_prefix(self):
        private, public, _ = self.ports
        status, body = self.request(private, '/management/uploads/example')
        self.assertEqual((status, json.loads(body)),
                         (200, {'upstream': 'worker', 'path': '/management/uploads/example'}))
        status, body = self.request(public, '/registry/uploads/example', b'chunk')
        self.assertEqual((status, json.loads(body)),
                         (200, {'upstream': 'worker', 'path': '/uploads/example'}))

    def test_public_management_and_catalog_blocked_legacy_fallback_preserved(self):
        _, public, pi = self.ports
        for path in ('/registry/management/uploads/example', '/registry/models', '/registry'):
            with self.subTest(path=path):
                self.assertEqual(self.request(public, path)[0], 404)
        for port in (public, pi):
            status, body = self.request(port, '/api/health')
            self.assertEqual((status, json.loads(body)),
                             (200, {'upstream': 'legacy', 'path': '/api/health'}))
        status, body = self.request(pi, '/staging/api/health')
        self.assertEqual((status, json.loads(body)),
                         (200, {'upstream': 'worker', 'path': '/api/health'}))

    def test_public_chunk_limit_accepts_exactly_four_mib(self):
        self.assertEqual(self.request(self.ports[1], '/registry/uploads/example',
                                      b'x' * (4 * 1024 * 1024))[0], 200)

    def test_public_chunk_body_limit_rejects_more_than_four_mib(self):
        self.assertEqual(self.request(self.ports[1], '/registry/uploads/example',
                                      b'x' * (4 * 1024 * 1024 + 1))[0], 413)
