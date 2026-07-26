#!/usr/bin/env bash
set -euo pipefail

cmd_context() {
  local active_mode active_path dl_path lb_path
  local lock_state lock_reason

  plume_context_lock_refresh

  active_mode="$(plume_mode_current)"
  active_path="$(plume_mode_path_get "${active_mode}" || true)"
  dl_path="$(plume_mode_path_get docker-lite || true)"
  lb_path="$(plume_mode_path_get laradock-bridge || true)"

  if plume_context_lock_is_active; then
    lock_state="locked"
    lock_reason="$(plume_context_lock_get_value reason || true)"
  else
    lock_state="unlocked"
    lock_reason=""
  fi

  if [[ "${PLUME_OUTPUT:-text}" == "json" ]]; then
    printf '{'
    printf '"lock":{"state":"%s","reason":"%s"},' "${lock_state}" "${lock_reason}"
    printf '"active":{"mode":"%s","path":"%s"},' "${active_mode}" "${active_path}"
    printf '"paths":{"docker_lite":"%s","laradock_bridge":"%s"}' "${dl_path}" "${lb_path}"
    printf '}\n'
    return 0
  fi

  printf '%-20s %-10s %s\n' "KEY" "STATE" "VALUE"
  printf '%-20s %-10s %s\n' "--------------------" "----------" "----------------------------------------"
  printf '%-20s %-10s %s\n' "lock" "${lock_state}" "${lock_reason:-"-"}"
  printf '%-20s %-10s %s\n' "active_mode" "-" "${active_mode}"
  printf '%-20s %-10s %s\n' "active_path" "-" "${active_path:-"-"}"
  printf '%-20s %-10s %s\n' "docker_lite_path" "-" "${dl_path:-"-"}"
  printf '%-20s %-10s %s\n' "laradock_path" "-" "${lb_path:-"-"}"
}
