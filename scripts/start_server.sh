#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATASET="${1:-/Users/koheikato/Downloads/mygarbageseg}"
PORT="${LABELME_IPAD_PORT:-8765}"

exec python3 -u "$ROOT_DIR/server/labelme_server.py" \
  --dataset "$DATASET" \
  --images-dir images \
  --labels-dir labels \
  --host 0.0.0.0 \
  --port "$PORT"
