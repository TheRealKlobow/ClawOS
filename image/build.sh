#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="$ROOT_DIR/out/work/state/build-state.env"

cleanup_with_status() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    echo "ERROR: build failed (state file: $STATE_FILE)" >&2
  fi
  bash "$ROOT_DIR/image/scripts/cleanup.sh" || true
  return $exit_code
}
trap cleanup_with_status EXIT ERR INT TERM

bash "$ROOT_DIR/image/scripts/prepare-base-image.sh"
bash "$ROOT_DIR/image/scripts/inject-overlay.sh"
bash "$ROOT_DIR/image/scripts/mount-overlay.sh"
bash "$ROOT_DIR/image/scripts/provision-runtime.sh"
bash "$ROOT_DIR/image/scripts/enable-services.sh"
bash "$ROOT_DIR/image/scripts/validate-image.sh"

# xz artifact for release
: "${OUTPUT_IMAGE_PATH:=$ROOT_DIR/out/clawos-pi.img}"
xz -T0 -f -k "$OUTPUT_IMAGE_PATH"

echo "Build flow complete"
