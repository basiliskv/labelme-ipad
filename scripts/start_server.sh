#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${LABELME_IPAD_PORT:-8765}"
DATASETS=("$@")
if [ "${#DATASETS[@]}" -eq 0 ]; then
  DATASETS=(/Users/koheikato/Downloads/mygarbageseg)
fi

DATASET_ARGS=()
for DATASET in "${DATASETS[@]}"; do
  DATASET_ARGS+=(--dataset "$DATASET")
done

exec python3 -u "$ROOT_DIR/server/labelme_server.py" \
  "${DATASET_ARGS[@]}" \
  --images-dir images \
  --labels-dir labels \
  --host 0.0.0.0 \
  --port "$PORT"
