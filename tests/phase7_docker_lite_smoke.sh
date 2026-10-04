#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
BIN_DIR="${TMP_ROOT}/bin"
STATE_FILE="${TMP_ROOT}/docker-state.env"
LOG_FILE="${TMP_ROOT}/docker-calls.log"
COMPOSE_FILE="${TMP_ROOT}/docker-compose.yml"
mkdir -p "${BIN_DIR}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${COMPOSE_FILE}" <<'YAML'
services:
  php-fpm:
    image: php:8.3-fpm
  redis:
    image: redis:7
YAML

cat > "${BIN_DIR}/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${PLUME_TEST_DOCKER_STATE}"
LOG_FILE="${PLUME_TEST_DOCKER_LOG}"

touch "${STATE_FILE}" "${LOG_FILE}"

record() {
  printf '%s\n' "$*" >> "${LOG_FILE}"
}

set_running() {
  local svc="$1"
  if ! grep -q "^${svc}=running$" "${STATE_FILE}" 2>/dev/null; then
    printf '%s=running\n' "${svc}" >> "${STATE_FILE}"
  fi
}

clear_running() {
  local svc="$1"
  grep -v "^${svc}=running$" "${STATE_FILE}" > "${STATE_FILE}.tmp" || true
  mv "${STATE_FILE}.tmp" "${STATE_FILE}"
}

is_running() {
  local svc="$1"
  grep -q "^${svc}=running$" "${STATE_FILE}" 2>/dev/null
}

set_image() {
  local img="$1"
  if ! grep -q "^image:${img}=present$" "${STATE_FILE}" 2>/dev/null; then
    printf 'image:%s=present\n' "${img}" >> "${STATE_FILE}"
  fi
}

has_image() {
  local img="$1"
  grep -q "^image:${img}=present$" "${STATE_FILE}" 2>/dev/null
}

if [[ "${1:-}" == "compose" ]]; then
  shift
  if [[ "${1:-}" == "-f" ]]; then
    shift 2
  fi
  while [[ "${1:-}" == "--profile" ]]; do
    shift 2
  done

  case "${1:-}" in
    version)
      record "compose version"
      echo "Docker Compose version v2.26.0"
      exit 0
      ;;
    pull)
      shift
      svc="${1:-}"
      record "compose pull ${svc}"
      case "${svc}" in
        php-fpm) set_image "php:8.3-fpm" ;;
        redis) set_image "redis:7" ;;
        nginx) set_image "nginx:stable" ;;
      esac
      exit 0
      ;;
    up)
      shift
      if [[ "${1:-}" == "-d" ]]; then
        shift
      fi
      svc="${1:-}"
      record "compose up ${svc}"
      set_running "${svc}"
      exit 0
      ;;
    stop)
      shift
      svc="${1:-}"
      record "compose stop ${svc}"
      clear_running "${svc}"
      exit 0
      ;;
    down)
      record "compose down"
      : > "${STATE_FILE}"
      exit 0
      ;;
    ps)
      shift
      if [[ "${1:-}" == "-q" ]]; then
        shift
        svc="${1:-}"
        if is_running "${svc}"; then
          echo "fake-${svc}-id"
        fi
        exit 0
      fi
      record "compose ps"
      echo "NAME STATE"
      exit 0
      ;;
    logs)
      shift
      if [[ "${1:-}" == "--tail" ]]; then
        shift 2
      fi
      svc="${1:-}"
      record "compose logs ${svc}"
      echo "${svc}: simulated log line"
      exit 0
      ;;
    config)
      shift
      if [[ "${1:-}" == "--images" ]]; then
        record "compose config --images"
        printf '%s\n' "nginx:stable" "php:8.3-fpm" "redis:7"
        exit 0
      fi
      ;;
  esac
fi

if [[ "${1:-}" == "image" && "${2:-}" == "inspect" ]]; then
  img="${3:-}"
  if has_image "${img}"; then
    exit 0
  fi
  exit 1
fi

if [[ "${1:-}" == "pull" ]]; then
  img="${2:-}"
  record "pull ${img}"
  set_image "${img}"
  exit 0
fi

if [[ "${1:-}" == "inspect" ]]; then
  shift
  if [[ "${1:-}" == "-f" ]]; then
    shift 2
  fi
  cid="${1:-}"
  svc="${cid#fake-}"
  svc="${svc%-id}"
  if is_running "${svc}"; then
    echo "true"
  else
    echo "false"
  fi
  exit 0
fi

exit 0
EOF
chmod +x "${BIN_DIR}/docker"

