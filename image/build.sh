#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT_DIR/image/scripts/prepare-base-image.sh"
bash "$ROOT_DIR/image/scripts/inject-overlay.sh"
bash "$ROOT_DIR/image/scripts/enable-services.sh"
bash "$ROOT_DIR/image/scripts/validate-image.sh"

echo "Build flow complete"
