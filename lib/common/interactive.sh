#!/usr/bin/env bash
set -euo pipefail

# Interactive prompts (TTY); non-interactive falls back to defaults.

plume_interactive_prompt() {
  local key="$1"
  local default="${2:-}"
  local label="${3:-${key}}"
  if declare -F plume_interactive_is_noninteractive >/dev/null 2>&1 \
    && plume_interactive_is_noninteractive; then
    printf '%s' "${default}"
    return 0
  fi
  if ! declare -F plume_interactive_enabled >/dev/null 2>&1 \
    || ! plume_interactive_enabled; then
    printf '%s' "${default}"
    return 0
  fi
  local answer=""
  if [[ -n "${default}" ]]; then
    printf '%s [%s]: ' "${label}" "${default}" >&2
  else
    printf '%s: ' "${label}" >&2
  fi
  read -r answer || true
  if [[ -z "${answer}" ]]; then
    printf '%s' "${default}"
  else
    printf '%s' "${answer}"
  fi
}

plume_interactive_confirm_action() {
  local message="${1:-Proceed?}"
  local default_yes="${2:-false}"
  if declare -F plume_interactive_is_noninteractive >/dev/null 2>&1 \
    && plume_interactive_is_noninteractive; then
    return 0
  fi
  if [[ "${PLUME_ASSUME_YES:-false}" == "true" ]]; then
    return 0
  fi
  if declare -F plume_interactive_confirm >/dev/null 2>&1; then
    plume_interactive_confirm "${message}" "${default_yes}"
    return $?
  fi
  return 0
}
