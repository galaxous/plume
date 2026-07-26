#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
BIN_DIR="${TMP_ROOT}/bin"
STATE_DIR="${TMP_ROOT}/state"
DOCKER_LOG="${TMP_ROOT}/docker.log"
WORKSPACE_DIR="${TMP_ROOT}/workspace"
COMPOSE_FILE="${WORKSPACE_DIR}/docker-compose.yml"
mkdir -p "${BIN_DIR}" "${STATE_DIR}" "${WORKSPACE_DIR}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${COMPOSE_FILE}" <<'YAML'
services:
  nginx:
    image: nginx:stable
YAML

cat > "${STATE_DIR}/mode-path-docker-lite" <<EOF
${WORKSPACE_DIR}
EOF

cat > "${BIN_DIR}/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "${PLUME_TEST_DOCKER_LOG}"
if [[ "${1:-}" == "compose" ]]; then
  shift
  if [[ "${1:-}" == "-f" ]]; then
    shift 2
  fi
  case "${1:-}" in
    version) echo "Docker Compose version v2.26.0"; exit 0 ;;
    up) exit 0 ;;
    pull) exit 0 ;;
  esac
fi
if [[ "${1:-}" == "image" && "${2:-}" == "inspect" ]]; then
  exit 0
fi
exit 0
EOF
chmod +x "${BIN_DIR}/docker"

cat > "${BIN_DIR}/lsof" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 1
EOF
chmod +x "${BIN_DIR}/lsof"

PATH="${BIN_DIR}:${PATH}" \
PLUME_STATE_DIR="${STATE_DIR}" \
PLUME_TEST_DOCKER_LOG="${DOCKER_LOG}" \
PLUME_DOCKER_LITE_COMPOSE_REQUIRED=false \
./plume.sh services up web --mode=docker-lite >/tmp/plume-phase7-modepath-up.out 2>&1

if grep -q "stub mode: compose not available" /tmp/plume-phase7-modepath-up.out; then
  echo "[FAIL] expected mode path compose resolution; got stub mode warning" >&2
  cat /tmp/plume-phase7-modepath-up.out >&2
  exit 1
fi

grep -q "compose -f ${COMPOSE_FILE} up -d nginx" "${DOCKER_LOG}" || {
  echo "[FAIL] expected docker compose up with mode path compose file" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

echo "phase7-docker-lite-mode-path-services-smoke:ok"
