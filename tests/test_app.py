import threading
import http.client

from adit_service import app

def _get(host: str, port: int, path: str):
    conn = http.client.HTTPConnection(host, port, timeout=2)
    conn.request("GET", path)
    resp = conn.getresponse()
    body = resp.read().decode("utf-8")
    conn.close()
    return resp.status, body

def test_root_returns_hello():
    server = app.create_server("127.0.0.1", 0)  # 0 = pick a free port
    host, port = server.server_address

    t = threading.Thread(target=server.serve_forever, daemon=True)
    t.start()

    try:
        status, body = _get(host, port, "/")
        assert status == 200
        assert body == "Hello from AWS DevOps test\n"
    finally:
        server.shutdown()
        server.server_close()

def test_health_returns_ok():
    server = app.create_server("127.0.0.1", 0)
    host, port = server.server_address

    t = threading.Thread(target=server.serve_forever, daemon=True)
    t.start()

    try:
        status, body = _get(host, port, "/health")
        assert status == 200
        assert body == "ok\n"
    finally:
        server.shutdown()
        server.server_close()

def test_unknown_path_returns_404():
    server = app.create_server("127.0.0.1", 0)
    host, port = server.server_address

    t = threading.Thread(target=server.serve_forever, daemon=True)
    t.start()

    try:
        status, body = _get(host, port, "/nope")
        assert status == 404
        assert body == "Not found\n"
    finally:
        server.shutdown()
        server.server_close()
