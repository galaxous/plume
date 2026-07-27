#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

grep -q '^PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE=target$' templates/native-local.env.example || {
  echo "[FAIL] local preset must set target auto-sync profile (daily dev)" >&2
  exit 1
}

grep -q '^PLUME_PHP_EXTENSIONS_AUTO_SYNC_PROFILE=target$' templates/native-prod.env.example || {
  echo "[FAIL] prod preset must set target auto-sync profile" >&2
  exit 1
}

echo "phase11-native-env-presets-smoke:ok"
