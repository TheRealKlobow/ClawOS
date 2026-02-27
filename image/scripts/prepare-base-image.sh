#!/usr/bin/env bash
set -euo pipefail

: "${BASE_IMAGE_PATH:=./out/base/raspios-lite.img}"
: "${OUTPUT_IMAGE_PATH:=./out/clawos-v1.img}"

mkdir -p "$(dirname "$OUTPUT_IMAGE_PATH")"
cp "$BASE_IMAGE_PATH" "$OUTPUT_IMAGE_PATH"
echo "Prepared output image: $OUTPUT_IMAGE_PATH"
