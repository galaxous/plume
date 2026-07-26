#!/usr/bin/env bash
set -euo pipefail

PLUME_OUTPUT="${PLUME_OUTPUT:-text}"
PLUME_ASSUME_YES="${PLUME_ASSUME_YES:-false}"
PLUME_QUIET="${PLUME_QUIET:-false}"
PLUME_ENV_FILE="${PLUME_ENV_FILE:-}"
PLUME_GLOBAL_HELP="${PLUME_GLOBAL_HELP:-false}"
PLUME_GLOBAL_VERSION="${PLUME_GLOBAL_VERSION:-false}"

plume_parse_global_flags() {
  PLUME_PARSED_ARGS=()

  local expect_env_file="false"
  local passthrough="false"
  local arg
  for arg in "$@"; do
    if [[ "${passthrough}" == "true" ]]; then
      PLUME_PARSED_ARGS+=("${arg}")
      continue
    fi
    if [[ "${expect_env_file}" == "true" ]]; then
      PLUME_ENV_FILE="${arg}"
      expect_env_file="false"
      continue
    fi

    case "${arg}" in
      --help|-h) PLUME_GLOBAL_HELP="true" ;;
      --version|-v) PLUME_GLOBAL_VERSION="true" ;;
      --json) PLUME_OUTPUT="json" ;;
      --yes) PLUME_ASSUME_YES="true" ;;
      --quiet) PLUME_QUIET="true" ;;
      --env-file=*) PLUME_ENV_FILE="${arg#--env-file=}" ;;
      --env-file) expect_env_file="true" ;;
      --)
        PLUME_PARSED_ARGS+=("--")
        passthrough="true"
        ;;
      *)
        PLUME_PARSED_ARGS+=("${arg}")
        ;;
    esac
  done

  if [[ "${expect_env_file}" == "true" ]]; then
    plume_err "--env-file requires a value"
    return 2
  fi
}

plume_audit_event() {
  local mode="$1"
  local event="$2"
  local details="${3:-}"
  if declare -F plume_state_db_append_event >/dev/null 2>&1; then
    plume_state_db_append_event "${mode}" "" "${event}" "${details}"
  fi
}

plume_require_yes_for_critical() {
  local mode="${1:-}"
  local event="${2:-critical.operation}"
  local details="${3:-}"
  local help_hint="${4:-Use --yes to confirm non-interactive execution.}"
  if [[ -z "${mode}" ]]; then
    if declare -F plume_mode_current >/dev/null 2>&1; then
      mode="$(plume_mode_current)"
    else
      mode="native"
    fi
  fi
  if [[ "${PLUME_ASSUME_YES:-false}" == "true" ]]; then
    plume_audit_event "${mode}" "${event}.approved" "${details}"
    return 0
  fi
  plume_audit_event "${mode}" "${event}.blocked" "${details}"
  plume_err "critical operation blocked: confirmation required. ${help_hint}"
  return 2
}
