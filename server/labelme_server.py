#!/usr/bin/env python3
"""Small HTTP server for editing Labelme datasets from an iPad app.

The server intentionally uses only Python's standard library so it can run on a
Mac with the system python3. It exposes images from a dataset directory and
reads/writes Labelme-compatible JSON files.
"""

from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import posixpath
import socket
import struct
import tempfile
import time
from dataclasses import dataclass
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from typing import Optional
from urllib.parse import parse_qs, unquote, urlparse


IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".gif", ".webp", ".tif", ".tiff"}
DEFAULT_DATASET = "/Users/koheikato/Downloads/mygarbageseg"


@dataclass(frozen=True)
class ImageRecord:
    id: str
    path: Path
    relative_path: str
    label_path: Path


class Dataset:
    def __init__(self, root: Path, images_dir: str, labels_dir: str) -> None:
        self.root = root.expanduser().resolve()
        self.images_root = (self.root / images_dir).resolve()
        self.labels_root = (self.root / labels_dir).resolve()
        self._records: list[ImageRecord] = []
        self._record_by_id: dict[str, ImageRecord] = {}
        self.refresh()

    def refresh(self) -> None:
        if not self.images_root.exists():
            raise FileNotFoundError(f"images directory not found: {self.images_root}")
        self.labels_root.mkdir(parents=True, exist_ok=True)

        records: list[ImageRecord] = []
        for path in sorted(self.images_root.rglob("*")):
            if not path.is_file() or path.suffix.lower() not in IMAGE_EXTENSIONS:
                continue
            relative_path = path.relative_to(self.images_root).as_posix()
            record_id = encode_id(relative_path)
            label_path = (self.labels_root / Path(relative_path).with_suffix(".json")).resolve()
            records.append(
                ImageRecord(
                    id=record_id,
                    path=path.resolve(),
                    relative_path=relative_path,
                    label_path=label_path,
                )
            )
        self._records = records
        self._record_by_id = {record.id: record for record in records}

    @property
    def records(self) -> list[ImageRecord]:
        return self._records

    def record(self, record_id: str) -> ImageRecord:
        try:
            return self._record_by_id[record_id]
        except KeyError as exc:
            raise KeyError(f"unknown image id: {record_id}") from exc

    def image_items(self, base_url: str, offset: int, limit: int, query: str) -> dict[str, Any]:
        needle = query.strip().lower()
        records = [
            record
            for record in self._records
            if not needle
            or needle in record.relative_path.lower()
            or needle in record.path.stem.lower()
            or needle in " ".join(label_names(record.label_path)).lower()
        ]
        page = records[offset : offset + limit]
        return {
            "datasetRoot": str(self.root),
            "imagesRoot": str(self.images_root),
            "labelsRoot": str(self.labels_root),
            "offset": offset,
            "limit": limit,
            "total": len(records),
            "items": [self._item_payload(record, base_url) for record in page],
        }

    def annotation_payload(self, record: ImageRecord, base_url: str) -> dict[str, Any]:
        if record.label_path.exists():
            payload = read_json(record.label_path)
            if not isinstance(payload, dict):
                payload = {}
        else:
            payload = {}

        width, height = image_size(record.path)
        payload.setdefault("version", "5.5.0")
        payload.setdefault("flags", {})
        payload.setdefault("shapes", [])
        payload["imagePath"] = label_image_path(record.relative_path)
        payload["imageData"] = None
        payload["imageHeight"] = int(payload.get("imageHeight") or height or 0)
        payload["imageWidth"] = int(payload.get("imageWidth") or width or 0)
        payload["imageUrl"] = f"{base_url}/api/image/{record.id}"
        return payload

    def save_annotation(self, record: ImageRecord, payload: dict[str, Any]) -> dict[str, Any]:
        width, height = image_size(record.path)
        cleaned = normalize_labelme_payload(payload, record.relative_path, width, height)
        record.label_path.parent.mkdir(parents=True, exist_ok=True)
        atomic_write_json(record.label_path, cleaned)
        return cleaned

    def health(self) -> dict[str, Any]:
        annotated = sum(1 for record in self._records if record.label_path.exists())
        return {
            "ok": True,
            "datasetRoot": str(self.root),
            "imagesRoot": str(self.images_root),
            "labelsRoot": str(self.labels_root),
            "imageCount": len(self._records),
            "annotatedCount": annotated,
            "hostHint": lan_ip_hint(),
        }

    def _item_payload(self, record: ImageRecord, base_url: str) -> dict[str, Any]:
        width, height = image_size(record.path)
        shape_count = 0
        labels: list[str] = []
        if record.label_path.exists():
            payload = read_json(record.label_path)
            if isinstance(payload, dict):
                shapes = payload.get("shapes") or []
                if isinstance(shapes, list):
                    shape_count = len(shapes)
                    labels = sorted(
                        {
                            str(shape.get("label", "")).strip()
                            for shape in shapes
                            if isinstance(shape, dict) and str(shape.get("label", "")).strip()
                        }
                    )
        return {
            "id": record.id,
            "fileName": record.path.name,
            "stem": record.path.stem,
            "relativePath": record.relative_path,
            "labelPath": str(record.label_path),
            "imageUrl": f"{base_url}/api/image/{record.id}",
            "annotationUrl": f"{base_url}/api/annotation/{record.id}",
            "annotated": record.label_path.exists(),
            "shapeCount": shape_count,
            "labels": labels,
            "imageWidth": width,
            "imageHeight": height,
            "updatedAt": max(record.path.stat().st_mtime, record.label_path.stat().st_mtime if record.label_path.exists() else 0),
        }


