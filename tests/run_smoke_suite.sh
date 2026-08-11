#!/usr/bin/env bash
# Unified smoke test entrypoint for local and release workflows.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

MODE="release"
ENABLE_LINUX="${PLUME_RUN_LINUX_TESTS:-0}"
PASSED_STEPS=()
SUITE_LABEL=""

usage() {
  cat <<'EOF'
Usage: ./tests/run_smoke_suite.sh [MODE] [OPTIONS]

Modes (default: --release):
  --release       Recommended local pre-release chain (same steps as GitHub smoke-tests.yml):
                  phase10_e2e_matrix, phase14, phase12 (x2), phase13.
                  phase10_e2e_matrix already runs phase11_e2e_matrix inside.
  --ci            Identical step list to .github/workflows/smoke-tests.yml.
  --phase11-full  Every tests/phase11_*_smoke.sh except phase11_e2e_matrix_smoke.sh (sorted).
  --all           Every tests/*smoke*.sh except *e2e_matrix* aggregators (sorted, fail-fast).

Options:
  --linux         Export PLUME_RUN_LINUX_TESTS=1 for this run (phase3 linux matrix in --all).
  -h, --help      Show this help.

Environment (optional passthrough):
  PLUME_RUN_LINUX_TESTS=1     Run Linux prereq matrix inside phase3_prereq_smoke.sh.
  PLUME_RUN_INTEGRATION=1     Real host package installs for phase12_native_host_provision (see README).

Examples:
  ./tests/run_smoke_suite.sh
  ./tests/run_smoke_suite.sh --ci
  ./tests/run_smoke_suite.sh --phase11-full
  PLUME_RUN_LINUX_TESTS=1 ./tests/run_smoke_suite.sh --all
  ./tests/run_smoke_suite.sh --all --linux
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release | --ci | --phase11-full | --all)
      MODE="${1#--}"
      ;;
    --linux)
      ENABLE_LINUX=1
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ "${ENABLE_LINUX}" == "1" ]]; then
  export PLUME_RUN_LINUX_TESTS=1
fi

# Avoid real-host manifest on_first_run during aggregated smokes (see D-108; phase11 covers it).
export PLUME_SKIP_ON_FIRST_RUN_PROVISION="${PLUME_SKIP_ON_FIRST_RUN_PROVISION:-true}"
export PLUME_NONINTERACTIVE="${PLUME_NONINTERACTIVE:-1}"
# Host brew FPM listen path may differ from canonical socket until pool sync; contract smokes check health only.
export PLUME_PHP_FPM_VERIFY_AFTER_START="${PLUME_PHP_FPM_VERIFY_AFTER_START:-false}"

print_summary() {
  local status="$1"
  echo ""
  echo "=== Smoke suite summary (${SUITE_LABEL}, mode=${MODE}) ==="
  if ((${#PASSED_STEPS[@]} > 0)); then
    local step
    for step in "${PASSED_STEPS[@]}"; do
      echo "[PASS] ${step}"
    done
  fi
  if [[ "${status}" == "ok" ]]; then
    echo "Total: ${#PASSED_STEPS[@]} passed"
    echo "run-smoke-suite:ok"
  else
    echo "Failed at: ${FAILED_STEP}"
    echo "Passed before failure: ${#PASSED_STEPS[@]}"
    echo "run-smoke-suite:fail"
  fi
}

FAILED_STEP=""

run_step() {
  local name="$1"
  local script="$2"
  echo "[RUN] ${name}"
  set +e
  bash "./tests/${script}"
  local rc=$?
  set -e
  if [[ "${rc}" -eq 0 ]]; then
    echo "[PASS] ${name}"
    PASSED_STEPS+=("${name}")
    return 0
  fi
  echo "[FAIL] ${name} (exit ${rc})" >&2
  FAILED_STEP="${name}"
  print_summary "fail"
  exit "${rc}"
}

run_ci_release_suite() {
  SUITE_LABEL="ci-release"
  run_step "phase10-e2e-matrix" "phase10_e2e_matrix_smoke.sh"
  run_step "phase14-golden-json" "phase14_golden_json_smoke.sh"
  run_step "phase12-native-host-provision" "phase12_native_host_provision_smoke.sh"
  run_step "phase12-native-host-provision-mailpit" "phase12_native_host_provision_mailpit_smoke.sh"
  run_step "phase12-site-publish-auto-provision-web" "phase12_site_publish_auto_provision_web_smoke.sh"
  run_step "phase13-deploy-apply" "phase13_deploy_apply_smoke.sh"
  run_step "phase15-scheduler-queue" "phase15_scheduler_queue_smoke.sh"
  run_step "phase16-plume-yml-v2" "phase16_plume_yml_v2_smoke.sh"
  run_step "phase17-native-stack-db" "phase17_native_stack_db_smoke.sh"
  run_step "phase17-native-stack-broker" "phase17_native_stack_broker_smoke.sh"
  run_step "phase17-native-stack-webui" "phase17_native_stack_webui_smoke.sh"
  run_step "phase17-native-stack-env" "phase17_native_stack_env_smoke.sh"
  run_step "phase17-native-redis-config" "phase17_native_redis_config_smoke.sh"
  run_step "phase17-native-db-broker-config" "phase17_native_stack_db_broker_config_smoke.sh"
  run_step "phase17-native-phpmyadmin" "phase17_native_phpmyadmin_smoke.sh"
  run_step "phase17-native-db-engine" "phase17_native_db_engine_smoke.sh"
  run_step "phase18-native-pgadmin" "phase18_native_pgadmin_smoke.sh"
}

run_phase11_full_suite() {
  SUITE_LABEL="phase11-full"
  local script
  while IFS= read -r script; do
    local base="${script##*/}"
    local name="${base%.sh}"
    name="${name//_/-}"
    run_step "${name}" "${base}"
  done < <(find "${ROOT_DIR}/tests" -maxdepth 1 -type f -name 'phase11_*_smoke.sh' ! -name 'phase11_e2e_matrix_smoke.sh' | sort)
}

run_all_suite() {
  SUITE_LABEL="all-smokes"
  local script
  while IFS= read -r script; do
    local base="${script##*/}"
    if [[ "${base}" == *e2e_matrix* ]]; then
      continue
    fi
    local name="${base%.sh}"
    name="${name//_/-}"
    run_step "${name}" "${base}"
  done < <(find "${ROOT_DIR}/tests" -maxdepth 1 -type f -name '*smoke*.sh' | sort)
}

echo "run-smoke-suite: mode=${MODE} PLUME_RUN_LINUX_TESTS=${PLUME_RUN_LINUX_TESTS:-0}"

case "${MODE}" in
  release | ci)
    run_ci_release_suite
    ;;
  phase11-full)
    run_phase11_full_suite
    ;;
  all)
    run_all_suite
    ;;
  *)
    echo "Internal error: unknown mode ${MODE}" >&2
    exit 2
    ;;
esac

print_summary "ok"
exit 0
