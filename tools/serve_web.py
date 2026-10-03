#!/usr/bin/env python3
"""Serve the Godot Web export with the MIME and security headers it needs.

Usage:
  python3 tools/serve_web.py --directory . --port 8000

The server binds to 0.0.0.0 so Arena live preview can reach it.
"""

from __future__ import annotations

import argparse
import functools
import http.server
import mimetypes
import os
import socketserver
from pathlib import Path


class GodotWebHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".html": "text/html; charset=utf-8",
        ".js": "text/javascript; charset=utf-8",
        ".mjs": "text/javascript; charset=utf-8",
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".worker.js": "text/javascript; charset=utf-8",
        ".png": "image/png",
        ".svg": "image/svg+xml",
        ".json": "application/json; charset=utf-8",
    }

    def guess_type(self, path: str) -> str:
        if path.endswith(".worker.js"):
            return "text/javascript; charset=utf-8"
        guessed = self.extensions_map.get(Path(path).suffix.lower())
        if guessed:
            return guessed
        return mimetypes.guess_type(path)[0] or "application/octet-stream"

    def end_headers(self) -> None:
        # Godot WebAssembly must be served with application/wasm. The headers
        # below also make the page safe for threaded/COEP builds if that option
        # is enabled later, and prevent MIME sniffing problems in browsers.
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Permissions-Policy", "interest-cohort=()")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


def main() -> None:
    parser = argparse.ArgumentParser(description="Serve a Godot Web export.")
    parser.add_argument("--directory", default=".", help="Directory containing index.html/index.wasm/index.js/index.pck")
    parser.add_argument("--host", default="0.0.0.0", help="Bind host")
    parser.add_argument("--port", type=int, default=int(os.environ.get("PORT", "8000")), help="Bind port")
    args = parser.parse_args()

    directory = Path(args.directory).resolve()
    if not directory.exists():
        raise SystemExit(f"Export directory does not exist: {directory}\nRun tools/export_web.sh first.")
    if not (directory / "index.html").exists():
        raise SystemExit(f"{directory}/index.html not found. Run tools/export_web.sh first.")

    handler = functools.partial(GodotWebHandler, directory=str(directory))
    with ReusableTCPServer((args.host, args.port), handler) as httpd:
        print(f"Serving Godot Web export from {directory}")
        print(f"Listening on http://{args.host}:{args.port}")
        httpd.serve_forever()


if __name__ == "__main__":
    main()
