#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
STATE_DIR="${TMP_ROOT}/state"
BIN_DIR="${TMP_ROOT}/bin"
DOCKER_LOG="${TMP_ROOT}/docker.log"
DL_PATH="${TMP_ROOT}/docker-lite"
LB_PATH="${TMP_ROOT}/laradock"
mkdir -p "${STATE_DIR}" "${BIN_DIR}" "${DL_PATH}" "${LB_PATH}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${DL_PATH}/docker-compose.yml" <<'YAML'
services:
  workspace: { image: composer:2 }
  php-fpm: { image: php:8.3-fpm }
YAML

cat > "${LB_PATH}/docker-compose.yml" <<'YAML'
services:
  workspace: { image: laradock/workspace }
  php-fpm: { image: laradock/php-fpm }
YAML

cat > "${LB_PATH}/.env" <<'EOF_ENV'
APP_CODE_PATH_HOST=../apps
APP_CODE_PATH_CONTAINER=/var/www
EOF_ENV

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
    version|exec) exit 0 ;;
  esac
fi
exit 0
EOF
chmod +x "${BIN_DIR}/docker"

BASE_ENV=("PLUME_STATE_DIR=${STATE_DIR}" "PATH=${BIN_DIR}:${PATH}" "PLUME_TEST_DOCKER_LOG=${DOCKER_LOG}")

env "${BASE_ENV[@]}" ./plume.sh mode use docker-lite >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set "${DL_PATH}" >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services exec php --mode=docker-lite --cmd=sh --no-tty >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services exec composer --mode=docker-lite --cmd=sh --no-tty >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services exec workspace --mode=docker-lite --no-tty >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services exec workspace --mode=docker-lite --no-tty bash >/dev/null

grep -q "compose -f ${DL_PATH}/docker-compose.yml exec -T php-fpm sh" "${DOCKER_LOG}" || {
  echo "[FAIL] docker-lite exec php did not target php-fpm" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}
grep -q "compose -f ${DL_PATH}/docker-compose.yml exec -T workspace sh" "${DOCKER_LOG}" || {
  echo "[FAIL] docker-lite exec composer did not target workspace" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}
grep -q "compose -f ${DL_PATH}/docker-compose.yml exec -T workspace bash" "${DOCKER_LOG}" || {
  echo "[FAIL] docker-lite exec workspace bash shorthand did not run" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

env "${BASE_ENV[@]}" ./plume.sh mode use laradock-bridge --force >/dev/null
env "${BASE_ENV[@]}" ./plume.sh mode path set "${LB_PATH}" --force >/dev/null
env "${BASE_ENV[@]}" ./plume.sh services exec composer --mode=laradock-bridge --cmd=sh --no-tty >/dev/null

grep -q "compose -f ${LB_PATH}/docker-compose.yml exec -T workspace sh" "${DOCKER_LOG}" || {
  echo "[FAIL] laradock-bridge exec composer did not target workspace" >&2
  cat "${DOCKER_LOG}" >&2 || true
  exit 1
}

set +e
env "${BASE_ENV[@]}" ./plume.sh services exec php --mode=native >/tmp/plume-phase7-services-exec.out 2>&1
code=$?
set -e
if [[ "${code}" -ne 2 ]]; then
  echo "[FAIL] native services exec should fail with exit 2 (got ${code})" >&2
  cat /tmp/plume-phase7-services-exec.out >&2 || true
  exit 1
fi

echo "phase7-services-exec-smoke:ok"