class Handler(BaseHTTPRequestHandler):
    dataset: Dataset

    def do_OPTIONS(self) -> None:
        self.send_response(HTTPStatus.NO_CONTENT)
        self._cors_headers()
        self.end_headers()

    def do_GET(self) -> None:
        try:
            parsed = urlparse(self.path)
            path = parsed.path
            query = parse_qs(parsed.query)
            if path in {"/", "/index.html"}:
                self._send_html(status_page(self.dataset.health()))
                return
            if path == "/api/health":
                self._send_json(self.dataset.health())
                return
            if path == "/api/images":
                self.dataset.refresh()
                offset = int(first(query, "offset", "0"))
                limit = max(1, min(int(first(query, "limit", "120")), 500))
                search = first(query, "q", "")
                self._send_json(self.dataset.image_items(self.base_url(), offset, limit, search))
                return
            if path.startswith("/api/image/"):
                record = self.dataset.record(unquote(path.removeprefix("/api/image/")))
                self._send_file(record.path)
                return
            if path.startswith("/api/annotation/"):
                record = self.dataset.record(unquote(path.removeprefix("/api/annotation/")))
                self._send_json(self.dataset.annotation_payload(record, self.base_url()))
                return
            self._send_error(HTTPStatus.NOT_FOUND, "not found")
        except Exception as exc:
            self._send_exception(exc)

    def do_PUT(self) -> None:
        try:
            parsed = urlparse(self.path)
            if not parsed.path.startswith("/api/annotation/"):
                self._send_error(HTTPStatus.NOT_FOUND, "not found")
                return
            record = self.dataset.record(unquote(parsed.path.removeprefix("/api/annotation/")))
            length = int(self.headers.get("Content-Length") or 0)
            body = self.rfile.read(length)
            payload = json.loads(body.decode("utf-8"))
            if not isinstance(payload, dict):
                raise ValueError("request body must be a JSON object")
            saved = self.dataset.save_annotation(record, payload)
            saved["imageUrl"] = f"{self.base_url()}/api/image/{record.id}"
            self._send_json(saved)
        except Exception as exc:
            self._send_exception(exc)

    def log_message(self, format: str, *args: Any) -> None:
        now = time.strftime("%H:%M:%S")
        print(f"[{now}] {self.address_string()} {format % args}")

    def base_url(self) -> str:
        host = self.headers.get("Host") or f"127.0.0.1:{self.server.server_port}"
        return f"http://{host}"

    def _send_json(self, payload: Any, status: HTTPStatus = HTTPStatus.OK) -> None:
        data = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(status)
        self._cors_headers()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _send_html(self, html: str) -> None:
        data = html.encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self._cors_headers()
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _send_file(self, path: Path) -> None:
        content_type = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        data = path.read_bytes()
        self.send_response(HTTPStatus.OK)
        self._cors_headers()
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", "public, max-age=60")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _send_exception(self, exc: Exception) -> None:
        status = HTTPStatus.NOT_FOUND if isinstance(exc, KeyError) else HTTPStatus.BAD_REQUEST
        self._send_error(status, str(exc))

    def _send_error(self, status: HTTPStatus, message: str) -> None:
        self._send_json({"ok": False, "error": message}, status)

    def _cors_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, PUT, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")


