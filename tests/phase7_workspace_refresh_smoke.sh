#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
BIN_DIR="${TMP_ROOT}/bin"
STATE_DIR="${TMP_ROOT}/state"
DOCKER_LOG="${TMP_ROOT}/docker.log"
DL_PATH="${TMP_ROOT}/docker-lite"
mkdir -p "${BIN_DIR}" "${STATE_DIR}" "${DL_PATH}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${DL_PATH}/docker-compose.yml" <<'YAML'
services:
  nginx:
    image: nginx:stable
    profiles: ["core"]
YAML

cat > "${BIN_DIR}/docker" <<'EOF'
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
    version|up|pull|stop|down|ps|logs) exit 0 ;;
    config)
      shift
      if [[ "${1:-}" == "--images" ]]; then
        echo "nginx:stable"
      fi
      exit 0
      ;;
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
  "PLUME_TEST_DOCKER_LOG=${DOCKER_LOG}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true"
)

env "${BASE_ENV[@]}" ./plume.sh mode use docker-lite >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set "${DL_PATH}" >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services workspace refresh --mode=docker-lite >/dev/null

grep -Eq "compose -f ${DL_PATH}/docker-compose.yml --profile core --profile web-nginx up -d --force-recreate --build|compose -f ${DL_PATH}/docker-compose.yml --profile web-nginx --profile core up -d --force-recreate --build" "${DOCKER_LOG}" || {
  echo "[FAIL] workspace refresh did not run force-recreate+build compose up" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh services workspace rebuild --mode=docker-lite >/dev/null

grep -Eq "compose -f ${DL_PATH}/docker-compose.yml --profile core --profile web-nginx up -d --force-recreate --build|compose -f ${DL_PATH}/docker-compose.yml --profile web-nginx --profile core up -d --force-recreate --build" "${DOCKER_LOG}" || {
  echo "[FAIL] workspace rebuild alias did not run force-recreate+build compose up" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

echo "phase7-workspace-refresh-smoke:ok"
