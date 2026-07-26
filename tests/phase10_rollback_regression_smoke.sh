#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

bash ./tests/phase9_deploy_rollback_smoke.sh
echo "phase10-rollback-regression-smoke:ok"
