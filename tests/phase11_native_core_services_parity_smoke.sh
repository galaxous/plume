#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
SITE_REGISTRY="${TMP_ROOT}/sites"
PROJECT_DIR="${TMP_ROOT}/project"
MOCK_BIN="${TMP_ROOT}/bin"
PMA_SHARE="${TMP_ROOT}/phpmyadmin-share"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${SITE_REGISTRY}" "${PROJECT_DIR}/public" "${MOCK_BIN}" "${PMA_SHARE}"
mkdir -p "${HOME_DIR}/.config/plume"
: > "${HOME_DIR}/.config/plume/.env"
printf '<?php echo "pma";\n' > "${PMA_SHARE}/index.php"

cleanup() {
  if [[ -f "${STATE_DIR}/native-pids/phpmyadmin.pid" ]]; then
    kill "$(cat "${STATE_DIR}/native-pids/phpmyadmin.pid" 2>/dev/null || true)" 2>/dev/null || true
  fi
  if command -v lsof >/dev/null 2>&1; then
    local leak p
    leak="$(lsof -nP -iTCP:8081 -sTCP:LISTEN -t 2>/dev/null || true)"
    for p in ${leak}; do
      if ps -p "${p}" -o command= 2>/dev/null | grep -q 'http.server.*8081'; then
        kill "${p}" 2>/dev/null || true
      fi
    done
  fi
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_SITE_REGISTRY_DIR=${SITE_REGISTRY}"
  "PLUME_SITE_HOSTS_SYNC=false"
  "PLUME_NATIVE_DB_HOSTS_SYNC=false"
  "PLUME_NONINTERACTIVE=1"
)

assert_ok() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
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

env "${BASE_ENV[@]}" ./plume.sh mode use native --force --yes >/dev/null

# 1) php (fpm) parity
assert_ok "php-fpm alias starts php in native" \
  env "${BASE_ENV[@]}" ./plume.sh services up php-fpm --mode=native

# 2) web server parity: driver-based enabled semantics + site add per server
for server in nginx apache2 caddy; do
  assert_ok "web driver status for ${server}" \
    bash -lc "env HOME='${HOME_DIR}' PLUME_STATE_DIR='${STATE_DIR}' PLUME_WEB_SERVER_DRIVER='${server}' ./plume.sh services status --mode=native | grep -q '^${server}[[:space:]]\\+true'"

  SITE_ID="$(env "${BASE_ENV[@]}" ./plume.sh site add --path="${PROJECT_DIR}" --domain="${server}.parity.test" --server="${server}" --publish | tail -n 1)"
  [[ -n "${SITE_ID}" ]] || {
    echo "[FAIL] site add for ${server} should return id" >&2
    exit 1
  }
  env "${BASE_ENV[@]}" ./plume.sh site remove "${SITE_ID}" >/dev/null
done
echo "[PASS] web servers site parity (nginx/apache2/caddy)"

# 3–4) DB + phpMyAdmin parity — hermetic mock (native brew: one SQL formula; D-128)
cat > "${MOCK_BIN}/brew" <<EOF
#!/usr/bin/env bash
case "\$1" in
  --prefix)
    case "\${2:-}" in
      phpmyadmin) echo "${TMP_ROOT}/brew-phpmyadmin" ;;
      mariadb|mysql) echo "${TMP_ROOT}/brew-mysql" ;;
      *) echo "${TMP_ROOT}/brew" ;;
    esac
    exit 0
    ;;
  list) exit 1 ;;
  install)
    if [[ "\${2:-}" == "phpmyadmin" ]]; then
      mkdir -p "${TMP_ROOT}/brew-phpmyadmin/share/phpmyadmin"
      cp -R "${PMA_SHARE}/." "${TMP_ROOT}/brew-phpmyadmin/share/phpmyadmin/"
    fi
    exit 0
    ;;
  services|tap) exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "${MOCK_BIN}/brew"

cat > "${MOCK_BIN}/mysqladmin" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${MOCK_BIN}/mysqladmin"

cat > "${MOCK_BIN}/mysql" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${MOCK_BIN}/mysql"

cat > "${MOCK_BIN}/php" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-S" ]]; then
  port="${2#127.0.0.1:}"
  docroot="$4"
  exec python3 -m http.server "${port}" --bind 127.0.0.1 --directory "${docroot}"
fi
exit 0
EOF
chmod +x "${MOCK_BIN}/php"

DB_MOCK_ENV=(
  "${BASE_ENV[@]}"
  "PATH=${MOCK_BIN}:/usr/bin:/bin"
  "PLUME_NATIVE_HOST_INSTALL_DRIVER=mock"
  "PLUME_SKIP_ON_FIRST_RUN_PROVISION=true"
)

assert_ok "mariadb start native" \
  env "${DB_MOCK_ENV[@]}" PLUME_MARIADB_ENABLED=true PLUME_MYSQL_ENABLED=false \
  ./plume.sh services up mariadb --mode=native
assert_ok "mysql start native" \
  env "${DB_MOCK_ENV[@]}" PLUME_MARIADB_ENABLED=false PLUME_MYSQL_ENABLED=true \
  ./plume.sh services up mysql --mode=native

# 4) phpmyadmin parity with engine routing
assert_ok "phpmyadmin with mariadb engine" \
  env "${DB_MOCK_ENV[@]}" PLUME_MARIADB_ENABLED=true PLUME_MYSQL_ENABLED=false PMA_DB_ENGINE=mariadb \
  ./plume.sh services up phpmyadmin --mode=native

assert_ok "phpmyadmin with mysql engine" \
  env "${DB_MOCK_ENV[@]}" PLUME_MARIADB_ENABLED=false PLUME_MYSQL_ENABLED=true PMA_DB_ENGINE=mysql \
  ./plume.sh services up phpmyadmin --mode=native

assert_fail_code 2 "phpmyadmin invalid engine blocked" \
  env "${DB_MOCK_ENV[@]}" PMA_ARBITRARY=0 PLUME_MARIADB_ENABLED=false PLUME_MYSQL_ENABLED=false PMA_DB_ENGINE=postgres \
  ./plume.sh services up phpmyadmin --mode=native

# 5) laravel-horizon parity + supervisor dependency
assert_fail_code 2 "laravel-horizon blocked without supervisor" \
  env "${BASE_ENV[@]}" PLUME_SUPERVISOR_ENABLED=false ./plume.sh services up laravel-horizon --mode=native

assert_ok "laravel-horizon starts with supervisor enabled" \
  env "${BASE_ENV[@]}" PLUME_SUPERVISOR_ENABLED=true PLUME_HORIZON_ENABLED=true ./plume.sh services up laravel-horizon --mode=native

# 6) redis parity
assert_ok "redis start native" \
  env "${BASE_ENV[@]}" PLUME_REDIS_ENABLED=true ./plume.sh services up redis --mode=native
assert_ok "redis status visible in native" \
  bash -lc "env HOME='${HOME_DIR}' PLUME_STATE_DIR='${STATE_DIR}' PLUME_REDIS_ENABLED=true ./plume.sh services status --mode=native | grep -Eq '^redis[[:space:]]+true[[:space:]]+true'"

echo "phase11-native-core-services-parity-smoke:ok"
