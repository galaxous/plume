#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
BIN_DIR="${TMP_ROOT}/bin"
STATE_DIR="${TMP_ROOT}/state"
DL_PATH="${TMP_ROOT}/docker-lite"
DOCKER_LOG="${TMP_ROOT}/docker.log"
mkdir -p "${BIN_DIR}" "${STATE_DIR}" "${DL_PATH}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${DL_PATH}/docker-compose.yml" <<'YAML'
services:
  workspace: { image: composer:2 }
  php-fpm: { image: php:8.3-fpm }
  nginx: { image: nginx:stable, profiles: ["web-nginx"] }
  caddy: { image: caddy:2, profiles: ["web-caddy"] }
YAML

cat > "${BIN_DIR}/docker" <<'EOF_DOCKER'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${PLUME_TEST_DOCKER_LOG}"
if [[ "${1:-}" == "compose" ]]; then
  shift
  if [[ "${1:-}" == "-f" ]]; then
    shift 2
  fi
  while [[ "${1:-}" == "--profile" ]]; do
    shift 2
  done
  case "${1:-}" in
    version|up|pull|stop|down|rm) exit 0 ;;
    ps)
      shift
      if [[ "${1:-}" == "-q" ]]; then
        echo "cid-123"
      fi
      exit 0
      ;;
    config)
      shift
      if [[ "${1:-}" == "--images" ]]; then
        echo "composer:2"
        echo "php:8.3-fpm"
        echo "nginx:stable"
        echo "caddy:2"
      fi
      exit 0
      ;;
  esac
fi
if [[ "${1:-}" == "image" && "${2:-}" == "inspect" ]]; then
  exit 0
fi
exit 0
EOF_DOCKER
chmod +x "${BIN_DIR}/docker"

BASE_ENV=(
  "PATH=${BIN_DIR}:${PATH}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_TEST_DOCKER_LOG=${DOCKER_LOG}"
  "PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true"
)

env "${BASE_ENV[@]}" ./plume.sh mode use docker-lite >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set "${DL_PATH}" >/dev/null

env "${BASE_ENV[@]}" PLUME_WEB_SERVER_DRIVER=caddy ./plume.sh services workspace apply --mode=docker-lite >/dev/null

grep -Eq "compose -f ${DL_PATH}/docker-compose.yml --profile core --profile web-caddy|compose -f ${DL_PATH}/docker-compose.yml --profile web-caddy --profile core" "${DOCKER_LOG}" || {
  echo "[FAIL] expected web-caddy profile in workspace apply" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

grep -Eq "compose -f ${DL_PATH}/docker-compose.yml --profile core --profile web-caddy up -d caddy|compose -f ${DL_PATH}/docker-compose.yml --profile web-caddy --profile core up -d caddy" "${DOCKER_LOG}" || {
  echo "[FAIL] expected caddy reconcile up" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

grep -Eq "compose -f ${DL_PATH}/docker-compose.yml --profile core --profile web-caddy rm -f -s nginx|compose -f ${DL_PATH}/docker-compose.yml --profile web-caddy --profile core rm -f -s nginx" "${DOCKER_LOG}" || {
  echo "[FAIL] expected nginx reconcile removal" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

echo "phase7-workspace-web-driver-reconcile-smoke:ok"
