from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs
import json
import os
import socket
import time


HOST = os.environ.get("SPEED_TEST_HOST", "127.0.0.1")
PORT = int(os.environ.get("SPEED_TEST_PORT", "8080"))
SERVER_LABEL = os.environ.get("SPEED_TEST_SERVER_LABEL", "Hosted speed test backend")
LOCATION_LABEL = os.environ.get(
    "SPEED_TEST_LOCATION_LABEL",
    socket.gethostname(),
)
PUBLIC_BASE_URL = os.environ.get(
    "SPEED_TEST_PUBLIC_BASE_URL",
    f"http://{HOST}:{PORT}",
)


class SpeedTestHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _set_common_headers(
        self,
        status_code=200,
        content_type="application/json",
        content_length=None,
    ):
        self.send_response(status_code)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Expose-Headers", "Content-Length")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Type", content_type)
        if content_length is not None:
            self.send_header("Content-Length", str(content_length))
        self.end_headers()

    def _write_json(self, payload, status_code=200):
        encoded = json.dumps(payload).encode("utf-8")
        self._set_common_headers(status_code=status_code, content_length=len(encoded))
        self.wfile.write(encoded)

    def do_OPTIONS(self):
        self._set_common_headers(status_code=204, content_length=0)

    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == "/api/meta":
            self._write_json(
                {
                    "serverLabel": SERVER_LABEL,
                    "locationLabel": LOCATION_LABEL,
                    "endpoint": PUBLIC_BASE_URL,
                    "serverTimeMs": int(time.time() * 1000),
                }
            )
            return

        if parsed.path == "/api/ping":
            self._write_json(
                {
                    "ok": True,
                    "serverTimeMs": int(time.time() * 1000),
                    "serverLabel": SERVER_LABEL,
                }
            )
            return

        if parsed.path == "/api/info":
            forwarded_for = self.headers.get("X-Forwarded-For", "")
            client_ip = forwarded_for.split(",")[0].strip() or self.client_address[0]
            self._write_json(
                {
                    "clientIp": client_ip,
                    "provider": "Reported by frontend IP lookup",
                    "regionLabel": "Provided by frontend IP lookup",
                    "serverLabel": SERVER_LABEL,
                    "locationLabel": LOCATION_LABEL,
                    "endpoint": PUBLIC_BASE_URL,
                }
            )
            return

        if parsed.path == "/api/download":
            params = parse_qs(parsed.query)
            total_bytes = int(params.get("bytes", [20 * 1024 * 1024])[0])
            chunk = b"0" * 65536
            self._set_common_headers(
                content_type="application/octet-stream",
                content_length=total_bytes,
            )
            remaining = total_bytes
            while remaining > 0:
                size = min(len(chunk), remaining)
                self.wfile.write(chunk[:size])
                remaining -= size
            return

        self._write_json({"error": "Not found"}, status_code=404)

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path != "/api/upload":
            self._write_json({"error": "Not found"}, status_code=404)
            return

        content_length = int(self.headers.get("Content-Length", "0"))
        _ = self.rfile.read(content_length)
        self._write_json(
            {
                "receivedBytes": content_length,
                "serverTimeMs": int(time.time() * 1000),
            }
        )

    def log_message(self, format, *args):
        print(
            "%s - - [%s] %s"
            % (self.client_address[0], self.log_date_time_string(), format % args)
        )


if __name__ == "__main__":
    server = ThreadingHTTPServer((HOST, PORT), SpeedTestHandler)
    print(f"Speed test backend listening on {PUBLIC_BASE_URL}")
    server.serve_forever()
