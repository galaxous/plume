#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
STATE_DIR="${TMP_ROOT}/state"
BIN_DIR="${TMP_ROOT}/bin"
COMPOSE_FILE="${TMP_ROOT}/docker-compose.yml"
mkdir -p "${STATE_DIR}" "${BIN_DIR}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${COMPOSE_FILE}" <<'YAML'
services:
  laravel-horizon:
    image: laradock/laravel-horizon:latest
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
    up|pull|stop|down|ps|config) exit 0 ;;
  esac
fi
if [[ "${1:-}" == "image" && "${2:-}" == "inspect" ]]; then
  exit 0
fi
if [[ "${1:-}" == "inspect" ]]; then
  echo "true"
  exit 0
fi
exit 0
EOF
chmod +x "${BIN_DIR}/docker"

BASE_ENV=(
  "PATH=${BIN_DIR}:${PATH}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true"
  "PLUME_DOCKER_LITE_COMPOSE_FILE=${COMPOSE_FILE}"
  "PLUME_HORIZON_REQUIRE_SUPERVISOR=true"
  "PLUME_SUPERVISOR_ENABLED=false"
  "PLUME_HORIZON_ENABLED=true"
)

env "${BASE_ENV[@]}" ./plume.sh services up horizon --mode=docker-lite >/tmp/plume-phase7-horizon-dep.out 2>&1 || {
  echo "[FAIL] docker-lite horizon should start when mapped with supervisor to same container" >&2
  cat /tmp/plume-phase7-horizon-dep.out >&2 || true
  exit 1
}

echo "phase7-horizon-dependency-dockerlite-smoke:ok"
