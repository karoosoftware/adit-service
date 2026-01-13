# app.py
from http.server import BaseHTTPRequestHandler, HTTPServer, ThreadingHTTPServer
from socketserver import ThreadingMixIn
from concurrent.futures import ThreadPoolExecutor
import time

class Handler(BaseHTTPRequestHandler):
    def _send_text(self, status: int, text: str):
        body = (text + "\n").encode("utf-8")
        self.send_response(status)
        self.send_header("Content-type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


    def do_GET(self):
        if self.path == "/health":
            return self._send_text(200, "ok")

        if self.path == "/":
            return self._send_text(200, "Hello from AWS DevOps test")

        return self._send_text(404, "Not found")

class ThreadPoolHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True

    def __init__(self, server_address, RequestHandlerClass, max_workers=10):
        super().__init__(server_address, RequestHandlerClass)
        self.executor = ThreadPoolExecutor(max_workers=max_workers)

    def process_request(self, request, client_address):
        self.executor.submit(self.process_request_thread, request, client_address)


def main():
    server = ThreadPoolHTTPServer(("0.0.0.0", 8080), Handler)
    server.serve_forever()

if __name__ == "__main__":
    main()

