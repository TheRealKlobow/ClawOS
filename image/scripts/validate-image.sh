#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
: "${OUTPUT_IMAGE_PATH:=$ROOT_DIR/out/clawos-pi.img}"

[[ -f "$OUTPUT_IMAGE_PATH" ]] || { echo "ERROR: missing output image" >&2; exit 1; }
[[ -s "$OUTPUT_IMAGE_PATH" ]] || { echo "ERROR: output image is empty" >&2; exit 1; }

echo "Validated image artifact exists: $OUTPUT_IMAGE_PATH"
