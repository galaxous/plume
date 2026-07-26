#!/usr/bin/env bash
set -euo pipefail

plume_sync_parse_mode() {
  local mode
  mode="$(plume_mode_current)"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --mode=*) mode="${arg#*=}" ;;
    esac
  done
  case "${mode}" in
    native|docker-lite|laradock-bridge) ;;
    *)
      plume_err "invalid mode for sync: ${mode}"
      return 2
      ;;
  esac
  printf '%s' "${mode}"
}

plume_sync_parse_schedule() {
  local schedule="${PLUME_SYNC_CRON_SCHEDULE:-0 * * * *}"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --schedule=*) schedule="${arg#*=}" ;;
    esac
  done
  printf '%s' "${schedule}"
}

plume_sync_cron_marker() {
  echo "# plume-sync-hourly"
}

plume_sync_reconcile_docker_lite() {
  local mode="docker-lite"
  local service running live_port live_https csv="" first="true"

  while IFS= read -r service; do
    [[ -z "${service}" ]] && continue
    running="false"
    if command -v docker >/dev/null 2>&1 && plume_docker_lite_container_running "${service}"; then
      running="true"
    fi
    plume_services_runtime_set "${service}" "running" "${running}" "${mode}"

    live_port="$(plume_docker_lite_live_port "${service}" || true)"
    if [[ "${running}" == "true" && -n "${live_port}" ]]; then
      plume_services_ports_set "${service}" "${live_port}" "${mode}"
    elif [[ "${service}" != "php" && "${service}" != "composer" ]]; then
      plume_services_ports_unset "${service}" "${mode}"
    fi

    if [[ "${service}" == "web" ]]; then
      live_https="$(plume_docker_lite_live_port "web" "443" || true)"
      if [[ "${running}" == "true" && -n "${live_https}" ]]; then
        plume_services_ports_set "web_https" "${live_https}" "${mode}"
      else
        plume_services_ports_unset "web_https" "${mode}"
      fi
    fi

    if [[ "${first}" == "true" ]]; then
      first="false"
      csv="'$(plume_state_db_escape "${service}")'"
    else
      csv="${csv},'$(plume_state_db_escape "${service}")'"
    fi
  done < <(plume_service_names_for_mode "${mode}")

  if [[ -n "${csv}" ]]; then
    plume_state_db_prune_services_not_in_list "${mode}" "${csv}"
  fi
  plume_state_db_append_event "${mode}" "" "sync.state" "docker-lite reconcile completed"
}

plume_sync_reconcile_laradock_bridge() {
  local mode="laradock-bridge"
  local service running live_port live_https csv="" first="true"

  while IFS= read -r service; do
    [[ -z "${service}" ]] && continue
    running="false"
    if command -v docker >/dev/null 2>&1 && plume_laradock_bridge_container_running "${service}"; then
      running="true"
    fi
    plume_services_runtime_set "${service}" "running" "${running}" "${mode}"

    live_port="$(plume_laradock_bridge_live_ports_all "${service}" || true)"
    if [[ -z "${live_port}" ]]; then
      live_port="$(plume_laradock_bridge_live_port "${service}" || true)"
    fi
    if [[ "${running}" == "true" && -n "${live_port}" ]]; then
      plume_services_ports_set "${service}" "${live_port}" "${mode}"
    elif [[ "${service}" != "php" ]]; then
      plume_services_ports_unset "${service}" "${mode}"
    fi

    if [[ "${service}" == "web" || "${service}" == "nginx" || "${service}" == "apache2" || "${service}" == "caddy" || "${service}" == "openresty" ]]; then
      live_https="$(plume_laradock_bridge_live_port "${service}" "443" || true)"
      if [[ "${running}" == "true" && -n "${live_https}" ]]; then
        plume_services_ports_set "web_https" "${live_https}" "${mode}"
      else
        plume_services_ports_unset "web_https" "${mode}"
      fi
    fi

    if [[ "${first}" == "true" ]]; then
      first="false"
      csv="'$(plume_state_db_escape "${service}")'"
    else
      csv="${csv},'$(plume_state_db_escape "${service}")'"
    fi
  done < <(plume_service_names_for_mode "${mode}")

  if [[ -n "${csv}" ]]; then
    plume_state_db_prune_services_not_in_list "${mode}" "${csv}"
  fi
  plume_state_db_append_event "${mode}" "" "sync.state" "laradock-bridge reconcile completed"
}

