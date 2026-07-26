#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
BIN_DIR="${TMP_ROOT}/bin"
PROJECT_DIR="${TMP_ROOT}/project"
LOG_FILE="${TMP_ROOT}/commands.log"
mkdir -p "${BIN_DIR}" "${PROJECT_DIR}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${BIN_DIR}/composer" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'composer %s\n' "$*" >> "${PLUME_TEST_CMD_LOG}"
EOF
chmod +x "${BIN_DIR}/composer"

cat > "${BIN_DIR}/php" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'php %s\n' "$*" >> "${PLUME_TEST_CMD_LOG}"
EOF
chmod +x "${BIN_DIR}/php"

cat > "${BIN_DIR}/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'npm %s\n' "$*" >> "${PLUME_TEST_CMD_LOG}"
EOF
chmod +x "${BIN_DIR}/npm"

cat > "${PROJECT_DIR}/composer.json" <<'EOF'
{"name":"plume/test"}
EOF

cat > "${PROJECT_DIR}/.env.example" <<'EOF'
APP_ENV=local
EOF

cat > "${PROJECT_DIR}/artisan" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "${PROJECT_DIR}/artisan"

cat > "${PROJECT_DIR}/package.json" <<'EOF'
{"name":"plume-test","scripts":{"build":"echo build","dev":"echo dev"}}
EOF

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
  "$@" >/dev/null 2>&1
  local got=$?
  set -e
  if [[ "${got}" -eq "${expected}" ]]; then
    echo "[PASS] ${name}"
  else
    echo "[FAIL] ${name} (expected ${expected}, got ${got})" >&2
    return 1
  fi
}

PATH="${BIN_DIR}:${PATH}" \
PLUME_TEST_CMD_LOG="${LOG_FILE}" \
./plume.sh project init \
  --path="${PROJECT_DIR}" \
  --migrate \
  --seed \
  --npm-install \
  --npm-build >/dev/null

assert_ok ".env copied from .env.example" test -f "${PROJECT_DIR}/.env"
assert_ok "composer install called" grep -Fq "composer install" "${LOG_FILE}"
assert_ok "artisan key:generate called" grep -Fq "php artisan key:generate --ansi" "${LOG_FILE}"
assert_ok "artisan storage:link called" grep -Fq "php artisan storage:link" "${LOG_FILE}"
assert_ok "artisan migrate called" grep -Fq "php artisan migrate --force" "${LOG_FILE}"
assert_ok "artisan db:seed called" grep -Fq "php artisan db:seed --force" "${LOG_FILE}"
assert_ok "npm install called" grep -Fq "npm install" "${LOG_FILE}"
assert_ok "npm run build called" grep -Fq "npm run build" "${LOG_FILE}"

PROJECT_DRY="${TMP_ROOT}/project-dry"
mkdir -p "${PROJECT_DRY}"
cat > "${PROJECT_DRY}/composer.json" <<'EOF'
{"name":"plume/test-dry"}
EOF
cat > "${PROJECT_DRY}/.env.example" <<'EOF'
APP_ENV=local
EOF
cat > "${PROJECT_DRY}/artisan" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "${PROJECT_DRY}/artisan"

PATH="${BIN_DIR}:${PATH}" \
PLUME_TEST_CMD_LOG="${LOG_FILE}" \
./plume.sh project init --path="${PROJECT_DRY}" --dry-run >/dev/null

assert_ok "dry-run does not create .env" bash -lc "[[ ! -f \"${PROJECT_DRY}/.env\" ]]"
assert_fail_code 2 "project init missing path fails" ./plume.sh project init

echo "phase4-project-init-smoke:ok"
