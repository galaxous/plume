#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
STATE_DIR="${TMP_ROOT}/state"
MOCK_BIN="${TMP_ROOT}/bin"
SHARE="${TMP_ROOT}/phpmyadmin-share"
HOSTS_FILE="${TMP_ROOT}/hosts"
ENV_FILE="${TMP_ROOT}/plume.env"
mkdir -p "${STATE_DIR}" "${MOCK_BIN}" "${SHARE}"
printf '127.0.0.1 localhost\n' > "${HOSTS_FILE}"
: > "${ENV_FILE}"

cleanup() { rm -rf "${TMP_ROOT}"; }
trap cleanup EXIT

cat > "${SHARE}/index.php" <<'EOF'
<?php echo 'pma-ok';
EOF

cat > "${MOCK_BIN}/brew" <<EOF
#!/usr/bin/env bash
case "\$1" in
  --prefix) echo "${TMP_ROOT}/brew-phpmyadmin" ;;
  list) exit 1 ;;
  install) mkdir -p "${TMP_ROOT}/brew-phpmyadmin/share/phpmyadmin"; cp -R "${SHARE}/." "${TMP_ROOT}/brew-phpmyadmin/share/phpmyadmin/"; exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "${MOCK_BIN}/brew"

cat > "${MOCK_BIN}/php" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-S" ]]; then
  port="${2#127.0.0.1:}"
  docroot="$4"
  nohup python3 -m http.server "${port}" --directory "${docroot}" >/dev/null 2>&1 &
  echo $!
  exit 0
fi
exit 0
EOF
chmod +x "${MOCK_BIN}/php"

BASE_ENV=(
  "HOME=${TMP_ROOT}/home"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_ENV_FILE=${ENV_FILE}"
  "PLUME_SERVICES_MANIFEST_FILE=${TMP_ROOT}/no-services-manifest.yml"
  "PLUME_HOSTS_FILE=${HOSTS_FILE}"
  "PLUME_NATIVE_DB_HOSTS_SYNC=true"
  "PATH=${MOCK_BIN}:/usr/bin:/bin"
  "PLUME_NATIVE_HOST_INSTALL_DRIVER=mock"
  "PLUME_PHPMYADMIN_ENABLED=true"
  "PLUME_MARIADB_ENABLED=true"
  "PLUME_MARIADB_PORT=3306"
  "PLUME_MYSQL_ENABLED=true"
  "PLUME_MYSQL_PORT=3307"
  "PMA_PORT=8081"
)

env "${BASE_ENV[@]}" ./plume.sh services install phpmyadmin --mode=native >/dev/null
CFG="${STATE_DIR}/native/phpmyadmin/htdocs/config.inc.php"
[[ -f "${CFG}" ]] || {
  echo "[FAIL] config.inc.php missing" >&2
  exit 1
}
grep -q "verbose'] = 'mariadb'" "${CFG}" || {
  echo "[FAIL] mariadb server entry missing" >&2
  cat "${CFG}" >&2
  exit 1
}
grep -q "verbose'] = 'mysql'" "${CFG}" || {
  echo "[FAIL] mysql server entry missing" >&2
  cat "${CFG}" >&2
  exit 1
}
grep -q "host'] = 'mariadb'" "${CFG}" || {
  echo "[FAIL] mariadb host entry missing" >&2
  cat "${CFG}" >&2
  exit 1
}
grep -q "port'] = '3307'" "${CFG}" || {
  echo "[FAIL] mysql port 3307 missing" >&2
  cat "${CFG}" >&2
  exit 1
}
grep -q "AllowArbitraryServer" "${CFG}" || {
  echo "[FAIL] AllowArbitraryServer missing" >&2
  cat "${CFG}" >&2
  exit 1
}
grep -q $'\tmariadb\t# plume-native-db:mariadb' "${HOSTS_FILE}" || {
  echo "[FAIL] hosts mariadb alias missing" >&2
  cat "${HOSTS_FILE}" >&2
  exit 1
}
grep -q $'\tmysql\t# plume-native-db:mysql' "${HOSTS_FILE}" || {
  echo "[FAIL] hosts mysql alias missing" >&2
  cat "${HOSTS_FILE}" >&2
  exit 1
}
echo "[PASS] phpmyadmin multi-server config + db hosts"

env "${BASE_ENV[@]}" ./plume.sh services up phpmyadmin --mode=native >/dev/null
PID_FILE="${STATE_DIR}/native-pids/phpmyadmin.pid"
[[ -f "${PID_FILE}" ]] || {
  echo "[FAIL] phpmyadmin pid file missing" >&2
  exit 1
}
echo "[PASS] phpmyadmin started pid=$(cat "${PID_FILE}")"

URL="$(env "${BASE_ENV[@]}" ./plume.sh services url phpmyadmin --mode=native)"
echo "${URL}" | grep -q 'url=http://127.0.0.1:8081' || {
  echo "[FAIL] services url phpmyadmin" >&2
  printf '%s\n' "${URL}" >&2
  exit 1
}
echo "[PASS] phpmyadmin url"

echo "phase17-native-phpmyadmin-smoke:ok"