assert_ok() {
  local name="$1"
  shift
  if "$@"; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name}" >&2
    return 1
  fi
}

assert_fail_code() {
  local expected="$1"
  local name="$2"
  shift 2
  set +e
  "$@" >/tmp/plume-phase7-docker-lite.out 2>&1
  local got=$?
  set -e
  if [[ "${got}" -eq "${expected}" ]]; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name} (expected ${expected}, got ${got})" >&2
    cat /tmp/plume-phase7-docker-lite.out >&2
    return 1
  fi
}

BASE_ENV=(
  "PATH=${BIN_DIR}:${PATH}"
  "PLUME_TEST_DOCKER_STATE=${STATE_FILE}"
  "PLUME_TEST_DOCKER_LOG=${LOG_FILE}"
  "PLUME_DOCKER_LITE_COMPOSE_REQUIRED=true"
  "PLUME_DOCKER_LITE_COMPOSE_FILE=${COMPOSE_FILE}"
)

run_base_env() {
  env "${BASE_ENV[@]}" "$@"
}

assert_ok "workspace up works" env "${BASE_ENV[@]}" ./plume.sh services workspace up --mode=docker-lite
assert_ok "workspace status works" env "${BASE_ENV[@]}" ./plume.sh services workspace status --mode=docker-lite
assert_ok "workspace status works with --path override" env "${BASE_ENV[@]}" ./plume.sh services workspace status --mode=docker-lite --path="${TMP_ROOT}"
assert_ok "workspace down works" env "${BASE_ENV[@]}" ./plume.sh services workspace down --mode=docker-lite

assert_ok "docker-lite services up redis" env "${BASE_ENV[@]}" ./plume.sh services up redis --mode=docker-lite
assert_ok "docker-lite services status with --path" env "${BASE_ENV[@]}" ./plume.sh services status --mode=docker-lite --path="${TMP_ROOT}"
health_out="$(run_base_env ./plume.sh services health redis --mode=docker-lite)"
if printf '%s\n' "${health_out}" | grep -q "healthy"; then
  echo "[PASS] docker-lite health redis healthy"
else
  echo "[FAIL] docker-lite health redis healthy" >&2
  exit 1
fi

logs_out="$(run_base_env ./plume.sh services logs redis --mode=docker-lite --tail=10)"
if printf '%s\n' "${logs_out}" | grep -q "simulated log line"; then
  echo "[PASS] docker-lite logs redis from compose"
else
  echo "[FAIL] docker-lite logs redis from compose" >&2
  printf '%s\n' "${logs_out}" >&2
  exit 1
fi

run_base_env ./plume.sh services up php --mode=docker-lite --version=php83 >/tmp/plume-phase7-docker-lite.out 2>&1
assert_ok "docker-lite php alias version parity" grep -q "version=8.3" /tmp/plume-phase7-docker-lite.out
assert_fail_code 2 "workspace command rejects native mode" env "${BASE_ENV[@]}" ./plume.sh services workspace up --mode=native

native_supported="$(./plume.sh --json services supported --mode=native)"
docker_supported="$(run_base_env ./plume.sh --json services supported --mode=docker-lite)"
native_count="$(printf '%s\n' "${native_supported}" | tr ',' '\n' | grep -c '"name"')"
docker_count="$(printf '%s\n' "${docker_supported}" | tr ',' '\n' | grep -c '"name"')"
if [[ "${docker_count}" -lt "${native_count}" ]]; then
  echo "[PASS] docker-lite service set is mode-specific (expected reduced count)"
else
  echo "[FAIL] expected docker-lite service count lower than native (${docker_count} !< ${native_count})" >&2
  exit 1
fi

if printf '%s\n' "${docker_supported}" | grep -q '"name":"composer"'; then
  echo "[FAIL] docker-lite should not expose composer as standalone service" >&2
  exit 1
else
  echo "[PASS] docker-lite composer is not a standalone service"
fi

if printf '%s\n' "${docker_supported}" | grep -q '"name":"horizon"' && printf '%s\n' "${docker_supported}" | grep -q '"name":"supervisor"'; then
  echo "[PASS] docker-lite keeps horizon/supervisor logical services"
else
  echo "[FAIL] docker-lite horizon/supervisor logical services missing" >&2
  exit 1
fi

assert_ok "compose lifecycle calls recorded" grep -Eq "compose up|compose down|compose ps" "${LOG_FILE}"
assert_ok "image preflight calls recorded" grep -Eq "compose config --images|pull nginx:stable|pull php:8.3-fpm|pull redis:7" "${LOG_FILE}"

echo "phase7-docker-lite-smoke:ok"