def first(query: dict[str, list[str]], key: str, default: str) -> str:
    values = query.get(key)
    return values[0] if values else default


def encode_id(relative_path: str) -> str:
    encoded = base64.urlsafe_b64encode(relative_path.encode("utf-8")).decode("ascii")
    return encoded.rstrip("=")


def decode_id(record_id: str) -> str:
    padding = "=" * ((4 - len(record_id) % 4) % 4)
    return base64.urlsafe_b64decode((record_id + padding).encode("ascii")).decode("utf-8")


def label_image_path(relative_path: str) -> str:
    return posixpath.join("..", "images", relative_path).replace("/", "\\")


def read_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def atomic_write_json(path: Path, payload: dict[str, Any]) -> None:
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=str(path.parent), delete=False) as file:
        json.dump(payload, file, ensure_ascii=False, indent=2)
        file.write("\n")
        temp_name = file.name
    os.replace(temp_name, path)


def normalize_labelme_payload(payload: dict[str, Any], relative_path: str, width: Optional[int], height: Optional[int]) -> dict[str, Any]:
    shapes = payload.get("shapes")
    if not isinstance(shapes, list):
        raise ValueError("Labelme payload requires a shapes array")

    cleaned_shapes = [normalize_shape(shape) for shape in shapes]
    flags = payload.get("flags") if isinstance(payload.get("flags"), dict) else {}
    other = {
        key: value
        for key, value in payload.items()
        if key
        not in {
            "version",
            "flags",
            "shapes",
            "imagePath",
            "imageData",
            "imageHeight",
            "imageWidth",
            "imageUrl",
        }
    }
    cleaned = {
        "version": str(payload.get("version") or "5.5.0"),
        "flags": flags,
        "shapes": cleaned_shapes,
        "imagePath": label_image_path(relative_path),
        "imageData": None,
        "imageHeight": int(payload.get("imageHeight") or height or 0),
        "imageWidth": int(payload.get("imageWidth") or width or 0),
    }
    cleaned.update(other)
    return cleaned


def normalize_shape(shape: Any) -> dict[str, Any]:
    if not isinstance(shape, dict):
        raise ValueError("each shape must be a JSON object")
    label = str(shape.get("label") or "").strip()
    if not label:
        raise ValueError("shape label is required")
    points = shape.get("points")
    if not isinstance(points, list) or not points:
        raise ValueError(f"shape {label!r} requires points")
    cleaned_points: list[list[float]] = []
    for point in points:
        if not isinstance(point, list) or len(point) != 2:
            raise ValueError(f"invalid point in shape {label!r}")
        cleaned_points.append([float(point[0]), float(point[1])])

    group_id = shape.get("group_id")
    if group_id is not None:
        group_id = int(group_id)

    reserved = {
        "label",
        "points",
        "group_id",
        "description",
        "shape_type",
        "flags",
        "mask",
    }
    cleaned = {key: value for key, value in shape.items() if key not in reserved}
    cleaned.update({
        "label": label,
        "points": cleaned_points,
        "group_id": group_id,
        "description": shape.get("description") if isinstance(shape.get("description"), str) else "",
        "shape_type": str(shape.get("shape_type") or "polygon"),
        "flags": shape.get("flags") if isinstance(shape.get("flags"), dict) else {},
        "mask": shape.get("mask") if isinstance(shape.get("mask"), str) else None,
    })
    return cleaned


