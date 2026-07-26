#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TMP_ROOT="$(mktemp -d)"
HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
FAKE_BIN="${TMP_ROOT}/fake-bin"
mkdir -p "${HOME_DIR}" "${STATE_DIR}" "${FAKE_BIN}"

cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

cat > "${FAKE_BIN}/php8.4" <<'EOF'
#!/usr/bin/env bash
echo "PHP 8.4.99-cli"
EOF
chmod +x "${FAKE_BIN}/php8.4"

cat > "${FAKE_BIN}/php-fpm-8.4" <<'EOF'
#!/usr/bin/env bash
echo "PHP 8.4.99-fpm"
EOF
chmod +x "${FAKE_BIN}/php-fpm-8.4"

BASE_ENV=(
  "HOME=${HOME_DIR}"
  "PLUME_STATE_DIR=${STATE_DIR}"
  "PLUME_PHP_INSTALLED_VERSIONS=8.4,9.9"
  "PLUME_PHP_DEFAULT_VERSION=8.4"
  "PLUME_PHP_SHIM_SEARCH_PATH=${FAKE_BIN}"
)

out_non_strict="$(env "${BASE_ENV[@]}" ./plume.sh doctor php || true)"
printf '%s\n' "${out_non_strict}" | grep -q '^VERSION  ROLE' || {
  echo "[FAIL] doctor php should print table header" >&2
  printf '%s\n' "${out_non_strict}" >&2
  exit 1
}

printf '%s\n' "${out_non_strict}" | grep -q '^php84' || {
  echo "[FAIL] doctor php should include php84 row" >&2
  printf '%s\n' "${out_non_strict}" >&2
  exit 1
}

printf '%s\n' "${out_non_strict}" | grep -q '^php99' || {
  echo "[FAIL] doctor php should include php99 row" >&2
  printf '%s\n' "${out_non_strict}" >&2
  exit 1
}

set +e
env "${BASE_ENV[@]}" ./plume.sh doctor php --strict >/dev/null 2>&1
rc=$?
set -e
if [[ "${rc}" -ne 2 ]]; then
  echo "[FAIL] doctor php --strict should fail when any configured version is missing binaries" >&2
  exit 1
fi

echo "phase11-doctor-php-smoke:ok"
