#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
STATE_DIR="${TMP_ROOT}/state"
mkdir -p "${STATE_DIR}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${STATE_DIR}/context.lock" <<'EOF'
locked=true
mode=native
path=
reason=services up
updated_at=2026-01-01 00:00:00
EOF

if ! PLUME_STATE_DIR="${STATE_DIR}" ./plume.sh mode use docker-lite >/tmp/plume-phase7-stale-lock.out 2>&1; then
  echo "[FAIL] mode switch should pass when lock is stale (no live workloads)" >&2
  cat /tmp/plume-phase7-stale-lock.out >&2 || true
  exit 1
fi

[[ ! -f "${STATE_DIR}/context.lock" ]] || {
  echo "[FAIL] stale lock should be auto-cleared" >&2
  exit 1
}

MODE_NOW="$(PLUME_STATE_DIR="${STATE_DIR}" ./plume.sh mode current)"
[[ "${MODE_NOW}" == "docker-lite" ]] || {
  echo "[FAIL] expected current mode docker-lite, got ${MODE_NOW}" >&2
  exit 1
}

echo "phase7-mode-stale-lock-auto-clear-smoke:ok"
