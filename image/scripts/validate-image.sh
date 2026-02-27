#!/usr/bin/env bash
set -euo pipefail

: "${OUTPUT_IMAGE_PATH:=./out/clawos-v1.img}"
[[ -f "$OUTPUT_IMAGE_PATH" ]]

echo "Validated image artifact exists: $OUTPUT_IMAGE_PATH"
