#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
STATE_DIR="${TMP_ROOT}/state"
DL_PATH="${TMP_ROOT}/dl"
BIN_DIR="${TMP_ROOT}/bin"
mkdir -p "${STATE_DIR}" "${DL_PATH}" "${BIN_DIR}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${DL_PATH}/docker-compose.yml" <<'YAML'
services:
  php-fpm:
    image: php:8.3-fpm
YAML

cat > "${BIN_DIR}/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "compose" ]]; then
  shift
  if [[ "${1:-}" == "-f" ]]; then
    shift 2
  fi
  case "${1:-}" in
    version) echo "Docker Compose version v2.26.0"; exit 0 ;;
    ps) exit 0 ;; # no running containers
  esac
fi
exit 0
EOF
chmod +x "${BIN_DIR}/docker"

cat > "${STATE_DIR}/services_runtime_docker-lite.env" <<'EOF'
php.running=true
redis.running=true
EOF

BASE_ENV=("PLUME_STATE_DIR=${STATE_DIR}" "PATH=${BIN_DIR}:${PATH}")

env "${BASE_ENV[@]}" ./plume.sh mode use docker-lite >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set "${DL_PATH}" >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode use native --force >/dev/null

grep -q "^php.running=false$" "${STATE_DIR}/services_runtime_docker-lite.env" || {
  echo "[FAIL] expected php.running=false after mode switch reconcile" >&2
  cat "${STATE_DIR}/services_runtime_docker-lite.env" >&2 || true
  exit 1
}

grep -q "^redis.running=false$" "${STATE_DIR}/services_runtime_docker-lite.env" || {
  echo "[FAIL] expected redis.running=false after mode switch reconcile" >&2
  cat "${STATE_DIR}/services_runtime_docker-lite.env" >&2 || true
  exit 1
}

echo "phase7-mode-switch-reconcile-dockerlite-state-smoke:ok"
