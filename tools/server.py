#!/usr/bin/env python3
"""Local server for the catalog editor: serves the page, reads and writes cards.json, stores scanned front
images and runs the German OCR (tesseract) for the "Scan card" dialog. Listens on localhost only.

    python tools/server.py            # then open http://127.0.0.1:8765/
"""

import argparse
import json
import os
import sys
import webbrowser
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlsplit

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
sys.path[:0] = [str(HERE), str(HERE / "ocr")]

MAX_BODY = 30 * 1024 * 1024


def _box(values):
    """x0,y0,x1,y1 fractions from a query value, or None."""
    try:
        x0, y0, x1, y1 = (float(v) for v in values[0].split(","))
    except (TypeError, ValueError, IndexError):
        return None
    return (x0, y0, x1, y1) if 0 <= x0 < x1 <= 1 and 0 <= y0 < y1 <= 1 else None


class Handler(SimpleHTTPRequestHandler):
    catalog: Path
    scans: Path
    lang: str

    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(HERE / "editor"), **kw)

    def log_message(self, fmt, *args):
        if "/api/" in str(args[0] if args else ""):
            super().log_message(fmt, *args)

    # A page on another site must not be able to read or overwrite the catalog through the browser
    # (DNS rebinding / cross-site requests), so only our own origin is accepted.
    def _trusted(self):
        host = self.headers.get("Host", "")
        port = self.server.server_address[1]
        if host not in (f"127.0.0.1:{port}", f"localhost:{port}"):
            return False
        origin = self.headers.get("Origin")
        return origin is None or origin == f"http://{host}"

    def _send(self, status, body=b"", ctype="application/json"):
        if isinstance(body, (dict, list)):
            body = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def end_headers(self):
        # Nothing is cached, the page neither, or the browser may keep running an old editor after it changed.
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def _error(self, status, message):
        self._send(status, {"error": message})

    def _body(self):
        length = int(self.headers.get("Content-Length", 0))
        if length > MAX_BODY:
            return None
        return self.rfile.read(length)

    def _scan_path(self, name):
        name = unquote(name)
        if not name.endswith(".jpg") or "/" in name or "\\" in name or name.startswith("."):
            return None
        return self.scans / name

    def do_GET(self):
        if not self._trusted():
            return self._error(HTTPStatus.FORBIDDEN, "untrusted origin")
        path = urlsplit(self.path).path
        if path in ("/", "/index.html"):
            self.path = "/catalog_editor.html"
        if path == "/api/catalog":
            text = self.catalog.read_text(encoding="utf-8") if self.catalog.exists() else ""
            return self._send(HTTPStatus.OK, text.encode("utf-8"), "text/plain; charset=utf-8")
        if path.startswith("/scans/"):
            file = self._scan_path(path.removeprefix("/scans/"))
            if file is None or not file.is_file():
                return self._error(HTTPStatus.NOT_FOUND, "no such scan")
            return self._send(HTTPStatus.OK, file.read_bytes(), "image/jpeg")
        super().do_GET()

    def do_PUT(self):
        if not self._trusted():
            return self._error(HTTPStatus.FORBIDDEN, "untrusted origin")
        path = urlsplit(self.path).path
        data = self._body()
        if data is None:
            return self._error(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, "too large")
        if path == "/api/catalog":
            try:
                from validate_catalog import fill_defaults, find_problems

                # Here too, not only in the editor, so that a page from before a change still saves.
                text, filled = fill_defaults(data.decode("utf-8"))
                for change in filled:
                    print(f"filled in {change}", flush=True)
                data = text.encode("utf-8")
                problems = find_problems(text)
            except ImportError as e:
                return self._error(HTTPStatus.INTERNAL_SERVER_ERROR, f"missing Python package: {e.name}")
            except UnicodeDecodeError as e:
                problems = [f"not UTF-8: {e}"]
            if problems:
                return self._error(HTTPStatus.BAD_REQUEST, "; ".join(problems[:8]))
            tmp = self.catalog.with_suffix(".json.tmp")
            tmp.write_bytes(data)
            os.replace(tmp, self.catalog)
            return self._send(HTTPStatus.OK, {"ok": True})
        if path.startswith("/api/scans/"):
            file = self._scan_path(path.removeprefix("/api/scans/"))
            if file is None:
                return self._error(HTTPStatus.BAD_REQUEST, "bad file name")
            self.scans.mkdir(parents=True, exist_ok=True)
            file.write_bytes(data)
            return self._send(HTTPStatus.OK, {"ok": True})
        self._error(HTTPStatus.NOT_FOUND, "unknown endpoint")

    def do_POST(self):
        if not self._trusted():
            return self._error(HTTPStatus.FORBIDDEN, "untrusted origin")
        endpoint = urlsplit(self.path).path
        if endpoint not in ("/api/ocr", "/api/qr"):
            return self._error(HTTPStatus.NOT_FOUND, "unknown endpoint")
        data = self._body()
        if data is None:
            return self._error(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, "too large")
        try:
            import cv2
            import numpy as np
            from ocr import read_front
            from qr import read_qr

            image = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR)
            if image is None:
                return self._error(HTTPStatus.BAD_REQUEST, "not an image")
            qr = read_qr(image)
            if endpoint == "/api/qr":
                return self._send(HTTPStatus.OK, {"qr": qr})
            # a card with its QR side up has no text to read
            query = parse_qs(urlsplit(self.path).query)
            # title/effect: boxes drawn on this photo; card_title/card_effect: boxes on the card, kept from earlier photos
            photo_boxes = {k: _box(query.get(k)) for k in ("title", "effect")}
            card_boxes = {k: _box(query.get("card_" + k)) for k in ("title", "effect")}
            reading = None if qr else read_front(image, self.lang, photo_boxes, card_boxes)
        except ImportError as e:
            return self._error(HTTPStatus.INTERNAL_SERVER_ERROR, f"missing Python package: {e.name}")
        except Exception as e:  # pytesseract raises TesseractNotFoundError and friends
            return self._error(HTTPStatus.INTERNAL_SERVER_ERROR, f"OCR failed: {e}")
        if reading is None:
            return self._send(HTTPStatus.OK, {"title": "", "effect": "", "effect_ok": False, "qr": qr})
        self._send(HTTPStatus.OK, {**reading._asdict(), "qr": qr})


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--catalog", type=Path, default=REPO / "cards" / "cards.json")
    p.add_argument("--scans", type=Path, default=REPO / "scans")
    p.add_argument("--port", type=int, default=8765)
    p.add_argument("--lang", default="deu")
    p.add_argument("--no-browser", action="store_true")
    args = p.parse_args()
    Handler.catalog, Handler.scans, Handler.lang = args.catalog, args.scans, args.lang
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    url = f"http://127.0.0.1:{args.port}/"
    print(f"Catalog editor at {url}  (catalog: {args.catalog}) - Ctrl+C to stop")
    if not args.no_browser:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
