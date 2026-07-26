#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

# shellcheck source=../lib/common/log.sh
source "${ROOT_DIR}/lib/common/log.sh"
# shellcheck source=../lib/common/cli.sh
source "${ROOT_DIR}/lib/common/cli.sh"
# shellcheck source=../lib/common/os.sh
source "${ROOT_DIR}/lib/common/os.sh"
# shellcheck source=../lib/common/sites.sh
source "${ROOT_DIR}/lib/common/sites.sh"
# shellcheck source=../lib/common/env.sh
source "${ROOT_DIR}/lib/common/env.sh"
# shellcheck source=../lib/common/macos_permissions.sh
source "${ROOT_DIR}/lib/common/macos_permissions.sh"

TMP_ROOT="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_ROOT}"
}
trap cleanup EXIT

HOME_DIR="${TMP_ROOT}/home"
STATE_DIR="${TMP_ROOT}/state"
SITES_DIR="${HOME_DIR}/.config/plume/sites"
mkdir -p "${SITES_DIR}" "${STATE_DIR}"

export HOME="${HOME_DIR}"
export PLUME_STATE_DIR="${STATE_DIR}"

desktop_path="${HOME}/Desktop/tunnelion"
mkdir -p "${desktop_path}/public"
printf '<?php echo "ok";' > "${desktop_path}/public/index.php"

if [[ "$(uname -s)" == "Darwin" ]]; then
  plume_sites_path_is_macos_tcc_sensitive "${desktop_path}" || {
    echo "[FAIL] Desktop path should be TCC-sensitive on Darwin" >&2
    exit 1
  }
  downloads_path="${HOME}/Downloads/app"
  mkdir -p "${downloads_path}"
  plume_sites_path_is_macos_tcc_sensitive "${downloads_path}" || {
    echo "[FAIL] Downloads path should be TCC-sensitive on Darwin" >&2
    exit 1
  }
fi

sites_path="${HOME}/Sites/clean"
mkdir -p "${sites_path}"
if plume_sites_path_is_macos_tcc_sensitive "${sites_path}"; then
  echo "[FAIL] ~/Sites should not be TCC-sensitive" >&2
  exit 1
fi

suggested="$(plume_macos_permissions_suggest_sites_path "${desktop_path}")"
[[ "${suggested}" == "${HOME}/Sites/tunnelion" ]] || {
  echo "[FAIL] unexpected suggest path: ${suggested}" >&2
  exit 1
}

export PLUME_NONINTERACTIVE=1
plume_macos_permissions_maybe_prompt_site_path "test" "${desktop_path}" "native" || {
  echo "[FAIL] noninteractive should not abort" >&2
  exit 1
}

if [[ "$(uname -s)" == "Darwin" ]]; then
  site_id="site-test-tcc"
  cat > "${SITES_DIR}/${site_id}.yml" <<EOF
id: ${site_id}
mode: native
path: ${desktop_path}
server: nginx
document_root: public
port: 80
status: active
php_version: "8.3"
domains:
  - myapp.test
EOF
  printf 'sites:\n  - %s\n' "${site_id}" > "${SITES_DIR}/index.yml"

  summary="$(plume_sites_macos_tcc_sensitive_site_summary)"
  [[ "${summary}" == *"${site_id}"* ]] || {
    echo "[FAIL] expected site in TCC summary: ${summary}" >&2
    exit 1
  }
fi

RUN=(env "HOME=${HOME_DIR}" "PLUME_STATE_DIR=${STATE_DIR}" "PLUME_AUTO_HOST_BOOTSTRAP=false" "PLUME_NONINTERACTIVE=1")

"${RUN[@]}" ./plume.sh init permissions >/dev/null
"${RUN[@]}" ./plume.sh init permissions --interactive >/dev/null

if [[ "$(uname -s)" == "Darwin" ]]; then
  doc_out="$("${RUN[@]}" ./plume.sh doctor web --mode=native 2>&1 || true)"
  echo "${doc_out}" | grep -q 'init permissions --interactive' || {
    echo "[FAIL] doctor web should hint init permissions --interactive" >&2
    echo "${doc_out}" >&2
    exit 1
  }
fi

echo "phase11_macos_permissions_smoke:ok"