cmd_sync_state() {
  local mode
  mode="$(plume_sync_parse_mode "$@")" || return 2

  if [[ "${mode}" == "docker-lite" ]]; then
    local target_path compose_file
    target_path="$(plume_services_workspace_parse_path "$@" || true)"
    if [[ -n "${target_path}" ]]; then
      if [[ "${target_path}" != /* ]]; then
        target_path="$(cd "${target_path}" 2>/dev/null && pwd || true)"
      fi
      if [[ -z "${target_path}" || ! -d "${target_path}" ]]; then
        plume_err "invalid --path for sync state: ${target_path}"
        return 2
      fi
      compose_file="${target_path}/docker-compose.yml"
      if [[ ! -f "${compose_file}" ]]; then
        compose_file="${target_path}/compose.yml"
      fi
      if [[ ! -f "${compose_file}" ]]; then
        plume_err "no compose file found under ${target_path} (expected docker-compose.yml or compose.yml)"
        return 2
      fi
      PLUME_RUNTIME_DOCKER_LITE_COMPOSE_FILE="${compose_file}"
      plume_workspace_compose_state_set docker-lite "${compose_file}"
    fi
    plume_sync_reconcile_docker_lite
    plume_info "sync state completed for docker-lite"
    return 0
  fi

  if [[ "${mode}" == "laradock-bridge" ]]; then
    if ! command -v plume_services_laradock_runtime_prepare >/dev/null 2>&1; then
      plume_err "laradock runtime prepare helper is unavailable"
      return 2
    fi
    plume_services_laradock_runtime_prepare "$@" || return 2
    plume_sync_reconcile_laradock_bridge
    plume_info "sync state completed for laradock-bridge"
    return 0
  fi

  plume_state_db_append_event "${mode}" "" "sync.state" "no-op for mode=${mode}"
  plume_info "sync state no-op for mode=${mode}"
}

cmd_sync_cron_install() {
  local mode schedule
  mode="$(plume_sync_parse_mode "$@")" || return 2
  schedule="$(plume_sync_parse_schedule "$@")"
  if ! command -v crontab >/dev/null 2>&1; then
    plume_err "crontab is required"
    return 2
  fi
  local marker script line existing
  marker="$(plume_sync_cron_marker)"
  script="${ROOT_DIR}/plume.sh"
  line="${schedule} cd ${ROOT_DIR} && ${script} sync cron run --mode=${mode} >/dev/null 2>&1 ${marker}"
  existing="$(crontab -l 2>/dev/null || true)"
  existing="$(printf '%s\n' "${existing}" | grep -vF "${marker}" || true)"
  { printf '%s\n' "${existing}"; printf '%s\n' "${line}"; } | sed '/^[[:space:]]*$/d' | crontab -
  plume_info "sync cron installed (${schedule}, mode=${mode})"
}

cmd_sync_cron_remove() {
  if ! command -v crontab >/dev/null 2>&1; then
    plume_err "crontab is required"
    return 2
  fi
  local marker existing
  marker="$(plume_sync_cron_marker)"
  existing="$(crontab -l 2>/dev/null || true)"
  printf '%s\n' "${existing}" | grep -vF "${marker}" | crontab - || true
  plume_info "sync cron removed"
}

cmd_sync_cron_status() {
  if ! command -v crontab >/dev/null 2>&1; then
    plume_err "crontab is required"
    return 2
  fi
  local marker hit
  marker="$(plume_sync_cron_marker)"
  hit="$(crontab -l 2>/dev/null | grep -F "${marker}" || true)"
  if [[ -z "${hit}" ]]; then
    echo "sync-cron: disabled"
  else
    echo "sync-cron: enabled"
    echo "${hit}"
  fi
}

cmd_sync_cron_run() {
  cmd_sync_state "$@"
}

cmd_sync_cron() {
  local sub="${1:-status}"
  shift || true
  case "${sub}" in
    install) cmd_sync_cron_install "$@" ;;
    remove) cmd_sync_cron_remove "$@" ;;
    status) cmd_sync_cron_status "$@" ;;
    run) cmd_sync_cron_run "$@" ;;
    *)
      plume_err "unknown sync cron subcommand: ${sub} (use install|remove|status|run)"
      return 2
      ;;
  esac
}

cmd_sync() {
  local sub="${1:-state}"
  shift || true
  case "${sub}" in
    state) cmd_sync_state "$@" ;;
    cron) cmd_sync_cron "$@" ;;
    *)
      plume_err "unknown sync subcommand: ${sub} (use state|cron)"
      return 2
      ;;
  esac
}