def label_names(path: Path) -> list[str]:
    if not path.exists():
        return []
    try:
        payload = read_json(path)
        shapes = payload.get("shapes", []) if isinstance(payload, dict) else []
        return [
            str(shape.get("label", "")).strip()
            for shape in shapes
            if isinstance(shape, dict) and str(shape.get("label", "")).strip()
        ]
    except Exception:
        return []


def image_size(path: Path) -> tuple[Optional[int], Optional[int]]:
    try:
        with path.open("rb") as file:
            header = file.read(32)
            if header.startswith(b"\x89PNG\r\n\x1a\n"):
                return struct.unpack(">II", header[16:24])
            if header[:2] == b"\xff\xd8":
                return jpeg_size(path)
    except Exception:
        return (None, None)
    return (None, None)


def jpeg_size(path: Path) -> tuple[Optional[int], Optional[int]]:
    with path.open("rb") as file:
        file.read(2)
        while True:
            marker_prefix = file.read(1)
            if marker_prefix != b"\xff":
                return (None, None)
            marker = file.read(1)
            while marker == b"\xff":
                marker = file.read(1)
            if marker in {b"\xc0", b"\xc1", b"\xc2", b"\xc3", b"\xc5", b"\xc6", b"\xc7", b"\xc9", b"\xca", b"\xcb", b"\xcd", b"\xce", b"\xcf"}:
                file.read(3)
                height, width = struct.unpack(">HH", file.read(4))
                return (width, height)
            size_bytes = file.read(2)
            if len(size_bytes) != 2:
                return (None, None)
            size = struct.unpack(">H", size_bytes)[0]
            if size < 2:
                return (None, None)
            file.seek(size - 2, os.SEEK_CUR)


def lan_ip_hint() -> str:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.connect(("8.8.8.8", 80))
            return sock.getsockname()[0]
    except Exception:
        return "127.0.0.1"


def status_page(health: dict[str, Any]) -> str:
    host_hint = health.get("hostHint", "127.0.0.1")
    return f"""<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Labelme iPad Server</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 32px; line-height: 1.5; }}
    code {{ background: #f1f3f5; padding: 2px 5px; border-radius: 4px; }}
  </style>
</head>
<body>
  <h1>Labelme iPad Server</h1>
  <p>Server is running.</p>
  <ul>
    <li>Dataset: <code>{health.get("datasetRoot")}</code></li>
    <li>Images: <code>{health.get("imageCount")}</code></li>
    <li>Annotated: <code>{health.get("annotatedCount")}</code></li>
  </ul>
  <p>iPad app URL: <code>http://{host_hint}:8765</code></p>
  <p>API: <a href="/api/health">/api/health</a> / <a href="/api/images">/api/images</a></p>
</body>
</html>"""


def make_handler(dataset: Dataset) -> type[Handler]:
    class BoundHandler(Handler):
        pass

    BoundHandler.dataset = dataset
    return BoundHandler


def main() -> None:
    parser = argparse.ArgumentParser(description="Serve a Labelme dataset for the iPad app.")
    parser.add_argument("--dataset", default=DEFAULT_DATASET, help="Dataset root. Defaults to %(default)s")
    parser.add_argument("--images-dir", default="images", help="Images directory under dataset root.")
    parser.add_argument("--labels-dir", default="labels", help="Labels directory under dataset root.")
    parser.add_argument("--host", default="0.0.0.0", help="Bind host.")
    parser.add_argument("--port", type=int, default=8765, help="Bind port.")
    args = parser.parse_args()

    dataset = Dataset(Path(args.dataset), args.images_dir, args.labels_dir)
    server = ThreadingHTTPServer((args.host, args.port), make_handler(dataset))
    hint = lan_ip_hint()
    print(f"Dataset: {dataset.root}")
    print(f"Images:  {dataset.images_root} ({len(dataset.records)} files)")
    print(f"Labels:  {dataset.labels_root}")
    print(f"Open on this Mac: http://127.0.0.1:{args.port}")
    print(f"Use on iPad:      http://{hint}:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server.")


if __name__ == "__main__":
    main()
