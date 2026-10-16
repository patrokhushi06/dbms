"""
Laboratory Equipment Booking & Maintenance System - static front-end server.
Serves app.html (and any files next to this script) on http://localhost:5000
"""
import http.server
import socketserver
import os

PORT = 5000
DIRECTORY = os.path.dirname(os.path.abspath(__file__))
APP_TITLE = "Laboratory Equipment Booking & Maintenance System"


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_GET(self):
        if self.path in ("/", ""):
            self.path = "/app.html"
        return super().do_GET()

    def end_headers(self):
        # always serve the latest app.html while developing
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        print(f"{APP_TITLE}\nServing at http://localhost:{PORT}")
        httpd.serve_forever()
