#!/usr/bin/env python3
"""Exercise real HTTP range interruptions without Nix or the upstream server."""
import importlib.util
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import tempfile
import threading
import unittest

spec = importlib.util.spec_from_file_location('prefetch', Path(__file__).with_name('prefetch-archive.py'))
prefetch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prefetch)
DATA = bytes(range(256)) * 256


class RangeTests(unittest.TestCase):
    def run_server(self, ignore=False):
        requests = []
        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                request = self.headers['Range']
                requests.append(request)
                start, end = map(int, request.removeprefix('bytes=').split('-'))
                body = DATA[start:end+1]
                self.send_response(200 if ignore else 206)
                self.send_header('Content-Length', str(len(body)))
                if not ignore:
                    self.send_header('Content-Range', f'bytes {start}-{end}/{len(DATA)}')
                self.end_headers()
                # Deliberately drop the first connection halfway through its body.
                if len(requests) == 1 and not ignore:
                    body = body[:len(body)//2]
                self.wfile.write(body)
                self.close_connection = True
            def log_message(self, *_):
                pass
        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        return f'http://127.0.0.1:{server.server_port}', requests

    def test_resumes_after_dropped_connection(self):
        url, requests = self.run_server()
        with tempfile.TemporaryDirectory() as tmp:
            part = prefetch.fetch_range(url, Path(tmp), 0, len(DATA), len(DATA), retry_delay=0)
            self.assertEqual(part.read_bytes(), DATA)
        self.assertEqual(requests, ['bytes=0-65535', 'bytes=32768-65535'])

    def test_rejects_server_that_ignores_range(self):
        url, _ = self.run_server(ignore=True)
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(RuntimeError, 'ignored or changed range'):
                prefetch.fetch_range(url, Path(tmp), 0, len(DATA), len(DATA), retry_delay=0)


if __name__ == '__main__':
    unittest.main()
