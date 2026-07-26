#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

run_step() {
  local name="$1"
  local script="$2"
  echo "[RUN] ${name}"
  bash "./tests/${script}"
  echo "[PASS] ${name}"
}

run_step "phase11-native-adapter-contract" "phase11_native_adapter_contract_smoke.sh"
run_step "phase11-native-core-services-parity" "phase11_native_core_services_parity_smoke.sh"
run_step "phase11-native-php-matrix" "phase11_native_php_matrix_smoke.sh"
run_step "phase11-env-autobootstrap" "phase11_env_autobootstrap_smoke.sh"
run_step "phase11-host-onboarding" "phase11_host_onboarding_smoke.sh"
run_step "phase11-macos-permissions" "phase11_macos_permissions_smoke.sh"
run_step "phase11-site-reload-validate" "phase11_site_reload_validate_smoke.sh"
run_step "phase11-services-web-sync-config" "phase11_services_web_sync_config_smoke.sh"
run_step "phase11-services-web-sync-config-reload" "phase11_services_web_sync_config_reload_smoke.sh"

echo "phase11-e2e-matrix-smoke:ok"
