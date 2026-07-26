#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
STATE_DIR="${TMP_ROOT}/state"
BIN_DIR="${TMP_ROOT}/bin"
DOCKER_PATH="${TMP_ROOT}/docker-lite"
NEW_PATH="${TMP_ROOT}/new-path"
COMPOSE_FILE="${DOCKER_PATH}/docker-compose.yml"
mkdir -p "${STATE_DIR}" "${BIN_DIR}" "${DOCKER_PATH}" "${NEW_PATH}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${COMPOSE_FILE}" <<'YAML'
services:
  nginx:
    image: nginx:stable
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
    version)
      echo "Docker Compose version v2.26.0"
      exit 0
      ;;
    ps)
      echo "cid-running"
      exit 0
      ;;
  esac
fi
if [[ "${1:-}" == "inspect" && "${2:-}" == "-f" ]]; then
  echo "true"
  exit 0
fi
exit 0
EOF
chmod +x "${BIN_DIR}/docker"

assert_fail_code() {
  local expected="$1"
  shift
  set +e
  "$@" >/tmp/plume-phase7-mode-block-running.out 2>&1
  local got=$?
  set -e
  [[ "${got}" -eq "${expected}" ]]
}

BASE_ENV=("PLUME_STATE_DIR=${STATE_DIR}" "PATH=${BIN_DIR}:${PATH}")

env "${BASE_ENV[@]}" ./plume.sh mode use docker-lite >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set "${DOCKER_PATH}" >/dev/null

assert_fail_code 2 env "${BASE_ENV[@]}" ./plume.sh mode use native --force || {
  echo "[FAIL] mode use native should be blocked when docker-lite containers running" >&2
  cat /tmp/plume-phase7-mode-block-running.out >&2 || true
  exit 1
}

assert_fail_code 2 env "${BASE_ENV[@]}" ./plume.sh mode path set "${NEW_PATH}" --force || {
  echo "[FAIL] mode path set should be blocked when docker-lite containers running" >&2
  cat /tmp/plume-phase7-mode-block-running.out >&2 || true
  exit 1
}

assert_fail_code 2 env "${BASE_ENV[@]}" ./plume.sh mode path clear --force || {
  echo "[FAIL] mode path clear should be blocked when docker-lite containers running" >&2
  cat /tmp/plume-phase7-mode-block-running.out >&2 || true
  exit 1
}

echo "phase7-mode-change-block-running-dockerlite-smoke:ok"
