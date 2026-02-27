#!/usr/bin/env bash
set -euo pipefail

bash tests/smoke/boot-test.sh
bash tests/smoke/gateway-test.sh
bash tests/smoke/recovery-test.sh
