#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
BIN_DIR="${TMP_ROOT}/bin"
STATE_DIR="${TMP_ROOT}/state"
DL_PATH="${TMP_ROOT}/docker-lite"
DOCKER_LOG="${TMP_ROOT}/docker.log"
RUN_MARKER="${TMP_ROOT}/running.marker"
mkdir -p "${BIN_DIR}" "${STATE_DIR}" "${DL_PATH}" "${DL_PATH}/conf" "${DL_PATH}/workspace"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${DL_PATH}/docker-compose.yml" <<'YAML'
services:
  workspace:
    image: composer:2
YAML

cat > "${DL_PATH}/.env.docker-lite" <<'EOF'
WORKSPACE_INSTALL_NODE=false
EOF

cat > "${DL_PATH}/conf/nginx.conf" <<'EOF'
server { listen 80; }
EOF

cat > "${DL_PATH}/workspace/Dockerfile" <<'EOF'
FROM composer:2
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
  while [[ "${1:-}" == "--profile" ]]; do
    shift 2
  done
  case "${1:-}" in
    version) exit 0 ;;
    ps)
      shift
      if [[ "${1:-}" == "-q" ]]; then
        if [[ -f "${PLUME_TEST_RUN_MARKER}" ]]; then
          echo "cid-123"
        fi
      fi
      exit 0
      ;;
    up)
      touch "${PLUME_TEST_RUN_MARKER}"
      exit 0
      ;;
    down)
      rm -f "${PLUME_TEST_RUN_MARKER}"
      exit 0
      ;;
  esac
fi
exit 0
EOF
chmod +x "${BIN_DIR}/docker"

BASE_ENV=(
  "PATH=${BIN_DIR}:${PATH}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_TEST_DOCKER_LOG=${DOCKER_LOG}"
  "PLUME_TEST_RUN_MARKER=${RUN_MARKER}"
)

env "${BASE_ENV[@]}" ./plume.sh mode use docker-lite >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set "${DL_PATH}" >/dev/null

# 1) first apply (no snapshot, not running) => up -d
env "${BASE_ENV[@]}" ./plume.sh services workspace apply --mode=docker-lite >/dev/null
grep -q "up -d$" "${DOCKER_LOG}" || {
  echo "[FAIL] first apply should run plain up -d" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

# 2) no change + running => noop (no new up command)
before_up_count="$(grep -c " up -d" "${DOCKER_LOG}" || true)"
env "${BASE_ENV[@]}" ./plume.sh services workspace apply --mode=docker-lite >/dev/null
after_up_count="$(grep -c " up -d" "${DOCKER_LOG}" || true)"
if [[ "${before_up_count}" -ne "${after_up_count}" ]]; then
  echo "[FAIL] second apply should be noop when no changes" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
fi

# 3) config change => force recreate
echo "# changed" >> "${DL_PATH}/conf/nginx.conf"
env "${BASE_ENV[@]}" ./plume.sh services workspace apply --mode=docker-lite >/dev/null
grep -q "up -d --force-recreate$" "${DOCKER_LOG}" || {
  echo "[FAIL] config change should run up -d --force-recreate" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

# 4) context change => force recreate + build
echo "# changed" >> "${DL_PATH}/workspace/Dockerfile"
env "${BASE_ENV[@]}" ./plume.sh services workspace apply --mode=docker-lite >/dev/null
grep -q "up -d --force-recreate --build$" "${DOCKER_LOG}" || {
  echo "[FAIL] context change should run up -d --force-recreate --build" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

echo "phase7-workspace-apply-smoke:ok"
