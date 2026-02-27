#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Placeholder: mount image and copy overlays/templates in CI or build host.
# Keep deterministic by only copying tracked files from image/overlays and image/config.

echo "Overlay injection step defined (implement mount/copy in build environment)."
ls -la "$ROOT_DIR/image/overlays" >/dev/null
ls -la "$ROOT_DIR/image/config" >/dev/null
