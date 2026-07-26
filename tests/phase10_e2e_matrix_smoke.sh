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

# Native baseline
run_step "phase2-router" "phase2_router_smoke.sh"
run_step "phase4-site" "phase4_site_smoke.sh"
run_step "phase6-native-e2e" "phase6_native_e2e_smoke.sh"
run_step "phase6-service-update-path" "phase6_service_smoke.sh"
run_step "phase9-status-monitor" "phase9_status_monitor_smoke.sh"
run_step "phase10-install-to-operate" "phase10_install_to_operate_smoke.sh"
run_step "phase10-rollback-regression" "phase10_rollback_regression_smoke.sh"

# Laradock-bridge baseline
run_step "phase8-laradock-bootstrap" "phase8_laradock_bootstrap_smoke.sh"
run_step "phase8-laradock-runtime" "phase8_laradock_runtime_smoke.sh"
run_step "phase8-contract-normalization" "phase8_adapter_contract_normalization_smoke.sh"

# Docker-lite is beta-frozen, keep one contract smoke to detect regressions.
run_step "phase7-mode-path-registry" "phase7_mode_path_registry_smoke.sh"

run_step "phase11-e2e-matrix" "phase11_e2e_matrix_smoke.sh"

echo "phase10-e2e-matrix-smoke:ok"
