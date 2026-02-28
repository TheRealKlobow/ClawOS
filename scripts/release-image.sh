#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out"
: "${OUTPUT_IMAGE_PATH:=$OUT_DIR/clawos-pi.img}"
XZ_PATH="$OUTPUT_IMAGE_PATH.xz"
CHECKSUM_PATH="$OUT_DIR/SHA256SUMS.txt"
NOTES_PATH="$OUT_DIR/RELEASE_NOTES.md"

[[ -f "$OUTPUT_IMAGE_PATH" ]] || { echo "ERROR: missing image: $OUTPUT_IMAGE_PATH" >&2; exit 1; }
[[ -f "$XZ_PATH" ]] || { echo "ERROR: missing compressed image: $XZ_PATH" >&2; exit 1; }

mkdir -p "$OUT_DIR"
RUNTIME_BUNDLE_PATH="$(bash "$ROOT_DIR/scripts/build-runtime-bundle.sh")"

(
  cd "$OUT_DIR"
  # Only checksum published artifacts. The raw .img is an intermediate build file and is not released.
  sha256sum "$(basename "$XZ_PATH")" "$(basename "$RUNTIME_BUNDLE_PATH")" >"$(basename "$CHECKSUM_PATH")"
)

cp "$ROOT_DIR/docs/release-notes-template.md" "$NOTES_PATH"

echo "Release files generated:"
echo "- $XZ_PATH"
echo "- $RUNTIME_BUNDLE_PATH"
echo "- $CHECKSUM_PATH"
echo "- $NOTES_PATH"
